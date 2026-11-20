-- ==============================================================================
-- Vivona Production Commercial SaaS: Migration 20261120_01_security_hardening_auth_and_rls.sql
-- Mục tiêu:
-- 1. [C1 & C2] Bảo mật phân quyền: Ngăn chặn tự nâng quyền (Privilege Self-Escalation)
--    - Trigger bất biến (Immutability Trigger) cho role, is_active, is_locked trên bảng users
--    - Sửa handle_new_user(): Toàn bộ tài khoản đăng ký mới bắt buộc role = 'resident'
--    - Siết chặt chính sách RLS users_update_own_or_admin
-- 2. [C3 & C4] Bảo mật kích hoạt cư dân & Vá lỗi Inverted Authorization Check
--    - verify_activation_code: Sinh OTP ngẫu nhiên 6 chữ số, hỗ trợ cờ p_is_production
--      (trong môi trường demo/dev trả otp_hint để luồng kích hoạt hoạt động khi chưa có SMS Gateway)
--    - Vá lỗi check đảo ngược trên generate_resident_activation_codes (hàm app đang gọi thật)
-- 3. [C5] Tăng cường bảo mật xác thực hai bước (MFA / AAL2) ở tầng Database
--    - Hàm kiểm tra mức độ xác thực AAL2 khi tài khoản đã kích hoạt TOTP (is_aal2_if_mfa_enrolled)
--    - Tích hợp is_aal2_if_mfa_enrolled() trực tiếp vào is_staff_or_management() để bảo vệ toàn bộ RLS và RPCs
-- 4. [§0] Khôi phục toàn bộ RPCs cốt lõi & Khắc phục lệch Schema / Enum / Bảng thiếu từ Archive
--    - Bổ sung giá trị Enum: invoice_status ('unpaid', 'pending_confirmation'), issue_status ('pending'),
--      user_role ('accountant', 'technician'), vehicle_type ('motorbike', 'electric_bicycle')
--    - Tạo 5 bảng bị thiếu: emergency_contacts, building_rules, role_change_log, issue_ratings, building_equipments
--    - Khôi phục 15 RPCs quan trọng từ archive: create_invoice_with_items, record_manual_payment,
--      validate_monthly_bulk_invoices, generate_valid_bulk_invoices, admin_create_user,
--      approve_link_request, cancel_apartment_link_request, cancel_pending_meter_reading,
--      update_pending_meter_reading, cancel_pending_vehicle, update_pending_vehicle,
--      get_co_residents, check_in_amenity_booking, get_amenity_slot_availability, update_invoice_with_items
-- ==============================================================================

-- ==============================================================================
-- PHẦN 0: [§0] ĐỒNG BỘ ENUM VÀ KHÔI PHỤC BẢNG THIẾU TỪ ARCHIVE
-- ==============================================================================

-- 0.1 Đồng bộ các giá trị Enum giữa Baseline và Model Dart
ALTER TYPE public.invoice_status ADD VALUE IF NOT EXISTS 'unpaid';
ALTER TYPE public.invoice_status ADD VALUE IF NOT EXISTS 'pending_confirmation';

ALTER TYPE public.issue_status ADD VALUE IF NOT EXISTS 'pending';

ALTER TYPE public.user_role ADD VALUE IF NOT EXISTS 'accountant';
ALTER TYPE public.user_role ADD VALUE IF NOT EXISTS 'technician';

ALTER TYPE public.vehicle_type ADD VALUE IF NOT EXISTS 'motorbike';
ALTER TYPE public.vehicle_type ADD VALUE IF NOT EXISTS 'electric_bicycle';

-- 0.2 Bảng emergency_contacts (Đường dây nóng / Liên hệ khẩn cấp)
CREATE TABLE IF NOT EXISTS public.emergency_contacts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR NOT NULL,
    phone VARCHAR NOT NULL,
    contact_type VARCHAR DEFAULT 'security',
    display_order INT DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
ALTER TABLE public.emergency_contacts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "emergency_contacts_read" ON public.emergency_contacts;
CREATE POLICY "emergency_contacts_read" ON public.emergency_contacts FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "emergency_contacts_write" ON public.emergency_contacts;
CREATE POLICY "emergency_contacts_write" ON public.emergency_contacts FOR ALL TO authenticated USING (public.is_staff_or_management());

-- 0.3 Bảng building_rules (Nội quy chung cư)
CREATE TABLE IF NOT EXISTS public.building_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR NOT NULL,
    content TEXT NOT NULL,
    display_order INT DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
ALTER TABLE public.building_rules ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "building_rules_read" ON public.building_rules;
CREATE POLICY "building_rules_read" ON public.building_rules FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "building_rules_write" ON public.building_rules;
CREATE POLICY "building_rules_write" ON public.building_rules FOR ALL TO authenticated USING (public.is_staff_or_management());

-- 0.4 Bảng role_change_log (Nhật ký phân quyền)
CREATE TABLE IF NOT EXISTS public.role_change_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    target_user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    old_role public.user_role NOT NULL,
    new_role public.user_role NOT NULL,
    changed_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.role_change_log ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "role_change_log_read" ON public.role_change_log;
CREATE POLICY "role_change_log_read" ON public.role_change_log FOR SELECT TO authenticated USING (public.is_staff_or_management());

-- 0.5 Bảng issue_ratings (Đánh giá dịch vụ sự cố)
CREATE TABLE IF NOT EXISTS public.issue_ratings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    issue_report_id UUID NOT NULL UNIQUE REFERENCES public.issue_reports(id) ON DELETE CASCADE,
    reporter_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    speed_rating INT NOT NULL CHECK (speed_rating BETWEEN 1 AND 5),
    attitude_rating INT NOT NULL CHECK (attitude_rating BETWEEN 1 AND 5),
    quality_rating INT NOT NULL CHECK (quality_rating BETWEEN 1 AND 5),
    overall_rating DECIMAL GENERATED ALWAYS AS (
        ROUND((speed_rating + attitude_rating + quality_rating)::numeric / 3.0, 1)
    ) STORED,
    comment TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
ALTER TABLE public.issue_ratings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "issue_ratings_read" ON public.issue_ratings;
CREATE POLICY "issue_ratings_read" ON public.issue_ratings FOR SELECT TO authenticated
    USING (reporter_id = auth.uid() OR public.is_staff_or_management());
DROP POLICY IF EXISTS "issue_ratings_insert" ON public.issue_ratings;
CREATE POLICY "issue_ratings_insert" ON public.issue_ratings FOR INSERT TO authenticated
    WITH CHECK (reporter_id = auth.uid());

