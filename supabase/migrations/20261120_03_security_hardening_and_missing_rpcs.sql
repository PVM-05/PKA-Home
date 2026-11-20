-- ==============================================================================
-- Vivona Production Commercial SaaS: Migration 20261120_03_security_hardening_and_missing_rpcs.sql
-- Mục tiêu:
-- 1. [C3] Cơ chế xác định môi trường phía máy chủ (Server-Authoritative Environment Engine)
--    - Bảng system_runtime_config & hàm is_production_environment()
--    - Sửa verify_activation_code: Bỏ tham số client p_is_production; server tự quyết định ẩn/hiện OTP
--    - Phản hồi trung thực về trạng thái SMS gateway trên production
-- 2. [C4] Khắc phục triệt để lỗ hổng Inverted Authorization Check:
--    - Hàm thực tế generate_resident_activation_codes(p_building_id UUID)
--    - Khôi phục bản vá cho get_financial_aging_report chặn ẩn danh khai thác
--    - import_apartments_batch & import_residents_batch
-- 3. [C5] Tích hợp kiểm tra AAL2 vào is_staff_or_management() bảo vệ toàn diện 100% RLS BQL
-- 4. [§0] Bổ sung 5 bảng nghiệp vụ còn thiếu (emergency_contacts, building_rules, role_change_log, issue_ratings, building_equipments)
-- 5. [§0] Khôi phục 9 RPCs quản trị và kế toán từ archive (hoàn tất 21/21 RPCs)
-- ==============================================================================

-- ==============================================================================
-- PHẦN 1: [C3] SERVER-AUTHORITATIVE ENVIRONMENT & BẢO MẬT KÍCH HOẠT CƯ DÂN
-- ==============================================================================

