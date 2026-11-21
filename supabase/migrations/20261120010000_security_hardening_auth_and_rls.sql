-- ==============================================================================
-- Vivona Production Commercial SaaS: Migration 20261120010000_security_hardening_auth_and_rls.sql
-- Mục tiêu:
-- 1. [C1 & C2] Bảo mật phân quyền: Ngăn chặn tự nâng quyền (Privilege Self-Escalation)
--    - Trigger bất biến (Immutability Trigger) cho role, is_active, is_locked trên bảng users
--    - Sửa handle_new_user(): Toàn bộ tài khoản đăng ký mới bắt buộc role = 'resident'
--    - Siết chặt chính sách RLS users_update_own_or_admin
-- 2. [C3 & C4] Bảo mật kích hoạt cư dân & Vá lỗi Inverted Authorization Check
--    - verify_activation_code: Sinh OTP ngẫu nhiên 6 chữ số, loại bỏ hoàn toàn otp_hint rò rỉ
--    - Vá lỗi bypass IF NOT v_is_authorized AND v_caller_id IS NOT NULL cho toàn bộ RPCs
-- 3. [C5] Tăng cường bảo mật xác thực hai bước (MFA / AAL2) ở tầng Database
--    - Hàm kiểm tra mức độ xác thực AAL2 khi tài khoản đã kích hoạt TOTP (is_aal2_if_mfa_enrolled)
-- 4. [§0] Khôi phục toàn bộ 10 RPCs cốt lõi từ migrations_archive bị thiếu trong bản squashed baseline
--    - approve_link_request, cancel_apartment_link_request
--    - cancel_pending_meter_reading, update_pending_meter_reading
--    - cancel_pending_vehicle, update_pending_vehicle
--    - get_co_residents, check_in_amenity_booking
--    - get_amenity_slot_availability, update_invoice_with_items
-- ==============================================================================

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
    -- Nếu có sự thay đổi về vai trò (role) hoặc trạng thái khóa / kích hoạt
    IF (NEW.role IS DISTINCT FROM OLD.role 
        OR NEW.is_locked IS DISTINCT FROM OLD.is_locked 
        OR NEW.is_active IS DISTINCT FROM OLD.is_active) THEN
        
        -- Chỉ Ban Quản Lý (admin/management) hoặc service_role nội bộ mới được phép sửa đổi
        IF NOT (public.is_staff_or_management() OR (auth.jwt() ->> 'role' = 'service_role')) THEN
            RAISE EXCEPTION 'Truy cập bị từ chối: Chỉ Ban Quản Lý hoặc Quản trị viên mới có quyền cập nhật vai trò hoặc trạng thái bảo mật của tài khoản.'
                USING ERRCODE = '42501';
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
    -- Chỉ chấp nhận role từ metadata nếu được tạo bởi service_role nội bộ có thẩm quyền
    IF (auth.jwt() ->> 'role' = 'service_role') THEN
        v_meta_role := NEW.raw_user_meta_data->>'role';
        IF v_meta_role IN ('admin', 'management', 'staff', 'resident') THEN
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

-- 2.1 verify_activation_code: Sinh OTP ngẫu nhiên 6 chữ số và loại bỏ otp_hint
CREATE OR REPLACE FUNCTION public.verify_activation_code(
    p_phone TEXT,
    p_activation_code TEXT
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

    -- Tìm bản ghi kích hoạt đang chờ của số điện thoại này
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

    -- Kiểm tra số lần nhập sai (Rate Limiting Throttling)
    IF v_act.code_attempts >= 5 THEN
        UPDATE public.resident_activations
        SET status = 'locked', updated_at = CURRENT_TIMESTAMP
        WHERE id = v_act.id;

        RETURN jsonb_build_object(
            'success', FALSE,
            'message', 'Mã kích hoạt đã bị khóa do nhập sai quá 5 lần. Vui lòng liên hệ Ban Quản Lý để được cấp mã mới.'
        );
    END IF;

    -- Kiểm tra khớp mã (so sánh hash trước, hoặc mã thô nếu bản ghi cũ chưa hash)
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

    -- Sinh OTP bảo mật 6 số ngẫu nhiên thực tế (100000 - 999999)
    v_otp := LPAD((FLOOR(RANDOM() * 900000) + 100000)::TEXT, 6, '0');

    -- Mã đúng: Cập nhật mã OTP ngẫu nhiên và gia hạn dùng 10 phút
    UPDATE public.resident_activations
    SET otp_code = v_otp,
        otp_expires_at = CURRENT_TIMESTAMP + INTERVAL '10 minutes',
        code_attempts = 0,
        status = 'otp_sent',
        updated_at = CURRENT_TIMESTAMP
    WHERE id = v_act.id;

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Mã kích hoạt hợp lệ. Mã xác thực OTP đã được gửi đến số điện thoại của bạn.',
        'full_name', v_act.full_name,
        'apartment_code', v_act.apt_code,
        'phone', v_norm_phone,
        'activation_code', v_norm_code
    );
END;
$function$;

-- 2.2 Sửa inverted caller check trong generate_bulk_resident_activations
CREATE OR REPLACE FUNCTION public.generate_bulk_resident_activations(p_building_id UUID DEFAULT NULL)
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

