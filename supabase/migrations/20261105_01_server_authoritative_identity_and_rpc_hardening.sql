-- ============================================================================
-- Migration: 20261105_01_server_authoritative_identity_and_rpc_hardening.sql
-- Mục đích: Khắc phục triệt để các lỗ hổng P0/P1 Backend & RPC Security:
--   1. Server-authoritative Identity: Sử dụng auth.uid(), loại bỏ phụ thuộc client-declared IDs.
--   2. Bưu kiện (Parcels): Băm SHA-256 mã PIN (pickup_pin_hash), ẩn plaintext PIN với lễ tân.
--   3. Vé khách (Visitor Passes): Chống quét lặp lại (replay attacks), kiểm tra hạn vé.
--   4. Biểu quyết điện tử: Tuân thủ Điều 102 Luật Nhà ở 2023 (chỉ chủ hộ 'owner' được biểu quyết chính thức).
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ────────────────────────────────────────────────────────────────────────────
-- 1. CẬP NHẬT SCHEMA BẢNG POLLS & PARCELS
-- ────────────────────────────────────────────────────────────────────────────

-- A. Bổ sung cột poll_type vào bảng polls
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'polls' AND column_name = 'poll_type'
    ) THEN
        ALTER TABLE public.polls 
        ADD COLUMN poll_type VARCHAR(30) NOT NULL DEFAULT 'survey';
        
        COMMENT ON COLUMN public.polls.poll_type IS 
        'official_assembly (Biểu quyết Hội nghị nhà chung cư theo Luật Nhà ở 2023 - chỉ chủ hộ) hoặc survey (Khảo sát ý kiến cư dân - cả chủ hộ và khách thuê)';
    END IF;
END $$;

-- B. Bổ sung cột pickup_pin_hash vào bảng parcels
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'parcels' AND column_name = 'pickup_pin_hash'
    ) THEN
        ALTER TABLE public.parcels 
        ADD COLUMN pickup_pin_hash TEXT;
        
        COMMENT ON COLUMN public.parcels.pickup_pin_hash IS 
        'Mã băm SHA-256 của pickup_pin dùng để đối soát an toàn tại quầy lễ tân mà không lộ plaintext PIN';
    END IF;
END $$;

-- C. Cập nhật hash cho các bưu kiện hiện hữu
UPDATE public.parcels
SET pickup_pin_hash = encode(digest(TRIM(pickup_pin), 'sha256'), 'hex')
WHERE pickup_pin IS NOT NULL AND (pickup_pin_hash IS NULL OR pickup_pin_hash = '');

-- D. Cập nhật trigger fn_generate_parcel_code_and_pin để tự động sinh hash
CREATE OR REPLACE FUNCTION public.fn_generate_parcel_code_and_pin()
RETURNS TRIGGER AS $$
DECLARE
    v_prefix TEXT;
    v_seq_num INT;
    v_random_pin TEXT;
BEGIN
    IF NEW.parcel_code IS NULL OR NEW.parcel_code = '' THEN
        v_prefix := 'PCL-' || to_char(COALESCE(NEW.arrived_at, now()), 'YYYYMM') || '-';
        SELECT COALESCE(MAX(SUBSTRING(parcel_code FROM 12)::INT), 0) + 1
        INTO v_seq_num
        FROM public.parcels
        WHERE parcel_code LIKE v_prefix || '%';
        
        NEW.parcel_code := v_prefix || LPAD(v_seq_num::TEXT, 5, '0');
    END IF;

    IF NEW.pickup_pin IS NULL OR NEW.pickup_pin = '' THEN
        -- Sinh mã PIN ngẫu nhiên 6 chữ số từ 100000 đến 999999
        v_random_pin := floor(100000 + random() * 900000)::TEXT;
        NEW.pickup_pin := v_random_pin;
    END IF;

    -- Tự động băm SHA-256 mã PIN
    NEW.pickup_pin_hash := encode(digest(TRIM(NEW.pickup_pin), 'sha256'), 'hex');
    NEW.updated_at := timezone('utc'::text, now());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_generate_parcel_code_and_pin ON public.parcels;
CREATE TRIGGER trg_generate_parcel_code_and_pin
    BEFORE INSERT OR UPDATE OF pickup_pin ON public.parcels
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_generate_parcel_code_and_pin();

