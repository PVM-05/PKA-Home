-- ============================================================================
-- Migration: 20261103_02_digital_voting_and_petitions.sql
-- Mục đích: Biểu Quyết Điện Tử (Digital Voting / Online Polling theo Điều 102
--          Luật Nhà ở 2023) & Kiến Nghị Cộng Đồng Cư Dân (D7)
-- ============================================================================

-- ─── 1. BẢNG POLLS (ĐỢT BIỂU QUYẾT & KHẢO SÁT) ─────────────────────────────
CREATE TABLE IF NOT EXISTS polls (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    poll_code VARCHAR(30) UNIQUE,
    building_id UUID REFERENCES buildings(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    description TEXT,
    category VARCHAR(30) NOT NULL DEFAULT 'general', -- general, agm, finance, maintenance, rule
    vote_weight_type VARCHAR(20) NOT NULL DEFAULT 'per_apartment', -- per_apartment, by_area
    choice_type VARCHAR(20) NOT NULL DEFAULT 'single_choice', -- single_choice, multiple_choice, yes_no_abstain
    min_participation_rate NUMERIC(5,2) DEFAULT 50.0, -- % tham gia tối thiểu
    required_approval_rate NUMERIC(5,2) DEFAULT 50.0, -- % tán thành để thông qua
    start_time TIMESTAMPTZ NOT NULL DEFAULT now(),
    end_time TIMESTAMPTZ NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'active', -- draft, active, closed, cancelled
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index tra cứu polls
CREATE INDEX IF NOT EXISTS idx_polls_status_time ON polls(status, start_time, end_time);
CREATE INDEX IF NOT EXISTS idx_polls_building_id ON polls(building_id);

-- ─── 2. BẢNG POLL_OPTIONS (CÁC PHƯƠNG ÁN LỰA CHỌN) ─────────────────────────
CREATE TABLE IF NOT EXISTS poll_options (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    poll_id UUID NOT NULL REFERENCES polls(id) ON DELETE CASCADE,
    option_text TEXT NOT NULL,
    option_order INT DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_poll_options_poll_id ON poll_options(poll_id, option_order);

-- ─── 3. BẢNG POLL_VOTES (PHIẾU BẦU CỦA CĂN HỘ) ─────────────────────────────
CREATE TABLE IF NOT EXISTS poll_votes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    poll_id UUID NOT NULL REFERENCES polls(id) ON DELETE CASCADE,
    apartment_id UUID NOT NULL REFERENCES apartments(id) ON DELETE CASCADE,
    voter_user_id UUID NOT NULL REFERENCES users(id),
    selected_option_ids UUID[] NOT NULL,
    vote_weight NUMERIC(10,2) NOT NULL DEFAULT 1.0, -- m2 nếu by_area, 1.0 nếu per_apartment
    voted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unq_poll_apartment UNIQUE(poll_id, apartment_id)
);

CREATE INDEX IF NOT EXISTS idx_poll_votes_poll_id ON poll_votes(poll_id);
CREATE INDEX IF NOT EXISTS idx_poll_votes_apartment_id ON poll_votes(apartment_id);

-- ─── 4. BẢNG RESIDENT_PETITIONS (KIẾN NGHỊ CƯ DÂN) ─────────────────────────
CREATE TABLE IF NOT EXISTS resident_petitions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    petition_code VARCHAR(30) UNIQUE,
    apartment_id UUID NOT NULL REFERENCES apartments(id) ON DELETE CASCADE,
    author_user_id UUID NOT NULL REFERENCES users(id),
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    category VARCHAR(30) NOT NULL DEFAULT 'general', -- security, hygiene, amenity, noise, other
    image_urls TEXT[] DEFAULT '{}',
    endorsement_count INT DEFAULT 0,
    status VARCHAR(20) NOT NULL DEFAULT 'pending', -- pending, acknowledged, in_progress, resolved, rejected
    official_response TEXT,
    responded_by_staff_id UUID REFERENCES users(id),
    responded_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_petitions_status ON resident_petitions(status);
CREATE INDEX IF NOT EXISTS idx_petitions_apartment_id ON resident_petitions(apartment_id);

-- ─── 5. BẢNG PETITION_ENDORSEMENTS (LƯỢT ĐỒNG THUẬN CỦA CĂN HỘ) ─────────────
CREATE TABLE IF NOT EXISTS petition_endorsements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    petition_id UUID NOT NULL REFERENCES resident_petitions(id) ON DELETE CASCADE,
    apartment_id UUID NOT NULL REFERENCES apartments(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unq_petition_apartment UNIQUE(petition_id, apartment_id)
);

CREATE INDEX IF NOT EXISTS idx_endorsements_petition_id ON petition_endorsements(petition_id);

-- ─── 6. SEQUENCES VÀ TRIGGERS SINH MÃ TỰ ĐỘNG ──────────────────────────────
CREATE SEQUENCE IF NOT EXISTS poll_code_seq START 1;
CREATE SEQUENCE IF NOT EXISTS petition_code_seq START 1;

-- Trigger sinh mã POLL-YYYYMM-XXXXX
CREATE OR REPLACE FUNCTION generate_poll_code()
RETURNS TRIGGER AS $$
DECLARE
    v_prefix TEXT;
    v_seq_num BIGINT;
BEGIN
    IF NEW.poll_code IS NULL OR NEW.poll_code = '' THEN
        v_prefix := 'POLL-' || to_char(NOW(), 'YYYYMM') || '-';
        v_seq_num := nextval('poll_code_seq');
        NEW.poll_code := v_prefix || lpad(v_seq_num::TEXT, 5, '0');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_generate_poll_code ON polls;
CREATE TRIGGER trg_generate_poll_code
BEFORE INSERT ON polls
FOR EACH ROW
EXECUTE FUNCTION generate_poll_code();

-- Trigger sinh mã PET-YYYYMM-XXXXX
CREATE OR REPLACE FUNCTION generate_petition_code()
RETURNS TRIGGER AS $$
DECLARE
    v_prefix TEXT;
    v_seq_num BIGINT;
BEGIN
    IF NEW.petition_code IS NULL OR NEW.petition_code = '' THEN
        v_prefix := 'PET-' || to_char(NOW(), 'YYYYMM') || '-';
        v_seq_num := nextval('petition_code_seq');
        NEW.petition_code := v_prefix || lpad(v_seq_num::TEXT, 5, '0');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_generate_petition_code ON resident_petitions;
CREATE TRIGGER trg_generate_petition_code
BEFORE INSERT ON resident_petitions
FOR EACH ROW
EXECUTE FUNCTION generate_petition_code();

-- Trigger bảo vệ tính bất biến của phiếu bầu khi cuộc biểu quyết đã đóng
CREATE OR REPLACE FUNCTION enforce_poll_vote_immutability()
RETURNS TRIGGER AS $$
DECLARE
    v_poll_status VARCHAR(20);
    v_poll_end TIMESTAMPTZ;
BEGIN
    SELECT status, end_time INTO v_poll_status, v_poll_end FROM polls WHERE id = OLD.poll_id;
    IF v_poll_status = 'closed' OR now() > v_poll_end THEN
        RAISE EXCEPTION 'Cuộc biểu quyết đã kết thúc. Không được phép chỉnh sửa hoặc xóa phiếu bầu!';
    END IF;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_enforce_poll_vote_immutability ON poll_votes;
CREATE TRIGGER trg_enforce_poll_vote_immutability
BEFORE UPDATE OR DELETE ON poll_votes
FOR EACH ROW
EXECUTE FUNCTION enforce_poll_vote_immutability();

-- ─── 7. CÁC RPCs NGHIỆP VỤ BIỂU QUYẾT & KIẾN NGHỊ ──────────────────────────

-- RPC 1: Bỏ phiếu biểu quyết
CREATE OR REPLACE FUNCTION submit_poll_vote(
    p_poll_id UUID,
    p_apartment_id UUID,
    p_voter_user_id UUID,
    p_option_ids UUID[]
)
RETURNS JSONB AS $$
DECLARE
    v_poll RECORD;
    v_apt_area NUMERIC(10,2);
    v_calculated_weight NUMERIC(10,2);
    v_vote_id UUID;
BEGIN
    -- 1. Kiểm tra poll tồn tại và còn hạn
    SELECT * INTO v_poll FROM polls WHERE id = p_poll_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Cuộc biểu quyết không tồn tại');
    END IF;

    IF v_poll.status != 'active' OR now() < v_poll.start_time OR now() > v_poll.end_time THEN
        RETURN jsonb_build_object('success', false, 'message', 'Cuộc biểu quyết hiện không trong thời gian tiếp nhận phiếu');
    END IF;

    -- 2. Kiểm tra căn hộ đã biểu quyết chưa
    IF EXISTS (SELECT 1 FROM poll_votes WHERE poll_id = p_poll_id AND apartment_id = p_apartment_id) THEN
        RETURN jsonb_build_object('success', false, 'message', 'Căn hộ này đã tham gia biểu quyết rồi');
    END IF;

    -- 3. Xác định trọng số phiếu bầu (Điều 102 Luật Nhà ở 2023)
    IF v_poll.vote_weight_type = 'by_area' THEN
        SELECT COALESCE(area, 50.0) INTO v_apt_area FROM apartments WHERE id = p_apartment_id;
        v_calculated_weight := COALESCE(v_apt_area, 50.0);
    ELSE
        v_calculated_weight := 1.0;
    END IF;

    -- 4. Ghi nhận phiếu bầu
    INSERT INTO poll_votes (
        poll_id,
        apartment_id,
        voter_user_id,
        selected_option_ids,
        vote_weight,
        voted_at
    ) VALUES (
        p_poll_id,
        p_apartment_id,
        p_voter_user_id,
        p_option_ids,
        v_calculated_weight,
        now()
    ) RETURNING id INTO v_vote_id;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Gửi phiếu biểu quyết thành công',
        'vote_id', v_vote_id,
        'weight', v_calculated_weight
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC 2: Thống kê kết quả biểu quyết thời gian thực
CREATE OR REPLACE FUNCTION get_poll_results(p_poll_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_poll RECORD;
    v_total_apartments INT;
    v_total_area NUMERIC(12,2);
    v_voted_apartments INT;
    v_voted_area NUMERIC(12,2);
    v_participation_rate NUMERIC(5,2);
    v_options_result JSONB;
    v_is_quorum_met BOOLEAN;
BEGIN
    SELECT * INTO v_poll FROM polls WHERE id = p_poll_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Cuộc biểu quyết không tồn tại');
    END IF;

    -- Lấy tổng số căn và tổng diện tích của tòa nhà (hoặc toàn dự án)
    IF v_poll.building_id IS NOT NULL THEN
        SELECT COUNT(*), COALESCE(SUM(area), 0.0)
        INTO v_total_apartments, v_total_area
        FROM apartments
        WHERE building_id = v_poll.building_id;
    ELSE
        SELECT COUNT(*), COALESCE(SUM(area), 0.0)
        INTO v_total_apartments, v_total_area
        FROM apartments;
    END IF;

    IF v_total_apartments = 0 THEN v_total_apartments := 1; END IF;
    IF v_total_area = 0 THEN v_total_area := 1.0; END IF;

    -- Lấy số căn và diện tích đã biểu quyết
    SELECT COUNT(*), COALESCE(SUM(vote_weight), 0.0)
    INTO v_voted_apartments, v_voted_area
    FROM poll_votes
    WHERE poll_id = p_poll_id;

    -- Tỷ lệ tham gia %
    IF v_poll.vote_weight_type = 'by_area' THEN
        v_participation_rate := ROUND((v_voted_area / v_total_area) * 100, 2);
    ELSE
        v_participation_rate := ROUND((v_voted_apartments::NUMERIC / v_total_apartments::NUMERIC) * 100, 2);
    END IF;

    v_is_quorum_met := v_participation_rate >= COALESCE(v_poll.min_participation_rate, 50.0);

    -- Thống kê từng option
    SELECT jsonb_agg(
        jsonb_build_object(
            'option_id', opt.id,
            'option_text', opt.option_text,
            'vote_count', COALESCE(counts.cnt, 0),
            'vote_weight_sum', COALESCE(counts.weight_sum, 0.0),
            'percent_of_votes', CASE 
                WHEN v_voted_apartments > 0 THEN 
                    CASE 
                        WHEN v_poll.vote_weight_type = 'by_area' THEN ROUND((COALESCE(counts.weight_sum, 0.0) / v_voted_area) * 100, 2)
                        ELSE ROUND((COALESCE(counts.cnt, 0)::NUMERIC / v_voted_apartments::NUMERIC) * 100, 2)
                    END
                ELSE 0.0 
            END
        ) ORDER BY opt.option_order ASC
    ) INTO v_options_result
    FROM poll_options opt
    LEFT JOIN (
        SELECT unnest(selected_option_ids) AS opt_id,
               COUNT(*) AS cnt,
               SUM(vote_weight) AS weight_sum
        FROM poll_votes
        WHERE poll_id = p_poll_id
        GROUP BY opt_id
    ) counts ON opt.id = counts.opt_id
    WHERE opt.poll_id = p_poll_id;

    RETURN jsonb_build_object(
        'success', true,
        'poll_id', v_poll.id,
        'poll_code', v_poll.poll_code,
        'title', v_poll.title,
        'status', v_poll.status,
        'vote_weight_type', v_poll.vote_weight_type,
        'total_apartments', v_total_apartments,
        'voted_apartments', v_voted_apartments,
        'total_area', v_total_area,
        'voted_area', v_voted_area,
        'participation_rate', v_participation_rate,
        'is_quorum_met', v_is_quorum_met,
        'options', COALESCE(v_options_result, '[]'::JSONB)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC 3: Đồng thuận kiến nghị
CREATE OR REPLACE FUNCTION endorse_petition(
    p_petition_id UUID,
    p_apartment_id UUID,
    p_user_id UUID
)
RETURNS JSONB AS $$
DECLARE
    v_new_count INT;
BEGIN
    -- Kiểm tra đã ủng hộ chưa
    IF EXISTS (SELECT 1 FROM petition_endorsements WHERE petition_id = p_petition_id AND apartment_id = p_apartment_id) THEN
        RETURN jsonb_build_object('success', false, 'message', 'Căn hộ của bạn đã bấm đồng thuận kiến nghị này rồi');
    END IF;

    -- Thêm lượt ủng hộ
    INSERT INTO petition_endorsements (petition_id, apartment_id, user_id)
    VALUES (p_petition_id, p_apartment_id, p_user_id);

    -- Cập nhật count
    UPDATE resident_petitions
    SET endorsement_count = endorsement_count + 1,
        updated_at = now()
    WHERE id = p_petition_id
    RETURNING endorsement_count INTO v_new_count;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Đã ghi nhận sự đồng thuận của bạn',
        'endorsement_count', v_new_count
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC 4: Ban Quản Lý cập nhật phản hồi chính thức cho kiến nghị
CREATE OR REPLACE FUNCTION update_petition_response(
    p_petition_id UUID,
    p_status VARCHAR(20),
    p_response TEXT,
    p_staff_id UUID
)
RETURNS JSONB AS $$
BEGIN
    UPDATE resident_petitions
    SET status = p_status,
        official_response = p_response,
        responded_by_staff_id = p_staff_id,
        responded_at = now(),
        updated_at = now()
    WHERE id = p_petition_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Không tìm thấy kiến nghị');
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Cập nhật phản hồi chính thức thành công',
        'status', p_status
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ─── 8. CẤU HÌNH ROW LEVEL SECURITY (RLS) ──────────────────────────────────
ALTER TABLE polls ENABLE ROW LEVEL SECURITY;
ALTER TABLE poll_options ENABLE ROW LEVEL SECURITY;
ALTER TABLE poll_votes ENABLE ROW LEVEL SECURITY;
ALTER TABLE resident_petitions ENABLE ROW LEVEL SECURITY;
ALTER TABLE petition_endorsements ENABLE ROW LEVEL SECURITY;

-- Policy Polls: Mọi người đã xác thực đều có thể xem polls
CREATE POLICY "Anyone authenticated can view polls"
    ON polls FOR SELECT TO authenticated USING (true);

CREATE POLICY "Management can manage polls"
    ON polls FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('admin', 'management')
        )
    );

-- Policy Poll Options: Mọi người xem options
CREATE POLICY "Anyone authenticated can view poll options"
    ON poll_options FOR SELECT TO authenticated USING (true);

CREATE POLICY "Management can manage poll options"
    ON poll_options FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('admin', 'management')
        )
    );

