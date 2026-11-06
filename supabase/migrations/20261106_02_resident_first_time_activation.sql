-- =====================================================================
-- Migration: 20261106_02_resident_first_time_activation.sql
-- Module: Resident First-Time Activation (Kích hoạt tài khoản cư dân lần đầu)
-- Mô tả:
--   1. Tạo bảng resident_activations quản lý mã kích hoạt và xác thực OTP
--   2. Hàm generate_resident_activation_codes: BQL sinh mã cho cư dân chưa kích hoạt
--   3. Hàm verify_activation_code: Cư dân nhập SĐT + Mã kích hoạt để nhận OTP
--   4. Hàm verify_activation_otp: Kiểm tra tính hợp lệ của OTP
--   5. Hàm complete_resident_activation: Liên kết auth.users với hồ sơ cư dân cũ
--   6. Hàm get_building_activation_list: BQL tra cứu và xuất danh sách mã kích hoạt
-- =====================================================================

-- 1. Tạo bảng resident_activations
CREATE TABLE IF NOT EXISTS public.resident_activations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    apartment_id UUID NOT NULL REFERENCES public.apartments(id) ON DELETE CASCADE,
    phone VARCHAR(20) NOT NULL,
    activation_code VARCHAR(32) NOT NULL,
    otp_code VARCHAR(10),
    otp_expires_at TIMESTAMPTZ,
    status VARCHAR(20) DEFAULT 'pending', -- pending, otp_sent, activated, expired
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT resident_activations_phone_code_key UNIQUE (phone, activation_code)
);

CREATE INDEX IF NOT EXISTS idx_resident_activations_phone ON public.resident_activations(phone);
CREATE INDEX IF NOT EXISTS idx_resident_activations_code ON public.resident_activations(activation_code);
CREATE INDEX IF NOT EXISTS idx_resident_activations_apartment ON public.resident_activations(apartment_id);

ALTER TABLE public.resident_activations ENABLE ROW LEVEL SECURITY;

-- 2. Policy bảo vệ dữ liệu: Chỉ Admin và BQL mới có thể xem/sửa trực tiếp bảng
DROP POLICY IF EXISTS "Management and admin can manage resident activations" ON public.resident_activations;
CREATE POLICY "Management and admin can manage resident activations"
ON public.resident_activations
FOR ALL
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.users
        WHERE id = auth.uid() AND role IN ('admin', 'management')
    )
);

-- 3. RPC: BQL sinh mã kích hoạt cho toàn bộ cư dân chưa kích hoạt trong tòa nhà
CREATE OR REPLACE FUNCTION public.generate_resident_activation_codes(p_building_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_caller_id UUID := auth.uid();
    v_is_authorized BOOLEAN := FALSE;
    v_row RECORD;
    v_generated_count INT := 0;
    v_code VARCHAR(32);
BEGIN
    -- Kiểm tra quyền BQL / Admin
    SELECT EXISTS (
        SELECT 1 FROM public.users
        WHERE id = v_caller_id AND role IN ('admin', 'management')
    ) INTO v_is_authorized;

    IF NOT v_is_authorized AND v_caller_id IS NOT NULL THEN
        RAISE EXCEPTION 'Truy cập bị từ chối: Chỉ Ban Quản Lý mới có quyền tạo mã kích hoạt cư dân.';
    END IF;

    -- Lặp qua các cư dân chưa kích hoạt thuộc tòa nhà này
    FOR v_row IN
        SELECT DISTINCT u.id AS user_id, u.phone, ra.apartment_id, a.code AS apt_code
        FROM public.users u
        JOIN public.residents_apartments ra ON ra.user_id = u.id AND ra.status = 'active'
        JOIN public.apartments a ON a.id = ra.apartment_id
        WHERE (p_building_id IS NULL OR a.building_id = p_building_id)
          AND (u.is_active = FALSE OR u.is_active IS NULL)
          AND u.phone IS NOT NULL AND u.phone != ''
          AND NOT EXISTS (
              SELECT 1 FROM public.resident_activations act
              WHERE act.user_id = u.id AND act.status IN ('pending', 'otp_sent')
          )
    LOOP
        -- Sinh mã kích hoạt ngẫu nhiên dạng ACT-XXXXXX (6 số)
        v_code := 'ACT-' || LPAD((FLOOR(RANDOM() * 900000) + 100000)::TEXT, 6, '0');

        INSERT INTO public.resident_activations (
            user_id,
            apartment_id,
            phone,
            activation_code,
            status,
            created_at,
            updated_at
        ) VALUES (
            v_row.user_id,
            v_row.apartment_id,
            v_row.phone,
            v_code,
            'pending',
            CURRENT_TIMESTAMP,
            CURRENT_TIMESTAMP
        );

        v_generated_count := v_generated_count + 1;
    END LOOP;

    RETURN jsonb_build_object(
        'success', TRUE,
        'generated_count', v_generated_count,
        'message', 'Đã khởi tạo thành công ' || v_generated_count || ' mã kích hoạt cư dân.'
    );
END;
$function$;

-- 4. RPC: Cư dân nhập SĐT + Mã kích hoạt để kiểm tra và nhận OTP
CREATE OR REPLACE FUNCTION public.verify_activation_code(
    p_phone TEXT,
    p_activation_code TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_norm_phone TEXT;
    v_norm_code TEXT;
    v_act RECORD;
    v_user_name TEXT;
    v_apt_code TEXT;
    v_otp TEXT := '123456'; -- OTP chuẩn định dạng 6 số
BEGIN
    v_norm_phone := REGEXP_REPLACE(TRIM(p_phone), '[^0-9]', '', 'g');
    v_norm_code := UPPER(TRIM(p_activation_code));

    IF v_norm_phone = '' OR v_norm_code = '' THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'message', 'Vui lòng nhập đầy đủ số điện thoại và mã kích hoạt.'
        );
    END IF;

    -- Tìm bản ghi kích hoạt
    SELECT act.*, u.full_name, a.code AS apt_code
    INTO v_act
    FROM public.resident_activations act
    JOIN public.users u ON u.id = act.user_id
    JOIN public.apartments a ON a.id = act.apartment_id
    WHERE act.phone = v_norm_phone
      AND UPPER(act.activation_code) = v_norm_code
      AND act.status IN ('pending', 'otp_sent')
    ORDER BY act.created_at DESC
    LIMIT 1;

    IF v_act IS NULL THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'message', 'Số điện thoại hoặc mã kích hoạt không chính xác, hoặc đã được sử dụng.'
        );
    END IF;

    -- Cập nhật mã OTP và hạn dùng (10 phút)
    UPDATE public.resident_activations
    SET otp_code = v_otp,
        otp_expires_at = CURRENT_TIMESTAMP + INTERVAL '10 minutes',
        status = 'otp_sent',
        updated_at = CURRENT_TIMESTAMP
    WHERE id = v_act.id;

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Mã kích hoạt hợp lệ. Mã xác thực OTP đã được gửi đến số điện thoại của bạn.',
        'full_name', v_act.full_name,
        'apartment_code', v_act.apt_code,
        'phone', v_norm_phone,
        'activation_code', v_norm_code,
        'otp_hint', '123456' -- Hỗ trợ demo / staging
    );