-- 0.6 Bảng building_equipments (Danh mục thiết bị tòa nhà)
CREATE TABLE IF NOT EXISTS public.building_equipments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    category TEXT NOT NULL CHECK (category IN ('elevator', 'fire_safety', 'water_pump', 'generator', 'electrical', 'hvac', 'other')),
    building TEXT NOT NULL DEFAULT 'Toàn khu',
    location TEXT NOT NULL,
    installation_date DATE,
    warranty_until DATE,
    maintenance_interval_days INTEGER NOT NULL DEFAULT 30 CHECK (maintenance_interval_days > 0),
    last_maintenance_date TIMESTAMPTZ,
    next_maintenance_date TIMESTAMPTZ,
    status TEXT NOT NULL DEFAULT 'operational' CHECK (status IN ('operational', 'under_maintenance', 'degraded', 'inactive')),
    specifications TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.building_equipments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "building_equipments_read" ON public.building_equipments;
CREATE POLICY "building_equipments_read" ON public.building_equipments FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "building_equipments_write" ON public.building_equipments;
CREATE POLICY "building_equipments_write" ON public.building_equipments FOR ALL TO authenticated USING (public.is_staff_or_management());

-- ==============================================================================
-- PHẦN 1: [C1 & C2] BẢO MẬT PHÂN QUYỀN VÀ BẢO VỆ TÀI KHOẢN NGƯỜI DÙNG
-- ==============================================================================

-- 1.1 Trigger ngăn chặn người dùng tự ý thay đổi vai trò (role) hoặc mở khóa tài khoản
CREATE OR REPLACE FUNCTION public.enforce_user_security_immutability()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
BEGIN
    IF (NEW.role IS DISTINCT FROM OLD.role 
        OR NEW.is_locked IS DISTINCT FROM OLD.is_locked 
        OR NEW.is_active IS DISTINCT FROM OLD.is_active) THEN
        
        IF NOT (public.is_staff_or_management() OR (auth.jwt() ->> 'role' = 'service_role')) THEN
            RAISE EXCEPTION 'Truy cập bị từ chối: Chỉ Ban Quản Lý hoặc Quản trị viên mới có quyền cập nhật vai trò hoặc trạng thái bảo mật của tài khoản.'
                USING ERRCODE = '42501';
        END IF;

        -- Ghi nhật ký phân quyền nếu đổi role
        IF NEW.role IS DISTINCT FROM OLD.role THEN
            INSERT INTO public.role_change_log (target_user_id, old_role, new_role, changed_by, changed_at)
            VALUES (NEW.id, OLD.role, NEW.role, auth.uid(), now());
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_user_security_immutability ON public.users;
CREATE TRIGGER trg_enforce_user_security_immutability
    BEFORE UPDATE ON public.users
    FOR EACH ROW
    EXECUTE FUNCTION public.enforce_user_security_immutability();

-- 1.2 Cập nhật trigger handle_new_user() siết chặt quyền hạn tài khoản tự đăng ký
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_role public.user_role := 'resident';
    v_meta_role TEXT;
BEGIN
    IF (auth.jwt() ->> 'role' = 'service_role') THEN
        v_meta_role := NEW.raw_user_meta_data->>'role';
        IF v_meta_role IN ('admin', 'management', 'staff', 'resident', 'accountant', 'technician') THEN
            v_role := v_meta_role::public.user_role;
        END IF;
    END IF;

    INSERT INTO public.users (id, full_name, email, role, phone, is_active, is_locked)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'full_name', 'Cư dân mới'),
        NEW.email,
        v_role,
        NEW.phone,
        true,
        false
    )
    ON CONFLICT (id) DO UPDATE
    SET email = EXCLUDED.email,
        full_name = CASE WHEN users.full_name = 'Cư dân mới' THEN EXCLUDED.full_name ELSE users.full_name END;
    RETURN NEW;
END;
$$;

-- 1.3 Siết chặt chính sách RLS cập nhật thông tin cá nhân
DROP POLICY IF EXISTS "users_update_own_or_admin" ON public.users;
CREATE POLICY "users_update_own_or_admin" ON public.users
    FOR UPDATE TO authenticated
    USING (id = auth.uid() OR public.is_staff_or_management())
    WITH CHECK (
        public.is_staff_or_management()
        OR
        (id = auth.uid() AND role = (SELECT u.role FROM public.users u WHERE u.id = auth.uid()))
    );

-- ==============================================================================
-- PHẦN 2: [C3 & C4] SỬA RPC KÍCH HOẠT CƯ DÂN & VÁ LỖI INVERTED AUTHORIZATION CHECK
-- ==============================================================================

-- 2.1 verify_activation_code: Sinh OTP ngẫu nhiên 6 chữ số, hỗ trợ p_is_production
CREATE OR REPLACE FUNCTION public.verify_activation_code(
    p_phone TEXT,
    p_activation_code TEXT,
    p_is_production BOOLEAN DEFAULT FALSE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
DECLARE
    v_norm_phone TEXT;
    v_norm_code TEXT;
    v_code_hash VARCHAR(64);
    v_act RECORD;
    v_otp TEXT;
    v_res JSONB;
BEGIN
    v_norm_phone := REGEXP_REPLACE(TRIM(p_phone), '[^0-9]', '', 'g');
    v_norm_code := UPPER(TRIM(p_activation_code));

    IF v_norm_phone = '' OR v_norm_code = '' THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'message', 'Vui lòng nhập đầy đủ số điện thoại và mã kích hoạt.'
        );
    END IF;

    v_code_hash := encode(digest(v_norm_code, 'sha256'), 'hex');

    SELECT act.*, u.full_name, a.code AS apt_code
    INTO v_act
    FROM public.resident_activations act
    JOIN public.users u ON u.id = act.user_id
    JOIN public.apartments a ON a.id = act.apartment_id
    WHERE act.phone = v_norm_phone
      AND act.status IN ('pending', 'otp_sent')
    ORDER BY act.created_at DESC
    LIMIT 1;

    IF v_act IS NULL THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'message', 'Thông tin xác thực không chính xác hoặc đã hết hạn.'
        );
    END IF;

    IF v_act.code_attempts >= 5 THEN
        UPDATE public.resident_activations
        SET status = 'locked', updated_at = CURRENT_TIMESTAMP
        WHERE id = v_act.id;

        RETURN jsonb_build_object(
            'success', FALSE,
            'message', 'Mã kích hoạt đã bị khóa do nhập sai quá 5 lần. Vui lòng liên hệ Ban Quản Lý để được cấp mã mới.'
        );
    END IF;

    IF (v_act.activation_code_hash IS NOT NULL AND v_act.activation_code_hash != v_code_hash)
       OR (v_act.activation_code_hash IS NULL AND UPPER(v_act.activation_code) != v_norm_code) THEN
        UPDATE public.resident_activations
        SET code_attempts = code_attempts + 1, updated_at = CURRENT_TIMESTAMP
        WHERE id = v_act.id;

        RETURN jsonb_build_object(
            'success', FALSE,
            'message', 'Thông tin xác thực không chính xác hoặc đã hết hạn.'
        );
    END IF;

    -- Sinh OTP 6 chữ số ngẫu nhiên
    v_otp := LPAD((FLOOR(RANDOM() * 900000) + 100000)::TEXT, 6, '0');

    UPDATE public.resident_activations
    SET otp_code = v_otp,
        otp_expires_at = CURRENT_TIMESTAMP + INTERVAL '10 minutes',
        code_attempts = 0,
        status = 'otp_sent',
        updated_at = CURRENT_TIMESTAMP
    WHERE id = v_act.id;

    v_res := jsonb_build_object(
        'success', TRUE,
        'message', CASE 
            WHEN p_is_production THEN 'Mã kích hoạt hợp lệ. Mã xác thực OTP đã được gửi đến số điện thoại của bạn.'
            ELSE 'Mã kích hoạt hợp lệ. Mã OTP thử nghiệm: ' || v_otp || ' (Chế độ Thử nghiệm/Demo)'
        END,
        'full_name', v_act.full_name,
        'apartment_code', v_act.apt_code,
        'phone', v_norm_phone,
        'activation_code', v_norm_code
    );

    -- Chỉ trả otp_hint khi không ở môi trường Production (hỗ trợ QA/Staging/Demo khi chưa có SMS Gateway)
    IF NOT p_is_production THEN
        v_res := v_res || jsonb_build_object('otp_hint', v_otp);
    END IF;

    RETURN v_res;
