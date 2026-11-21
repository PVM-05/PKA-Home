-- ==============================================================================
-- Vivona Production Commercial SaaS: Migration 20261120040000_patch_activation_and_staff_roles.sql
-- Mục tiêu:
-- 1. [Bảo Vệ Đa Tầng] Đảm bảo mọi môi trường DB (kể cả nơi đã áp dụng 20261120_03 bản cũ)
--    đều nhận đầy đủ các bản vá lỗi triển khai và 3 RPCs mới.
-- 2. [Blocker 1] Loại bỏ enum 'manager' không tồn tại khỏi is_staff_or_management().
-- 3. [Blocker 2] Dùng đúng cột code_attempts, expires_at thay vì failed_attempts.
-- 4. [Blocker 3] Gán status = 'otp_sent' khi sinh OTP và trả về full_name, apartment_code.
-- 5. [§0] Bổ sung 3 RPCs còn lại: update_own_profile, get_upcoming_maintenance_equipments, record_meter_reading.
-- 6. Mở rộng đầy đủ các trường của bảng building_equipments tương thích BuildingEquipmentModel.
-- ==============================================================================

-- 1. Đảm bảo cấu trúc cột của bảng resident_activations
ALTER TABLE public.resident_activations ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ DEFAULT (CURRENT_TIMESTAMP + INTERVAL '30 days');
ALTER TABLE public.resident_activations ADD COLUMN IF NOT EXISTS code_attempts INT DEFAULT 0;