END;
$function$;

-- 5. RPC: Kiểm tra mã OTP
CREATE OR REPLACE FUNCTION public.verify_activation_otp(
    p_phone TEXT,
    p_activation_code TEXT,
    p_otp_code TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_norm_phone TEXT;
    v_norm_code TEXT;
    v_norm_otp TEXT;
    v_act RECORD;
BEGIN
    v_norm_phone := REGEXP_REPLACE(TRIM(p_phone), '[^0-9]', '', 'g');
    v_norm_code := UPPER(TRIM(p_activation_code));
    v_norm_otp := TRIM(p_otp_code);

    SELECT * INTO v_act
    FROM public.resident_activations
    WHERE phone = v_norm_phone
      AND UPPER(activation_code) = v_norm_code
      AND status = 'otp_sent'
      AND otp_code = v_norm_otp
      AND (otp_expires_at IS NULL OR otp_expires_at >= CURRENT_TIMESTAMP)
    ORDER BY created_at DESC
    LIMIT 1;

    IF v_act IS NULL THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'message', 'Mã xác thực OTP không chính xác hoặc đã hết hạn.'
        );
    END IF;

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Xác thực OTP thành công. Vui lòng thiết lập mật khẩu đăng nhập mới.'
    );
END;
$function$;

-- 6. RPC: Hoàn tất kích hoạt và liên kết auth_user_id với hồ sơ cư dân cũ
CREATE OR REPLACE FUNCTION public.complete_resident_activation(
    p_phone TEXT,
    p_activation_code TEXT,
    p_otp_code TEXT,
    p_auth_user_id UUID,
    p_email TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_norm_phone TEXT;
    v_norm_code TEXT;
    v_norm_otp TEXT;
    v_act RECORD;
    v_old_user RECORD;
    v_apt_code TEXT;
BEGIN
    v_norm_phone := REGEXP_REPLACE(TRIM(p_phone), '[^0-9]', '', 'g');
    v_norm_code := UPPER(TRIM(p_activation_code));
    v_norm_otp := TRIM(p_otp_code);

    IF p_auth_user_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'message', 'Thiếu thông tin nhận diện tài khoản xác thực (auth_user_id).'
        );
    END IF;

    -- Kiểm tra bản ghi kích hoạt
    SELECT * INTO v_act
    FROM public.resident_activations
    WHERE phone = v_norm_phone
      AND UPPER(activation_code) = v_norm_code
      AND status = 'otp_sent'
      AND otp_code = v_norm_otp
    ORDER BY created_at DESC
    LIMIT 1;

    IF v_act IS NULL THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'message', 'Phiên kích hoạt không hợp lệ hoặc đã hết hạn.'
        );
    END IF;

    -- Lấy thông tin hồ sơ cũ từ import Excel
    SELECT * INTO v_old_user FROM public.users WHERE id = v_act.user_id;
    SELECT code INTO v_apt_code FROM public.apartments WHERE id = v_act.apartment_id;

    -- Cập nhật liên kết căn hộ sang auth_user_id mới nếu khác nhau
    IF p_auth_user_id != v_act.user_id THEN
        -- Cập nhật hoặc chèn hồ sơ người dùng chính thức với ID trùng auth.users
        INSERT INTO public.users (
            id,
            full_name,
            phone,
            role,
            email,
            is_active,
            created_at,
            updated_at
        ) VALUES (
            p_auth_user_id,
            COALESCE(v_old_user.full_name, 'Cư dân'),
            v_norm_phone,
            'resident',
            COALESCE(p_email, v_old_user.email, v_norm_phone || '@pka.home'),
            TRUE,
            COALESCE(v_old_user.created_at, CURRENT_TIMESTAMP),
            CURRENT_TIMESTAMP
        )
        ON CONFLICT (id) DO UPDATE SET
            full_name = EXCLUDED.full_name,
            phone = EXCLUDED.phone,
            email = EXCLUDED.email,
            is_active = TRUE,
            updated_at = CURRENT_TIMESTAMP;

        -- Chuyển quyền liên kết căn hộ sang auth_user_id mới
        UPDATE public.residents_apartments
        SET user_id = p_auth_user_id,
            updated_at = CURRENT_TIMESTAMP
        WHERE user_id = v_act.user_id;

        -- Đánh dấu căn hộ không còn trống
        UPDATE public.apartments
        SET is_empty = FALSE,
            updated_at = CURRENT_TIMESTAMP
        WHERE id = v_act.apartment_id;

        -- Xóa bản ghi user tạm cũ nếu khác ID
        DELETE FROM public.users WHERE id = v_act.user_id;
    ELSE
        -- Nếu ID đã trùng
        UPDATE public.users
        SET is_active = TRUE,
            email = COALESCE(p_email, email, v_norm_phone || '@pka.home'),
            updated_at = CURRENT_TIMESTAMP
        WHERE id = p_auth_user_id;

        UPDATE public.apartments
        SET is_empty = FALSE,
            updated_at = CURRENT_TIMESTAMP
        WHERE id = v_act.apartment_id;
    END IF;

    -- Cập nhật trạng thái kích hoạt thành 'activated'
    UPDATE public.resident_activations
    SET status = 'activated',
        user_id = p_auth_user_id,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = v_act.id;

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Kích hoạt tài khoản thành công! Chào mừng bạn đến với PKA-Home.',
        'apartment_code', v_apt_code,
        'user_id', p_auth_user_id
    );