-- 2.6 Sửa inverted caller check trong get_financial_aging_report
CREATE OR REPLACE FUNCTION public.get_financial_aging_report(
    p_period TEXT DEFAULT NULL,
    p_building_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
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
            COALESCE(SUBSTRING(apt_code FROM '^[A-Za-z]+'), 'Chung') AS block_name,
            COALESCE(SUM(total_amount), 0) AS block_billed,
            COALESCE(SUM(CASE WHEN status = 'paid' THEN total_amount ELSE 0 END), 0) AS block_collected,
            COALESCE(SUM(CASE WHEN status != 'paid' THEN total_amount ELSE 0 END), 0) AS block_outstanding,
            ROUND(
                COALESCE(
                    SUM(CASE WHEN status = 'paid' THEN total_amount ELSE 0 END) * 100.0 / 
                    NULLIF(SUM(total_amount), 0), 
                    0
                ), 1
            ) AS collection_rate
        FROM filtered_invoices
        GROUP BY SUBSTRING(apt_code FROM '^[A-Za-z]+')
        ORDER BY block_name
    ),
    debtors AS (
        SELECT
            f.apartment_id,
            f.apt_code AS apartment_code,
            COALESCE(u.full_name, 'Chưa xác định') AS owner_name,
            COALESCE(u.phone, '') AS owner_phone,
            SUM(f.total_amount) AS total_debt,
            MAX(f.days_overdue) AS max_days_overdue,
            COUNT(*) AS unpaid_invoices_count,
            MIN(f.due_date) AS oldest_due_date,
            CASE 
                WHEN MAX(f.days_overdue) > 90 THEN 'over_90'
                WHEN MAX(f.days_overdue) > 60 THEN '61_to_90'
                WHEN MAX(f.days_overdue) > 30 THEN '31_to_60'
                ELSE '0_to_30'
            END AS risk_level
        FROM filtered_invoices f
        LEFT JOIN public.residents_apartments ra ON ra.apartment_id = f.apartment_id AND ra.relation_role IN ('owner', 'head_of_household')
        LEFT JOIN public.users u ON u.id = ra.user_id
        WHERE f.status != 'paid'
        GROUP BY f.apartment_id, f.apt_code, u.full_name, u.phone
        ORDER BY total_debt DESC
        LIMIT 50
    )
    SELECT jsonb_build_object(
        'filter_period', p_period,
        'filter_building_id', p_building_id,
        'summary', (SELECT to_jsonb(s) FROM summary s),
        'aging_buckets', (SELECT to_jsonb(b) FROM buckets b),
        'collection_by_block', (SELECT jsonb_agg(to_jsonb(br)) FROM block_rates br),
        'debtors', (SELECT jsonb_agg(to_jsonb(d)) FROM debtors d)
    ) INTO v_result;

    RETURN v_result;
END;
$$;

-- 2.7 Sửa inverted caller check trong import_apartments_batch
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

-- 2.8 Sửa inverted caller check trong import_residents_batch
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

-- ==============================================================================
-- PHẦN 3: [C5] BẢO MẬT XÁC THỰC HAI YẾU TỐ (MFA / AAL2) Ở TẦNG DATABASE
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.is_aal2_if_mfa_enrolled()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth, pg_catalog
AS $$
    -- Kiểm tra nếu tài khoản có yếu tố TOTP verified trong auth.mfa_factors
    -- thì JWT hiện hành bắt buộc phải đạt cấp độ 'aal2'
    SELECT CASE
        WHEN auth.uid() IS NULL THEN FALSE
        WHEN EXISTS (
            SELECT 1 FROM auth.mfa_factors f
            WHERE f.user_id = auth.uid() AND f.status = 'verified'
        ) THEN (COALESCE(auth.jwt() ->> 'aal', 'aal1') = 'aal2')
        ELSE TRUE
    END;
$$;

-- ==============================================================================
-- PHẦN 4: [§0] KHÔI PHỤC CÁC RPCs CỐT LÕI TỪ ARCHIVE BỊ THIẾU
-- ==============================================================================

-- 4.1 Phê duyệt yêu cầu liên kết căn hộ (approve_link_request)
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

-- 4.2 Hủy yêu cầu liên kết căn hộ (cancel_apartment_link_request)
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

-- 4.3 Cập nhật phiếu khai báo chỉ số điện nước (update_pending_meter_reading)
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

-- 4.4 Hủy phiếu khai báo chỉ số điện nước (cancel_pending_meter_reading)
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

-- 4.5 Hủy yêu cầu đăng ký phương tiện (cancel_pending_vehicle)
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

-- 4.6 Cập nhật thông tin phương tiện đang chờ duyệt (update_pending_vehicle)
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

-- 4.7 Lấy danh sách thành viên cùng căn hộ (get_co_residents)
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

-- 4.8 Xác nhận check-in lượt đặt tiện ích (check_in_amenity_booking)
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

-- 4.9 Tra cứu tính khả dụng của khung giờ tiện ích (get_amenity_slot_availability)
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

-- 4.10 Cập nhật hóa đơn và các hạng mục chi phí ACID (update_invoice_with_items)
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