-- Policy Poll Votes: Cư dân xem phiếu của căn hộ mình, BQL xem toàn bộ
CREATE POLICY "Residents view own apartment votes"
    ON poll_votes FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM residents_apartments ra
            WHERE ra.user_id = auth.uid() AND ra.apartment_id = poll_votes.apartment_id
        ) OR EXISTS (
            SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('admin', 'management')
        )
    );

CREATE POLICY "Residents can insert vote for own apartment"
    ON poll_votes FOR INSERT TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM residents_apartments ra
            WHERE ra.user_id = auth.uid() AND ra.apartment_id = poll_votes.apartment_id
        )
    );

-- Policy Petitions: Mọi người xem kiến nghị, Cư dân tạo kiến nghị, BQL cập nhật phản hồi
CREATE POLICY "Anyone authenticated can view petitions"
    ON resident_petitions FOR SELECT TO authenticated USING (true);

CREATE POLICY "Residents can create petitions"
    ON resident_petitions FOR INSERT TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM residents_apartments ra
            WHERE ra.user_id = auth.uid() AND ra.apartment_id = resident_petitions.apartment_id
        )
    );

CREATE POLICY "Management can update petitions"
    ON resident_petitions FOR UPDATE TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('admin', 'management')
        )
    );

-- Policy Petition Endorsements
CREATE POLICY "Anyone authenticated can view endorsements"
    ON petition_endorsements FOR SELECT TO authenticated USING (true);

CREATE POLICY "Residents can insert endorsement"
    ON petition_endorsements FOR INSERT TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM residents_apartments ra
            WHERE ra.user_id = auth.uid() AND ra.apartment_id = petition_endorsements.apartment_id
        )
    );