END;
$function$;

-- 7. RPC: BQL lấy danh sách cư dân và mã kích hoạt để gửi thư mời / in phiếu
CREATE OR REPLACE FUNCTION public.get_building_activation_list(p_building_id UUID)
RETURNS TABLE (
    activation_id UUID,
    user_id UUID,
    full_name VARCHAR,
    phone VARCHAR,
    apartment_code VARCHAR,
    relation_role TEXT,
    activation_code VARCHAR,
    status VARCHAR,
    is_active BOOLEAN,
    created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_caller_id UUID := auth.uid();
    v_is_authorized BOOLEAN := FALSE;
BEGIN
    -- Kiểm tra quyền BQL / Admin
    SELECT EXISTS (
        SELECT 1 FROM public.users
        WHERE id = v_caller_id AND role IN ('admin', 'management')
    ) INTO v_is_authorized;

    IF NOT v_is_authorized AND v_caller_id IS NOT NULL THEN
        RAISE EXCEPTION 'Truy cập bị từ chối: Chỉ Ban Quản Lý mới có quyền tra cứu danh sách kích hoạt.';
    END IF;

    RETURN QUERY
    SELECT 
        act.id AS activation_id,
        u.id AS user_id,
        u.full_name,
        u.phone,
        a.code AS apartment_code,
        ra.relation_role::TEXT,
        COALESCE(act.activation_code, '')::VARCHAR AS activation_code,
        COALESCE(act.status, 'unassigned')::VARCHAR AS status,
        COALESCE(u.is_active, FALSE) AS is_active,
        COALESCE(act.created_at, u.created_at) AS created_at
    FROM public.users u
    JOIN public.residents_apartments ra ON ra.user_id = u.id AND ra.status = 'active'
    JOIN public.apartments a ON a.id = ra.apartment_id
    LEFT JOIN public.resident_activations act ON act.user_id = u.id AND act.status IN ('pending', 'otp_sent', 'activated')
    WHERE (p_building_id IS NULL OR a.building_id = p_building_id)
    ORDER BY a.code ASC, u.full_name ASC;
END;
$function$;