-- 2. Khắc phục triệt để verify_activation_code (Server-Authoritative, code_attempts, status='otp_sent')
CREATE OR REPLACE FUNCTION public.verify_activation_code(
    p_phone TEXT,
    p_activation_code TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_clean_phone TEXT;
    v_clean_code TEXT;
    v_record RECORD;
    v_user_name TEXT;
    v_apartment_code TEXT;
    v_otp_code TEXT;
    v_hashed_input TEXT;
    v_is_prod BOOLEAN;
BEGIN
    v_clean_phone := regexp_replace(p_phone, '[^0-9]', '', 'g');
    v_clean_code := UPPER(TRIM(p_activation_code));

    -- Server tự xác định môi trường hoạt động
    v_is_prod := public.is_production_environment();

    -- 1. Tìm bản ghi kích hoạt đang chờ hoặc đã gửi OTP
    SELECT * INTO v_record
    FROM public.resident_activations
    WHERE phone = v_clean_phone AND status IN ('pending', 'otp_sent')
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error_code', 'NOT_FOUND',
            'message', 'Không tìm thấy thông tin kích hoạt cho số điện thoại này. Vui lòng liên hệ BQL.'
        );
    END IF;

    -- 2. Kiểm tra Rate Limiting (Tối đa 5 lần thử sai)
    IF COALESCE(v_record.code_attempts, 0) >= 5 THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error_code', 'MAX_ATTEMPTS_EXCEEDED',
            'message', 'Mã kích hoạt đã bị khóa do nhập sai quá 5 lần. Vui lòng yêu cầu BQL cấp mã mới.'
        );
    END IF;

    -- 3. Kiểm tra hết hạn mã kích hoạt
    IF COALESCE(v_record.expires_at, v_record.created_at + INTERVAL '30 days') < CURRENT_TIMESTAMP THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error_code', 'EXPIRED',
            'message', 'Mã kích hoạt đã hết hạn. Vui lòng liên hệ Ban Quản Lý để được cấp mã mới.'
        );
    END IF;

    -- 4. Kiểm tra khớp mã kích hoạt
    v_hashed_input := encode(digest(v_clean_code, 'sha256'), 'hex');
    IF v_record.activation_code_hash IS NOT NULL AND v_record.activation_code_hash != '' THEN
        IF v_record.activation_code_hash != v_hashed_input THEN
            UPDATE public.resident_activations
            SET code_attempts = COALESCE(code_attempts, 0) + 1, updated_at = CURRENT_TIMESTAMP
            WHERE id = v_record.id;
            RETURN jsonb_build_object(
                'success', FALSE,
                'error_code', 'INVALID_CODE',
                'message', 'Mã kích hoạt không chính xác. Bạn còn ' || (4 - COALESCE(v_record.code_attempts, 0)) || ' lần thử.'
            );
        END IF;
    ELSE
        IF UPPER(TRIM(v_record.activation_code)) != v_clean_code THEN
            UPDATE public.resident_activations
            SET code_attempts = COALESCE(code_attempts, 0) + 1, updated_at = CURRENT_TIMESTAMP
            WHERE id = v_record.id;
            RETURN jsonb_build_object(
                'success', FALSE,
                'error_code', 'INVALID_CODE',
                'message', 'Mã kích hoạt không chính xác. Bạn còn ' || (4 - COALESCE(v_record.code_attempts, 0)) || ' lần thử.'
            );
        END IF;
    END IF;

    -- 5. Sinh mã OTP ngẫu nhiên 6 chữ số thực tế (100000 - 999999)
    v_otp_code := lpad(floor(random() * 900000 + 100000)::text, 6, '0');

    UPDATE public.resident_activations
    SET status = 'otp_sent',
        otp_code = v_otp_code,
        otp_expires_at = CURRENT_TIMESTAMP + INTERVAL '10 minutes',
        code_attempts = 0,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = v_record.id;

    -- 6. Lấy thông tin cư dân và căn hộ
    SELECT full_name INTO v_user_name FROM public.users WHERE id = v_record.user_id;
    SELECT code INTO v_apartment_code FROM public.apartments WHERE id = v_record.apartment_id;

    -- 7. Phản hồi server-authoritative
    IF NOT v_is_prod THEN
        -- Môi trường Dev/Staging: Trả về otp_hint để thông luồng kiểm thử
        RETURN jsonb_build_object(
            'success', TRUE,
            'user_name', COALESCE(v_user_name, 'Cư dân'),
            'full_name', COALESCE(v_user_name, 'Cư dân'),
            'apartment_code', COALESCE(v_apartment_code, ''),
            'phone', v_clean_phone,
            'activation_code', v_clean_code,
            'otp_hint', v_otp_code,
            'is_production', FALSE,
            'message', 'Mã kích hoạt hợp lệ. Chế độ thử nghiệm: Mã OTP tự động điền là ' || v_otp_code
        );
    ELSE
        -- Môi trường Production: Ẩn tuyệt đối otp_hint, phản hồi trung thực về SMS
        RETURN jsonb_build_object(
            'success', TRUE,
            'user_name', COALESCE(v_user_name, 'Cư dân'),
            'full_name', COALESCE(v_user_name, 'Cư dân'),
            'apartment_code', COALESCE(v_apartment_code, ''),
            'phone', v_clean_phone,
            'activation_code', v_clean_code,
            'is_production', TRUE,
            'sms_dispatched', FALSE,
            'message', 'Mã kích hoạt hợp lệ. Lưu ý: Cổng SMS Brandname của tòa nhà chưa được kết nối. Vui lòng liên hệ trực tiếp Ban Quản Lý tòa nhà để nhận mã xác thực OTP.'
        );
    END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.verify_activation_code(TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.verify_activation_code(TEXT, TEXT) TO anon, authenticated;

-- 3. Khắc phục is_staff_or_management(): Loại bỏ hoàn toàn enum 'manager' không tồn tại
CREATE OR REPLACE FUNCTION public.is_staff_or_management()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Cưỡng chế cấp độ xác thực AAL2 nếu người dùng đã kích hoạt MFA TOTP
  IF NOT public.is_aal2_if_mfa_enrolled() THEN
    RETURN FALSE;
  END IF;

  RETURN EXISTS (
    SELECT 1 FROM public.users
    WHERE id = auth.uid()
      AND role IN ('admin', 'management', 'staff', 'accountant', 'technician')
      AND is_active = true
      AND is_locked = false
  );
END;
$$;

-- 4. Bổ sung các cột cho building_equipments tương thích với BuildingEquipmentModel
ALTER TABLE public.building_equipments
    ADD COLUMN IF NOT EXISTS building TEXT DEFAULT 'Toàn khu',
    ADD COLUMN IF NOT EXISTS warranty_until DATE,
    ADD COLUMN IF NOT EXISTS maintenance_interval_days INTEGER DEFAULT 30,
    ADD COLUMN IF NOT EXISTS last_maintenance_date TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS next_maintenance_date TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS specifications TEXT;

CREATE INDEX IF NOT EXISTS idx_building_equipments_next_maint ON public.building_equipments(next_maintenance_date);

-- 5. Bổ sung 3 RPCs hoàn tất danh mục 22/22

-- 5.1 Cập nhật hồ sơ cá nhân an toàn (update_own_profile)
CREATE OR REPLACE FUNCTION public.update_own_profile(
    p_full_name VARCHAR DEFAULT NULL,
    p_phone VARCHAR DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_catalog
AS $$
DECLARE
    v_user RECORD;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Yêu cầu đăng nhập để cập nhật hồ sơ.';
    END IF;

    UPDATE public.users 
    SET 
        full_name = COALESCE(TRIM(p_full_name), full_name),
        phone = COALESCE(TRIM(p_phone), phone),
        updated_at = NOW()
    WHERE id = auth.uid()
    RETURNING id, full_name, phone, role, created_at, updated_at INTO v_user;

    RETURN to_jsonb(v_user);
END;
$$;

REVOKE ALL ON FUNCTION public.update_own_profile(VARCHAR, VARCHAR) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.update_own_profile(VARCHAR, VARCHAR) TO authenticated;

-- 5.2 Tra cứu thiết bị sắp đến hạn bảo trì trong N ngày (get_upcoming_maintenance_equipments)
CREATE OR REPLACE FUNCTION public.get_upcoming_maintenance_equipments(p_days_ahead INTEGER DEFAULT 7)
RETURNS SETOF public.building_equipments
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
    SELECT *
    FROM public.building_equipments
    WHERE next_maintenance_date IS NOT NULL
      AND next_maintenance_date <= (now() + (p_days_ahead || ' days')::interval)
      AND status != 'inactive'
    ORDER BY next_maintenance_date ASC;
$$;

REVOKE ALL ON FUNCTION public.get_upcoming_maintenance_equipments(INTEGER) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_upcoming_maintenance_equipments(INTEGER) TO authenticated;

-- 5.3 Ghi nhận chỉ số điện nước cá lẻ hoặc ngoại tuyến (record_meter_reading)
CREATE OR REPLACE FUNCTION public.record_meter_reading(
    p_apartment_id UUID DEFAULT NULL,
    p_period VARCHAR DEFAULT NULL,
    p_electric_reading NUMERIC DEFAULT 0,
    p_water_reading NUMERIC DEFAULT 0,
    p_electric_image_url TEXT DEFAULT NULL,
    p_water_image_url TEXT DEFAULT NULL,
    p_notes TEXT DEFAULT NULL,
    apartment_id UUID DEFAULT NULL,
    period VARCHAR DEFAULT NULL,
    electric_reading NUMERIC DEFAULT NULL,
    water_reading NUMERIC DEFAULT NULL,
    electric_image_url TEXT DEFAULT NULL,
    water_image_url TEXT DEFAULT NULL,
    notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_apt_id UUID;
    v_prd VARCHAR;
    v_elec NUMERIC;
    v_water NUMERIC;
    v_elec_img TEXT;
    v_water_img TEXT;
    v_nt TEXT;
    v_submission_id UUID;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Yêu cầu đăng nhập để ghi nhận chỉ số điện nước';
    END IF;

    v_apt_id := COALESCE(p_apartment_id, apartment_id);
    v_prd := COALESCE(p_period, period, to_char(CURRENT_DATE, 'YYYY-MM'));
    v_elec := COALESCE(p_electric_reading, electric_reading, 0);
    v_water := COALESCE(p_water_reading, water_reading, 0);
    v_elec_img := COALESCE(p_electric_image_url, electric_image_url);
    v_water_img := COALESCE(p_water_image_url, water_image_url);
    v_nt := COALESCE(p_notes, notes);

    IF v_apt_id IS NULL THEN
        RAISE EXCEPTION 'Mã định danh căn hộ (apartment_id) không được để trống';
    END IF;

    INSERT INTO public.meter_reading_submissions (
        apartment_id,
        submitted_by,
        period,
        electric_reading,
        water_reading,
        electric_image_url,
        water_image_url,
        status,
        anomaly_reason,
        created_at,
        updated_at
    ) VALUES (
        v_apt_id,
        auth.uid(),
        v_prd,
        v_elec,
        v_water,
        v_elec_img,
        v_water_img,
        'pending',
        v_nt,
        NOW(),
        NOW()
    ) RETURNING id INTO v_submission_id;

    RETURN jsonb_build_object(
        'success', true,
        'id', v_submission_id,
        'message', 'Đã ghi nhận chỉ số điện nước thành công'
    );
END;
$$;

REVOKE ALL ON FUNCTION public.record_meter_reading(UUID, VARCHAR, NUMERIC, NUMERIC, TEXT, TEXT, TEXT, UUID, VARCHAR, NUMERIC, NUMERIC, TEXT, TEXT, TEXT) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.record_meter_reading(UUID, VARCHAR, NUMERIC, NUMERIC, TEXT, TEXT, TEXT, UUID, VARCHAR, NUMERIC, NUMERIC, TEXT, TEXT, TEXT) TO authenticated;