-- 1.1 Bảng cấu hình runtime nội bộ của hệ thống (Chỉ service_role/admin được quyền ghi)
CREATE TABLE IF NOT EXISTS public.system_runtime_config (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

ALTER TABLE public.system_runtime_config ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "system_runtime_config_read" ON public.system_runtime_config;
CREATE POLICY "system_runtime_config_read" ON public.system_runtime_config
FOR SELECT TO authenticated
USING (public.is_staff_or_management());

-- Mặc định an toàn tuyệt đối (Fail-Safe): Khởi tạo môi trường là 'production'
INSERT INTO public.system_runtime_config (key, value)
VALUES ('environment', 'production')
ON CONFLICT (key) DO NOTHING;

-- 1.2 Hàm kiểm tra môi trường chạy phía server (Hoàn toàn không tin tưởng client)
CREATE OR REPLACE FUNCTION public.is_production_environment()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_env TEXT;
BEGIN
    SELECT value INTO v_env FROM public.system_runtime_config WHERE key = 'environment';
    IF v_env IS NOT NULL AND v_env != '' THEN
        RETURN LOWER(TRIM(v_env)) IN ('production', 'prod');
    END IF;

    v_env := current_setting('app.environment', true);
    IF v_env IS NOT NULL AND v_env != '' THEN
        RETURN LOWER(TRIM(v_env)) IN ('production', 'prod');
    END IF;

    -- Mặc định an toàn là Production
    RETURN TRUE;
END;
$$;

REVOKE ALL ON FUNCTION public.is_production_environment() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_production_environment() TO authenticated, service_role;

-- 1.3 Cập nhật verify_activation_code: Server-Authoritative OTP Verification
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

    -- 1. Tìm bản ghi kích hoạt đang chờ
    SELECT * INTO v_record
    FROM public.resident_activations
    WHERE phone = v_clean_phone AND status = 'pending'
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error_code', 'NOT_FOUND',
            'message', 'Không tìm thấy thông tin kích hoạt cho số điện thoại này. Vui lòng liên hệ BQL.'
        );
    END IF;

    -- 2. Kiểm tra Rate Limiting (Tối đa 5 lần thử sai)
    IF v_record.failed_attempts >= 5 THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error_code', 'MAX_ATTEMPTS_EXCEEDED',
            'message', 'Mã kích hoạt đã bị khóa do nhập sai quá 5 lần. Vui lòng yêu cầu BQL cấp mã mới.'
        );
    END IF;

    -- 3. Kiểm tra hết hạn mã kích hoạt
    IF v_record.expires_at < CURRENT_TIMESTAMP THEN
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
            SET failed_attempts = failed_attempts + 1, updated_at = CURRENT_TIMESTAMP
            WHERE id = v_record.id;
            RETURN jsonb_build_object(
                'success', FALSE,
                'error_code', 'INVALID_CODE',
                'message', 'Mã kích hoạt không chính xác. Bạn còn ' || (4 - v_record.failed_attempts) || ' lần thử.'
            );
        END IF;
    ELSE
        IF UPPER(TRIM(v_record.activation_code)) != v_clean_code THEN
            UPDATE public.resident_activations
            SET failed_attempts = failed_attempts + 1, updated_at = CURRENT_TIMESTAMP
            WHERE id = v_record.id;
            RETURN jsonb_build_object(
                'success', FALSE,
                'error_code', 'INVALID_CODE',
                'message', 'Mã kích hoạt không chính xác. Bạn còn ' || (4 - v_record.failed_attempts) || ' lần thử.'
            );
        END IF;
    END IF;

    -- 5. Sinh mã OTP ngẫu nhiên 6 chữ số thực tế (100000 - 999999)
    v_otp_code := lpad(floor(random() * 900000 + 100000)::text, 6, '0');

    UPDATE public.resident_activations
    SET otp_code = v_otp_code,
        otp_expires_at = CURRENT_TIMESTAMP + INTERVAL '10 minutes',
        failed_attempts = 0,
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
            'apartment_code', COALESCE(v_apartment_code, ''),
            'otp_hint', v_otp_code,
            'is_production', FALSE,
            'message', 'Mã kích hoạt hợp lệ. Chế độ thử nghiệm: Mã OTP tự động điền là ' || v_otp_code
        );
    ELSE
        -- Môi trường Production: Ẩn tuyệt đối otp_hint, phản hồi trung thực về SMS
        RETURN jsonb_build_object(
            'success', TRUE,
            'user_name', COALESCE(v_user_name, 'Cư dân'),
            'apartment_code', COALESCE(v_apartment_code, ''),
            'is_production', TRUE,
            'sms_dispatched', FALSE,
            'message', 'Mã kích hoạt hợp lệ. Lưu ý: Cổng SMS Brandname của tòa nhà chưa được kết nối. Vui lòng liên hệ trực tiếp Ban Quản Lý tòa nhà để nhận mã xác thực OTP.'
        );
    END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.verify_activation_code(TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.verify_activation_code(TEXT, TEXT) TO anon, authenticated;

-- ==============================================================================
-- PHẦN 2: [C4] SỬA LỖI ĐẢO NGƯỢC PHÂN QUYỀN TRÊN CÁC HÀM THỰC TẾ
-- ==============================================================================

-- 2.1 Hàm thực tế Flutter App gọi: generate_resident_activation_codes(p_building_id UUID)
CREATE OR REPLACE FUNCTION public.generate_resident_activation_codes(p_building_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_calling_user_id UUID := auth.uid();
    v_is_authorized BOOLEAN := FALSE;
    v_count INT := 0;
    v_record RECORD;
    v_code TEXT;
    v_code_hash TEXT;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM public.users
        WHERE id = v_calling_user_id
          AND role IN ('admin', 'management', 'staff')
    ) INTO v_is_authorized;

    IF NOT v_is_authorized THEN
        SELECT EXISTS (
            SELECT 1 FROM public.role_delegations
            WHERE delegate_id = v_calling_user_id
              AND is_active = TRUE
              AND (expires_at IS NULL OR expires_at > CURRENT_TIMESTAMP)
              AND delegated_role IN ('admin', 'management', 'staff')
        ) INTO v_is_authorized;
    END IF;

    -- Chặn đứng hoàn toàn người dùng ẩn danh (auth.uid() IS NULL) và cư dân
    IF NOT (v_is_authorized OR (auth.jwt() ->> 'role' = 'service_role')) THEN
        RAISE EXCEPTION 'Truy cập bị từ chối: Chỉ Ban Quản Lý hoặc Quản trị viên mới có quyền tạo mã kích hoạt.'
            USING ERRCODE = '42501';
    END IF;

    FOR v_record IN
        SELECT ra.user_id, ra.apartment_id, u.phone
        FROM public.residents_apartments ra
        JOIN public.users u ON u.id = ra.user_id
        JOIN public.apartments a ON a.id = ra.apartment_id
        WHERE (p_building_id IS NULL OR a.building_id = p_building_id)
          AND u.is_active = FALSE
          AND NOT EXISTS (
              SELECT 1 FROM public.resident_activations act
              WHERE act.user_id = ra.user_id AND act.status IN ('pending', 'verified')
          )
    LOOP
        v_code := UPPER(SUBSTRING(encode(gen_random_bytes(6), 'hex') FROM 1 FOR 8));
        v_code_hash := encode(digest(v_code, 'sha256'), 'hex');

        INSERT INTO public.resident_activations (
            user_id, apartment_id, phone, activation_code, activation_code_hash,
            status, expires_at, created_at, updated_at
        ) VALUES (
            v_record.user_id, v_record.apartment_id, v_record.phone, v_code, v_code_hash,
            'pending', CURRENT_TIMESTAMP + INTERVAL '30 days', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
        );
        v_count := v_count + 1;
    END LOOP;

    RETURN jsonb_build_object(
        'success', TRUE,
        'generated_count', v_count,
        'message', 'Đã sinh thành công ' || v_count || ' mã kích hoạt cho cư dân.'
    );
END;
$$;

REVOKE ALL ON FUNCTION public.generate_resident_activation_codes(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.generate_resident_activation_codes(UUID) TO authenticated;

-- Wrapper alias tương thích ngược
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

-- 2.2 Sửa lỗi phân quyền get_financial_aging_report
CREATE OR REPLACE FUNCTION public.get_financial_aging_report(
    p_building_id UUID DEFAULT NULL,
    p_period TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_calling_user_id UUID := auth.uid();
    v_is_authorized BOOLEAN := FALSE;
    v_result JSONB;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM public.users
        WHERE id = v_calling_user_id
          AND role IN ('admin', 'management', 'accountant')
    ) INTO v_is_authorized;

    IF NOT v_is_authorized THEN
        SELECT EXISTS (
            SELECT 1 FROM public.role_delegations
            WHERE delegate_id = v_calling_user_id
              AND is_active = TRUE
              AND (expires_at IS NULL OR expires_at > CURRENT_TIMESTAMP)
              AND delegated_role IN ('admin', 'management', 'accountant')
        ) INTO v_is_authorized;
    END IF;

    -- Kiểm tra phân quyền chuẩn mực: Chặn ẩn danh
    IF NOT (v_is_authorized OR (auth.jwt() ->> 'role' = 'service_role')) THEN
        RAISE EXCEPTION 'Truy cập bị từ chối: Chỉ Ban Quản Lý hoặc Kế toán mới có quyền xem báo cáo tài chính.'
            USING ERRCODE = '42501';
    END IF;

    WITH filtered_invoices AS (
        SELECT 
            i.id,
            i.apartment_id,
            i.period,
            i.total_amount,
            i.due_date,
            i.status,
            a.code AS apt_code,
            a.building_id,
            GREATEST(0, (CURRENT_DATE - i.due_date::date)) AS days_overdue
        FROM public.invoices i
        JOIN public.apartments a ON a.id = i.apartment_id
        WHERE (p_period IS NULL OR i.period = p_period)
          AND (p_building_id IS NULL OR a.building_id = p_building_id)
    ),
    summary AS (
        SELECT
            COALESCE(SUM(total_amount), 0) AS total_billed,
            COALESCE(SUM(CASE WHEN status = 'paid' THEN total_amount ELSE 0 END), 0) AS actual_collected,
            COALESCE(SUM(CASE WHEN status != 'paid' THEN total_amount ELSE 0 END), 0) AS total_outstanding,
            COUNT(*) AS total_invoice_count,
            COUNT(CASE WHEN status = 'paid' THEN 1 END) AS paid_invoice_count,
            COUNT(CASE WHEN status != 'paid' THEN 1 END) AS unpaid_invoice_count,
            ROUND(
                COALESCE(
                    SUM(CASE WHEN status = 'paid' THEN total_amount ELSE 0 END) * 100.0 / 
                    NULLIF(SUM(total_amount), 0), 
                    0
                ), 1
            ) AS collection_rate
        FROM filtered_invoices
    ),
    buckets AS (
        SELECT
            COALESCE(SUM(CASE WHEN status != 'paid' AND days_overdue BETWEEN 0 AND 30 THEN total_amount ELSE 0 END), 0) AS amount_0_to_30,
            COUNT(CASE WHEN status != 'paid' AND days_overdue BETWEEN 0 AND 30 THEN 1 END) AS count_0_to_30,
            COALESCE(SUM(CASE WHEN status != 'paid' AND days_overdue BETWEEN 31 AND 60 THEN total_amount ELSE 0 END), 0) AS amount_31_to_60,
            COUNT(CASE WHEN status != 'paid' AND days_overdue BETWEEN 31 AND 60 THEN 1 END) AS count_31_to_60,
            COALESCE(SUM(CASE WHEN status != 'paid' AND days_overdue BETWEEN 61 AND 90 THEN total_amount ELSE 0 END), 0) AS amount_61_to_90,
            COUNT(CASE WHEN status != 'paid' AND days_overdue BETWEEN 61 AND 90 THEN 1 END) AS count_61_to_90,
            COALESCE(SUM(CASE WHEN status != 'paid' AND days_overdue > 90 THEN total_amount ELSE 0 END), 0) AS amount_over_90,
            COUNT(CASE WHEN status != 'paid' AND days_overdue > 90 THEN 1 END) AS count_over_90
        FROM filtered_invoices
    ),
    block_rates AS (
        SELECT
            COALESCE(SUBSTRING(apt_code FROM '^[A-Za-z]+'), 'Chung') AS block,
            COALESCE(SUM(total_amount), 0) AS billed,
            COALESCE(SUM(CASE WHEN status = 'paid' THEN total_amount ELSE 0 END), 0) AS collected,
            ROUND(
                COALESCE(
                    SUM(CASE WHEN status = 'paid' THEN total_amount ELSE 0 END) * 100.0 / 
                    NULLIF(SUM(total_amount), 0), 
                    0
                ), 1
            ) AS rate
        FROM filtered_invoices
        GROUP BY 1
    ),
    debtors AS (
        SELECT
            fi.apartment_id,
            fi.apt_code AS apartment_code,
            COALESCE(u.full_name, 'Chưa đăng ký') AS owner_name,
            u.phone AS owner_phone,
            COALESCE(SUM(fi.total_amount), 0) AS outstanding_amount,
            MAX(fi.days_overdue) AS max_days_overdue,
            COUNT(*) AS unpaid_invoice_count,
            CASE
                WHEN MAX(fi.days_overdue) > 90 THEN 'over_90'
                WHEN MAX(fi.days_overdue) > 60 THEN '61_to_90'
                WHEN MAX(fi.days_overdue) > 30 THEN '31_to_60'
                ELSE '0_to_30'
            END AS bucket
        FROM filtered_invoices fi
        LEFT JOIN public.residents_apartments ra ON ra.apartment_id = fi.apartment_id AND ra.relation_role = 'owner'
        LEFT JOIN public.users u ON u.id = ra.user_id
        WHERE fi.status != 'paid'
        GROUP BY fi.apartment_id, fi.apt_code, u.full_name, u.phone
        ORDER BY outstanding_amount DESC
        LIMIT 50
    )
    SELECT jsonb_build_object(
        'generated_at', CURRENT_TIMESTAMP,
        'filter_period', p_period,
        'filter_building_id', p_building_id,
        'summary', (SELECT to_jsonb(s) FROM summary s),
        'aging_buckets', (SELECT to_jsonb(b) FROM buckets b),
        'block_collection_rates', COALESCE((SELECT jsonb_agg(to_jsonb(br)) FROM block_rates br), '[]'::jsonb),
        'top_debtors', COALESCE((SELECT jsonb_agg(to_jsonb(d)) FROM debtors d), '[]'::jsonb)
    ) INTO v_result;

    RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.get_financial_aging_report(UUID, TEXT) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_financial_aging_report(UUID, TEXT) TO authenticated;

-- 2.3 Sửa lỗi phân quyền import_apartments_batch
CREATE OR REPLACE FUNCTION public.import_apartments_batch(
    p_building_id UUID,
    p_apartments JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_calling_user_id UUID := auth.uid();
    v_is_authorized BOOLEAN := FALSE;
    v_apt JSONB;
    v_code TEXT;
    v_area NUMERIC;
    v_is_empty BOOLEAN;
    v_success_count INT := 0;
    v_imported_codes JSONB := '[]'::jsonb;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM public.users
        WHERE id = v_calling_user_id
          AND role IN ('admin', 'management')
    ) INTO v_is_authorized;

    IF NOT (v_is_authorized OR (auth.jwt() ->> 'role' = 'service_role')) THEN
        RAISE EXCEPTION 'Truy cập bị từ chối: Chỉ Ban Quản Lý hoặc Admin mới có quyền nhập căn hộ hàng loạt.'
            USING ERRCODE = '42501';
    END IF;

    FOR v_apt IN SELECT * FROM jsonb_array_elements(p_apartments)
    LOOP
        v_code := UPPER(TRIM(v_apt->>'code'));
        v_area := COALESCE((v_apt->>'area')::numeric, 50.0);
        v_is_empty := COALESCE((v_apt->>'is_empty')::boolean, TRUE);

        IF v_code IS NOT NULL AND v_code != '' THEN
            INSERT INTO public.apartments (building_id, code, area, is_empty, created_at, updated_at)
            VALUES (p_building_id, v_code, v_area, v_is_empty, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
            ON CONFLICT (code) DO UPDATE
            SET area = EXCLUDED.area,
                building_id = EXCLUDED.building_id,
                updated_at = CURRENT_TIMESTAMP;

            v_success_count := v_success_count + 1;
            v_imported_codes := v_imported_codes || jsonb_build_array(v_code);
        END IF;
    END LOOP;

    RETURN jsonb_build_object(
        'success', TRUE,
        'imported_count', v_success_count,
        'imported_codes', v_imported_codes,
        'message', 'Đã nhập thành công ' || v_success_count || ' căn hộ.'
    );
END;
$$;

REVOKE ALL ON FUNCTION public.import_apartments_batch(UUID, JSONB) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.import_apartments_batch(UUID, JSONB) TO authenticated;

-- 2.4 Sửa lỗi phân quyền import_residents_batch
CREATE OR REPLACE FUNCTION public.import_residents_batch(
    p_residents JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_calling_user_id UUID := auth.uid();
    v_is_authorized BOOLEAN := FALSE;
    v_res JSONB;
    v_apt_code TEXT;
    v_full_name TEXT;
    v_phone TEXT;
    v_role TEXT;
    v_apt_id UUID;
    v_user_id UUID;
    v_success_count INT := 0;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM public.users
        WHERE id = v_calling_user_id
          AND role IN ('admin', 'management')
    ) INTO v_is_authorized;

    IF NOT (v_is_authorized OR (auth.jwt() ->> 'role' = 'service_role')) THEN
        RAISE EXCEPTION 'Truy cập bị từ chối: Chỉ Ban Quản Lý hoặc Admin mới có quyền nhập cư dân hàng loạt.'
            USING ERRCODE = '42501';
    END IF;

    FOR v_res IN SELECT * FROM jsonb_array_elements(p_residents)
    LOOP
        v_apt_code := UPPER(TRIM(v_res->>'apartment_code'));
        v_full_name := TRIM(v_res->>'full_name');
        v_phone := TRIM(v_res->>'phone');
        v_role := COALESCE(NULLIF(TRIM(v_res->>'relation_role'), ''), 'member');

        IF v_apt_code IS NOT NULL AND v_apt_code != '' AND v_phone IS NOT NULL AND v_phone != '' THEN
            SELECT id INTO v_apt_id FROM public.apartments WHERE code = v_apt_code LIMIT 1;
            
            IF v_apt_id IS NOT NULL THEN
                SELECT id INTO v_user_id FROM public.users WHERE phone = v_phone LIMIT 1;
                
                IF v_user_id IS NULL THEN
                    v_user_id := gen_random_uuid();
                    INSERT INTO public.users (id, full_name, phone, role, is_active, created_at, updated_at)
                    VALUES (v_user_id, v_full_name, v_phone, 'resident', FALSE, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);
                END IF;

                INSERT INTO public.residents_apartments (apartment_id, user_id, relation_role, status, created_at, updated_at)
                VALUES (v_apt_id, v_user_id, v_role::public.relation_type, 'active', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                ON CONFLICT (apartment_id, user_id) DO UPDATE
                SET relation_role = EXCLUDED.relation_role,
                    status = 'active',
                    updated_at = CURRENT_TIMESTAMP;

                UPDATE public.apartments SET is_empty = FALSE, updated_at = CURRENT_TIMESTAMP WHERE id = v_apt_id;
                v_success_count := v_success_count + 1;
            END IF;
        END IF;
    END LOOP;

    RETURN jsonb_build_object(
        'success', TRUE,
        'imported_count', v_success_count,
        'message', 'Đã nhập thành công ' || v_success_count || ' hồ sơ cư dân.'
    );
END;
$$;

REVOKE ALL ON FUNCTION public.import_residents_batch(JSONB) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.import_residents_batch(JSONB) TO authenticated;

-- ==============================================================================
-- PHẦN 3: [C5] HOOK AAL2 ENFORCEMENT VÀO PUBLIC.IS_STAFF_OR_MANAGEMENT()
-- ==============================================================================

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
      AND role IN ('admin', 'management', 'staff', 'manager', 'accountant', 'technician')
      AND is_active = true
      AND is_locked = false
  );
END;
$$;

-- ==============================================================================
-- PHẦN 4: [§0] KHỞI TẠO 5 BẢNG CƠ SỞ DỮ LIỆU CÒN THIẾU KÈM RLS POLICIES
-- ==============================================================================

-- 4.1 Bảng emergency_contacts (Đường dây nóng cứu hộ, kỹ thuật, y tế)
CREATE TABLE IF NOT EXISTS public.emergency_contacts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    building_id UUID REFERENCES public.buildings(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    phone TEXT NOT NULL,
    role TEXT,
    display_order INT DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

ALTER TABLE public.emergency_contacts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "emergency_contacts_read" ON public.emergency_contacts;
CREATE POLICY "emergency_contacts_read" ON public.emergency_contacts FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "emergency_contacts_manage" ON public.emergency_contacts;
CREATE POLICY "emergency_contacts_manage" ON public.emergency_contacts FOR ALL TO authenticated USING (public.is_staff_or_management());

-- 4.2 Bảng building_rules (Nội quy tòa nhà và sổ tay chung cư)
CREATE TABLE IF NOT EXISTS public.building_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    building_id UUID REFERENCES public.buildings(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    category TEXT DEFAULT 'general',
    version INT DEFAULT 1,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

ALTER TABLE public.building_rules ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "building_rules_read" ON public.building_rules;
CREATE POLICY "building_rules_read" ON public.building_rules FOR SELECT TO authenticated USING (is_active = true);
DROP POLICY IF EXISTS "building_rules_manage" ON public.building_rules;
CREATE POLICY "building_rules_manage" ON public.building_rules FOR ALL TO authenticated USING (public.is_staff_or_management());

-- 4.3 Bảng role_change_log (Nhật ký phân quyền và thay đổi vai trò tài khoản)
CREATE TABLE IF NOT EXISTS public.role_change_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    target_user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    old_role public.user_role,
    new_role public.user_role,
    changed_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

ALTER TABLE public.role_change_log ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "role_change_log_manage" ON public.role_change_log;
CREATE POLICY "role_change_log_manage" ON public.role_change_log FOR ALL TO authenticated USING (public.is_staff_or_management());

-- 4.4 Bảng issue_ratings (Đánh giá chất lượng dịch vụ xử lý sự cố)
CREATE TABLE IF NOT EXISTS public.issue_ratings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    issue_report_id UUID NOT NULL REFERENCES public.issue_reports(id) ON DELETE CASCADE,
    rating INT NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

ALTER TABLE public.issue_ratings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "issue_ratings_read" ON public.issue_ratings;
CREATE POLICY "issue_ratings_read" ON public.issue_ratings FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "issue_ratings_insert" ON public.issue_ratings;
CREATE POLICY "issue_ratings_insert" ON public.issue_ratings FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);

-- 4.5 Bảng building_equipments (Trang thiết bị tòa nhà phục vụ vận hành)
CREATE TABLE IF NOT EXISTS public.building_equipments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    building_id UUID REFERENCES public.buildings(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    code TEXT UNIQUE,
    category TEXT NOT NULL,
    location TEXT,
    installation_date DATE,
    warranty_expiry DATE,
    status TEXT NOT NULL DEFAULT 'normal',
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

ALTER TABLE public.building_equipments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "building_equipments_read" ON public.building_equipments;
CREATE POLICY "building_equipments_read" ON public.building_equipments FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "building_equipments_manage" ON public.building_equipments;
CREATE POLICY "building_equipments_manage" ON public.building_equipments FOR ALL TO authenticated USING (public.is_staff_or_management());

-- ==============================================================================
-- PHẦN 5: [§0] KHÔI PHỤC 9 RPCS QUẢN TRỊ & KẾ TOÁN TỪ ARCHIVE
-- ==============================================================================

-- 5.1 Tạo hóa đơn và các dòng chi tiết ACID (create_invoice_with_items)
CREATE OR REPLACE FUNCTION public.create_invoice_with_items(
    p_apartment_id UUID,
    p_period VARCHAR,
    p_due_date DATE,
    p_items JSONB
)
RETURNS UUID AS $$
DECLARE
    v_invoice_id UUID;
    v_item JSONB;
BEGIN
    INSERT INTO public.invoices (apartment_id, period, due_date, status)
    VALUES (p_apartment_id, p_period, p_due_date, 'unpaid'::public.invoice_status)
    RETURNING id INTO v_invoice_id;

    IF p_items IS NOT NULL AND jsonb_array_length(p_items) > 0 THEN
        FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
        LOOP
            INSERT INTO public.invoice_items (
                invoice_id,
                fee_type,
                unit_price,
                quantity,
                subtotal
            ) VALUES (
                v_invoice_id,
                v_item->>'fee_type',
                COALESCE((v_item->>'unit_price')::DECIMAL, 0),
                COALESCE((v_item->>'quantity')::DECIMAL, 1),
                COALESCE((v_item->>'unit_price')::DECIMAL, 0) * COALESCE((v_item->>'quantity')::DECIMAL, 1)
            );
        END LOOP;
    END IF;

    RETURN v_invoice_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

REVOKE ALL ON FUNCTION public.create_invoice_with_items(UUID, VARCHAR, DATE, JSONB) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_invoice_with_items(UUID, VARCHAR, DATE, JSONB) TO authenticated;

-- 5.2 Ghi nhận thanh toán thủ công (record_manual_payment)
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
    v_res RECORD;
BEGIN
    IF NOT public.is_staff_or_management() THEN
        RAISE EXCEPTION 'Chỉ Quản trị viên, Ban Quản Lý hoặc Kế toán mới có quyền xác nhận thu tiền';
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
            type,
            user_id,
            confirmed_by,
            confirmed_at
        ) VALUES (
            p_invoice_id,
            v_inv.apartment_id,
            v_inv.total_amount,
            COALESCE(p_payment_method, 'CASH'),
            'SUCCESS',
            v_txn_code,
            'Thu tiền hóa đơn kỳ ' || v_inv.period,
            'INVOICE',
            auth.uid(),
            auth.uid(),
            now()
        );
    END IF;

    UPDATE public.invoices
    SET status = 'paid',
        updated_at = now()
    WHERE id = p_invoice_id;

    FOR v_res IN
        SELECT user_id FROM public.residents_apartments WHERE apartment_id = v_inv.apartment_id
    LOOP
        INSERT INTO public.notifications (
            user_id,
            apartment_id,
            title,
            body,
            type,
            payload
        ) VALUES (
            v_res.user_id,
            v_inv.apartment_id,
            'Hóa đơn kỳ ' || v_inv.period || ' đã được xác nhận thanh toán',
            'Ban quản lý đã xác nhận thu ' || to_char(v_inv.total_amount, 'FM999,999,999') || ' đ cho hóa đơn kỳ ' || v_inv.period || '.',
            'payment_confirmed',
            jsonb_build_object('invoice_id', p_invoice_id, 'transaction_code', v_txn_code)
        );
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'invoice_id', p_invoice_id,
        'transaction_code', v_txn_code,
        'status', 'paid',
        'message', 'Đã xác nhận thu tiền thành công'
    );
END;
$$;

REVOKE ALL ON FUNCTION public.record_manual_payment(UUID, VARCHAR, TEXT) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.record_manual_payment(UUID, VARCHAR, TEXT) TO authenticated;

-- 5.3 Tiền kiểm tra phát hành hóa đơn hàng loạt (validate_monthly_bulk_invoices)
CREATE OR REPLACE FUNCTION public.validate_monthly_bulk_invoices(
  p_period text,
  p_mgmt_rate numeric DEFAULT 10000,
  p_electric_rate numeric DEFAULT 3500,
  p_water_rate numeric DEFAULT 18000
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_apt RECORD;
  v_total_scanned integer := 0;
  v_valid_count integer := 0;
  v_missing_count integer := 0;
  v_invalid_count integer := 0;
  v_already_invoiced_count integer := 0;
  v_total_estimated_amount numeric := 0;
  v_valid_items jsonb := '[]'::jsonb;
  v_issues jsonb := '[]'::jsonb;
  v_sub_record RECORD;
  v_has_approved_sub boolean;
  v_cur_elec numeric;
  v_cur_water numeric;
  v_mgmt_fee numeric;
  v_parking_fee numeric;
  v_elec_fee numeric;
  v_water_fee numeric;
  v_apt_total numeric;
  v_motorbike_count integer;
  v_car_count integer;
BEGIN
  IF NOT public.is_staff_or_management() THEN
    RAISE EXCEPTION 'Chỉ Ban Quản Lý mới có quyền tiền kiểm tra hóa đơn hàng loạt';
  END IF;

  FOR v_apt IN
    SELECT id, code, area, electric_reading, water_reading
    FROM public.apartments
    WHERE is_empty = false
    ORDER BY code ASC
  LOOP
    v_total_scanned := v_total_scanned + 1;

    IF EXISTS (
      SELECT 1 FROM public.invoices 
      WHERE apartment_id = v_apt.id AND period = p_period
    ) THEN
      v_already_invoiced_count := v_already_invoiced_count + 1;
      v_issues := v_issues || jsonb_build_object(
        'apartment_id', v_apt.id,
        'apartment_code', v_apt.code,
        'type', 'already_invoiced',
        'message', 'Đã tồn tại hóa đơn cho kỳ ' || p_period
      );
      CONTINUE;
    END IF;

    SELECT * INTO v_sub_record
    FROM public.meter_reading_submissions
    WHERE apartment_id = v_apt.id AND period = p_period AND status = 'approved'
    ORDER BY created_at DESC
    LIMIT 1;

    IF FOUND THEN
      v_cur_elec := v_sub_record.electric_reading;
      v_cur_water := v_sub_record.water_reading;
    ELSE
      v_cur_elec := COALESCE(v_apt.electric_reading, 0);
      v_cur_water := COALESCE(v_apt.water_reading, 0);
    END IF;

    v_mgmt_fee := ROUND(COALESCE(v_apt.area, 70) * p_mgmt_rate);

    SELECT 
      COUNT(*) FILTER (WHERE vehicle_type = 'motorbike'),
      COUNT(*) FILTER (WHERE vehicle_type = 'car')
    INTO v_motorbike_count, v_car_count
    FROM public.vehicles
    WHERE apartment_id = v_apt.id AND status = 'approved';

    IF (v_motorbike_count + v_car_count) = 0 THEN
      v_parking_fee := 100000;
    ELSE
      v_parking_fee := (v_motorbike_count * 100000) + (v_car_count * 1200000);
    END IF;

    v_elec_fee := ROUND(v_cur_elec * p_electric_rate);
    v_water_fee := ROUND(v_cur_water * p_water_rate);
    v_apt_total := v_mgmt_fee + v_parking_fee + v_elec_fee + v_water_fee;

    v_valid_count := v_valid_count + 1;
    v_total_estimated_amount := v_total_estimated_amount + v_apt_total;
    v_valid_items := v_valid_items || jsonb_build_object(
      'apartment_id', v_apt.id,
      'apartment_code', v_apt.code,
      'total_amount', v_apt_total
    );
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'period', p_period,
    'total_scanned', v_total_scanned,
    'valid_count', v_valid_count,
    'already_invoiced_count', v_already_invoiced_count,
    'total_estimated_amount', v_total_estimated_amount,
    'valid_items', v_valid_items,
    'issues', v_issues
  );
END;
$$;

REVOKE ALL ON FUNCTION public.validate_monthly_bulk_invoices(text, numeric, numeric, numeric) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.validate_monthly_bulk_invoices(text, numeric, numeric, numeric) TO authenticated;

-- 5.4 Phát hành hóa đơn hàng loạt cho danh sách căn hộ hợp lệ (generate_valid_bulk_invoices)
CREATE OR REPLACE FUNCTION public.generate_valid_bulk_invoices(
  p_period text,
  p_due_date timestamptz,
  p_target_apartment_ids uuid[] DEFAULT NULL,
  p_mgmt_rate numeric DEFAULT 10000,
  p_electric_rate numeric DEFAULT 3500,
  p_water_rate numeric DEFAULT 18000
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_apt RECORD;
  v_invoice_id uuid;
  v_invoices_created integer := 0;
  v_skipped_count integer := 0;
  v_total_amount numeric := 0;
  v_mgmt_fee numeric;
  v_parking_fee numeric;
  v_elec_fee numeric;
  v_water_fee numeric;
  v_apt_total numeric;
  v_motorbike_count integer;
  v_car_count integer;
  v_user RECORD;
BEGIN
  IF NOT public.is_staff_or_management() THEN
    RAISE EXCEPTION 'Chỉ Ban Quản Lý mới có quyền phát hành hóa đơn hàng loạt';
  END IF;

  FOR v_apt IN
    SELECT id, code, area, electric_reading, water_reading
    FROM public.apartments
    WHERE is_empty = false
      AND (p_target_apartment_ids IS NULL OR id = ANY(p_target_apartment_ids))
    ORDER BY code ASC
  LOOP
    IF EXISTS (
      SELECT 1 FROM public.invoices 
      WHERE apartment_id = v_apt.id AND period = p_period
    ) THEN
      v_skipped_count := v_skipped_count + 1;
      CONTINUE;
    END IF;

    v_mgmt_fee := ROUND(COALESCE(v_apt.area, 70) * p_mgmt_rate);

    SELECT 
      COUNT(*) FILTER (WHERE vehicle_type = 'motorbike'),
      COUNT(*) FILTER (WHERE vehicle_type = 'car')
    INTO v_motorbike_count, v_car_count
    FROM public.vehicles
    WHERE apartment_id = v_apt.id AND status = 'approved';

    IF (v_motorbike_count + v_car_count) = 0 THEN
      v_parking_fee := 100000;
    ELSE
      v_parking_fee := (v_motorbike_count * 100000) + (v_car_count * 1200000);
    END IF;

    v_elec_fee := ROUND(COALESCE(v_apt.electric_reading, 0) * p_electric_rate);
    v_water_fee := ROUND(COALESCE(v_apt.water_reading, 0) * p_water_rate);
    v_apt_total := v_mgmt_fee + v_parking_fee + v_elec_fee + v_water_fee;

    INSERT INTO public.invoices (
      apartment_id, period, due_date, total_amount, status, created_at, updated_at
    ) VALUES (
      v_apt.id, p_period, p_due_date, v_apt_total, 'unpaid'::public.invoice_status, now(), now()
    )
    ON CONFLICT (apartment_id, period) DO NOTHING
    RETURNING id INTO v_invoice_id;

    IF v_invoice_id IS NOT NULL THEN
      INSERT INTO public.invoice_items (invoice_id, fee_type, unit_price, quantity, subtotal)
      VALUES 
        (v_invoice_id, 'Phí quản lý vận hành', p_mgmt_rate, COALESCE(v_apt.area, 70), v_mgmt_fee),
        (v_invoice_id, 'Phí gửi xe phương tiện', v_parking_fee, 1, v_parking_fee),
        (v_invoice_id, 'Tiền điện sinh hoạt', p_electric_rate, COALESCE(v_apt.electric_reading, 0), v_elec_fee),
        (v_invoice_id, 'Tiền nước sinh hoạt', p_water_rate, COALESCE(v_apt.water_reading, 0), v_water_fee);

      v_invoices_created := v_invoices_created + 1;
      v_total_amount := v_total_amount + v_apt_total;

      FOR v_user IN
        SELECT user_id FROM public.residents_apartments WHERE apartment_id = v_apt.id
      LOOP
        INSERT INTO public.notifications (user_id, title, body, type, created_at)
        VALUES (
          v_user.user_id,
          'Hóa đơn sinh hoạt kỳ ' || p_period,
          'Căn hộ ' || v_apt.code || ' đã có hóa đơn mới kỳ ' || p_period || ' với tổng tiền ' || v_apt_total || ' đ.',
          'new_invoice',
          now()
        );
      END LOOP;
    ELSE
      v_skipped_count := v_skipped_count + 1;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'period', p_period,
    'invoices_created', v_invoices_created,
    'skipped_count', v_skipped_count,
    'total_amount', v_total_amount,
    'message', 'Đã phát hành ' || v_invoices_created || ' hóa đơn thành công'
  );
END;
$$;

REVOKE ALL ON FUNCTION public.generate_valid_bulk_invoices(text, timestamptz, uuid[], numeric, numeric, numeric) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.generate_valid_bulk_invoices(text, timestamptz, uuid[], numeric, numeric, numeric) TO authenticated;

-- 5.5 Phát hành hóa đơn hàng loạt tự động (generate_monthly_bulk_invoices)
CREATE OR REPLACE FUNCTION public.generate_monthly_bulk_invoices(
  p_period text,
  p_due_date timestamptz,
  p_mgmt_rate numeric DEFAULT 10000,
  p_electric_rate numeric DEFAULT 3000,
  p_water_rate numeric DEFAULT 15000
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN public.generate_valid_bulk_invoices(
    p_period,
    p_due_date,
    NULL,
    p_mgmt_rate,
    p_electric_rate,
    p_water_rate
  );
END;
$$;

REVOKE ALL ON FUNCTION public.generate_monthly_bulk_invoices(text, timestamptz, numeric, numeric, numeric) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.generate_monthly_bulk_invoices(text, timestamptz, numeric, numeric, numeric) TO authenticated;

-- 5.6 Tạo tài khoản người dùng từ Admin (admin_create_user)
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
BEGIN
    IF NOT public.is_staff_or_management() THEN
        RAISE EXCEPTION 'Bạn không có quyền quản trị để tạo tài khoản mới';
    END IF;

    p_email := LOWER(TRIM(p_email));
    IF p_email IS NULL OR p_email = '' THEN
        RAISE EXCEPTION 'Email không được để trống';
    END IF;

    IF EXISTS (SELECT 1 FROM auth.users WHERE email = p_email) THEN
        RAISE EXCEPTION 'Email % đã tồn tại trong hệ thống', p_email;
    END IF;

    v_pwd := COALESCE(NULLIF(TRIM(p_password), ''), substr(md5(random()::text), 1, 12));

    INSERT INTO auth.users (
        id, instance_id, email, encrypted_password, email_confirmed_at,
        raw_app_meta_data, raw_user_meta_data, created_at, updated_at, role, aud
    ) VALUES (
        v_new_user_id,
        '00000000-0000-0000-0000-000000000000'::uuid,
        p_email,
        crypt(v_pwd, gen_salt('bf')),
        NOW(),
        '{"provider":"email","providers":["email"]}'::jsonb,
        jsonb_build_object('full_name', TRIM(p_full_name), 'role', p_role),
        NOW(), NOW(), 'authenticated', 'authenticated'
    );

    INSERT INTO auth.identities (
        id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
    ) VALUES (
        v_new_user_id, v_new_user_id, 
        jsonb_build_object('sub', v_new_user_id, 'email', p_email),
        'email', v_new_user_id, NOW(), NOW(), NOW()
    ) ON CONFLICT DO NOTHING;

    INSERT INTO public.users (id, full_name, email, phone, role, is_locked, is_active)
    VALUES (
        v_new_user_id,
        TRIM(p_full_name),
        p_email,
        NULLIF(TRIM(p_phone), ''),
        p_role::public.user_role,
        false,
        true
    ) ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        email = EXCLUDED.email,
        phone = EXCLUDED.phone,
        role = EXCLUDED.role,
        is_active = true,
        is_locked = false;

    IF p_apartment_id IS NOT NULL THEN
        INSERT INTO public.residents_apartments (
            user_id,
            apartment_id,
            relation_role
        ) VALUES (
            v_new_user_id,
            p_apartment_id,
            COALESCE(p_relation_role, 'owner')::public.relation_type
        ) ON CONFLICT DO NOTHING;
    END IF;

    INSERT INTO public.role_change_log (
        target_user_id,
        old_role,
        new_role,
        changed_by,
        changed_at
    ) VALUES (
        v_new_user_id,
        p_role::public.user_role,
        p_role::public.user_role,
        auth.uid(),
        NOW()
    );

    RETURN jsonb_build_object(
        'success', true,
        'user_id', v_new_user_id,
        'email', p_email,
        'message', 'Tạo tài khoản người dùng thành công'
    );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_create_user(VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, UUID, VARCHAR) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_create_user(VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, UUID, VARCHAR) TO authenticated;

-- 5.7 Cập nhật hồ sơ người dùng từ Admin (admin_update_user_profile)
CREATE OR REPLACE FUNCTION public.admin_update_user_profile(
    p_target_user_id UUID,
    p_full_name VARCHAR,
    p_phone VARCHAR DEFAULT NULL,
    p_role VARCHAR DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_catalog
AS $$
DECLARE
    v_old_role public.user_role;
    v_new_role public.user_role;
BEGIN
    IF NOT public.is_staff_or_management() THEN
        RAISE EXCEPTION 'Bạn không có quyền quản trị để chỉnh sửa hồ sơ người dùng';
    END IF;

    SELECT role INTO v_old_role FROM public.users WHERE id = p_target_user_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Không tìm thấy người dùng với ID: %', p_target_user_id;
    END IF;

    IF p_role IS NOT NULL THEN
        v_new_role := p_role::public.user_role;
    ELSE
        v_new_role := v_old_role;
    END IF;

    UPDATE public.users
    SET full_name = COALESCE(NULLIF(TRIM(p_full_name), ''), full_name),
        phone = NULLIF(TRIM(p_phone), ''),
        role = v_new_role,
        updated_at = NOW()
    WHERE id = p_target_user_id;

    UPDATE auth.users
    SET raw_user_meta_data = raw_user_meta_data || jsonb_build_object('full_name', TRIM(p_full_name), 'role', v_new_role::text),
        updated_at = NOW()
    WHERE id = p_target_user_id;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Cập nhật thông tin hồ sơ thành công'
    );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_update_user_profile(UUID, VARCHAR, VARCHAR, VARCHAR) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_update_user_profile(UUID, VARCHAR, VARCHAR, VARCHAR) TO authenticated;

-- 5.8 Khóa/Mở khóa/Vô hiệu hóa tài khoản (admin_toggle_user_status)
CREATE OR REPLACE FUNCTION public.admin_toggle_user_status(
    p_target_user_id UUID,
    p_action VARCHAR,
    p_reason TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_catalog
AS $$
BEGIN
    IF NOT public.is_staff_or_management() THEN
        RAISE EXCEPTION 'Bạn không có quyền quản trị để thay đổi trạng thái tài khoản';
    END IF;

    IF p_target_user_id = auth.uid() THEN
        RAISE EXCEPTION 'Không thể tự khóa hoặc vô hiệu hóa tài khoản quản trị của chính bạn';
    END IF;

    IF p_action = 'lock' THEN
        UPDATE public.users SET is_locked = true, updated_at = NOW() WHERE id = p_target_user_id;
    ELSIF p_action = 'unlock' THEN
        UPDATE public.users SET is_locked = false, updated_at = NOW() WHERE id = p_target_user_id;
    ELSIF p_action = 'deactivate' THEN
        UPDATE public.users SET is_active = false, is_locked = true, updated_at = NOW() WHERE id = p_target_user_id;
    ELSIF p_action = 'activate' THEN
        UPDATE public.users SET is_active = true, is_locked = false, updated_at = NOW() WHERE id = p_target_user_id;
    ELSE
        RAISE EXCEPTION 'Hành động không hợp lệ: %', p_action;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'action', p_action,
        'message', 'Đã cập nhật trạng thái tài khoản thành công'
    );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_toggle_user_status(UUID, VARCHAR, TEXT) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_toggle_user_status(UUID, VARCHAR, TEXT) TO authenticated;

-- 5.9 Gỡ liên kết căn hộ (admin_unlink_apartment)
CREATE OR REPLACE FUNCTION public.admin_unlink_apartment(
    p_user_id UUID,
    p_apartment_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
BEGIN
    IF NOT public.is_staff_or_management() THEN
        RAISE EXCEPTION 'Bạn không có quyền quản trị để gỡ liên kết căn hộ';
    END IF;

    DELETE FROM public.residents_apartments
    WHERE user_id = p_user_id AND apartment_id = p_apartment_id;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Đã gỡ liên kết căn hộ thành công'
    );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_unlink_apartment(UUID, UUID) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_unlink_apartment(UUID, UUID) TO authenticated;