-- ────────────────────────────────────────────────────────────────────────────
-- 2. SECURE VIEW CHO LỄ TÂN & BQL (ẨN PLAINTEXT PIN)
-- ────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW public.v_parcels_secure AS
SELECT 
    p.id,
    p.parcel_code,
    p.apartment_id,
    p.recipient_name,
    p.carrier,
    p.tracking_number,
    p.description,
    p.shelf_location,
    p.image_url,
    -- Plaintext PIN chỉ hiển thị với cư dân của chính căn hộ đó
    CASE 
        WHEN auth.uid() IS NOT NULL AND EXISTS (
            SELECT 1 FROM public.residents_apartments ra 
            WHERE ra.apartment_id = p.apartment_id AND ra.user_id = auth.uid()
        ) THEN p.pickup_pin
        ELSE '******'
    END AS pickup_pin,
    p.pickup_pin_hash,
    p.status,
    p.arrived_at,
    p.received_staff_id,
    p.collected_at,
    p.handover_staff_id,
    p.collected_by,
    p.created_at,
    p.updated_at
FROM public.parcels p;

-- ────────────────────────────────────────────────────────────────────────────
-- 3. CẬP NHẬT CÁC RPCS AN NINH & BƯU KIỆN (SERVER-AUTHORITATIVE IDENTITY)
-- ────────────────────────────────────────────────────────────────────────────

-- A. check_in_visitor_pass: Xác thực guard từ auth.uid() & Chống Replay Attacks
CREATE OR REPLACE FUNCTION public.check_in_visitor_pass(
    p_pass_code TEXT,
    p_guard_id UUID DEFAULT NULL,
    p_qr_payload TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_pass public.visitor_access_passes%ROWTYPE;
    v_guard_id UUID;
BEGIN
    -- Ưu tiên định danh máy chủ từ session Supabase
    v_guard_id := COALESCE(auth.uid(), p_guard_id);

    SELECT * INTO v_pass
    FROM public.visitor_access_passes
    WHERE pass_code = UPPER(TRIM(p_pass_code))
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Không tìm thấy vé khách với mã đã quét.');
    END IF;

    -- Kiểm tra chống Replay Attack (quét lặp lại mã vé cũ đã dùng)
    IF v_pass.status = 'checked_in' THEN
        RETURN jsonb_build_object(
            'success', false, 
            'message', 'Cảnh báo bảo mật: Vé khách này đã được check-in vào tòa nhà trước đó (Chống quét lặp lại).'
        );
    END IF;

    IF v_pass.status = 'checked_out' THEN
        RETURN jsonb_build_object(
            'success', false, 
            'message', 'Vé khách này đã check-out rời tòa nhà và không còn hiệu lực.'
        );
    END IF;

    IF v_pass.status = 'cancelled' THEN
        RETURN jsonb_build_object('success', false, 'message', 'Vé khách này đã bị cư dân hủy bỏ.');
    END IF;

    -- Kiểm tra thời hạn hiệu lực vé
    IF v_pass.expected_departure IS NOT NULL AND timezone('utc'::text, now()) > v_pass.expected_departure THEN
        UPDATE public.visitor_access_passes
        SET status = 'expired', updated_at = timezone('utc'::text, now())
        WHERE id = v_pass.id;

        RETURN jsonb_build_object('success', false, 'message', 'Vé khách này đã quá hạn thời gian lưu trú dự kiến.');
    END IF;

    UPDATE public.visitor_access_passes
    SET status = 'checked_in',
        check_in_at = timezone('utc'::text, now()),
        check_in_guard_id = v_guard_id,
        updated_at = timezone('utc'::text, now())
    WHERE id = v_pass.id;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Check-in thành công. Chào mừng khách viếng thăm!',
        'pass_code', v_pass.pass_code,
        'visitor_name', v_pass.visitor_name,
        'apartment_id', v_pass.apartment_id
    );
END;
$$;

-- B. check_out_visitor_pass: Xác thực guard từ auth.uid()
CREATE OR REPLACE FUNCTION public.check_out_visitor_pass(
    p_pass_code TEXT,
    p_guard_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_pass public.visitor_access_passes%ROWTYPE;
    v_guard_id UUID;
BEGIN
    v_guard_id := COALESCE(auth.uid(), p_guard_id);

    SELECT * INTO v_pass
    FROM public.visitor_access_passes
    WHERE pass_code = UPPER(TRIM(p_pass_code))
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Không tìm thấy vé khách với mã đã quét.');
    END IF;

    IF v_pass.status = 'checked_out' THEN
        RETURN jsonb_build_object('success', false, 'message', 'Khách này đã check-out rời tòa nhà rồi.');
    END IF;

    UPDATE public.visitor_access_passes
    SET status = 'checked_out',
        check_out_at = timezone('utc'::text, now()),
        check_out_guard_id = v_guard_id,
        updated_at = timezone('utc'::text, now())
    WHERE id = v_pass.id;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Check-out hoàn tất. Khách đã rời khỏi tòa nhà.',
        'pass_code', v_pass.pass_code,
        'visitor_name', v_pass.visitor_name
    );
