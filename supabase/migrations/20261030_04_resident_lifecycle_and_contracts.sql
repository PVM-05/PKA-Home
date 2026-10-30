-- ==============================================================================
-- Migration: 20261030_04_resident_lifecycle_and_contracts.sql
-- Giai đoạn D1: Vòng đời cư dân, Hợp đồng thuê & Mã mời tự phục vụ
-- ==============================================================================

-- 1. Nâng cấp bảng residents_apartments lưu trữ hợp đồng và vòng đời lưu trú
ALTER TABLE public.residents_apartments
    ADD COLUMN IF NOT EXISTS start_date DATE NOT NULL DEFAULT CURRENT_DATE,
    ADD COLUMN IF NOT EXISTS end_date DATE,
    ADD COLUMN IF NOT EXISTS status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'expired', 'terminated')),
    ADD COLUMN IF NOT EXISTS deposit_amount NUMERIC(12, 2) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS contract_number VARCHAR(50),
    ADD COLUMN IF NOT EXISTS note TEXT;

CREATE INDEX IF NOT EXISTS idx_residents_apartments_status ON public.residents_apartments(status);
CREATE INDEX IF NOT EXISTS idx_residents_apartments_dates ON public.residents_apartments(start_date, end_date);

-- 2. Tạo bảng apartment_invitations quản lý mã mời tham gia căn hộ
CREATE TABLE IF NOT EXISTS public.apartment_invitations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    apartment_id UUID NOT NULL REFERENCES public.apartments(id) ON DELETE CASCADE,
    created_by UUID NOT NULL REFERENCES public.users(id),
    invite_code VARCHAR(16) NOT NULL UNIQUE,
    target_role public.apartment_relation_role NOT NULL DEFAULT 'member',
    max_uses INT NOT NULL DEFAULT 1,
    used_count INT NOT NULL DEFAULT 0,
    expires_at TIMESTAMPTZ NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'revoked', 'exhausted', 'expired')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_apt_invites_code ON public.apartment_invitations(invite_code);
CREATE INDEX IF NOT EXISTS idx_apt_invites_apt ON public.apartment_invitations(apartment_id);
CREATE INDEX IF NOT EXISTS idx_apt_invites_status ON public.apartment_invitations(status);

ALTER TABLE public.apartment_invitations ENABLE ROW LEVEL SECURITY;

-- RLS: Ban quản lý có toàn quyền; Cư dân xem và tạo mã mời cho chính căn hộ mình sở hữu
CREATE POLICY "invitations_select_policy" ON public.apartment_invitations
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.users u
            WHERE u.id = auth.uid() AND u.role IN ('admin', 'management')
        )
        OR
        EXISTS (
            SELECT 1 FROM public.residents_apartments ra
            WHERE ra.apartment_id = apartment_invitations.apartment_id
              AND ra.user_id = auth.uid()
              AND ra.relation_role = 'owner'
              AND ra.status = 'active'
        )
    );

CREATE POLICY "invitations_insert_policy" ON public.apartment_invitations
    FOR INSERT TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.users u
            WHERE u.id = auth.uid() AND u.role IN ('admin', 'management')
        )
        OR
        EXISTS (
            SELECT 1 FROM public.residents_apartments ra
            WHERE ra.apartment_id = apartment_invitations.apartment_id
              AND ra.user_id = auth.uid()
              AND ra.relation_role = 'owner'
              AND ra.status = 'active'
        )
    );

CREATE POLICY "invitations_update_policy" ON public.apartment_invitations
    FOR UPDATE TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.users u
            WHERE u.id = auth.uid() AND u.role IN ('admin', 'management')
        )
        OR
        EXISTS (
            SELECT 1 FROM public.residents_apartments ra
            WHERE ra.apartment_id = apartment_invitations.apartment_id
              AND ra.user_id = auth.uid()
              AND ra.relation_role = 'owner'
              AND ra.status = 'active'
        )
    );