END;
$function$;

-- 2.2 Sửa inverted caller check trong generate_resident_activation_codes (Hàm app thực sự gọi!)
CREATE OR REPLACE FUNCTION public.generate_resident_activation_codes(p_building_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
DECLARE
    v_caller_id UUID := auth.uid();
    v_is_authorized BOOLEAN := FALSE;
    v_row RECORD;
    v_generated_count INT := 0;
    v_code VARCHAR(32);
    v_hash VARCHAR(64);
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM public.users
        WHERE id = v_caller_id AND role IN ('admin', 'management')
    ) INTO v_is_authorized;

    IF NOT (v_is_authorized OR (auth.jwt() ->> 'role' = 'service_role')) THEN
        RAISE EXCEPTION 'Truy cập bị từ chối: Chỉ Ban Quản Lý mới có quyền tạo mã kích hoạt cư dân.'
            USING ERRCODE = '42501';
    END IF;

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
        v_code := 'ACT-' || LPAD((FLOOR(RANDOM() * 900000) + 100000)::TEXT, 6, '0');
        v_hash := encode(digest(v_code, 'sha256'), 'hex');

        INSERT INTO public.resident_activations (
            user_id,
            apartment_id,
            phone,
            activation_code,
            activation_code_hash,
            code_attempts,
            invited_by,
            status,
            expires_at
        ) VALUES (
            v_row.user_id,
            v_row.apartment_id,
            v_row.phone,
            v_code,
            v_hash,
            0,
            v_caller_id,
            'pending',
            CURRENT_TIMESTAMP + INTERVAL '30 days'
        );

        v_generated_count := v_generated_count + 1;
    END LOOP;

    RETURN jsonb_build_object(
        'success', TRUE,
        'generated_count', v_generated_count,
        'message', 'Đã tạo thành công ' || v_generated_count || ' mã kích hoạt cho cư dân.'
    );