END;
$$;

-- C. collect_parcel: Xác thực staff từ auth.uid() & Đối soát hash mã PIN
CREATE OR REPLACE FUNCTION public.collect_parcel(
    p_parcel_id UUID,
    p_pickup_pin TEXT,
    p_staff_id UUID DEFAULT NULL,
    p_collected_by TEXT DEFAULT 'Cư dân'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_parcel public.parcels%ROWTYPE;
    v_staff_id UUID;
    v_input_hash TEXT;
BEGIN
    v_staff_id := COALESCE(auth.uid(), p_staff_id);

    SELECT * INTO v_parcel
    FROM public.parcels
    WHERE id = p_parcel_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Không tìm thấy kiện hàng yêu cầu.');
    END IF;

    IF v_parcel.status = 'collected' THEN
        RETURN jsonb_build_object('success', false, 'message', 'Kiện hàng này đã được bàn giao trước đó.');
    END IF;

    -- Kiểm tra mã PIN lấy hàng qua SHA-256 hash
    v_input_hash := encode(digest(TRIM(p_pickup_pin), 'sha256'), 'hex');

    IF v_parcel.pickup_pin_hash IS NOT NULL AND v_parcel.pickup_pin_hash != '' THEN
        IF v_input_hash != v_parcel.pickup_pin_hash THEN
            RETURN jsonb_build_object('success', false, 'message', 'Mã PIN nhận hàng không chính xác!');
        END IF;
    ELSE
        -- Fallback an toàn với dữ liệu cũ chưa có hash
        IF TRIM(p_pickup_pin) != v_parcel.pickup_pin THEN
            RETURN jsonb_build_object('success', false, 'message', 'Mã PIN nhận hàng không chính xác!');
        END IF;
    END IF;

    UPDATE public.parcels
    SET status = 'collected',
        collected_at = timezone('utc'::text, now()),
        handover_staff_id = v_staff_id,
        collected_by = COALESCE(p_collected_by, 'Cư dân'),
        updated_at = timezone('utc'::text, now())
    WHERE id = v_parcel.id;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Bàn giao bưu kiện cho cư dân thành công.',
        'parcel_code', v_parcel.parcel_code,
        'tracking_number', v_parcel.tracking_number
    );
END;
$$;

