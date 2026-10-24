-- ==============================================================================
-- Migration: 20261024_03_admin_user_management.sql
-- Mục tiêu: Nâng cấp toàn diện Module Quản trị Người Dùng:
-- 1. Thêm cột email và is_active vào public.users, backfill từ auth.users
-- 2. Cập nhật trigger handle_new_user() tự động đồng bộ email
-- 3. Khóa tài khoản ở mức máy chủ (Trigger chặn mọi thao tác dữ liệu nếu is_locked/is_active = false)
-- 4. RPC admin_create_user: Admin tạo tài khoản nhân viên / cư dân trực tiếp
-- 5. RPC admin_update_user_profile: Chỉnh sửa hồ sơ người dùng
-- 6. RPC admin_toggle_user_status: Khóa / Mở khóa / Vô hiệu hóa (soft delete)
-- 7. RPC admin_unlink_apartment: Gỡ liên kết từng căn hộ cụ thể cho cư dân đa căn hộ
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. CỘT EMAIL & IS_ACTIVE TRONG PUBLIC.USERS VÀ BACKFILL DỮ LIỆU
-- ------------------------------------------------------------------------------
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS email VARCHAR,
ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT true;

-- Đồng bộ email cũ từ auth.users sang public.users nếu đang NULL
UPDATE public.users u
SET email = LOWER(TRIM(au.email))
FROM auth.users au
WHERE u.id = au.id AND (u.email IS NULL OR u.email = '');

-- Tạo chỉ mục tìm kiếm nhanh theo email và phone
CREATE INDEX IF NOT EXISTS idx_users_email ON public.users(email);
CREATE INDEX IF NOT EXISTS idx_users_phone ON public.users(phone);
CREATE INDEX IF NOT EXISTS idx_users_status ON public.users(is_locked, is_active);

-- ------------------------------------------------------------------------------
-- 2. CẬP NHẬT TRIGGER TỰ ĐỘNG ĐỒNG BỘ EMAIL TỪ AUTH.USERS
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_user() 
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.users (id, full_name, email, role, is_active, is_locked)
  VALUES (
    new.id, 
    coalesce(new.raw_user_meta_data->>'full_name', 'Người dùng mới'),
    lower(trim(new.email)),
    coalesce((new.raw_user_meta_data->>'role')::public.user_role, 'resident'::public.user_role),
    true,
    false
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    full_name = EXCLUDED.full_name;
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ------------------------------------------------------------------------------
-- 3. KHÓA TÀI KHOẢN PHÍA MÁY CHỦ (SERVER-SIDE ENFORCEMENT)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.check_user_active_and_unlocked()
RETURNS TRIGGER AS $$
DECLARE
    v_is_locked BOOLEAN;
    v_is_active BOOLEAN;
BEGIN
    IF auth.uid() IS NULL THEN
        RETURN NEW;
    END IF;

    SELECT is_locked, is_active INTO v_is_locked, v_is_active
    FROM public.users 
    WHERE id = auth.uid();

    IF v_is_locked = true THEN
        RAISE EXCEPTION 'Tài khoản của bạn đã bị Ban Quản Lý khóa tạm thời';
    END IF;

    IF v_is_active = false THEN
        RAISE EXCEPTION 'Tài khoản của bạn đã bị vô hiệu hóa trong hệ thống';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Gắn trigger chặn thao tác vào các bảng nghiệp vụ chính
DROP TRIGGER IF EXISTS trg_check_user_active_invoices ON public.invoices;
CREATE TRIGGER trg_check_user_active_invoices
BEFORE INSERT OR UPDATE ON public.invoices
FOR EACH ROW EXECUTE FUNCTION public.check_user_active_and_unlocked();

DROP TRIGGER IF EXISTS trg_check_user_active_amenities ON public.amenity_bookings;
CREATE TRIGGER trg_check_user_active_amenities
BEFORE INSERT OR UPDATE ON public.amenity_bookings
FOR EACH ROW EXECUTE FUNCTION public.check_user_active_and_unlocked();

DROP TRIGGER IF EXISTS trg_check_user_active_issues ON public.issue_reports;
CREATE TRIGGER trg_check_user_active_issues
BEFORE INSERT OR UPDATE ON public.issue_reports
FOR EACH ROW EXECUTE FUNCTION public.check_user_active_and_unlocked();

-- ------------------------------------------------------------------------------
-- 4. RPC ADMIN_CREATE_USER: TẠO TÀI KHOẢN NGƯỜI DÙNG TRỰC TIẾP TỪ ADMIN
-- ------------------------------------------------------------------------------
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
    -- Chỉ Admin hoặc Staff mới có quyền tạo người dùng
    IF NOT (public.is_admin() OR public.is_staff()) THEN
        RAISE EXCEPTION 'Bạn không có quyền quản trị để tạo tài khoản mới';
    END IF;

    p_email := LOWER(TRIM(p_email));
    IF p_email IS NULL OR p_email = '' THEN
        RAISE EXCEPTION 'Email không được để trống';
    END IF;

    IF EXISTS (SELECT 1 FROM auth.users WHERE email = p_email) THEN
        RAISE EXCEPTION 'Email % đã tồn tại trong hệ thống', p_email;
    END IF;

    v_pwd := COALESCE(NULLIF(TRIM(p_password), ''), 'PkaHome@2026');

    -- Tạo bản ghi trong auth.users
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

    -- Tạo bản ghi trong public.users
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

    -- Liên kết căn hộ nếu có
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

    -- Ghi nhật ký quản trị
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

-- ------------------------------------------------------------------------------
-- 5. RPC ADMIN_UPDATE_USER_PROFILE: CHỈNH SỬA HỒ SƠ TÀI KHOẢN TỪ ADMIN
-- ------------------------------------------------------------------------------
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
    IF NOT (public.is_admin() OR public.is_staff()) THEN
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

    -- Đồng bộ full_name và role sang auth.users metadata
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

-- ------------------------------------------------------------------------------
-- 6. RPC ADMIN_TOGGLE_USER_STATUS: KHÓA / MỞ KHÓA / VÔ HIỆU HÓA (SOFT DELETE)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_toggle_user_status(
    p_target_user_id UUID,
    p_action VARCHAR, -- 'lock', 'unlock', 'deactivate', 'activate'
    p_reason TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_catalog
AS $$
BEGIN
    IF NOT (public.is_admin() OR public.is_staff()) THEN
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

-- ------------------------------------------------------------------------------
-- 7. RPC ADMIN_UNLINK_APARTMENT: GỠ LIÊN KẾT ĐÚNG CĂN HỘ ĐƯỢC CHỌN
-- ------------------------------------------------------------------------------
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
    IF NOT (public.is_admin() OR public.is_staff()) THEN
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