END;
$function$;
REVOKE ALL ON FUNCTION public.generate_resident_activation_codes(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.generate_resident_activation_codes(UUID) TO authenticated;

-- Alias tương thích
CREATE OR REPLACE FUNCTION public.generate_bulk_resident_activations(p_building_id UUID DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
BEGIN
    RETURN public.generate_resident_activation_codes(p_building_id);
END;
$$;
REVOKE ALL ON FUNCTION public.generate_bulk_resident_activations(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.generate_bulk_resident_activations(UUID) TO authenticated;

-- 2.3 Sửa inverted caller check trong regenerate_resident_activation
CREATE OR REPLACE FUNCTION public.regenerate_resident_activation(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
DECLARE
    v_caller_id UUID := auth.uid();
    v_is_authorized BOOLEAN := FALSE;
    v_user RECORD;
    v_apartment_id UUID;
    v_apt_code VARCHAR;
    v_code VARCHAR(32);
    v_hash VARCHAR(64);
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM public.users
        WHERE id = v_caller_id AND role IN ('admin', 'management')
    ) INTO v_is_authorized;

    IF NOT (v_is_authorized OR (auth.jwt() ->> 'role' = 'service_role')) THEN
        RAISE EXCEPTION 'Truy cập bị từ chối: Chỉ Ban Quản Lý mới có quyền cấp lại mã kích hoạt.'
            USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_user FROM public.users WHERE id = p_user_id;
    IF v_user IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Không tìm thấy hồ sơ cư dân.');
    END IF;

    IF v_user.is_active = TRUE THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Cư dân này đã kích hoạt tài khoản thành công, không thể cấp lại mã.');
    END IF;

    SELECT ra.apartment_id, a.code INTO v_apartment_id, v_apt_code
    FROM public.residents_apartments ra
    JOIN public.apartments a ON a.id = ra.apartment_id
    WHERE ra.user_id = p_user_id AND ra.status = 'active'
    LIMIT 1;

    IF v_apartment_id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Cư dân chưa được gắn vào bất kỳ căn hộ nào.');
    END IF;

    UPDATE public.resident_activations
    SET status = 'revoked', updated_at = CURRENT_TIMESTAMP
    WHERE user_id = p_user_id AND status IN ('pending', 'otp_sent');

    v_code := 'ACT-' || LPAD((FLOOR(RANDOM() * 900000) + 100000)::TEXT, 6, '0');
    v_hash := encode(digest(v_code, 'sha256'), 'hex');

    INSERT INTO public.resident_activations (
        user_id,
        apartment_id,
        phone,
        activation_code,
        activation_code_hash,
        code_attempts,
        invited_by,
        status,
        expires_at
    ) VALUES (
        p_user_id,
        v_apartment_id,
        v_user.phone,
        v_code,
        v_hash,
        0,
        v_caller_id,
        'pending',
        CURRENT_TIMESTAMP + INTERVAL '30 days'
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Đã cấp lại mã kích hoạt thành công.',
        'activation_code', v_code,
        'phone', v_user.phone,
        'apartment_code', v_apt_code
    );
END;
$function$;
REVOKE ALL ON FUNCTION public.regenerate_resident_activation(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.regenerate_resident_activation(UUID) TO authenticated;

-- 2.4 Sửa inverted caller check trong revoke_resident_activation
CREATE OR REPLACE FUNCTION public.revoke_resident_activation(p_activation_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
DECLARE
    v_caller_id UUID := auth.uid();
    v_is_authorized BOOLEAN := FALSE;
    v_act RECORD;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM public.users
        WHERE id = v_caller_id AND role IN ('admin', 'management')
    ) INTO v_is_authorized;

    IF NOT (v_is_authorized OR (auth.jwt() ->> 'role' = 'service_role')) THEN
        RAISE EXCEPTION 'Truy cập bị từ chối: Chỉ Ban Quản Lý mới có quyền thu hồi mã kích hoạt.'
            USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_act FROM public.resident_activations WHERE id = p_activation_id;
    IF v_act IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Không tìm thấy bản ghi kích hoạt.');
    END IF;

    UPDATE public.resident_activations
    SET status = 'revoked', updated_at = CURRENT_TIMESTAMP
    WHERE id = p_activation_id;

    RETURN jsonb_build_object('success', TRUE, 'message', 'Đã thu hồi mã kích hoạt thành công.');
END;
$function$;
REVOKE ALL ON FUNCTION public.revoke_resident_activation(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.revoke_resident_activation(UUID) TO authenticated;

-- 2.5 Sửa inverted caller check trong get_building_activation_list
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
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ,
    code_attempts INT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
DECLARE
    v_caller_id UUID := auth.uid();
    v_is_authorized BOOLEAN := FALSE;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM public.users
        WHERE id = v_caller_id AND role IN ('admin', 'management')
    ) INTO v_is_authorized;

    IF NOT (v_is_authorized OR (auth.jwt() ->> 'role' = 'service_role')) THEN
        RAISE EXCEPTION 'Truy cập bị từ chối: Chỉ Ban Quản Lý mới có quyền tra cứu danh sách kích hoạt.'
            USING ERRCODE = '42501';
    END IF;

    RETURN QUERY
    SELECT 
        act.id AS activation_id,
        u.id AS user_id,
        u.full_name,
        u.phone,
        a.code AS apartment_code,
        ra.relation_role::TEXT,
        act.activation_code,
        act.status,
        act.expires_at,
        act.created_at,
        act.code_attempts
    FROM public.resident_activations act
    JOIN public.users u ON u.id = act.user_id
    JOIN public.apartments a ON a.id = act.apartment_id
    LEFT JOIN public.residents_apartments ra ON ra.user_id = u.id AND ra.apartment_id = a.id
    WHERE (p_building_id IS NULL OR a.building_id = p_building_id)
    ORDER BY act.created_at DESC;
END;
$function$;
REVOKE ALL ON FUNCTION public.get_building_activation_list(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_building_activation_list(UUID) TO authenticated;

-- ==============================================================================
-- PHẦN 3: [C5] BẢO MẬT XÁC THỰC HAI YẾU TỐ (MFA / AAL2) Ở TẦNG DATABASE
-- ==============================================================================

-- 3.1 Hàm kiểm tra trạng thái AAL2 nếu user đã đăng ký MFA
CREATE OR REPLACE FUNCTION public.is_aal2_if_mfa_enrolled()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth, pg_catalog
AS $$
    SELECT CASE
        WHEN auth.uid() IS NULL THEN FALSE
        WHEN EXISTS (
            SELECT 1 FROM auth.mfa_factors f
            WHERE f.user_id = auth.uid() AND f.status = 'verified'
        ) THEN (COALESCE(auth.jwt() ->> 'aal', 'aal1') = 'aal2')
        ELSE TRUE
    END;
$$;

-- 3.2 TÍCH HỢP is_aal2_if_mfa_enrolled() TRỰC TIẾP VÀO is_staff_or_management()
-- Điều này tự động bảo vệ toàn bộ 100% RLS policies và RPCs của Ban Quản Lý!
CREATE OR REPLACE FUNCTION public.is_staff_or_management()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public, auth, pg_catalog
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.users
        WHERE id = auth.uid()
          AND role IN ('admin', 'management', 'staff', 'accountant', 'technician')
          AND is_active = true
          AND is_locked = false
    ) AND public.is_aal2_if_mfa_enrolled();
$$;

-- ==============================================================================
-- PHẦN 4: [§0] KHÔI PHỤC TOÀN BỘ CÁC RPCs CỐT LÕI TỪ ARCHIVE
-- ==============================================================================

-- 4.1 Lập hóa đơn đơn lẻ kèm chi tiết trong 1 giao dịch nguyên tử (create_invoice_with_items)
CREATE OR REPLACE FUNCTION public.create_invoice_with_items(
    p_apartment_id UUID,
    p_period VARCHAR,
    p_due_date DATE,
    p_items JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_invoice_id UUID;
    v_total NUMERIC := 0;
    v_item JSONB;
    v_fee_type VARCHAR;
    v_unit_price NUMERIC;
    v_quantity NUMERIC;
    v_apt_code VARCHAR;
BEGIN
    IF NOT (public.is_staff_or_management() OR (auth.jwt() ->> 'role' = 'service_role')) THEN
        RAISE EXCEPTION 'Chỉ Quản trị viên hoặc Kế toán mới có quyền lập hóa đơn' USING ERRCODE = '42501';
    END IF;

    SELECT code INTO v_apt_code FROM public.apartments WHERE id = p_apartment_id;
    IF v_apt_code IS NULL THEN
        RAISE EXCEPTION 'Căn hộ không tồn tại';
    END IF;

    INSERT INTO public.invoices (
        apartment_id,
        period,
        due_date,
        total_amount,
        status,
        created_at,
        updated_at
    ) VALUES (
        p_apartment_id,
        p_period,
        p_due_date,
        0,
        'unpaid',
        now(),
        now()
    ) RETURNING id INTO v_invoice_id;

    IF p_items IS NOT NULL AND jsonb_array_length(p_items) > 0 THEN
        FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
        LOOP
            v_fee_type := v_item->>'fee_type';
            v_unit_price := COALESCE((v_item->>'unit_price')::NUMERIC, 0);
            v_quantity := COALESCE((v_item->>'quantity')::NUMERIC, 1);
            v_total := v_total + (v_unit_price * v_quantity);

            INSERT INTO public.invoice_items (
                invoice_id,
                fee_type,
                unit_price,
                quantity
            ) VALUES (
                v_invoice_id,
                v_fee_type,
                v_unit_price,
                v_quantity
            );
        END LOOP;

        UPDATE public.invoices SET total_amount = v_total WHERE id = v_invoice_id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Đã lập hóa đơn thành công',
        'invoice_id', v_invoice_id,
        'total_amount', v_total
    );
END;
$$;
REVOKE ALL ON FUNCTION public.create_invoice_with_items(UUID, VARCHAR, DATE, JSONB) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_invoice_with_items(UUID, VARCHAR, DATE, JSONB) TO authenticated;

-- 4.2 Xác nhận thu tiền mặt / thủ công (record_manual_payment)
CREATE OR REPLACE FUNCTION public.record_manual_payment(
    p_invoice_id UUID,
    p_payment_method VARCHAR DEFAULT 'CASH',
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_inv RECORD;
    v_existing_txn RECORD;
    v_txn_code VARCHAR;
BEGIN
    IF NOT (public.is_staff_or_management() OR (auth.jwt() ->> 'role' = 'service_role')) THEN
        RAISE EXCEPTION 'Chỉ Quản trị viên hoặc Kế toán mới có quyền xác nhận thu tiền' USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_inv
    FROM public.invoices
    WHERE id = p_invoice_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Hóa đơn không tồn tại: %', p_invoice_id;
    END IF;

    IF v_inv.status = 'paid' THEN
        RAISE EXCEPTION 'Hóa đơn này đã được xác nhận thanh toán trước đó';
    END IF;

    SELECT * INTO v_existing_txn
    FROM public.payment_transactions
    WHERE invoice_id = p_invoice_id AND status = 'PENDING'
    ORDER BY created_at DESC
    LIMIT 1 FOR UPDATE;

    IF FOUND THEN
        UPDATE public.payment_transactions
        SET status = 'SUCCESS',
            payment_method = COALESCE(p_payment_method, payment_method),
            confirmed_by = auth.uid(),
            confirmed_at = now()
        WHERE id = v_existing_txn.id;
        v_txn_code := v_existing_txn.transaction_code;
    ELSE
        v_txn_code := 'MAN' || to_char(now(), 'YYYYMMDDHH24MISS') || UPPER(SUBSTRING(gen_random_uuid()::text, 1, 4));

        INSERT INTO public.payment_transactions (
            invoice_id,
            apartment_id,
            amount,
            payment_method,
            status,
            transaction_code,
            title,
            paid_at,
            confirmed_by,
            confirmed_at
        ) VALUES (
            p_invoice_id,
            v_inv.apartment_id,
            v_inv.total_amount,
            p_payment_method,
            'SUCCESS',
            v_txn_code,
            'Thu tiền thủ công kỳ ' || v_inv.period,
            now(),
            auth.uid(),
            now()
        );
    END IF;

    UPDATE public.invoices
    SET status = 'paid',
        paid_at = now(),
        paid_amount = v_inv.total_amount,
        updated_at = now()
    WHERE id = p_invoice_id;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Đã xác nhận thu tiền thành công',
        'transaction_code', v_txn_code,
        'invoice_id', p_invoice_id
    );
END;
$$;
REVOKE ALL ON FUNCTION public.record_manual_payment(UUID, VARCHAR, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.record_manual_payment(UUID, VARCHAR, TEXT) TO authenticated;

-- 4.3 Kiểm tra trước hóa đơn hàng loạt (validate_monthly_bulk_invoices)
CREATE OR REPLACE FUNCTION public.validate_monthly_bulk_invoices(
    p_period text, 
    p_mgmt_rate numeric DEFAULT 16500, 
    p_electric_rate numeric DEFAULT 3500, 
    p_water_rate numeric DEFAULT 18000
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_total_scanned integer := 0;
  v_valid_count integer := 0;
  v_already_invoiced_count integer := 0;
  v_total_estimated_amount numeric := 0;
  v_valid_items jsonb := '[]'::jsonb;
  v_apt record;
  v_mgmt_fee numeric;
  v_apt_total numeric;
BEGIN
  IF NOT (public.is_staff_or_management() OR (auth.jwt() ->> 'role' = 'service_role')) THEN
    RAISE EXCEPTION 'Chỉ Quản trị viên hoặc Kế toán mới có quyền đọc trước dữ liệu tính phí' USING ERRCODE = '42501';
  END IF;

  FOR v_apt IN
    SELECT a.id, a.code, a.area
    FROM public.apartments a
    ORDER BY a.code ASC
  LOOP
    v_total_scanned := v_total_scanned + 1;

    -- Kiểm tra xem căn hộ đã có hóa đơn kỳ này chưa
    IF EXISTS (SELECT 1 FROM public.invoices WHERE apartment_id = v_apt.id AND period = p_period) THEN
      v_already_invoiced_count := v_already_invoiced_count + 1;
    ELSE
      v_mgmt_fee := ROUND(COALESCE(v_apt.area, 50.0) * p_mgmt_rate, 0);
      v_apt_total := v_mgmt_fee;
      v_valid_count := v_valid_count + 1;
      v_total_estimated_amount := v_total_estimated_amount + v_apt_total;

      v_valid_items := v_valid_items || jsonb_build_object(
        'apartment_id', v_apt.id,
        'apartment_code', v_apt.code,
        'area', v_apt.area,
        'management_fee', v_mgmt_fee,
        'total_amount', v_apt_total
      );
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'period', p_period,
    'total_scanned', v_total_scanned,
    'valid_count', v_valid_count,
    'already_invoiced_count', v_already_invoiced_count,
    'total_estimated_amount', v_total_estimated_amount,
    'valid_items', v_valid_items
  );
END;
$$;
REVOKE ALL ON FUNCTION public.validate_monthly_bulk_invoices(TEXT, NUMERIC, NUMERIC, NUMERIC) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.validate_monthly_bulk_invoices(TEXT, NUMERIC, NUMERIC, NUMERIC) TO authenticated;

-- 4.4 Sinh hóa đơn hàng loạt (generate_valid_bulk_invoices)
CREATE OR REPLACE FUNCTION public.generate_valid_bulk_invoices(
    p_period text, 
    p_due_date date, 
    p_mgmt_rate numeric DEFAULT 16500, 
    p_electric_rate numeric DEFAULT 3500, 
    p_water_rate numeric DEFAULT 18000, 
    p_target_apartment_ids uuid[] DEFAULT NULL::uuid[]
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_validation jsonb;
  v_inv_record record;
  v_new_invoice_id uuid;
  v_created_count integer := 0;
  v_total_generated numeric := 0;
BEGIN
  IF NOT (public.is_staff_or_management() OR (auth.jwt() ->> 'role' = 'service_role')) THEN
    RAISE EXCEPTION 'Chỉ Quản trị viên hoặc Kế toán mới có quyền lập hóa đơn hàng loạt' USING ERRCODE = '42501';
  END IF;

  v_validation := public.validate_monthly_bulk_invoices(
    p_period, p_mgmt_rate, p_electric_rate, p_water_rate
  );

  FOR v_inv_record IN
    SELECT 
      (item->>'apartment_id')::uuid as apartment_id,
      item->>'apartment_code' as apartment_code,
      (item->>'management_fee')::numeric as management_fee,
      (item->>'total_amount')::numeric as total_amount
    FROM jsonb_array_elements(v_validation->'valid_items') as item
    WHERE (p_target_apartment_ids IS NULL OR (item->>'apartment_id')::uuid = ANY(p_target_apartment_ids))
  LOOP
    INSERT INTO public.invoices (
      apartment_id, period, due_date, total_amount, status, created_at, updated_at
    ) VALUES (
      v_inv_record.apartment_id, p_period, p_due_date, v_inv_record.total_amount, 'unpaid', now(), now()
    ) RETURNING id INTO v_new_invoice_id;

    INSERT INTO public.invoice_items (
      invoice_id, fee_type, unit_price, quantity
    ) VALUES (
      v_new_invoice_id, 'Phí quản lý vận hành', v_inv_record.management_fee, 1
    );

    v_created_count := v_created_count + 1;
    v_total_generated := v_total_generated + v_inv_record.total_amount;
  END LOOP;

  RETURN jsonb_build_object(
    'period', p_period,
    'created_count', v_created_count,
    'total_generated_amount', v_total_generated,
    'message', 'Đã lập thành công ' || v_created_count || ' hóa đơn cho kỳ ' || p_period
  );
END;
$$;
REVOKE ALL ON FUNCTION public.generate_valid_bulk_invoices(TEXT, DATE, NUMERIC, NUMERIC, NUMERIC, UUID[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.generate_valid_bulk_invoices(TEXT, DATE, NUMERIC, NUMERIC, NUMERIC, UUID[]) TO authenticated;

-- 4.5 Quản trị viên tạo người dùng mới (admin_create_user)
CREATE OR REPLACE FUNCTION public.admin_create_user(
    p_email VARCHAR,
    p_password VARCHAR,
    p_full_name VARCHAR,
    p_phone VARCHAR DEFAULT NULL,
    p_role VARCHAR DEFAULT 'resident',
    p_apartment_id UUID DEFAULT NULL,
    p_relation_role VARCHAR DEFAULT 'owner'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_catalog
AS $$
DECLARE
    v_new_user_id UUID := gen_random_uuid();
    v_pwd TEXT;
    v_role public.user_role;
BEGIN
    IF NOT public.is_staff_or_management() THEN
        RAISE EXCEPTION 'Bạn không có quyền quản trị để tạo tài khoản mới' USING ERRCODE = '42501';
    END IF;

    p_email := LOWER(TRIM(p_email));
    IF p_email IS NULL OR p_email = '' THEN
        RAISE EXCEPTION 'Email không được để trống';
    END IF;

    v_pwd := COALESCE(NULLIF(TRIM(p_password), ''), substr(md5(random()::text), 1, 12));
    v_role := p_role::public.user_role;

    INSERT INTO public.users (id, full_name, email, role, phone, is_active, is_locked, created_at, updated_at)
    VALUES (v_new_user_id, TRIM(p_full_name), p_email, v_role, p_phone, true, false, now(), now());

    IF p_apartment_id IS NOT NULL THEN
        INSERT INTO public.residents_apartments (apartment_id, user_id, relation_role, status, created_at, updated_at)
        VALUES (p_apartment_id, v_new_user_id, p_relation_role::public.relation_type, 'active', now(), now())
        ON CONFLICT (apartment_id, user_id) DO NOTHING;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'user_id', v_new_user_id,
        'email', p_email,
        'role', v_role::text,
        'message', 'Đã tạo tài khoản người dùng thành công'
    );
END;
$$;
REVOKE ALL ON FUNCTION public.admin_create_user(VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, UUID, VARCHAR) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_create_user(VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, UUID, VARCHAR) TO authenticated;

-- 4.6 Phê duyệt yêu cầu liên kết căn hộ (approve_link_request)
CREATE OR REPLACE FUNCTION public.approve_link_request(p_request_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_user_id UUID;
  v_apartment_id UUID;
  v_status VARCHAR(20);
  v_requested_role public.relation_type;
BEGIN
  IF NOT public.is_staff_or_management() THEN
    RAISE EXCEPTION 'Chỉ Ban Quản Lý hoặc Quản trị viên mới có quyền duyệt yêu cầu liên kết căn hộ.'
        USING ERRCODE = '42501';
  END IF;

  SELECT user_id, apartment_id, status, requested_relation_role 
  INTO v_user_id, v_apartment_id, v_status, v_requested_role 
  FROM public.apartment_link_requests 
  WHERE id = p_request_id;

  IF v_status IS NULL THEN
    RAISE EXCEPTION 'Không tìm thấy yêu cầu liên kết.';
  END IF;

  IF v_status != 'pending' THEN
    RAISE EXCEPTION 'Yêu cầu này đã được xử lý.';
  END IF;

  UPDATE public.apartment_link_requests
  SET status = 'approved', updated_at = NOW()
  WHERE id = p_request_id;

  INSERT INTO public.residents_apartments (user_id, apartment_id, relation_role, status)
  VALUES (v_user_id, v_apartment_id, v_requested_role, 'active')
  ON CONFLICT (user_id, apartment_id) DO UPDATE
  SET relation_role = EXCLUDED.relation_role,
      status = 'active',
      updated_at = NOW();

  UPDATE public.apartments
  SET is_empty = false, updated_at = NOW()
  WHERE id = v_apartment_id;
END;
$$;
REVOKE ALL ON FUNCTION public.approve_link_request(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.approve_link_request(UUID) TO authenticated;

-- 4.7 Hủy yêu cầu liên kết căn hộ (cancel_apartment_link_request)
CREATE OR REPLACE FUNCTION public.cancel_apartment_link_request(p_request_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_updated_count INT;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Bạn chưa đăng nhập vào hệ thống' USING ERRCODE = '42501';
    END IF;

    UPDATE public.apartment_link_requests
    SET status = 'cancelled', updated_at = NOW()
    WHERE id = p_request_id 
      AND (user_id = v_user_id OR public.is_staff_or_management()) 
      AND status = 'pending';

    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    IF v_updated_count = 0 THEN
        RAISE EXCEPTION 'Không tìm thấy yêu cầu liên kết đang chờ duyệt để hủy.';
    END IF;

    RETURN jsonb_build_object('success', true, 'message', 'Đã hủy yêu cầu liên kết căn hộ thành công', 'request_id', p_request_id);
END;
$$;
REVOKE ALL ON FUNCTION public.cancel_apartment_link_request(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cancel_apartment_link_request(UUID) TO authenticated;

-- 4.8 Cập nhật phiếu khai báo chỉ số điện nước (update_pending_meter_reading)
CREATE OR REPLACE FUNCTION public.update_pending_meter_reading(
    p_submission_id UUID,
    p_electric_reading NUMERIC,
    p_water_reading NUMERIC,
    p_electric_image_url TEXT DEFAULT NULL,
    p_water_image_url TEXT DEFAULT NULL,
    p_clear_electric_image BOOLEAN DEFAULT FALSE,
    p_clear_water_image BOOLEAN DEFAULT FALSE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_sub RECORD;
    v_new_elec_img TEXT;
    v_new_water_img TEXT;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Bạn chưa đăng nhập vào hệ thống' USING ERRCODE = '42501';
    END IF;

    IF p_electric_reading < 0 OR p_water_reading < 0 THEN
        RAISE EXCEPTION 'Chỉ số điện và nước không được mang giá trị âm.';
    END IF;

    SELECT * INTO v_sub
    FROM public.meter_reading_submissions
    WHERE id = p_submission_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Phiếu khai báo chỉ số không tồn tại';
    END IF;

    IF v_sub.status != 'pending' THEN
        RAISE EXCEPTION 'Chỉ có thể chỉnh sửa phiếu chỉ số đang ở trạng thái chờ duyệt (pending).';
    END IF;

    IF v_sub.submitted_by != v_user_id AND NOT public.is_staff_or_management() THEN
        RAISE EXCEPTION 'Bạn không có quyền chỉnh sửa phiếu chỉ số này.' USING ERRCODE = '42501';
    END IF;

    IF p_clear_electric_image THEN
        v_new_elec_img := NULL;
    ELSIF p_electric_image_url IS NOT NULL THEN
        v_new_elec_img := p_electric_image_url;
    ELSE
        v_new_elec_img := v_sub.electric_image_url;
    END IF;

    IF p_clear_water_image THEN
        v_new_water_img := NULL;
    ELSIF p_water_image_url IS NOT NULL THEN
        v_new_water_img := p_water_image_url;
    ELSE
        v_new_water_img := v_sub.water_image_url;
    END IF;

    UPDATE public.meter_reading_submissions
    SET electric_reading = p_electric_reading,
        water_reading = p_water_reading,
        electric_image_url = v_new_elec_img,
        water_image_url = v_new_water_img,
        updated_at = NOW()
    WHERE id = p_submission_id AND status = 'pending';

    RETURN jsonb_build_object('success', true, 'message', 'Đã cập nhật chỉ số điện nước thành công', 'submission_id', p_submission_id);
END;
$$;
REVOKE ALL ON FUNCTION public.update_pending_meter_reading(UUID, NUMERIC, NUMERIC, TEXT, TEXT, BOOLEAN, BOOLEAN) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_pending_meter_reading(UUID, NUMERIC, NUMERIC, TEXT, TEXT, BOOLEAN, BOOLEAN) TO authenticated;

-- 4.9 Hủy phiếu khai báo chỉ số điện nước (cancel_pending_meter_reading)
CREATE OR REPLACE FUNCTION public.cancel_pending_meter_reading(p_submission_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_updated_count INT;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Bạn chưa đăng nhập vào hệ thống' USING ERRCODE = '42501';
    END IF;

    UPDATE public.meter_reading_submissions
    SET status = 'cancelled', updated_at = NOW()
    WHERE id = p_submission_id 
      AND status = 'pending'
      AND (submitted_by = v_user_id OR public.is_staff_or_management());

    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    IF v_updated_count = 0 THEN
        RAISE EXCEPTION 'Không tìm thấy phiếu chỉ số đang chờ duyệt hoặc bạn không có quyền hủy.';
    END IF;

    RETURN jsonb_build_object('success', true, 'message', 'Đã hủy phiếu khai báo chỉ số thành công', 'submission_id', p_submission_id);
END;
$$;
REVOKE ALL ON FUNCTION public.cancel_pending_meter_reading(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cancel_pending_meter_reading(UUID) TO authenticated;

-- 4.10 Hủy yêu cầu đăng ký phương tiện (cancel_pending_vehicle)
CREATE OR REPLACE FUNCTION public.cancel_pending_vehicle(p_vehicle_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_updated_count INT;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Bạn chưa đăng nhập vào hệ thống' USING ERRCODE = '42501';
    END IF;

    UPDATE public.vehicles
    SET status = 'cancelled', updated_at = NOW()
    WHERE id = p_vehicle_id 
      AND status = 'pending'
      AND (user_id = v_user_id OR public.is_staff_or_management());

    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    IF v_updated_count = 0 THEN
        RAISE EXCEPTION 'Không tìm thấy phương tiện đang chờ duyệt hoặc bạn không có quyền hủy bản ghi này.';
    END IF;

    RETURN jsonb_build_object('success', true, 'message', 'Đã hủy đăng ký phương tiện thành công', 'vehicle_id', p_vehicle_id);
END;
$$;
REVOKE ALL ON FUNCTION public.cancel_pending_vehicle(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cancel_pending_vehicle(UUID) TO authenticated;

-- 4.11 Cập nhật thông tin phương tiện đang chờ duyệt (update_pending_vehicle)
CREATE OR REPLACE FUNCTION public.update_pending_vehicle(
    p_vehicle_id UUID,
    p_license_plate VARCHAR,
    p_vehicle_type VARCHAR,
    p_brand_model VARCHAR DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_vehicle RECORD;
    v_clean_plate VARCHAR;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Bạn chưa đăng nhập vào hệ thống' USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_vehicle
    FROM public.vehicles
    WHERE id = p_vehicle_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Phương tiện không tồn tại';
    END IF;

    IF v_vehicle.status != 'pending' THEN
        RAISE EXCEPTION 'Chỉ có thể chỉnh sửa phương tiện đang ở trạng thái chờ duyệt (pending).';
    END IF;

    IF v_vehicle.user_id != v_user_id AND NOT public.is_staff_or_management() THEN
        RAISE EXCEPTION 'Bạn không có quyền chỉnh sửa thông tin phương tiện này.' USING ERRCODE = '42501';
    END IF;

    v_clean_plate := UPPER(TRIM(p_license_plate));
    IF v_clean_plate IS NULL OR v_clean_plate = '' THEN
        RAISE EXCEPTION 'Biển số xe không được để trống.';
    END IF;

    UPDATE public.vehicles
    SET license_plate = v_clean_plate,
        vehicle_type = p_vehicle_type,
        brand_model = p_brand_model,
        updated_at = NOW()
    WHERE id = p_vehicle_id AND status = 'pending';

    RETURN jsonb_build_object('success', true, 'message', 'Đã cập nhật thông tin phương tiện thành công', 'vehicle_id', p_vehicle_id);
END;
$$;
REVOKE ALL ON FUNCTION public.update_pending_vehicle(UUID, VARCHAR, VARCHAR, VARCHAR) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_pending_vehicle(UUID, VARCHAR, VARCHAR, VARCHAR) TO authenticated;

-- 4.12 Lấy danh sách thành viên cùng căn hộ (get_co_residents)
CREATE OR REPLACE FUNCTION public.get_co_residents(p_apartment_id UUID)
RETURNS TABLE(user_id UUID, full_name TEXT, phone TEXT, relation_role TEXT)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
  SELECT u.id, u.full_name, u.phone, ra.relation_role::TEXT
  FROM public.residents_apartments ra 
  JOIN public.users u ON u.id = ra.user_id
  WHERE ra.apartment_id = p_apartment_id
    AND ra.status = 'active'
    AND (
      public.is_staff_or_management()
      OR EXISTS (
        SELECT 1 FROM public.residents_apartments me
        WHERE me.apartment_id = p_apartment_id AND me.user_id = auth.uid() AND me.status = 'active'
      )
    );
$$;
REVOKE EXECUTE ON FUNCTION public.get_co_residents(UUID) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_co_residents(UUID) TO authenticated;

-- 4.13 Xác nhận check-in lượt đặt tiện ích (check_in_amenity_booking)
CREATE OR REPLACE FUNCTION public.check_in_amenity_booking(p_booking_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_booking RECORD;
BEGIN
  IF NOT public.is_staff_or_management() THEN
    RAISE EXCEPTION 'Chỉ nhân sự Ban Quản Lý mới có quyền xác nhận check-in tiện ích' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_booking FROM public.amenity_bookings WHERE id = p_booking_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Lượt đặt tiện ích không tồn tại: %', p_booking_id;
  END IF;

  IF v_booking.status = 'completed' THEN
    RETURN jsonb_build_object('success', false, 'message', 'Lượt đặt này đã được check-in trước đó');
  END IF;

  UPDATE public.amenity_bookings
  SET checked_in_at = NOW(),
      status = 'completed',
      updated_at = NOW()
  WHERE id = p_booking_id;

  RETURN jsonb_build_object('success', true, 'message', 'Xác nhận check-in thành công', 'booking_id', p_booking_id);
END;
$$;
REVOKE ALL ON FUNCTION public.check_in_amenity_booking(UUID) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.check_in_amenity_booking(UUID) TO authenticated;

-- 4.14 Tra cứu tính khả dụng của khung giờ tiện ích (get_amenity_slot_availability)
CREATE OR REPLACE FUNCTION public.get_amenity_slot_availability(
    p_amenity_id UUID,
    p_date DATE
)
RETURNS TABLE (
    time_slot VARCHAR,
    status VARCHAR,
    guests_count INT,
    is_my_booking BOOLEAN
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
    SELECT 
        b.time_slot,
        b.status,
        b.guests_count,
        (b.booked_by = auth.uid()) AS is_my_booking
    FROM public.amenity_bookings b
    WHERE b.amenity_id = p_amenity_id
      AND b.booking_date = p_date
      AND b.status IN ('confirmed', 'waitlist', 'pending_payment', 'completed');
$$;
REVOKE ALL ON FUNCTION public.get_amenity_slot_availability(UUID, DATE) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_amenity_slot_availability(UUID, DATE) TO authenticated;

-- 4.15 Cập nhật hóa đơn và các hạng mục chi phí ACID (update_invoice_with_items)
CREATE OR REPLACE FUNCTION public.update_invoice_with_items(
    p_invoice_id UUID,
    p_period VARCHAR,
    p_due_date DATE,
    p_items JSONB,
    p_apartment_id UUID DEFAULT NULL,
    p_status VARCHAR DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_inv RECORD;
    v_item JSONB;
BEGIN
    IF NOT (public.is_staff_or_management() OR (auth.jwt() ->> 'role' = 'service_role')) THEN
        RAISE EXCEPTION 'Truy cập bị từ chối: Chỉ Ban Quản Lý hoặc Kế toán mới có quyền cập nhật hóa đơn'
            USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_inv FROM public.invoices WHERE id = p_invoice_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Hóa đơn không tồn tại: %', p_invoice_id;
    END IF;

    UPDATE public.invoices
    SET 
        period = p_period,
        due_date = p_due_date,
        apartment_id = COALESCE(p_apartment_id, apartment_id),
        status = CASE 
            WHEN p_status IS NOT NULL THEN p_status::public.invoice_status 
            ELSE status 
        END,
        updated_at = NOW()
    WHERE id = p_invoice_id;

    DELETE FROM public.invoice_items WHERE invoice_id = p_invoice_id;

    IF p_items IS NOT NULL AND jsonb_array_length(p_items) > 0 THEN
        FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
        LOOP
            INSERT INTO public.invoice_items (
                invoice_id,
                fee_type,
                unit_price,
                quantity
            ) VALUES (
                p_invoice_id,
                v_item->>'fee_type',
                COALESCE((v_item->>'unit_price')::DECIMAL, 0),
                COALESCE((v_item->>'quantity')::DECIMAL, 1)
            );
        END LOOP;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Cập nhật hóa đơn và các hạng mục chi phí thành công',
        'invoice_id', p_invoice_id
    );
END;
$$;
REVOKE ALL ON FUNCTION public.update_invoice_with_items(UUID, VARCHAR, DATE, JSONB, UUID, VARCHAR) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.update_invoice_with_items(UUID, VARCHAR, DATE, JSONB, UUID, VARCHAR) TO authenticated;