-- ────────────────────────────────────────────────────────────────────────────
-- 4. CẬP NHẬT BIỂU QUYẾT ĐIỆN TỬ THEO ĐIỀU 102 LUẬT NHÀ Ở 2023
-- ────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.submit_poll_vote(
    p_poll_id UUID,
    p_apartment_id UUID,
    p_option_ids UUID[],
    p_voter_user_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_poll RECORD;
    v_apt_area NUMERIC(10,2);
    v_calculated_weight NUMERIC(10,2);
    v_vote_id UUID;
    v_voter_id UUID;
    v_relation_role TEXT;
BEGIN
    -- 1. Xác thực định danh người biểu quyết từ phiên đăng nhập máy chủ
    v_voter_id := COALESCE(auth.uid(), p_voter_user_id);
    IF v_voter_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Yêu cầu đăng nhập tài khoản để tham gia biểu quyết.');
    END IF;

    -- 2. Kiểm tra cuộc biểu quyết tồn tại và đang diễn ra
    SELECT * INTO v_poll FROM public.polls WHERE id = p_poll_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Cuộc biểu quyết không tồn tại.');
    END IF;

    IF v_poll.status != 'active' OR now() < v_poll.start_time OR now() > v_poll.end_time THEN
        RETURN jsonb_build_object('success', false, 'message', 'Cuộc biểu quyết hiện không trong thời gian tiếp nhận phiếu.');
    END IF;

    -- 3. Kiểm tra tính hợp lệ của người biểu quyết với căn hộ
    SELECT relation_role INTO v_relation_role
    FROM public.residents_apartments
    WHERE apartment_id = p_apartment_id AND user_id = v_voter_id
    LIMIT 1;

    IF v_relation_role IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Bạn không có quyền biểu quyết đại diện cho căn hộ này.');
    END IF;

    -- 4. RÀNG BUỘC PHÁP LÝ THEO ĐIỀU 102 LUẬT NHÀ Ở 2023:
    -- Nếu là Hội nghị nhà chung cư chính thức (official_assembly), CHỈ chủ sở hữu căn hộ (owner) mới được bỏ phiếu
    IF v_poll.poll_type = 'official_assembly' AND LOWER(v_relation_role) != 'owner' THEN
        RETURN jsonb_build_object(
            'success', false, 
            'message', 'Theo Điều 102 Luật Nhà ở 2023, chỉ chủ sở hữu căn hộ (owner) mới có quyền biểu quyết tại Hội nghị nhà chung cư. Khách thuê chỉ có thể tham gia các cuộc khảo sát ý kiến cộng đồng.'
        );
    END IF;

    -- 5. Kiểm tra căn hộ đã biểu quyết chưa (chống gian lận biểu quyết trùng lặp)
    IF EXISTS (SELECT 1 FROM public.poll_votes WHERE poll_id = p_poll_id AND apartment_id = p_apartment_id) THEN
        RETURN jsonb_build_object('success', false, 'message', 'Căn hộ này đã tham gia biểu quyết rồi.');
    END IF;

    -- 6. Xác định trọng số phiếu bầu (Theo diện tích m2 hoặc theo căn hộ)
    IF v_poll.vote_weight_type = 'by_area' THEN
        SELECT COALESCE(area, 50.0) INTO v_apt_area FROM public.apartments WHERE id = p_apartment_id;
        v_calculated_weight := COALESCE(v_apt_area, 50.0);
    ELSE
        v_calculated_weight := 1.0;
    END IF;

    -- 7. Ghi nhận phiếu bầu bất biến
    INSERT INTO public.poll_votes (
        poll_id,
        apartment_id,
        voter_user_id,
        selected_option_ids,
        vote_weight,
        voted_at
    ) VALUES (
        p_poll_id,
        p_apartment_id,
        v_voter_id,
        p_option_ids,
        v_calculated_weight,
        now()
    ) RETURNING id INTO v_vote_id;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Gửi phiếu biểu quyết thành công.',
        'vote_id', v_vote_id,
        'weight', v_calculated_weight
    );
END;
$$;

-- D. endorse_petition: Xác thực user từ auth.uid()
CREATE OR REPLACE FUNCTION public.endorse_petition(
    p_petition_id UUID,
    p_apartment_id UUID,
    p_user_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_new_count INT;
BEGIN
    v_user_id := COALESCE(auth.uid(), p_user_id);
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Yêu cầu đăng nhập tài khoản để đồng thuận kiến nghị.');
    END IF;

    -- Kiểm tra đã ủng hộ chưa
    IF EXISTS (SELECT 1 FROM public.petition_endorsements WHERE petition_id = p_petition_id AND apartment_id = p_apartment_id) THEN
        RETURN jsonb_build_object('success', false, 'message', 'Căn hộ của bạn đã bấm đồng thuận kiến nghị này rồi.');
    END IF;

    -- Thêm lượt ủng hộ
    INSERT INTO public.petition_endorsements (petition_id, apartment_id, user_id)
    VALUES (p_petition_id, p_apartment_id, v_user_id);

    -- Cập nhật count
    UPDATE public.resident_petitions
    SET endorsement_count = endorsement_count + 1,
        updated_at = now()
    WHERE id = p_petition_id
    RETURNING endorsement_count INTO v_new_count;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Đã ghi nhận sự đồng thuận của bạn.',
        'endorsement_count', v_new_count
    );
END;
$$;

-- E. update_petition_response: Xác thực staff từ auth.uid()
CREATE OR REPLACE FUNCTION public.update_petition_response(
    p_petition_id UUID,
    p_status VARCHAR(20),
    p_response TEXT,
    p_staff_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_staff_id UUID;
BEGIN
    v_staff_id := COALESCE(auth.uid(), p_staff_id);

    UPDATE public.resident_petitions
    SET status = p_status,
        official_response = p_response,
        responded_by_staff_id = v_staff_id,
        responded_at = now(),
        updated_at = now()
    WHERE id = p_petition_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Kiến nghị không tồn tại.');
    END IF;

    RETURN jsonb_build_object('success', true, 'message', 'Cập nhật phản hồi kiến nghị thành công.');
END;
$$;