-- 3. RPC: Sinh mã mời căn hộ (create_apartment_invitation)
CREATE OR REPLACE FUNCTION public.create_apartment_invitation(
    p_apartment_id UUID,
    p_target_role VARCHAR DEFAULT 'member',
    p_expires_hours INT DEFAULT 48,
    p_max_uses INT DEFAULT 1
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_caller_id UUID := auth.uid();
    v_is_authorized BOOLEAN := FALSE;
    v_code VARCHAR(16);
    v_expires_at TIMESTAMPTZ;
    v_invitation_id UUID;
    v_apt_code VARCHAR(50);
BEGIN
    -- Kiểm tra quyền: Phải là Admin/BQL hoặc Chủ hộ của căn
    SELECT EXISTS (
        SELECT 1 FROM public.users WHERE id = v_caller_id AND role IN ('admin', 'management')
    ) INTO v_is_authorized;

    IF NOT v_is_authorized THEN
        SELECT EXISTS (
            SELECT 1 FROM public.residents_apartments
            WHERE apartment_id = p_apartment_id AND user_id = v_caller_id AND relation_role = 'owner' AND status = 'active'
        ) INTO v_is_authorized;
    END IF;

    IF NOT v_is_authorized THEN
        RAISE EXCEPTION 'Bạn không có quyền tạo mã mời cho căn hộ này.';
    END IF;

    -- Lấy mã căn hộ
    SELECT code INTO v_apt_code FROM public.apartments WHERE id = p_apartment_id;
    IF v_apt_code IS NULL THEN
        RAISE EXCEPTION 'Không tìm thấy căn hộ yêu cầu.';
    END IF;

    -- Sinh mã mời ngẫu nhiên 8 ký tự: PKA + 5 ký tự ngẫu nhiên
    v_code := UPPER(CONCAT('PKA', SUBSTRING(REPLACE(gen_random_uuid()::TEXT, '-', '') FROM 1 FOR 5)));
    v_expires_at := now() + (p_expires_hours || ' hours')::INTERVAL;

    INSERT INTO public.apartment_invitations (
        apartment_id,
        created_by,
        invite_code,
        target_role,
        max_uses,
        expires_at,
        status
    ) VALUES (
        p_apartment_id,
        v_caller_id,
        v_code,
        p_target_role::public.apartment_relation_role,
        COALESCE(p_max_uses, 1),
        v_expires_at,
        'active'
    ) RETURNING id INTO v_invitation_id;

    RETURN jsonb_build_object(
        'success', TRUE,
        'invitation_id', v_invitation_id,
        'invite_code', v_code,
        'apartment_id', p_apartment_id,
        'apartment_code', v_apt_code,
        'target_role', p_target_role,
        'expires_at', v_expires_at
    );
END;
$$;

-- 4. RPC: Kích hoạt / chấp nhận mã mời (accept_apartment_invitation)
CREATE OR REPLACE FUNCTION public.accept_apartment_invitation(
    p_invite_code VARCHAR
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_caller_id UUID := auth.uid();
    v_invite RECORD;
    v_apt_code VARCHAR(50);
BEGIN
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Vui lòng đăng nhập để sử dụng mã mời.';
    END IF;

    -- Lấy thông tin mã mời
    SELECT * INTO v_invite
    FROM public.apartment_invitations
    WHERE invite_code = UPPER(TRIM(p_invite_code))
    FOR UPDATE;

    IF v_invite IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Mã mời không tồn tại hoặc không chính xác.');
    END IF;

    IF v_invite.status != 'active' THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Mã mời này đã bị hủy hoặc đã sử dụng hết.');
    END IF;

    IF v_invite.expires_at <= now() THEN
        UPDATE public.apartment_invitations SET status = 'expired', updated_at = now() WHERE id = v_invite.id;
        RETURN jsonb_build_object('success', FALSE, 'message', 'Mã mời này đã hết hạn sử dụng.');
    END IF;

    IF v_invite.used_count >= v_invite.max_uses THEN
        UPDATE public.apartment_invitations SET status = 'exhausted', updated_at = now() WHERE id = v_invite.id;
        RETURN jsonb_build_object('success', FALSE, 'message', 'Mã mời đã đạt số lượng thành viên tối đa.');
    END IF;

    -- Lấy thông tin căn hộ
    SELECT code INTO v_apt_code FROM public.apartments WHERE id = v_invite.apartment_id;

    -- Upsert liên kết căn hộ cho cư dân
    INSERT INTO public.residents_apartments (
        user_id,
        apartment_id,
        relation_role,
        start_date,
        status
    ) VALUES (
        v_caller_id,
        v_invite.apartment_id,
        v_invite.target_role,
        CURRENT_DATE,
        'active'
    )
    ON CONFLICT (user_id, apartment_id) DO UPDATE SET
        relation_role = EXCLUDED.relation_role,
        status = 'active',
        start_date = CURRENT_DATE,
        end_date = NULL,
        updated_at = now();

    -- Cập nhật căn hộ không còn trống
    UPDATE public.apartments SET is_empty = FALSE, updated_at = now() WHERE id = v_invite.apartment_id;

    -- Cập nhật lượt dùng của mã mời
    UPDATE public.apartment_invitations
    SET used_count = used_count + 1,
        status = CASE WHEN used_count + 1 >= max_uses THEN 'exhausted' ELSE 'active' END,
        updated_at = now()
    WHERE id = v_invite.id;

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Kích hoạt gia nhập căn hộ thành công!',
        'apartment_id', v_invite.apartment_id,
        'apartment_code', v_apt_code,
        'role', v_invite.target_role
    );
END;
$$;

-- 5. RPC: Kết thúc thời gian lưu trú / hợp đồng (terminate_resident_stay)
CREATE OR REPLACE FUNCTION public.terminate_resident_stay(
    p_user_id UUID,
    p_apartment_id UUID,
    p_termination_date DATE DEFAULT CURRENT_DATE,
    p_note TEXT DEFAULT ''
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_caller_id UUID := auth.uid();
    v_is_authorized BOOLEAN := FALSE;
    v_remaining_active INT;
BEGIN
    -- Chỉ Admin/BQL hoặc chính Chủ hộ mới được kết thúc lưu trú của cư dân
    SELECT EXISTS (
        SELECT 1 FROM public.users WHERE id = v_caller_id AND role IN ('admin', 'management')
    ) INTO v_is_authorized;

    IF NOT v_is_authorized THEN
        SELECT EXISTS (
            SELECT 1 FROM public.residents_apartments
            WHERE apartment_id = p_apartment_id AND user_id = v_caller_id AND relation_role = 'owner' AND status = 'active'
        ) INTO v_is_authorized;
    END IF;

    IF NOT v_is_authorized THEN
        RAISE EXCEPTION 'Bạn không có quyền kết thúc lưu trú cho căn hộ này.';
    END IF;

    -- Cập nhật trạng thái quan hệ sang 'terminated' và chốt ngày end_date
    UPDATE public.residents_apartments
    SET status = 'terminated',
        end_date = COALESCE(p_termination_date, CURRENT_DATE),
        note = CASE 
            WHEN p_note IS NOT NULL AND TRIM(p_note) != '' THEN COALESCE(note || E'\n', '') || TRIM(p_note)
            ELSE note
        END,
        updated_at = now()
    WHERE user_id = p_user_id AND apartment_id = p_apartment_id;

    -- Đếm số cư dân active còn lại trong căn
    SELECT COUNT(*) INTO v_remaining_active
    FROM public.residents_apartments
    WHERE apartment_id = p_apartment_id AND status = 'active';

    IF v_remaining_active = 0 THEN
        UPDATE public.apartments SET is_empty = TRUE, updated_at = now() WHERE id = p_apartment_id;
    END IF;

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Đã kết thúc lưu trú thành công và lưu vết lịch sử đầy đủ.',
        'user_id', p_user_id,
        'apartment_id', p_apartment_id,
        'remaining_active_residents', v_remaining_active
    );
END;
$$;

-- 6. RPC: Lấy danh sách hợp đồng và lịch sử lưu trú của căn hộ (get_apartment_contracts)
CREATE OR REPLACE FUNCTION public.get_apartment_contracts(
    p_apartment_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_results JSONB;
BEGIN
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', ra.id,
                'user_id', ra.user_id,
                'apartment_id', ra.apartment_id,
                'full_name', u.full_name,
                'phone', u.phone,
                'relation_role', ra.relation_role,
                'status', ra.status,
                'start_date', ra.start_date,
                'end_date', ra.end_date,
                'deposit_amount', ra.deposit_amount,
                'contract_number', ra.contract_number,
                'note', ra.note,
                'created_at', ra.created_at
            ) ORDER BY ra.status ASC, ra.start_date DESC
        ),
        '[]'::JSONB
    ) INTO v_results
    FROM public.residents_apartments ra
    JOIN public.users u ON u.id = ra.user_id
    WHERE ra.apartment_id = p_apartment_id;

    RETURN v_results;
END;
$$;
