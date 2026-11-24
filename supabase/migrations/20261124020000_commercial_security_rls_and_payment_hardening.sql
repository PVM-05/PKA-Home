-- ==============================================================================
-- Vivona Production Commercial SaaS:
-- Migration 20261124020000_commercial_security_rls_and_payment_hardening.sql
--
-- Mục tiêu khắc phục triệt để toàn bộ lỗ hổng P0, P1 & P2 từ báo cáo Audit Thương mại hóa:
--   1. [P0-C1] Chặn leo thang đặc quyền (staff/technician/accountant -> admin), tách is_super_admin()
--      và is_building_staff(building_id, roles). Siết chặt admin_* RPCs & trigger users.
--   2. [P0-C2] Xóa toàn bộ RLS USING(true) làm rò rỉ PII (users, apartments, polls, tickets...)
--      và cách ly Multi-Tenant theo building_id / organization_id trên 35+ bảng nghiệp vụ.
--   3. [P0-C3] Thu hồi quyền cư dân tự INSERT payment_transactions; siết create_invoice_with_items
--      & update_invoice_with_items (kiểm tra quyền tòa nhà, SET search_path, tự tính total_amount).
--   4. [P0-C4] Vá đối soát VNPay/SePay: Tenant-scoped building_id, cộng dồn thanh toán từng phần,
--      chặn gạch nợ hóa đơn đã hủy, tự động ghi Có (CREDIT) tiền nộp thừa vào sổ cái căn hộ.
--   5. [P0-C5] Vá dứt điểm các lỗi Schema Drift crash runtime:
--      - Loại bỏ enum 'manager' không tồn tại khỏi RLS & process_sepay_webhook (dùng 'management')
--      - Sửa role_delegations (dùng is_revoked/starts_at/ends_at thay cho is_active/expires_at)
--      - Sửa import_apartments_batch dùng ON CONFLICT (building_id, code)
--      - Sửa validate/generate bulk invoices: lọc theo building_id, tính sản lượng tiêu thụ thực tế,
--        không tự thu 100.000đ phí xe khi căn hộ không có xe.
--   6. [P1-H1..H10] Hardening toàn bộ SECURITY DEFINER RPCs (SET search_path, REVOKE anon, auth.uid()),
--      v_parcels_secure (security_invoker = true, ẩn hash PIN), complete_resident_activation
--      (khóa OTP brute-force, kiểm tra otp_expires_at & auth.uid()), Storage vehicle-docs/handover-docs,
--      building_utility_rates theo tòa nhà + tính bậc thang EVN/Nước, audit_logs chống giả mạo.
--   7. [P2-M1/M4/M5/M6] Bảng lưu vết đồng thuận PDPL 2026 phía server (user_pdpl_consents),
--      RPC đối soát giao dịch nguyên tử (reconcile_unmatched_payment_transaction), nâng độ dài
--      mã tra cứu lookup_code lên 12 ký tự hex & chuẩn hóa 100% thương hiệu Vivona.
-- ==============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ==============================================================================
-- PHẦN 1: HÀM BẢO MẬT ĐA CƠ SỞ & CHỐNG LEO THANG ĐẶC QUYỀN [P0-C1, P0-C2]
-- ==============================================================================

-- 1.1 Kiểm tra Super-Admin nền tảng (yêu cầu AAL2 nếu bật MFA)
CREATE OR REPLACE FUNCTION public.is_super_admin()
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RETURN FALSE;
    END IF;

    IF NOT public.is_aal2_if_mfa_enrolled() THEN
        RETURN FALSE;
    END IF;

    RETURN EXISTS (
        SELECT 1 FROM public.users
        WHERE id = auth.uid()
          AND role = 'admin'
          AND is_active = true
          AND is_locked = false
    );
END;
$$;

REVOKE ALL ON FUNCTION public.is_super_admin() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_super_admin() TO authenticated, service_role;

-- 1.2 Kiểm tra nhân sự/BQL theo đúng phạm vi tòa nhà (Tenant-Scoped + AAL2 + Role Delegation)
CREATE OR REPLACE FUNCTION public.is_building_staff(
    p_building_id UUID,
    p_required_roles TEXT[] DEFAULT ARRAY['admin', 'management', 'manager', 'owner', 'staff', 'accountant', 'technician', 'security', 'receptionist']
)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_user_role TEXT;
BEGIN
    IF v_uid IS NULL THEN
        RETURN FALSE;
    END IF;

    -- Cưỡng chế AAL2 nếu người dùng đã kích hoạt MFA
    IF NOT public.is_aal2_if_mfa_enrolled() THEN
        RETURN FALSE;
    END IF;

    SELECT role::TEXT INTO v_user_role
    FROM public.users
    WHERE id = v_uid
      AND is_active = true
      AND is_locked = false;

    IF v_user_role IS NULL THEN
        RETURN FALSE;
    END IF;

    -- Super Admin nền tảng
    IF v_user_role = 'admin' THEN
        RETURN TRUE;
    END IF;

    IF p_building_id IS NULL THEN
        RETURN FALSE;
    END IF;

    -- 1. Kiểm tra membership trực tiếp tại tòa nhà hoặc owner/admin của tổ chức sở hữu tòa nhà
    IF public.has_building_role(p_building_id, p_required_roles, v_uid) THEN
        RETURN TRUE;
    END IF;

    -- 2. Kiểm tra ủy quyền vai trò có thời hạn (role_delegations) đúng tòa nhà
    IF EXISTS (
        SELECT 1 FROM public.role_delegations rd
        WHERE rd.delegate_id = v_uid
          AND rd.is_revoked = false
          AND rd.starts_at <= now()
          AND rd.ends_at >= now()
          AND rd.delegated_role = ANY(p_required_roles)
          AND (
              rd.building_id = p_building_id
              OR (
                  rd.building_id IS NULL
                  AND p_building_id IN (SELECT public.get_user_accessible_buildings(v_uid))
              )
          )
    ) THEN
        RETURN TRUE;
    END IF;

    -- 3. Kiểm tra nhân sự có vai trò cấp hệ thống khớp và có quyền truy cập tòa nhà này
    IF v_user_role = ANY(p_required_roles)
       AND p_building_id IN (SELECT public.get_user_accessible_buildings(v_uid)) THEN
        RETURN TRUE;
    END IF;

    RETURN FALSE;
END;
$$;

REVOKE ALL ON FUNCTION public.is_building_staff(UUID, TEXT[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_building_staff(UUID, TEXT[]) TO authenticated, service_role;

-- 1.3 Hàm kiểm tra quyền truy cập tòa nhà (Cư dân hoặc BQL thuộc tòa nhà)
CREATE OR REPLACE FUNCTION public.can_access_building(p_building_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_uid UUID := auth.uid();
BEGIN
    IF v_uid IS NULL OR p_building_id IS NULL THEN
        RETURN FALSE;
    END IF;

    IF public.is_super_admin() THEN
        RETURN TRUE;
    END IF;

    IF p_building_id IN (SELECT public.get_user_accessible_buildings(v_uid)) THEN
        RETURN TRUE;
    END IF;

    -- Hỗ trợ cư dân đã gắn residents_apartments kể cả khi building_memberships chưa đồng bộ
    RETURN EXISTS (
        SELECT 1
        FROM public.residents_apartments ra
        JOIN public.apartments a ON a.id = ra.apartment_id
        WHERE ra.user_id = v_uid
          AND COALESCE(ra.status, 'active') = 'active'
          AND a.building_id = p_building_id
    );
END;
$$;

REVOKE ALL ON FUNCTION public.can_access_building(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.can_access_building(UUID) TO authenticated, service_role;

-- 1.4 Hàm kiểm tra quyền truy cập căn hộ
CREATE OR REPLACE FUNCTION public.can_access_apartment(p_apartment_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_building_id UUID;
BEGIN
    IF v_uid IS NULL OR p_apartment_id IS NULL THEN
        RETURN FALSE;
    END IF;

    IF public.is_super_admin() THEN
        RETURN TRUE;
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.residents_apartments ra
        WHERE ra.apartment_id = p_apartment_id
          AND ra.user_id = v_uid
          AND COALESCE(ra.status, 'active') = 'active'
    ) THEN
        RETURN TRUE;
    END IF;

    SELECT building_id INTO v_building_id FROM public.apartments WHERE id = p_apartment_id;
    RETURN public.is_building_staff(v_building_id);
END;
$$;

REVOKE ALL ON FUNCTION public.can_access_apartment(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.can_access_apartment(UUID) TO authenticated, service_role;

-- 1.5 Hàm kiểm tra 2 người dùng có cùng phạm vi tòa nhà / tổ chức mà người gọi có quyền quản lý
CREATE OR REPLACE FUNCTION public.can_manage_target_user(p_target_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_caller_role TEXT;
    v_target_role TEXT;
BEGIN
    IF v_uid IS NULL OR p_target_user_id IS NULL THEN
        RETURN FALSE;
    END IF;

    IF public.is_super_admin() THEN
        RETURN TRUE;
    END IF;

    IF NOT public.is_aal2_if_mfa_enrolled() THEN
        RETURN FALSE;
    END IF;

    SELECT role::TEXT INTO v_caller_role
    FROM public.users
    WHERE id = v_uid AND is_active = true AND is_locked = false;

    -- Chỉ vai trò management mới có quyền quản trị tài khoản trong phạm vi tòa nhà của mình
    IF v_caller_role != 'management' THEN
        RETURN FALSE;
    END IF;

    SELECT role::TEXT INTO v_target_role FROM public.users WHERE id = p_target_user_id;
    -- Tuyệt đối không cho phép quản lý tòa nhà thao tác trên tài khoản Super Admin
    IF v_target_role = 'admin' THEN
        RETURN FALSE;
    END IF;

    -- Người dùng mục tiêu phải thuộc ít nhất 1 tòa nhà mà người gọi có quyền quản lý
    RETURN EXISTS (
        SELECT 1
        FROM public.residents_apartments ra
        JOIN public.apartments a ON a.id = ra.apartment_id
        WHERE ra.user_id = p_target_user_id
          AND public.is_building_staff(a.building_id, ARRAY['admin', 'management', 'manager', 'owner'])
    ) OR EXISTS (
        SELECT 1
        FROM public.building_memberships bm
        WHERE bm.user_id = p_target_user_id
          AND public.is_building_staff(bm.building_id, ARRAY['admin', 'management', 'manager', 'owner'])
    );
END;
$$;

REVOKE ALL ON FUNCTION public.can_manage_target_user(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.can_manage_target_user(UUID) TO authenticated, service_role;

-- 1.6 Khóa chặt Trigger bất biến bảo mật trên bảng public.users (Ngăn staff/technician/management tự nâng lên admin)
CREATE OR REPLACE FUNCTION public.enforce_user_security_immutability()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_is_service_role BOOLEAN := (COALESCE(auth.jwt() ->> 'role', '') = 'service_role');
BEGIN
    IF (NEW.role IS DISTINCT FROM OLD.role
        OR NEW.is_locked IS DISTINCT FROM OLD.is_locked
        OR NEW.is_active IS DISTINCT FROM OLD.is_active) THEN

        IF v_is_service_role OR public.is_super_admin() THEN
            RETURN NEW;
        END IF;

        -- Không ai ngoài Super Admin được gán vai trò 'admin' hoặc sửa tài khoản 'admin'
        IF NEW.role = 'admin' OR OLD.role = 'admin' THEN
            RAISE EXCEPTION 'Truy cập bị từ chối: Chỉ Quản trị viên cấp cao (Super Admin) mới có quyền phân bổ hoặc chỉnh sửa vai trò Admin.'
                USING ERRCODE = '42501';
        END IF;

        -- Không ai được tự nâng quyền hoặc tự mở khóa chính mình
        IF NEW.id = auth.uid() THEN
            RAISE EXCEPTION 'Truy cập bị từ chối: Không được phép tự thay đổi vai trò hoặc trạng thái bảo mật của chính bạn.'
                USING ERRCODE = '42501';
        END IF;

        -- Chỉ Ban Quản Lý tòa nhà của người dùng đó mới được thay đổi vai trò/trạng thái
        IF NOT public.can_manage_target_user(OLD.id) THEN
            RAISE EXCEPTION 'Truy cập bị từ chối: Bạn không có quyền thay đổi vai trò hoặc trạng thái tài khoản ngoài phạm vi quản lý.'
                USING ERRCODE = '42501';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

-- 1.7 Siết chặt RLS bảng public.users (Xóa bỏ hoàn toàn USING(true) làm lộ PII toàn hệ thống)
DROP POLICY IF EXISTS "users_read_all_authenticated" ON public.users;
DROP POLICY IF EXISTS "users_read_scoped" ON public.users;
CREATE POLICY "users_read_scoped" ON public.users
    FOR SELECT TO authenticated
    USING (
        id = auth.uid()
        OR public.is_super_admin()
        OR EXISTS (
            -- Cư dân cùng căn hộ đang hoạt động
            SELECT 1
            FROM public.residents_apartments ra_me
            JOIN public.residents_apartments ra_other ON ra_other.apartment_id = ra_me.apartment_id
            WHERE ra_me.user_id = auth.uid()
              AND ra_other.user_id = public.users.id
              AND COALESCE(ra_me.status, 'active') = 'active'
              AND COALESCE(ra_other.status, 'active') = 'active'
        )
        OR EXISTS (
            -- Nhân sự / BQL chỉ xem được cư dân thuộc tòa nhà mình quản lý
            SELECT 1
            FROM public.residents_apartments ra
            JOIN public.apartments a ON a.id = ra.apartment_id
            WHERE ra.user_id = public.users.id
              AND public.is_building_staff(a.building_id)
        )
        OR EXISTS (
            -- Nhân sự / BQL cùng tòa nhà hoặc tổ chức
            SELECT 1
            FROM public.building_memberships bm
            WHERE bm.user_id = public.users.id
              AND public.is_building_staff(bm.building_id)
        )
    );

DROP POLICY IF EXISTS "users_update_own_or_admin" ON public.users;
CREATE POLICY "users_update_own_or_admin" ON public.users
    FOR UPDATE TO authenticated
    USING (
        id = auth.uid()
        OR public.is_super_admin()
        OR public.can_manage_target_user(id)
    )
    WITH CHECK (
        public.is_super_admin()
        OR (
            id = auth.uid()
            AND role = (SELECT u.role FROM public.users u WHERE u.id = auth.uid())
            AND is_locked = (SELECT u.is_locked FROM public.users u WHERE u.id = auth.uid())
            AND is_active = (SELECT u.is_active FROM public.users u WHERE u.id = auth.uid())
        )
        OR (
            public.can_manage_target_user(id)
            AND role != 'admin'
        )
    );

-- 1.8 Thu hồi quyền EXECUTE trực tiếp các hàm phân quyền từ anon
REVOKE ALL ON FUNCTION public.get_user_accessible_organizations(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_user_accessible_organizations(UUID) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.get_user_accessible_buildings(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_user_accessible_buildings(UUID) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.has_building_role(UUID, TEXT[], UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.has_building_role(UUID, TEXT[], UUID) TO authenticated, service_role;

-- ==============================================================================
-- PHẦN 2: CÁCH LY MULTI-TENANT RLS & VÁ LỖI ENUM 'manager' [P0-C2, P0-C3, P0-C5, P1-H10]
-- ==============================================================================

-- 2.1 Bảng accounting_periods (vá enum 'manager' -> tenant-scoped)
DROP POLICY IF EXISTS "ap_read_policy" ON public.accounting_periods;
CREATE POLICY "ap_read_policy" ON public.accounting_periods
    FOR SELECT TO authenticated
    USING (public.can_access_building(building_id));

DROP POLICY IF EXISTS "ap_manage_policy" ON public.accounting_periods;
CREATE POLICY "ap_manage_policy" ON public.accounting_periods
    FOR ALL TO authenticated
    USING (public.is_building_staff(building_id, ARRAY['admin', 'management', 'manager', 'owner', 'accountant']))
    WITH CHECK (public.is_building_staff(building_id, ARRAY['admin', 'management', 'manager', 'owner', 'accountant']));

-- 2.2 Bảng apartment_ledger_entries (vá enum 'manager' -> tenant-scoped)
DROP POLICY IF EXISTS "ale_read_policy" ON public.apartment_ledger_entries;
CREATE POLICY "ale_read_policy" ON public.apartment_ledger_entries
    FOR SELECT TO authenticated
    USING (
        public.is_building_staff(building_id, ARRAY['admin', 'management', 'manager', 'owner', 'accountant'])
        OR EXISTS (
            SELECT 1 FROM public.residents_apartments ra
            WHERE ra.user_id = auth.uid()
              AND ra.apartment_id = apartment_ledger_entries.apartment_id
              AND COALESCE(ra.status, 'active') = 'active'
        )
    );

DROP POLICY IF EXISTS "ale_insert_policy" ON public.apartment_ledger_entries;
CREATE POLICY "ale_insert_policy" ON public.apartment_ledger_entries
    FOR INSERT TO authenticated
    WITH CHECK (public.is_building_staff(building_id, ARRAY['admin', 'management', 'manager', 'owner', 'accountant']));

-- 2.3 Bảng credit_notes (vá enum 'manager' -> tenant-scoped)
DROP POLICY IF EXISTS "cn_read_policy" ON public.credit_notes;
CREATE POLICY "cn_read_policy" ON public.credit_notes
    FOR SELECT TO authenticated
    USING (
        public.is_building_staff(building_id, ARRAY['admin', 'management', 'manager', 'owner', 'accountant'])
        OR EXISTS (
            SELECT 1 FROM public.residents_apartments ra
            WHERE ra.user_id = auth.uid()
              AND ra.apartment_id = credit_notes.apartment_id
              AND COALESCE(ra.status, 'active') = 'active'
        )
    );

DROP POLICY IF EXISTS "cn_manage_policy" ON public.credit_notes;
CREATE POLICY "cn_manage_policy" ON public.credit_notes
    FOR ALL TO authenticated
    USING (public.is_building_staff(building_id, ARRAY['admin', 'management', 'manager', 'owner', 'accountant']))
    WITH CHECK (public.is_building_staff(building_id, ARRAY['admin', 'management', 'manager', 'owner', 'accountant']));

-- 2.4 Bảng building_payment_configs (vá enum 'manager' & cách ly tenant)
DROP POLICY IF EXISTS "Cho phép xem thông tin tài khoản ngân hàng tòa nhà" ON public.building_payment_configs;
CREATE POLICY "Cho phép xem thông tin tài khoản ngân hàng tòa nhà"
    ON public.building_payment_configs FOR SELECT TO authenticated
    USING (is_active = true AND public.can_access_building(building_id));

DROP POLICY IF EXISTS "Ban Quản Lý toàn quyền quản lý cấu hình SePay" ON public.building_payment_configs;
CREATE POLICY "Ban Quản Lý toàn quyền quản lý cấu hình SePay"
    ON public.building_payment_configs FOR ALL TO authenticated
    USING (public.is_building_staff(building_id, ARRAY['admin', 'management', 'manager', 'owner', 'accountant']))
    WITH CHECK (public.is_building_staff(building_id, ARRAY['admin', 'management', 'manager', 'owner', 'accountant']));

-- 2.5 Bảng building_payment_secrets (bổ sung AAL2 & is_super_admin)
DROP POLICY IF EXISTS "Chỉ Quản trị viên cấp cao mới xem được payment secrets" ON public.building_payment_secrets;
CREATE POLICY "Chỉ Quản trị viên cấp cao mới xem được payment secrets"
    ON public.building_payment_secrets FOR ALL TO authenticated
    USING (public.is_super_admin())
    WITH CHECK (public.is_super_admin());

-- 2.6 Bảng apartments (Xóa USING(true), cách ly tenant)
DROP POLICY IF EXISTS "apartments_read_authenticated" ON public.apartments;
CREATE POLICY "apartments_read_tenant" ON public.apartments
    FOR SELECT TO authenticated
    USING (public.can_access_building(building_id));

DROP POLICY IF EXISTS "apartments_write_admin" ON public.apartments;
CREATE POLICY "apartments_write_admin" ON public.apartments
    FOR ALL TO authenticated
    USING (public.is_building_staff(building_id, ARRAY['admin', 'management', 'manager', 'owner']))
    WITH CHECK (public.is_building_staff(building_id, ARRAY['admin', 'management', 'manager', 'owner']));

-- 2.7 Bảng invoices & invoice_items (Tenant-scoped)
DROP POLICY IF EXISTS "invoices_read" ON public.invoices;
CREATE POLICY "invoices_read" ON public.invoices
    FOR SELECT TO authenticated
    USING (public.can_access_apartment(apartment_id));

DROP POLICY IF EXISTS "invoices_write_admin" ON public.invoices;
CREATE POLICY "invoices_write_admin" ON public.invoices
    FOR ALL TO authenticated
    USING (public.is_building_staff((SELECT a.building_id FROM public.apartments a WHERE a.id = invoices.apartment_id), ARRAY['admin', 'management', 'manager', 'owner', 'accountant']))
    WITH CHECK (public.is_building_staff((SELECT a.building_id FROM public.apartments a WHERE a.id = invoices.apartment_id), ARRAY['admin', 'management', 'manager', 'owner', 'accountant']));

DROP POLICY IF EXISTS "invoice_items_read" ON public.invoice_items;
CREATE POLICY "invoice_items_read" ON public.invoice_items
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.invoices i
            WHERE i.id = invoice_items.invoice_id
              AND public.can_access_apartment(i.apartment_id)
        )
    );

DROP POLICY IF EXISTS "invoice_items_write_admin" ON public.invoice_items;
CREATE POLICY "invoice_items_write_admin" ON public.invoice_items
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.invoices i
            JOIN public.apartments a ON a.id = i.apartment_id
            WHERE i.id = invoice_items.invoice_id
              AND public.is_building_staff(a.building_id, ARRAY['admin', 'management', 'manager', 'owner', 'accountant'])
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.invoices i
            JOIN public.apartments a ON a.id = i.apartment_id
            WHERE i.id = invoice_items.invoice_id
              AND public.is_building_staff(a.building_id, ARRAY['admin', 'management', 'manager', 'owner', 'accountant'])
        )
    );

-- 2.8 [P0-C3] Bảng payment_transactions: CHẶN CƯ DÂN TỰ INSERT GIAO DỊCH GIẢ
DROP POLICY IF EXISTS "payment_transactions_read" ON public.payment_transactions;
CREATE POLICY "payment_transactions_read" ON public.payment_transactions
    FOR SELECT TO authenticated
    USING (
        user_id = auth.uid()
        OR (apartment_id IS NOT NULL AND public.can_access_apartment(apartment_id))
        OR public.is_super_admin()
    );

DROP POLICY IF EXISTS "payment_transactions_insert" ON public.payment_transactions;
CREATE POLICY "payment_transactions_insert" ON public.payment_transactions
    FOR INSERT TO authenticated
    WITH CHECK (
        public.is_super_admin()
        OR (
            apartment_id IS NOT NULL
            AND public.is_building_staff(
                (SELECT a.building_id FROM public.apartments a WHERE a.id = payment_transactions.apartment_id),
                ARRAY['admin', 'management', 'manager', 'owner', 'accountant']
            )
        )
    );

DROP POLICY IF EXISTS "payment_transactions_manage_admin" ON public.payment_transactions;
CREATE POLICY "payment_transactions_manage_admin" ON public.payment_transactions
    FOR UPDATE TO authenticated
    USING (
        public.is_super_admin()
        OR (
            apartment_id IS NOT NULL
            AND public.is_building_staff(
                (SELECT a.building_id FROM public.apartments a WHERE a.id = payment_transactions.apartment_id),
                ARRAY['admin', 'management', 'manager', 'owner', 'accountant']
            )
        )
    )
    WITH CHECK (
        public.is_super_admin()
        OR (
            apartment_id IS NOT NULL
            AND public.is_building_staff(
                (SELECT a.building_id FROM public.apartments a WHERE a.id = payment_transactions.apartment_id),
                ARRAY['admin', 'management', 'manager', 'owner', 'accountant']
            )
        )
    );

-- 2.9 Các bảng vận hành & cộng đồng: Xóa USING(true), cách ly theo building_id / apartment_id
DROP POLICY IF EXISTS "announcements_read_all" ON public.announcements;
CREATE POLICY "announcements_read_tenant" ON public.announcements
    FOR SELECT TO authenticated
    USING (building_id IS NULL OR public.can_access_building(building_id));

DROP POLICY IF EXISTS "announcements_write_admin" ON public.announcements;
CREATE POLICY "announcements_write_admin" ON public.announcements
    FOR ALL TO authenticated
    USING (building_id IS NOT NULL AND public.is_building_staff(building_id, ARRAY['admin', 'management', 'manager', 'owner', 'receptionist']))
    WITH CHECK (building_id IS NOT NULL AND public.is_building_staff(building_id, ARRAY['admin', 'management', 'manager', 'owner', 'receptionist']));

DROP POLICY IF EXISTS "amenities_read_all" ON public.building_amenities;
CREATE POLICY "amenities_read_tenant" ON public.building_amenities
    FOR SELECT TO authenticated
    USING (building_id IS NULL OR public.can_access_building(building_id));

DROP POLICY IF EXISTS "amenities_manage_admin" ON public.building_amenities;
CREATE POLICY "amenities_manage_admin" ON public.building_amenities
    FOR ALL TO authenticated
    USING (building_id IS NOT NULL AND public.is_building_staff(building_id, ARRAY['admin', 'management', 'manager', 'owner']))
    WITH CHECK (building_id IS NOT NULL AND public.is_building_staff(building_id, ARRAY['admin', 'management', 'manager', 'owner']));

DROP POLICY IF EXISTS "maintenance_windows_read" ON public.amenity_maintenance_windows;
CREATE POLICY "maintenance_windows_read" ON public.amenity_maintenance_windows
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.building_amenities ba
            WHERE ba.id = amenity_maintenance_windows.amenity_id
              AND (ba.building_id IS NULL OR public.can_access_building(ba.building_id))
        )
    );

DROP POLICY IF EXISTS "building_equipments_read" ON public.building_equipments;
CREATE POLICY "building_equipments_read" ON public.building_equipments
    FOR SELECT TO authenticated
    USING (building_id IS NULL OR public.can_access_building(building_id));

DROP POLICY IF EXISTS "building_equipments_manage" ON public.building_equipments;
CREATE POLICY "building_equipments_manage" ON public.building_equipments
    FOR ALL TO authenticated
    USING (
        public.is_super_admin()
        OR (building_id IS NOT NULL AND public.is_building_staff(building_id, ARRAY['admin', 'management', 'manager', 'owner', 'technician']))
    )
    WITH CHECK (
        public.is_super_admin()
        OR (building_id IS NOT NULL AND public.is_building_staff(building_id, ARRAY['admin', 'management', 'manager', 'owner', 'technician']))
    );

DROP POLICY IF EXISTS "emergency_contacts_read" ON public.emergency_contacts;
CREATE POLICY "emergency_contacts_read" ON public.emergency_contacts
    FOR SELECT TO authenticated
    USING (building_id IS NULL OR public.can_access_building(building_id));

DROP POLICY IF EXISTS "emergency_contacts_manage" ON public.emergency_contacts;
CREATE POLICY "emergency_contacts_manage" ON public.emergency_contacts
    FOR ALL TO authenticated
    USING (public.is_super_admin() OR (building_id IS NOT NULL AND public.is_building_staff(building_id, ARRAY['admin', 'management', 'manager', 'owner'])))
    WITH CHECK (public.is_super_admin() OR (building_id IS NOT NULL AND public.is_building_staff(building_id, ARRAY['admin', 'management', 'manager', 'owner'])));

DROP POLICY IF EXISTS "building_rules_read" ON public.building_rules;
CREATE POLICY "building_rules_read" ON public.building_rules
    FOR SELECT TO authenticated
    USING (is_active = true AND (building_id IS NULL OR public.can_access_building(building_id)));

DROP POLICY IF EXISTS "building_rules_manage" ON public.building_rules;
CREATE POLICY "building_rules_manage" ON public.building_rules
    FOR ALL TO authenticated
    USING (public.is_super_admin() OR (building_id IS NOT NULL AND public.is_building_staff(building_id, ARRAY['admin', 'management', 'manager', 'owner'])))
    WITH CHECK (public.is_super_admin() OR (building_id IS NOT NULL AND public.is_building_staff(building_id, ARRAY['admin', 'management', 'manager', 'owner'])));

DROP POLICY IF EXISTS "fee_schedules_read" ON public.fee_schedules;
CREATE POLICY "fee_schedules_read" ON public.fee_schedules
    FOR SELECT TO authenticated
    USING (building_id IS NULL OR public.can_access_building(building_id));

DROP POLICY IF EXISTS "fee_schedules_manage_admin" ON public.fee_schedules;
CREATE POLICY "fee_schedules_manage_admin" ON public.fee_schedules
    FOR ALL TO authenticated
    USING (public.is_super_admin() OR (building_id IS NOT NULL AND public.is_building_staff(building_id, ARRAY['admin', 'management', 'manager', 'owner', 'accountant'])))
    WITH CHECK (public.is_super_admin() OR (building_id IS NOT NULL AND public.is_building_staff(building_id, ARRAY['admin', 'management', 'manager', 'owner', 'accountant'])));

DROP POLICY IF EXISTS "ftp_read_policy" ON public.fee_tier_policies;
CREATE POLICY "ftp_read_policy" ON public.fee_tier_policies
    FOR SELECT TO authenticated
    USING (building_id IS NULL OR public.can_access_building(building_id));

DROP POLICY IF EXISTS "Public authenticated users can read materials" ON public.maintenance_materials;
CREATE POLICY "maintenance_materials_read_tenant" ON public.maintenance_materials
    FOR SELECT TO authenticated
    USING (building_id IS NULL OR public.can_access_building(building_id));

DROP POLICY IF EXISTS "parking_slots_read" ON public.parking_slots;
CREATE POLICY "parking_slots_read" ON public.parking_slots
    FOR SELECT TO authenticated
    USING (building_id IS NULL OR public.can_access_building(building_id));

DROP POLICY IF EXISTS "visitor_tickets_read" ON public.visitor_parking_tickets;
CREATE POLICY "visitor_tickets_read" ON public.visitor_parking_tickets
    FOR SELECT TO authenticated
    USING (building_id IS NOT NULL AND public.is_building_staff(building_id));

DROP POLICY IF EXISTS "org_subscriptions_read_authenticated" ON public.organization_subscriptions;
CREATE POLICY "org_subscriptions_read_tenant" ON public.organization_subscriptions
    FOR SELECT TO authenticated
    USING (organization_id IN (SELECT public.get_user_accessible_organizations(auth.uid())));

DROP POLICY IF EXISTS "Anyone authenticated can view polls" ON public.polls;
CREATE POLICY "polls_read_tenant" ON public.polls
    FOR SELECT TO authenticated
    USING (building_id IS NULL OR public.can_access_building(building_id));

DROP POLICY IF EXISTS "Anyone authenticated can view poll options" ON public.poll_options;
CREATE POLICY "poll_options_read_tenant" ON public.poll_options
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.polls p
            WHERE p.id = poll_options.poll_id
              AND (p.building_id IS NULL OR public.can_access_building(p.building_id))
        )
    );

DROP POLICY IF EXISTS "Anyone authenticated can view petitions" ON public.resident_petitions;
CREATE POLICY "petitions_read_tenant" ON public.resident_petitions
    FOR SELECT TO authenticated
    USING (building_id IS NULL OR public.can_access_building(building_id));

DROP POLICY IF EXISTS "Anyone authenticated can view endorsements" ON public.petition_endorsements;
CREATE POLICY "endorsements_read_tenant" ON public.petition_endorsements
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.resident_petitions rp
            WHERE rp.id = petition_endorsements.petition_id
              AND (rp.building_id IS NULL OR public.can_access_building(rp.building_id))
        )
    );

DROP POLICY IF EXISTS "issue_reports_read" ON public.issue_reports;
CREATE POLICY "issue_reports_read" ON public.issue_reports
    FOR SELECT TO authenticated
    USING (reporter_id = auth.uid() OR public.can_access_apartment(apartment_id));

DROP POLICY IF EXISTS "issue_reports_update" ON public.issue_reports;
CREATE POLICY "issue_reports_update" ON public.issue_reports
    FOR UPDATE TO authenticated
    USING (
        reporter_id = auth.uid()
        OR public.is_building_staff((SELECT a.building_id FROM public.apartments a WHERE a.id = issue_reports.apartment_id))
    )
    WITH CHECK (
        reporter_id = auth.uid()
        OR public.is_building_staff((SELECT a.building_id FROM public.apartments a WHERE a.id = issue_reports.apartment_id))
    );

DROP POLICY IF EXISTS "issue_images_read" ON public.issue_images;
CREATE POLICY "issue_images_read" ON public.issue_images
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.issue_reports ir
            WHERE ir.id = issue_images.issue_report_id
              AND (ir.reporter_id = auth.uid() OR public.can_access_apartment(ir.apartment_id))
        )
    );

DROP POLICY IF EXISTS "issue_images_insert" ON public.issue_images;
CREATE POLICY "issue_images_insert" ON public.issue_images
    FOR INSERT TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.issue_reports ir
            WHERE ir.id = issue_images.issue_report_id
              AND (ir.reporter_id = auth.uid() OR public.can_access_apartment(ir.apartment_id))
        )
    );

DROP POLICY IF EXISTS "issue_ratings_read" ON public.issue_ratings;
CREATE POLICY "issue_ratings_read" ON public.issue_ratings
    FOR SELECT TO authenticated
    USING (
        user_id = auth.uid()
        OR EXISTS (
            SELECT 1 FROM public.issue_reports ir
            WHERE ir.id = issue_ratings.issue_report_id
              AND public.can_access_apartment(ir.apartment_id)
        )
    );

DROP POLICY IF EXISTS "vehicles_read" ON public.vehicles;
CREATE POLICY "vehicles_read" ON public.vehicles
    FOR SELECT TO authenticated
    USING (user_id = auth.uid() OR public.can_access_apartment(apartment_id));

DROP POLICY IF EXISTS "vehicles_manage_admin" ON public.vehicles;
CREATE POLICY "vehicles_manage_admin" ON public.vehicles
    FOR ALL TO authenticated
    USING (
        user_id = auth.uid()
        OR public.is_building_staff((SELECT a.building_id FROM public.apartments a WHERE a.id = vehicles.apartment_id))
    )
    WITH CHECK (
        user_id = auth.uid()
        OR public.is_building_staff((SELECT a.building_id FROM public.apartments a WHERE a.id = vehicles.apartment_id))
    );

DROP POLICY IF EXISTS "meter_submissions_read" ON public.meter_reading_submissions;
CREATE POLICY "meter_submissions_read" ON public.meter_reading_submissions
    FOR SELECT TO authenticated
    USING (submitted_by = auth.uid() OR public.can_access_apartment(apartment_id));

DROP POLICY IF EXISTS "meter_submissions_insert" ON public.meter_reading_submissions;
CREATE POLICY "meter_submissions_insert" ON public.meter_reading_submissions
    FOR INSERT TO authenticated
    WITH CHECK (
        (submitted_by = auth.uid() AND public.can_access_apartment(apartment_id))
        OR public.is_building_staff((SELECT a.building_id FROM public.apartments a WHERE a.id = meter_reading_submissions.apartment_id))
    );

DROP POLICY IF EXISTS "meter_submissions_update_admin" ON public.meter_reading_submissions;
CREATE POLICY "meter_submissions_update_admin" ON public.meter_reading_submissions
    FOR UPDATE TO authenticated
    USING (public.is_building_staff((SELECT a.building_id FROM public.apartments a WHERE a.id = meter_reading_submissions.apartment_id)))
    WITH CHECK (public.is_building_staff((SELECT a.building_id FROM public.apartments a WHERE a.id = meter_reading_submissions.apartment_id)));

DROP POLICY IF EXISTS "residents_apartments_read" ON public.residents_apartments;
CREATE POLICY "residents_apartments_read" ON public.residents_apartments
    FOR SELECT TO authenticated
    USING (user_id = auth.uid() OR public.can_access_apartment(apartment_id));

DROP POLICY IF EXISTS "residents_apartments_write_admin" ON public.residents_apartments;
CREATE POLICY "residents_apartments_write_admin" ON public.residents_apartments
    FOR ALL TO authenticated
    USING (public.is_building_staff((SELECT a.building_id FROM public.apartments a WHERE a.id = residents_apartments.apartment_id), ARRAY['admin', 'management', 'manager', 'owner']))
    WITH CHECK (public.is_building_staff((SELECT a.building_id FROM public.apartments a WHERE a.id = residents_apartments.apartment_id), ARRAY['admin', 'management', 'manager', 'owner']));

DROP POLICY IF EXISTS "link_requests_read" ON public.apartment_link_requests;
CREATE POLICY "link_requests_read" ON public.apartment_link_requests
    FOR SELECT TO authenticated
    USING (
        user_id = auth.uid()
        OR public.is_building_staff((SELECT a.building_id FROM public.apartments a WHERE a.id = apartment_link_requests.apartment_id), ARRAY['admin', 'management', 'manager', 'owner', 'receptionist'])
    );

DROP POLICY IF EXISTS "link_requests_update_admin" ON public.apartment_link_requests;
CREATE POLICY "link_requests_update_admin" ON public.apartment_link_requests
    FOR UPDATE TO authenticated
    USING (public.is_building_staff((SELECT a.building_id FROM public.apartments a WHERE a.id = apartment_link_requests.apartment_id), ARRAY['admin', 'management', 'manager', 'owner', 'receptionist']))
    WITH CHECK (public.is_building_staff((SELECT a.building_id FROM public.apartments a WHERE a.id = apartment_link_requests.apartment_id), ARRAY['admin', 'management', 'manager', 'owner', 'receptionist']));

DROP POLICY IF EXISTS "amenity_bookings_read" ON public.amenity_bookings;
CREATE POLICY "amenity_bookings_read" ON public.amenity_bookings
    FOR SELECT TO authenticated
    USING (booked_by = auth.uid() OR public.can_access_apartment(apartment_id));

DROP POLICY IF EXISTS "amenity_bookings_update" ON public.amenity_bookings;
CREATE POLICY "amenity_bookings_update" ON public.amenity_bookings
    FOR UPDATE TO authenticated
    USING (
        booked_by = auth.uid()
        OR public.is_building_staff((SELECT a.building_id FROM public.apartments a WHERE a.id = amenity_bookings.apartment_id))
    )
    WITH CHECK (
        booked_by = auth.uid()
        OR public.is_building_staff((SELECT a.building_id FROM public.apartments a WHERE a.id = amenity_bookings.apartment_id))
    );

DROP POLICY IF EXISTS "role_delegations_read" ON public.role_delegations;
CREATE POLICY "role_delegations_read" ON public.role_delegations
    FOR SELECT TO authenticated
    USING (
        delegator_id = auth.uid()
        OR delegate_id = auth.uid()
        OR public.is_super_admin()
        OR (building_id IS NOT NULL AND public.is_building_staff(building_id, ARRAY['admin', 'management', 'manager', 'owner']))
    );

DROP POLICY IF EXISTS "role_delegations_manage" ON public.role_delegations;
CREATE POLICY "role_delegations_manage" ON public.role_delegations
    FOR ALL TO authenticated
    USING (
        public.is_super_admin()
        OR (building_id IS NOT NULL AND public.is_building_staff(building_id, ARRAY['admin', 'management', 'manager', 'owner']))
    )
    WITH CHECK (
        (public.is_super_admin() OR (building_id IS NOT NULL AND public.is_building_staff(building_id, ARRAY['admin', 'management', 'manager', 'owner'])))
        AND delegated_role != 'admin'
    );

DROP POLICY IF EXISTS "role_change_log_manage" ON public.role_change_log;
CREATE POLICY "role_change_log_read_scoped" ON public.role_change_log
    FOR SELECT TO authenticated
    USING (public.is_super_admin() OR public.can_manage_target_user(target_user_id));

-- 2.10 [P1-H10] Nhật ký kiểm toán (audit_logs): Cấm giả mạo actor_id và tách tenant
DROP POLICY IF EXISTS "audit_logs_read" ON public.audit_logs;
CREATE POLICY "audit_logs_read" ON public.audit_logs
    FOR SELECT TO authenticated
    USING (
        public.is_super_admin()
        OR (building_id IS NOT NULL AND public.is_building_staff(building_id, ARRAY['admin', 'management', 'manager', 'owner', 'accountant']))
    );

DROP POLICY IF EXISTS "audit_logs_insert" ON public.audit_logs;
CREATE POLICY "audit_logs_insert" ON public.audit_logs
    FOR INSERT TO authenticated
    WITH CHECK (
        actor_id = auth.uid()
        AND (
            action IN ('PDPL_DATA_EXPORTED', 'PDPL_ANONYMIZATION_REQUEST', 'PDPL_CONSENT_ACCEPTED', 'PDPL_CONSENT_REVOKED')
            OR public.is_super_admin()
            OR (building_id IS NOT NULL AND public.is_building_staff(building_id))
        )
    );

-- 2.11 Bàn giao tài sản (apartment_assets, apartment_handovers, handover_items) cách ly theo building_id
DROP POLICY IF EXISTS "assets_select_policy" ON public.apartment_assets;
CREATE POLICY "assets_select_policy" ON public.apartment_assets
    FOR SELECT TO authenticated
    USING (public.can_access_apartment(apartment_id));

DROP POLICY IF EXISTS "assets_modify_policy" ON public.apartment_assets;
CREATE POLICY "assets_modify_policy" ON public.apartment_assets
    FOR ALL TO authenticated
    USING (public.is_building_staff((SELECT a.building_id FROM public.apartments a WHERE a.id = apartment_assets.apartment_id), ARRAY['admin', 'management', 'manager', 'owner', 'technician']))
    WITH CHECK (public.is_building_staff((SELECT a.building_id FROM public.apartments a WHERE a.id = apartment_assets.apartment_id), ARRAY['admin', 'management', 'manager', 'owner', 'technician']));

DROP POLICY IF EXISTS "handovers_select_policy" ON public.apartment_handovers;
CREATE POLICY "handovers_select_policy" ON public.apartment_handovers
    FOR SELECT TO authenticated
    USING (conducted_by = auth.uid() OR resident_id = auth.uid() OR public.can_access_apartment(apartment_id));

DROP POLICY IF EXISTS "handovers_insert_policy" ON public.apartment_handovers;
CREATE POLICY "handovers_insert_policy" ON public.apartment_handovers
    FOR INSERT TO authenticated
    WITH CHECK (public.is_building_staff(building_id, ARRAY['admin', 'management', 'manager', 'owner', 'technician']));

DROP POLICY IF EXISTS "handovers_update_policy" ON public.apartment_handovers;
CREATE POLICY "handovers_update_policy" ON public.apartment_handovers
    FOR UPDATE TO authenticated
    USING (
        resident_id = auth.uid()
        OR conducted_by = auth.uid()
        OR public.is_building_staff(building_id, ARRAY['admin', 'management', 'manager', 'owner', 'technician'])
    )
    WITH CHECK (
        resident_id = auth.uid()
        OR conducted_by = auth.uid()
        OR public.is_building_staff(building_id, ARRAY['admin', 'management', 'manager', 'owner', 'technician'])
    );

-- ==============================================================================
-- PHẦN 3: BIỂU GIÁ ĐIỆN NƯỚC THEO TÒA NHÀ & TÍNH BẬC THANG [P1-H9]
-- ==============================================================================

ALTER TABLE public.building_utility_rates
    ADD COLUMN IF NOT EXISTS building_id UUID REFERENCES public.buildings(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_utility_rates_building_type
    ON public.building_utility_rates(building_id, utility_type, is_active);

DROP POLICY IF EXISTS "utility_rates_read" ON public.building_utility_rates;
CREATE POLICY "utility_rates_read" ON public.building_utility_rates
    FOR SELECT TO authenticated
    USING (building_id IS NULL OR public.can_access_building(building_id));

DROP POLICY IF EXISTS "utility_rates_manage" ON public.building_utility_rates;
CREATE POLICY "utility_rates_manage" ON public.building_utility_rates
    FOR ALL TO authenticated
    USING (public.is_super_admin() OR (building_id IS NOT NULL AND public.is_building_staff(building_id, ARRAY['admin', 'management', 'manager', 'owner', 'accountant'])))
    WITH CHECK (public.is_super_admin() OR (building_id IS NOT NULL AND public.is_building_staff(building_id, ARRAY['admin', 'management', 'manager', 'owner', 'accountant'])));

CREATE OR REPLACE FUNCTION public.calculate_utility_charge(
    p_utility_type VARCHAR,
    p_consumed NUMERIC,
    p_building_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_rate RECORD;
    v_consumed NUMERIC := GREATEST(0, COALESCE(p_consumed, 0));
    v_subtotal NUMERIC(15, 2) := 0;
    v_vat NUMERIC(15, 2) := 0;
    v_env NUMERIC(15, 2) := 0;
    v_total NUMERIC(15, 2) := 0;
    v_tier JSONB;
    v_from NUMERIC;
    v_to NUMERIC;
    v_tier_rate NUMERIC;
    v_tier_units NUMERIC;
BEGIN
    -- Ưu tiên biểu giá riêng của tòa nhà, fallback về biểu giá mặc định chung (building_id IS NULL)
    SELECT * INTO v_rate
    FROM public.building_utility_rates
    WHERE utility_type = p_utility_type
      AND is_active = true
      AND (p_building_id IS NULL OR building_id = p_building_id OR building_id IS NULL)
    ORDER BY (building_id IS NOT NULL) DESC, effective_from DESC
    LIMIT 1;

    IF NOT FOUND THEN
        IF p_utility_type = 'electricity' THEN
            v_subtotal := ROUND(v_consumed * 3500.00, 0);
            v_vat := ROUND(v_subtotal * 0.08, 0);
            v_total := v_subtotal + v_vat;
            RETURN jsonb_build_object(
                'subtotal', v_subtotal, 'vat_amount', v_vat, 'env_fee_amount', 0,
                'total_amount', v_total, 'unit_price', 3500.00
            );
        ELSE
            v_subtotal := ROUND(v_consumed * 25000.00, 0);
            v_vat := ROUND(v_subtotal * 0.05, 0);
            v_env := ROUND(v_subtotal * 0.10, 0);
            v_total := v_subtotal + v_vat + v_env;
            RETURN jsonb_build_object(
                'subtotal', v_subtotal, 'vat_amount', v_vat, 'env_fee_amount', v_env,
                'total_amount', v_total, 'unit_price', 25000.00
            );
        END IF;
    END IF;

    -- Hỗ trợ tính biểu giá lũy tiến bậc thang (tiered_evn / tiered_water) từ JSONB tiers
    IF v_rate.pricing_model IN ('tiered_evn', 'tiered_water')
       AND v_rate.tiers IS NOT NULL
       AND jsonb_typeof(v_rate.tiers) = 'array'
       AND jsonb_array_length(v_rate.tiers) > 0 THEN
        FOR v_tier IN SELECT * FROM jsonb_array_elements(v_rate.tiers)
        LOOP
            v_from := COALESCE((v_tier->>'from')::NUMERIC, 0);
            v_to := NULLIF(v_tier->>'to', '')::NUMERIC;
            v_tier_rate := COALESCE((v_tier->>'rate')::NUMERIC, v_rate.base_unit_price);
            IF v_consumed > v_from THEN
                IF v_to IS NOT NULL THEN
                    v_tier_units := GREATEST(0, LEAST(v_consumed, v_to) - v_from);
                ELSE
                    v_tier_units := GREATEST(0, v_consumed - v_from);
                END IF;
                v_subtotal := v_subtotal + ROUND(v_tier_units * v_tier_rate, 0);
            END IF;
        END LOOP;
    ELSE
        v_subtotal := ROUND(v_consumed * v_rate.base_unit_price, 0);
    END IF;

    v_vat := ROUND(v_subtotal * (COALESCE(v_rate.vat_percentage, 0) / 100.0), 0);
    v_env := ROUND(v_subtotal * (COALESCE(v_rate.environment_fee_percentage, 0) / 100.0), 0);
    v_total := v_subtotal + v_vat + v_env;

    RETURN jsonb_build_object(
        'subtotal', v_subtotal,
        'vat_amount', v_vat,
        'env_fee_amount', v_env,
        'total_amount', v_total,
        'unit_price', v_rate.base_unit_price
    );
END;
$$;

REVOKE ALL ON FUNCTION public.calculate_utility_charge(VARCHAR, NUMERIC, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.calculate_utility_charge(VARCHAR, NUMERIC, UUID) TO authenticated, service_role;

-- ==============================================================================
-- PHẦN 4: HARDENING CÁC RPC QUẢN TRỊ, HÓA ĐƠN, BÁO CÁO & IMPORT [P0-C1, P0-C3, P0-C5, P0-C6]
-- ==============================================================================

-- 4.1 [P0-C3] create_invoice_with_items: Bảo vệ RBAC theo tòa nhà, SET search_path, tự cộng total_amount
CREATE OR REPLACE FUNCTION public.create_invoice_with_items(
    p_apartment_id UUID,
    p_period VARCHAR,
    p_due_date DATE,
    p_items JSONB
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_building_id UUID;
    v_invoice_id UUID;
    v_item JSONB;
    v_unit_price NUMERIC(15,2);
    v_quantity NUMERIC(12,2);
    v_subtotal NUMERIC(15,2);
    v_total_amount NUMERIC(15,2) := 0;
BEGIN
    SELECT building_id INTO v_building_id FROM public.apartments WHERE id = p_apartment_id;
    IF v_building_id IS NULL THEN
        RAISE EXCEPTION 'Không tìm thấy căn hộ hợp lệ.' USING ERRCODE = '22023';
    END IF;

    IF NOT (
        COALESCE(auth.jwt() ->> 'role', '') = 'service_role'
        OR public.is_building_staff(v_building_id, ARRAY['admin', 'management', 'manager', 'owner', 'accountant'])
    ) THEN
        RAISE EXCEPTION 'Truy cập bị từ chối: Chỉ Ban Quản Lý hoặc Kế toán tòa nhà mới có quyền lập hóa đơn.'
            USING ERRCODE = '42501';
    END IF;

    INSERT INTO public.invoices (apartment_id, period, due_date, total_amount, status)
    VALUES (p_apartment_id, p_period, p_due_date, 0, 'unpaid'::public.invoice_status)
    RETURNING id INTO v_invoice_id;

    IF p_items IS NOT NULL AND jsonb_typeof(p_items) = 'array' AND jsonb_array_length(p_items) > 0 THEN
        FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
        LOOP
            v_unit_price := COALESCE((v_item->>'unit_price')::NUMERIC, 0);
            v_quantity := COALESCE((v_item->>'quantity')::NUMERIC, 1);
            IF v_unit_price < 0 OR v_quantity < 0 THEN
                RAISE EXCEPTION 'Đơn giá và số lượng hạng mục hóa đơn không được mang giá trị âm.'
                    USING ERRCODE = '22023';
            END IF;
            v_subtotal := ROUND(v_unit_price * v_quantity, 2);
            v_total_amount := v_total_amount + v_subtotal;

            INSERT INTO public.invoice_items (
                invoice_id, fee_type, unit_price, quantity, subtotal
            ) VALUES (
                v_invoice_id,
                v_item->>'fee_type',
                v_unit_price,
                v_quantity,
                v_subtotal
            );
        END LOOP;
    END IF;

    UPDATE public.invoices
    SET total_amount = v_total_amount, updated_at = now()
    WHERE id = v_invoice_id;

    RETURN v_invoice_id;
END;
$$;

REVOKE ALL ON FUNCTION public.create_invoice_with_items(UUID, VARCHAR, DATE, JSONB) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_invoice_with_items(UUID, VARCHAR, DATE, JSONB) TO authenticated, service_role;

-- 4.2 update_invoice_with_items: Kiểm tra quyền theo tòa nhà & cập nhật lại total_amount
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
    v_building_id UUID;
    v_item JSONB;
    v_unit_price NUMERIC(15,2);
    v_quantity NUMERIC(12,2);
    v_subtotal NUMERIC(15,2);
    v_total_amount NUMERIC(15,2) := 0;
BEGIN
    SELECT i.*, a.building_id INTO v_inv
    FROM public.invoices i
    JOIN public.apartments a ON a.id = i.apartment_id
    WHERE i.id = p_invoice_id
    FOR UPDATE OF i;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Hóa đơn không tồn tại: %', p_invoice_id;
    END IF;

    v_building_id := v_inv.building_id;
    IF NOT (
        COALESCE(auth.jwt() ->> 'role', '') = 'service_role'
        OR public.is_building_staff(v_building_id, ARRAY['admin', 'management', 'manager', 'owner', 'accountant'])
    ) THEN
        RAISE EXCEPTION 'Truy cập bị từ chối: Chỉ Ban Quản Lý hoặc Kế toán tòa nhà mới có quyền cập nhật hóa đơn.'
            USING ERRCODE = '42501';
    END IF;

    DELETE FROM public.invoice_items WHERE invoice_id = p_invoice_id;

    IF p_items IS NOT NULL AND jsonb_typeof(p_items) = 'array' AND jsonb_array_length(p_items) > 0 THEN
        FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
        LOOP
            v_unit_price := COALESCE((v_item->>'unit_price')::NUMERIC, 0);
            v_quantity := COALESCE((v_item->>'quantity')::NUMERIC, 1);
            IF v_unit_price < 0 OR v_quantity < 0 THEN
                RAISE EXCEPTION 'Đơn giá và số lượng hạng mục hóa đơn không được mang giá trị âm.'
                    USING ERRCODE = '22023';
            END IF;
            v_subtotal := ROUND(v_unit_price * v_quantity, 2);
            v_total_amount := v_total_amount + v_subtotal;

            INSERT INTO public.invoice_items (
                invoice_id, fee_type, unit_price, quantity, subtotal
            ) VALUES (
                p_invoice_id,
                v_item->>'fee_type',
                v_unit_price,
                v_quantity,
                v_subtotal
            );
        END LOOP;
    END IF;

    UPDATE public.invoices
    SET period = p_period,
        due_date = p_due_date,
        apartment_id = COALESCE(p_apartment_id, apartment_id),
        total_amount = v_total_amount,
        status = CASE
            WHEN p_status IS NOT NULL THEN p_status::public.invoice_status
            ELSE status
        END,
        updated_at = NOW()
    WHERE id = p_invoice_id;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Cập nhật hóa đơn và các hạng mục chi phí thành công',
        'invoice_id', p_invoice_id,
        'total_amount', v_total_amount
    );
END;
$$;

REVOKE ALL ON FUNCTION public.update_invoice_with_items(UUID, VARCHAR, DATE, JSONB, UUID, VARCHAR) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.update_invoice_with_items(UUID, VARCHAR, DATE, JSONB, UUID, VARCHAR) TO authenticated, service_role;

-- 4.3 [P0-C1] Siết chặt admin_create_user, admin_update_user_profile, admin_toggle_user_status, admin_unlink_apartment
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
SET search_path = public, auth, extensions, pg_catalog
AS $$
DECLARE
    v_new_user_id UUID := gen_random_uuid();
    v_pwd TEXT;
    v_caller_role TEXT;
    v_apt_building_id UUID;
BEGIN
    IF NOT (COALESCE(auth.jwt() ->> 'role', '') = 'service_role') THEN
        IF NOT public.is_aal2_if_mfa_enrolled() THEN
            RAISE EXCEPTION 'Yêu cầu xác thực hai yếu tố (MFA/AAL2) trước khi tạo tài khoản.' USING ERRCODE = '42501';
        END IF;

        SELECT role::TEXT INTO v_caller_role
        FROM public.users
        WHERE id = auth.uid() AND is_active = true AND is_locked = false;

        IF v_caller_role NOT IN ('admin', 'management') THEN
            RAISE EXCEPTION 'Chỉ Quản trị viên hoặc Ban Quản Lý mới có quyền tạo tài khoản mới.' USING ERRCODE = '42501';
        END IF;

        IF LOWER(TRIM(COALESCE(p_role, 'resident'))) = 'admin' AND v_caller_role != 'admin' THEN
            RAISE EXCEPTION 'Chỉ Super Admin mới có quyền tạo tài khoản vai trò Admin.' USING ERRCODE = '42501';
        END IF;

        IF p_apartment_id IS NOT NULL AND v_caller_role != 'admin' THEN
            SELECT building_id INTO v_apt_building_id FROM public.apartments WHERE id = p_apartment_id;
            IF NOT public.is_building_staff(v_apt_building_id, ARRAY['admin', 'management', 'manager', 'owner']) THEN
                RAISE EXCEPTION 'Bạn không có quyền gắn cư dân vào căn hộ thuộc tòa nhà khác.' USING ERRCODE = '42501';
            END IF;
        END IF;
    END IF;

    p_email := LOWER(TRIM(p_email));
    IF p_email IS NULL OR p_email = '' THEN
        RAISE EXCEPTION 'Email không được để trống';
    END IF;

    IF EXISTS (SELECT 1 FROM auth.users WHERE email = p_email) THEN
        RAISE EXCEPTION 'Email % đã tồn tại trong hệ thống', p_email;
    END IF;

    v_pwd := COALESCE(NULLIF(TRIM(p_password), ''), encode(gen_random_bytes(12), 'base64'));

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
        INSERT INTO public.residents_apartments (user_id, apartment_id, relation_role)
        VALUES (v_new_user_id, p_apartment_id, COALESCE(p_relation_role, 'owner')::public.apartment_relation_role)
        ON CONFLICT DO NOTHING;
    END IF;

    INSERT INTO public.role_change_log (target_user_id, old_role, new_role, changed_by, changed_at)
    VALUES (v_new_user_id, p_role::public.user_role, p_role::public.user_role, auth.uid(), NOW());

    RETURN jsonb_build_object(
        'success', true,
        'user_id', v_new_user_id,
        'email', p_email,
        'message', 'Tạo tài khoản người dùng thành công'
    );
END;
$$;

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
    IF NOT (COALESCE(auth.jwt() ->> 'role', '') = 'service_role' OR public.is_super_admin()) THEN
        IF p_target_user_id = auth.uid() AND p_role IS NOT NULL THEN
            RAISE EXCEPTION 'Không được phép tự nâng quyền hoặc thay đổi vai trò của chính bạn.' USING ERRCODE = '42501';
        END IF;

        IF NOT public.can_manage_target_user(p_target_user_id) THEN
            RAISE EXCEPTION 'Bạn không có quyền quản trị hồ sơ người dùng này.' USING ERRCODE = '42501';
        END IF;

        IF p_role IS NOT NULL AND LOWER(TRIM(p_role)) = 'admin' THEN
            RAISE EXCEPTION 'Chỉ Super Admin mới có quyền cấp vai trò Admin.' USING ERRCODE = '42501';
        END IF;
    END IF;

    SELECT role INTO v_old_role FROM public.users WHERE id = p_target_user_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Không tìm thấy người dùng với ID: %', p_target_user_id;
    END IF;

    v_new_role := COALESCE(NULLIF(TRIM(p_role), '')::public.user_role, v_old_role);

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

    IF v_new_role IS DISTINCT FROM v_old_role THEN
        INSERT INTO public.role_change_log (target_user_id, old_role, new_role, changed_by, changed_at)
        VALUES (p_target_user_id, v_old_role, v_new_role, auth.uid(), NOW());
    END IF;

    RETURN jsonb_build_object('success', true, 'message', 'Cập nhật thông tin hồ sơ thành công');
END;
$$;

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
    IF p_target_user_id = auth.uid() THEN
        RAISE EXCEPTION 'Không thể tự khóa hoặc vô hiệu hóa tài khoản quản trị của chính bạn';
    END IF;

    IF NOT (COALESCE(auth.jwt() ->> 'role', '') = 'service_role' OR public.is_super_admin() OR public.can_manage_target_user(p_target_user_id)) THEN
        RAISE EXCEPTION 'Bạn không có quyền thay đổi trạng thái tài khoản này.' USING ERRCODE = '42501';
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

    RETURN jsonb_build_object('success', true, 'action', p_action, 'message', 'Đã cập nhật trạng thái tài khoản thành công');
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_unlink_apartment(
    p_user_id UUID,
    p_apartment_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_building_id UUID;
BEGIN
    SELECT building_id INTO v_building_id FROM public.apartments WHERE id = p_apartment_id;
    IF NOT (COALESCE(auth.jwt() ->> 'role', '') = 'service_role' OR public.is_building_staff(v_building_id, ARRAY['admin', 'management', 'manager', 'owner'])) THEN
        RAISE EXCEPTION 'Bạn không có quyền quản trị để gỡ liên kết căn hộ thuộc tòa nhà này.' USING ERRCODE = '42501';
    END IF;

    DELETE FROM public.residents_apartments
    WHERE user_id = p_user_id AND apartment_id = p_apartment_id;

    RETURN jsonb_build_object('success', true, 'message', 'Đã gỡ liên kết căn hộ thành công');
END;
$$;

-- 4.4 [P0-C5] Sửa import_apartments_batch dùng ON CONFLICT (building_id, code) & kiểm tra quyền tòa nhà
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
    v_apt JSONB;
    v_code TEXT;
    v_area NUMERIC;
    v_is_empty BOOLEAN;
    v_success_count INT := 0;
    v_imported_codes JSONB := '[]'::jsonb;
BEGIN
    IF p_building_id IS NULL THEN
        RAISE EXCEPTION 'Thiếu mã tòa nhà (p_building_id).' USING ERRCODE = '22023';
    END IF;

    IF NOT (
        COALESCE(auth.jwt() ->> 'role', '') = 'service_role'
        OR public.is_building_staff(p_building_id, ARRAY['admin', 'management', 'manager', 'owner'])
    ) THEN
        RAISE EXCEPTION 'Truy cập bị từ chối: Bạn không có quyền nhập căn hộ cho tòa nhà này.'
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
            ON CONFLICT (building_id, code) DO UPDATE
            SET area = EXCLUDED.area,
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

-- 4.5 [P0-C5] Sửa get_financial_aging_report & generate_resident_activation_codes (cột role_delegations & tenant scope)
CREATE OR REPLACE FUNCTION public.get_financial_aging_report(
    p_building_id UUID DEFAULT NULL,
    p_period TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_calling_user_id UUID := auth.uid();
    v_is_service BOOLEAN := (COALESCE(auth.jwt() ->> 'role', '') = 'service_role');
    v_is_authorized BOOLEAN := FALSE;
    v_result JSONB;
BEGIN
    IF NOT v_is_service THEN
        IF p_building_id IS NOT NULL THEN
            v_is_authorized := public.is_building_staff(p_building_id, ARRAY['admin', 'management', 'manager', 'owner', 'accountant']);
        ELSE
            v_is_authorized := public.is_super_admin() OR EXISTS (
                SELECT 1 FROM public.users
                WHERE id = v_calling_user_id AND role IN ('admin', 'management', 'accountant')
                  AND is_active = true AND is_locked = false
            ) OR EXISTS (
                SELECT 1 FROM public.role_delegations
                WHERE delegate_id = v_calling_user_id
                  AND is_revoked = FALSE
                  AND starts_at <= CURRENT_TIMESTAMP
                  AND ends_at >= CURRENT_TIMESTAMP
                  AND delegated_role IN ('admin', 'management', 'accountant')
            );
        END IF;

        IF NOT v_is_authorized THEN
            RAISE EXCEPTION 'Truy cập bị từ chối: Chỉ Ban Quản Lý hoặc Kế toán mới có quyền xem báo cáo tài chính.'
                USING ERRCODE = '42501';
        END IF;
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
        WHERE i.status != 'cancelled'
          AND (p_period IS NULL OR i.period = p_period)
          AND (p_building_id IS NULL OR a.building_id = p_building_id)
          AND (v_is_service OR a.building_id IN (SELECT public.get_user_accessible_buildings(v_calling_user_id)))
    ),
    summary AS (
        SELECT
            COALESCE(SUM(total_amount), 0) AS total_billed,
            COALESCE(SUM(CASE WHEN status = 'paid' THEN total_amount ELSE 0 END), 0) AS actual_collected,
            COALESCE(SUM(CASE WHEN status != 'paid' THEN total_amount ELSE 0 END), 0) AS total_outstanding,
            COUNT(*) AS total_invoice_count,
            COUNT(CASE WHEN status = 'paid' THEN 1 END) AS paid_invoice_count,
            COUNT(CASE WHEN status != 'paid' THEN 1 END) AS unpaid_invoice_count,
            ROUND(COALESCE(SUM(CASE WHEN status = 'paid' THEN total_amount ELSE 0 END) * 100.0 / NULLIF(SUM(total_amount), 0), 0), 1) AS collection_rate
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
            ROUND(COALESCE(SUM(CASE WHEN status = 'paid' THEN total_amount ELSE 0 END) * 100.0 / NULLIF(SUM(total_amount), 0), 0), 1) AS rate
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

CREATE OR REPLACE FUNCTION public.generate_resident_activation_codes(p_building_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_catalog
AS $$
DECLARE
    v_calling_user_id UUID := auth.uid();
    v_is_service BOOLEAN := (COALESCE(auth.jwt() ->> 'role', '') = 'service_role');
    v_count INT := 0;
    v_record RECORD;
    v_code TEXT;
    v_code_hash TEXT;
BEGIN
    IF NOT v_is_service THEN
        IF p_building_id IS NOT NULL THEN
            IF NOT public.is_building_staff(p_building_id, ARRAY['admin', 'management', 'manager', 'owner', 'staff', 'receptionist']) THEN
                RAISE EXCEPTION 'Truy cập bị từ chối: Bạn không có quyền tạo mã kích hoạt cho tòa nhà này.' USING ERRCODE = '42501';
            END IF;
        ELSIF NOT public.is_super_admin() THEN
            RAISE EXCEPTION 'Truy cập bị từ chối: Vui lòng chỉ định tòa nhà hợp lệ.' USING ERRCODE = '42501';
        END IF;
    END IF;

    FOR v_record IN
        SELECT ra.user_id, ra.apartment_id, u.phone
        FROM public.residents_apartments ra
        JOIN public.users u ON u.id = ra.user_id
        JOIN public.apartments a ON a.id = ra.apartment_id
        WHERE (p_building_id IS NULL OR a.building_id = p_building_id)
          AND (v_is_service OR a.building_id IN (SELECT public.get_user_accessible_buildings(v_calling_user_id)))
          AND COALESCE(u.is_active, FALSE) = FALSE
          AND NOT EXISTS (
              SELECT 1 FROM public.resident_activations act
              WHERE act.user_id = ra.user_id AND act.status IN ('pending', 'otp_sent', 'activated')
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

-- 4.6 [P0-C6] Vá validate_monthly_bulk_invoices & generate_valid_bulk_invoices
--     (cách ly building_id, tính sản lượng tiêu thụ thực tế thay vì chỉ số lũy kế, không tự thu 100k khi không có xe)
CREATE OR REPLACE FUNCTION public.validate_monthly_bulk_invoices(
  p_period text,
  p_mgmt_rate numeric DEFAULT 10000,
  p_electric_rate numeric DEFAULT 3500,
  p_water_rate numeric DEFAULT 18000
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_apt RECORD;
  v_total_scanned integer := 0;
  v_valid_count integer := 0;
  v_already_invoiced_count integer := 0;
  v_total_estimated_amount numeric := 0;
  v_valid_items jsonb := '[]'::jsonb;
  v_issues jsonb := '[]'::jsonb;
  v_sub_record RECORD;
  v_elec_consumed numeric;
  v_water_consumed numeric;
  v_mgmt_fee numeric;
  v_parking_fee numeric;
  v_elec_fee numeric;
  v_water_fee numeric;
  v_apt_total numeric;
  v_motorbike_count integer;
  v_car_count integer;
BEGIN
  IF NOT public.is_staff_or_management() THEN
    RAISE EXCEPTION 'Chỉ Ban Quản Lý mới có quyền tiền kiểm tra hóa đơn hàng loạt' USING ERRCODE = '42501';
  END IF;

  FOR v_apt IN
    SELECT id, code, area, building_id
    FROM public.apartments
    WHERE is_empty = false
      AND building_id IN (SELECT public.get_user_accessible_buildings(auth.uid()))
    ORDER BY code ASC
  LOOP
    v_total_scanned := v_total_scanned + 1;

    IF EXISTS (
      SELECT 1 FROM public.invoices
      WHERE apartment_id = v_apt.id AND period = p_period AND status != 'cancelled'
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

    -- Lấy sản lượng tiêu thụ thực tế từ phiếu chỉ số đã duyệt trong kỳ (mới - cũ)
    SELECT electric_consumed, water_consumed INTO v_sub_record
    FROM public.meter_reading_submissions
    WHERE apartment_id = v_apt.id AND period = p_period AND status = 'approved'
    ORDER BY created_at DESC
    LIMIT 1;

    IF FOUND THEN
      v_elec_consumed := GREATEST(0, COALESCE(v_sub_record.electric_consumed, 0));
      v_water_consumed := GREATEST(0, COALESCE(v_sub_record.water_consumed, 0));
    ELSE
      v_elec_consumed := 0;
      v_water_consumed := 0;
    END IF;

    v_mgmt_fee := ROUND(COALESCE(v_apt.area, 70) * p_mgmt_rate);

    SELECT
      COUNT(*) FILTER (WHERE vehicle_type IN ('motorbike', 'motorcycle')),
      COUNT(*) FILTER (WHERE vehicle_type = 'car')
    INTO v_motorbike_count, v_car_count
    FROM public.vehicles
    WHERE apartment_id = v_apt.id AND status = 'approved';

    -- Chỉ tính phí gửi xe khi căn hộ thực sự có phương tiện được duyệt
    v_parking_fee := (v_motorbike_count * 100000) + (v_car_count * 1200000);
    v_elec_fee := ROUND(v_elec_consumed * p_electric_rate);
    v_water_fee := ROUND(v_water_consumed * p_water_rate);
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
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_apt RECORD;
  v_sub_record RECORD;
  v_invoice_id uuid;
  v_invoices_created integer := 0;
  v_skipped_count integer := 0;
  v_total_amount numeric := 0;
  v_elec_consumed numeric;
  v_water_consumed numeric;
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
    RAISE EXCEPTION 'Chỉ Ban Quản Lý mới có quyền phát hành hóa đơn hàng loạt' USING ERRCODE = '42501';
  END IF;

  FOR v_apt IN
    SELECT id, code, area, building_id
    FROM public.apartments
    WHERE is_empty = false
      AND building_id IN (SELECT public.get_user_accessible_buildings(auth.uid()))
      AND (p_target_apartment_ids IS NULL OR id = ANY(p_target_apartment_ids))
    ORDER BY code ASC
  LOOP
    IF NOT public.is_building_staff(v_apt.building_id, ARRAY['admin', 'management', 'manager', 'owner', 'accountant']) THEN
      v_skipped_count := v_skipped_count + 1;
      CONTINUE;
    END IF;

    IF EXISTS (
      SELECT 1 FROM public.invoices
      WHERE apartment_id = v_apt.id AND period = p_period AND status != 'cancelled'
    ) THEN
      v_skipped_count := v_skipped_count + 1;
      CONTINUE;
    END IF;

    SELECT electric_consumed, water_consumed INTO v_sub_record
    FROM public.meter_reading_submissions
    WHERE apartment_id = v_apt.id AND period = p_period AND status = 'approved'
    ORDER BY created_at DESC
    LIMIT 1;

    v_elec_consumed := CASE WHEN FOUND THEN GREATEST(0, COALESCE(v_sub_record.electric_consumed, 0)) ELSE 0 END;
    v_water_consumed := CASE WHEN FOUND THEN GREATEST(0, COALESCE(v_sub_record.water_consumed, 0)) ELSE 0 END;

    v_mgmt_fee := ROUND(COALESCE(v_apt.area, 70) * p_mgmt_rate);

    SELECT
      COUNT(*) FILTER (WHERE vehicle_type IN ('motorbike', 'motorcycle')),
      COUNT(*) FILTER (WHERE vehicle_type = 'car')
    INTO v_motorbike_count, v_car_count
    FROM public.vehicles
    WHERE apartment_id = v_apt.id AND status = 'approved';

    v_parking_fee := (v_motorbike_count * 100000) + (v_car_count * 1200000);
    v_elec_fee := ROUND(v_elec_consumed * p_electric_rate);
    v_water_fee := ROUND(v_water_consumed * p_water_rate);
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
        (v_invoice_id, 'Tiền điện sinh hoạt', p_electric_rate, v_elec_consumed, v_elec_fee),
        (v_invoice_id, 'Tiền nước sinh hoạt', p_water_rate, v_water_consumed, v_water_fee);

      IF v_parking_fee > 0 THEN
        INSERT INTO public.invoice_items (invoice_id, fee_type, unit_price, quantity, subtotal)
        VALUES (v_invoice_id, 'Phí gửi xe phương tiện', v_parking_fee, 1, v_parking_fee);
      END IF;

      v_invoices_created := v_invoices_created + 1;
      v_total_amount := v_total_amount + v_apt_total;

      FOR v_user IN
        SELECT user_id FROM public.residents_apartments WHERE apartment_id = v_apt.id AND COALESCE(status, 'active') = 'active'
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
SET search_path = public, pg_catalog
AS $$
BEGIN
  RETURN public.generate_valid_bulk_invoices(p_period, p_due_date, NULL, p_mgmt_rate, p_electric_rate, p_water_rate);
END;
$$;

-- ==============================================================================
-- PHẦN 5: TOÀN VẸN THANH TOÁN SEPAY / VNPAY & ĐỐI SOÁT NGUYÊN TỬ [P0-C4, P0-C5, P2-M4]
-- ==============================================================================

-- 5.1 Hàm phụ trợ tự động ghi Có tiền nộp thừa (OVERPAID) vào Sổ cái công nợ căn hộ
CREATE OR REPLACE FUNCTION public.fn_credit_overpayment_to_ledger(
    p_building_id UUID,
    p_apartment_id UUID,
    p_invoice_id UUID,
    p_period TEXT,
    p_excess_amount NUMERIC(15,2),
    p_reference_code TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_last_balance NUMERIC(15,2) := 0;
    v_new_balance NUMERIC(15,2);
    v_entry_code TEXT;
    v_norm_period VARCHAR(7);
BEGIN
    IF p_excess_amount <= 0 OR p_building_id IS NULL OR p_apartment_id IS NULL THEN
        RETURN;
    END IF;

    v_norm_period := CASE
        WHEN p_period ~ '^\d{4}-\d{2}$' THEN p_period
        ELSE to_char(now() AT TIME ZONE 'Asia/Ho_Chi_Minh', 'YYYY-MM')
    END;

    SELECT COALESCE(balance_after, 0) INTO v_last_balance
    FROM public.apartment_ledger_entries
    WHERE apartment_id = p_apartment_id
    ORDER BY created_at DESC
    LIMIT 1;

    -- Số dư nợ giảm đi (âm = dư Có cấn trừ kỳ sau)
    v_new_balance := COALESCE(v_last_balance, 0) - p_excess_amount;
    v_entry_code := 'LE-' || replace(v_norm_period, '-', '') || '-' || upper(substring(gen_random_uuid()::text, 1, 6));

    INSERT INTO public.apartment_ledger_entries (
        building_id, apartment_id, entry_code, entry_type, amount,
        balance_after, period, reference_type, reference_id, description
    ) VALUES (
        p_building_id,
        p_apartment_id,
        v_entry_code,
        'CREDIT',
        p_excess_amount,
        v_new_balance,
        v_norm_period,
        'PAYMENT',
        p_invoice_id,
        'Tiền nộp thừa tự động ghi Có (cấn trừ kỳ sau) - Mã GD: ' || COALESCE(p_reference_code, '')
    );
EXCEPTION WHEN OTHERS THEN
    -- Không làm hỏng giao dịch gạch nợ chính nếu kỳ kế toán đã đóng sổ; kế toán sẽ xử lý đối soát
    RAISE NOTICE 'Bỏ qua hạch toán tiền thừa tự động: %', SQLERRM;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_credit_overpayment_to_ledger(UUID, UUID, UUID, TEXT, NUMERIC, TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_credit_overpayment_to_ledger(UUID, UUID, UUID, TEXT, NUMERIC, TEXT) TO service_role;

-- 5.2 [P0-C4, P0-C5] Nâng cấp process_sepay_webhook (vá enum 'manager' -> 'management', cộng dồn trả góp, tự động ghi Có tiền thừa, chặn hóa đơn cancelled)
CREATE OR REPLACE FUNCTION public.process_sepay_webhook(
    p_payload JSONB,
    p_api_key TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_sepay_id TEXT;
    v_transfer_type TEXT;
    v_content TEXT;
    v_amount NUMERIC(15,2);
    v_invoice RECORD;
    v_user_id UUID;
    v_receipt_number TEXT;
    v_txn_code TEXT;
    v_now TIMESTAMPTZ := now();
    v_expected_key TEXT;
    v_account_number TEXT;
    v_target_building_id UUID;
    v_prior_paid NUMERIC(15,2) := 0;
    v_cumulative_paid NUMERIC(15,2) := 0;
    v_excess NUMERIC(15,2) := 0;
BEGIN
    IF p_api_key IS NULL OR trim(p_api_key) = '' THEN
        INSERT INTO public.audit_logs (actor_id, action, entity_name, details, created_at)
        VALUES (NULL, 'SEPAY_WEBHOOK_UNAUTHORIZED', 'invoices',
            jsonb_build_object('reason', 'Thiếu API Key xác thực Webhook SePay', 'severity', 'CRITICAL', 'timestamp', v_now), v_now);
        RAISE EXCEPTION '401 Unauthorized: p_api_key không được cung cấp hoặc để trống.';
    END IF;

    v_transfer_type := LOWER(COALESCE(p_payload->>'transferType', 'in'));
    IF v_transfer_type = 'out' THEN
        RETURN jsonb_build_object('success', true, 'status', 'IGNORED_OUTGOING', 'message', 'Giao dịch chi tiền ra khỏi tài khoản, bỏ qua an toàn.');
    END IF;

    v_sepay_id := COALESCE(
        p_payload->>'id',
        p_payload->>'referenceCode',
        p_payload->>'gateway_transaction_id',
        p_payload->>'transaction_id'
    );

    IF v_sepay_id IS NULL OR trim(v_sepay_id) = '' THEN
        RAISE EXCEPTION 'Webhook payload SePay thiếu thông tin định danh giao dịch (id hoặc referenceCode)';
    END IF;

    v_txn_code := 'TXN_' || v_sepay_id || '_' || upper(substring(gen_random_uuid()::text, 1, 8));

    -- Kiểm tra chống lặp Idempotency cho mọi trạng thái đã xử lý
    IF EXISTS (
        SELECT 1 FROM public.payment_transactions
        WHERE idempotency_key = v_sepay_id
          AND status IN ('SUCCESS', 'PARTIAL_PAID', 'OVERPAID')
    ) THEN
        RETURN jsonb_build_object('success', true, 'status', 'DUPLICATE', 'message', 'Giao dịch SePay này đã được ghi nhận trước đó.');
    END IF;

    v_content := COALESCE(p_payload->>'content', p_payload->>'description', '');
    v_amount := COALESCE((p_payload->>'transferAmount')::NUMERIC, (p_payload->>'amount')::NUMERIC, 0.0);

    IF v_amount <= 0 THEN
        RAISE EXCEPTION 'Số tiền giao dịch phải lớn hơn 0.';
    END IF;

    SELECT i.*, a.building_id AS invoice_building_id
    INTO v_invoice
    FROM public.invoices i
    JOIN public.apartments a ON i.apartment_id = a.id
    WHERE (
        (i.payment_code IS NOT NULL AND i.payment_code != '' AND v_content ILIKE '%' || i.payment_code || '%')
        OR (i.lookup_code IS NOT NULL AND i.lookup_code != '' AND v_content ILIKE '%' || i.lookup_code || '%')
        OR (p_payload->>'invoice_id' IS NOT NULL AND i.id::text = p_payload->>'invoice_id')
    )
    ORDER BY i.created_at DESC
    LIMIT 1
    FOR UPDATE OF i;

    IF FOUND THEN
        SELECT sepay_api_key INTO v_expected_key
        FROM public.building_payment_secrets
        WHERE building_id = v_invoice.invoice_building_id;

        IF v_expected_key IS NULL OR trim(p_api_key) != trim(v_expected_key) THEN
            INSERT INTO public.audit_logs (actor_id, building_id, action, entity_name, entity_id, details, created_at)
            VALUES (NULL, v_invoice.invoice_building_id, 'SEPAY_WEBHOOK_CROSS_TENANT_UNAUTHORIZED', 'invoices', v_invoice.id,
                jsonb_build_object('reason', 'API Key không khớp với cấu hình SePay của tòa nhà chứa hóa đơn', 'severity', 'CRITICAL', 'timestamp', v_now), v_now);
            RAISE EXCEPTION '401 Unauthorized: API Key không khớp với cấu hình SePay của tòa nhà chứa hóa đơn.';
        END IF;
    ELSE
        v_account_number := COALESCE(p_payload->>'accountNumber', p_payload->>'bank_account_number', p_payload->>'subAccount');

        SELECT building_id INTO v_target_building_id
        FROM public.building_payment_configs
        WHERE is_active = true
          AND v_account_number IS NOT NULL
          AND replace(bank_account_number, ' ', '') = replace(v_account_number, ' ', '')
        LIMIT 1;

        IF v_target_building_id IS NOT NULL THEN
            SELECT sepay_api_key INTO v_expected_key
            FROM public.building_payment_secrets
            WHERE building_id = v_target_building_id;
        END IF;

        IF v_target_building_id IS NULL OR v_expected_key IS NULL OR trim(p_api_key) != trim(v_expected_key) THEN
            INSERT INTO public.audit_logs (actor_id, action, entity_name, details, created_at)
            VALUES (NULL, 'SEPAY_WEBHOOK_UNAUTHORIZED', 'invoices',
                jsonb_build_object('reason', 'API Key không hợp lệ hoặc số tài khoản ngân hàng không thuộc tòa nhà nào', 'severity', 'CRITICAL', 'timestamp', v_now), v_now);
            RAISE EXCEPTION '401 Unauthorized: API Key không hợp lệ hoặc số tài khoản ngân hàng không khớp.';
        END IF;

        -- Vá lỗi enum: dùng 'management' thay cho 'manager'
        SELECT id INTO v_user_id FROM public.users WHERE role IN ('admin', 'management') LIMIT 1;

        INSERT INTO public.payment_transactions (
            reference_id, user_id, payment_type, payment_method,
            amount, status, idempotency_key, failure_reason, metadata, created_at, updated_at,
            type, transaction_code
        ) VALUES (
            gen_random_uuid(), v_user_id, 'INVOICE', 'VIETQR',
            v_amount, 'UNMATCHED', v_sepay_id,
            'Không tìm thấy hóa đơn khớp với nội dung chuyển khoản SePay: ' || v_content,
            p_payload, v_now, v_now, 'INVOICE', v_txn_code
        );

        RETURN jsonb_build_object(
            'success', true,
            'status', 'UNMATCHED',
            'message', 'Không tìm thấy hóa đơn khớp với nội dung chuyển khoản SePay. Giao dịch được lưu để kế toán đối soát.'
        );
    END IF;

    SELECT user_id INTO v_user_id
    FROM public.residents_apartments
    WHERE apartment_id = v_invoice.apartment_id AND COALESCE(status, 'active') = 'active'
    LIMIT 1;

    IF v_user_id IS NULL THEN
        SELECT id INTO v_user_id FROM public.users WHERE role IN ('admin', 'management') LIMIT 1;
    END IF;

    v_receipt_number := 'REC-' || to_char(v_now AT TIME ZONE 'Asia/Ho_Chi_Minh', 'YYYYMMDD') || '-' || upper(substring(gen_random_uuid()::text, 1, 6));

    -- Chặn gạch nợ hóa đơn đã bị hủy (cancelled)
    IF v_invoice.status = 'cancelled' THEN
        INSERT INTO public.payment_transactions (
            reference_id, invoice_id, user_id, apartment_id, payment_type,
            payment_method, amount, status, receipt_number, idempotency_key, failure_reason, metadata, created_at, updated_at,
            type, transaction_code
        ) VALUES (
            v_invoice.id, v_invoice.id, v_user_id, v_invoice.apartment_id, 'INVOICE',
            'VIETQR', v_amount, 'UNMATCHED', v_receipt_number, v_sepay_id,
            'Hóa đơn đã bị hủy trước khi nhận chuyển khoản SePay', p_payload, v_now, v_now, 'INVOICE', v_txn_code
        );

        RETURN jsonb_build_object(
            'success', true,
            'status', 'UNMATCHED',
            'invoice_id', v_invoice.id,
            'message', 'Hóa đơn đã bị hủy. Giao dịch được ghi nhận để kế toán đối soát hoàn tiền.'
        );
    END IF;

    -- Hóa đơn đã thanh toán trước đó -> OVERPAID + Tự động ghi Có sổ cái
    IF v_invoice.status = 'paid' THEN
        INSERT INTO public.payment_transactions (
            reference_id, invoice_id, user_id, apartment_id, payment_type,
            payment_method, amount, status, receipt_number, idempotency_key, metadata, created_at, updated_at,
            type, transaction_code
        ) VALUES (
            v_invoice.id, v_invoice.id, v_user_id, v_invoice.apartment_id, 'INVOICE',
            'VIETQR', v_amount, 'OVERPAID', v_receipt_number, v_sepay_id, p_payload, v_now, v_now,
            'INVOICE', v_txn_code
        );

        PERFORM public.fn_credit_overpayment_to_ledger(
            v_invoice.invoice_building_id, v_invoice.apartment_id, v_invoice.id, v_invoice.period, v_amount, v_sepay_id
        );

        RETURN jsonb_build_object(
            'success', true,
            'status', 'OVERPAID',
            'invoice_id', v_invoice.id,
            'credited_excess', v_amount,
            'message', 'Hóa đơn đã thanh toán trước đó. Số tiền nộp thừa đã tự động ghi Có vào sổ cái căn hộ.'
        );
    END IF;

    -- Tính tổng tiền đã thu cộng dồn (hỗ trợ trả nhiều lần qua SePay/VNPay)
    SELECT COALESCE(SUM(amount), 0) INTO v_prior_paid
    FROM public.payment_transactions
    WHERE invoice_id = v_invoice.id
      AND status IN ('SUCCESS', 'PARTIAL_PAID');

    v_cumulative_paid := v_prior_paid + v_amount;

    IF v_cumulative_paid >= v_invoice.total_amount THEN
        UPDATE public.invoices
        SET status = 'paid',
            paid_at = v_now,
            payment_method = 'vietqr',
            payment_reference = v_sepay_id,
            receipt_number = v_receipt_number,
            updated_at = v_now
        WHERE id = v_invoice.id;

        INSERT INTO public.payment_transactions (
            reference_id, invoice_id, user_id, apartment_id, payment_type,
            payment_method, amount, status, receipt_number, idempotency_key, metadata, created_at, updated_at,
            type, transaction_code
        ) VALUES (
            v_invoice.id, v_invoice.id, v_user_id, v_invoice.apartment_id, 'INVOICE',
            'VIETQR', v_amount, 'SUCCESS', v_receipt_number, v_sepay_id, p_payload, v_now, v_now,
            'INVOICE', v_txn_code
        );

        v_excess := v_cumulative_paid - v_invoice.total_amount;
        IF v_excess > 0 THEN
            PERFORM public.fn_credit_overpayment_to_ledger(
                v_invoice.invoice_building_id, v_invoice.apartment_id, v_invoice.id, v_invoice.period, v_excess, v_sepay_id
            );
        END IF;

        RETURN jsonb_build_object(
            'success', true,
            'status', 'SUCCESS',
            'invoice_id', v_invoice.id,
            'receipt_number', v_receipt_number,
            'credited_excess', v_excess,
            'message', 'Gạch nợ hóa đơn tự động qua SePay Webhook thành công.'
        );
    ELSE
        -- Nộp thiếu tiền -> Ghi nhận PARTIAL_PAID để cộng dồn chính xác cho lần thanh toán tiếp theo
        INSERT INTO public.payment_transactions (
            reference_id, invoice_id, user_id, apartment_id, payment_type,
            payment_method, amount, status, receipt_number, idempotency_key, metadata, created_at, updated_at,
            type, transaction_code
        ) VALUES (
            v_invoice.id, v_invoice.id, v_user_id, v_invoice.apartment_id, 'INVOICE',
            'VIETQR', v_amount, 'PARTIAL_PAID', v_receipt_number, v_sepay_id, p_payload, v_now, v_now,
            'INVOICE', v_txn_code
        );

        RETURN jsonb_build_object(
            'success', true,
            'status', 'PARTIAL_PAID',
            'invoice_id', v_invoice.id,
            'received_amount', v_amount,
            'cumulative_paid', v_cumulative_paid,
            'expected_amount', v_invoice.total_amount,
            'message', 'Đã ghi nhận thanh toán một phần qua SePay.'
        );
    END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.process_sepay_webhook(JSONB, TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.process_sepay_webhook(JSONB, TEXT) TO service_role;

-- 5.3 [P0-C4] Nâng cấp process_bank_payment_webhook (VNPay IPN):
--     Chặn Cross-Tenant Spoofing qua verified_building_id, cộng dồn trả góp, tự động ghi Có tiền thừa
CREATE OR REPLACE FUNCTION public.process_bank_payment_webhook(
    p_payload JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_gateway_tx_id TEXT;
    v_content TEXT;
    v_payment_code TEXT;
    v_verified_building_id UUID;
    v_amount NUMERIC(15,2);
    v_invoice RECORD;
    v_user_id UUID;
    v_receipt_number TEXT;
    v_txn_code TEXT;
    v_gateway_method TEXT;
    v_now TIMESTAMPTZ := now();
    v_prior_paid NUMERIC(15,2) := 0;
    v_cumulative_paid NUMERIC(15,2) := 0;
    v_excess NUMERIC(15,2) := 0;
BEGIN
    v_gateway_tx_id := COALESCE(
        p_payload->>'gateway_transaction_id',
        p_payload->>'transaction_id',
        p_payload->>'reference',
        p_payload->>'id'
    );

    IF v_gateway_tx_id IS NULL OR trim(v_gateway_tx_id) = '' THEN
        RAISE EXCEPTION 'Webhook payload thiếu thông tin mã giao dịch ngân hàng (gateway_transaction_id)';
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.payment_transactions
        WHERE idempotency_key = v_gateway_tx_id
          AND status IN ('SUCCESS', 'PARTIAL_PAID', 'OVERPAID')
    ) THEN
        RETURN jsonb_build_object('success', true, 'status', 'DUPLICATE', 'message', 'Giao dịch này đã được ghi nhận trước đó.');
    END IF;

    v_content := COALESCE(p_payload->>'content', p_payload->>'description', '');
    -- Hỗ trợ vnp_TxnRef dạng <payment_code>_<timestamp> bằng cách tách phần mã thanh toán gốc
    v_payment_code := split_part(COALESCE(p_payload->>'payment_code', ''), '_', 1);
    v_amount := COALESCE((p_payload->>'amount')::NUMERIC, 0.0);
    v_gateway_method := UPPER(COALESCE(NULLIF(p_payload->>'raw_gateway', ''), 'VIETQR'));
    v_txn_code := 'TXN_' || v_gateway_tx_id || '_' || upper(substring(gen_random_uuid()::text, 1, 6));

    IF NULLIF(p_payload->>'verified_building_id', '') IS NOT NULL THEN
        v_verified_building_id := (p_payload->>'verified_building_id')::UUID;
    END IF;

    IF v_amount <= 0 THEN
        RAISE EXCEPTION 'Số tiền giao dịch phải lớn hơn 0.';
    END IF;

    SELECT i.*, a.building_id AS invoice_building_id
    INTO v_invoice
    FROM public.invoices i
    JOIN public.apartments a ON a.id = i.apartment_id
    WHERE (
        (v_payment_code != '' AND i.payment_code = v_payment_code)
        OR (i.payment_code IS NOT NULL AND i.payment_code != '' AND v_content ILIKE '%' || i.payment_code || '%')
        OR (p_payload->>'invoice_id' IS NOT NULL AND i.id::text = p_payload->>'invoice_id')
    )
    ORDER BY i.created_at DESC
    LIMIT 1
    FOR UPDATE OF i;

    IF NOT FOUND THEN
        SELECT id INTO v_user_id FROM public.users WHERE role IN ('admin', 'management') LIMIT 1;
        INSERT INTO public.payment_transactions (
            reference_id, user_id, payment_type, payment_method,
            amount, status, idempotency_key, failure_reason, metadata, created_at, updated_at,
            type, transaction_code
        ) VALUES (
            gen_random_uuid(), v_user_id, 'INVOICE', v_gateway_method,
            v_amount, 'UNMATCHED', v_gateway_tx_id,
            'Không tìm thấy hóa đơn khớp với nội dung: ' || v_content,
            p_payload, v_now, v_now, 'INVOICE', v_txn_code
        );
        RETURN jsonb_build_object('success', false, 'status', 'UNMATCHED', 'message', 'Không tìm thấy hóa đơn khớp.');
    END IF;

    -- [P0-C4] Khóa Cross-Tenant VNPay IPN Spoofing
    IF v_verified_building_id IS NOT NULL AND v_invoice.invoice_building_id IS DISTINCT FROM v_verified_building_id THEN
        INSERT INTO public.audit_logs (actor_id, building_id, action, entity_name, entity_id, details, created_at)
        VALUES (NULL, v_invoice.invoice_building_id, 'VNPAY_IPN_CROSS_TENANT_BLOCKED', 'invoices', v_invoice.id,
            jsonb_build_object('verified_building_id', v_verified_building_id, 'invoice_building_id', v_invoice.invoice_building_id, 'gateway_tx_id', v_gateway_tx_id), v_now);
        RAISE EXCEPTION '403 Forbidden: Cổng thanh toán (TMN Code) không thuộc tòa nhà sở hữu hóa đơn này.';
    END IF;

    SELECT user_id INTO v_user_id
    FROM public.residents_apartments
    WHERE apartment_id = v_invoice.apartment_id AND COALESCE(status, 'active') = 'active'
    LIMIT 1;
    IF v_user_id IS NULL THEN
        SELECT id INTO v_user_id FROM public.users WHERE role IN ('admin', 'management') LIMIT 1;
    END IF;

    v_receipt_number := 'REC-' || to_char(v_now AT TIME ZONE 'Asia/Ho_Chi_Minh', 'YYYYMMDD') || '-' || upper(substring(gen_random_uuid()::text, 1, 6));

    IF v_invoice.status = 'cancelled' THEN
        INSERT INTO public.payment_transactions (
            reference_id, invoice_id, user_id, apartment_id, payment_type,
            payment_method, amount, status, receipt_number, idempotency_key, failure_reason, metadata, created_at, updated_at,
            type, transaction_code
        ) VALUES (
            v_invoice.id, v_invoice.id, v_user_id, v_invoice.apartment_id, 'INVOICE',
            v_gateway_method, v_amount, 'UNMATCHED', v_receipt_number, v_gateway_tx_id,
            'Hóa đơn đã bị hủy trước khi nhận IPN', p_payload, v_now, v_now, 'INVOICE', v_txn_code
        );
        RETURN jsonb_build_object('success', false, 'status', 'UNMATCHED', 'message', 'Hóa đơn đã bị hủy, không thể gạch nợ.');
    END IF;

    IF v_invoice.status = 'paid' THEN
        INSERT INTO public.payment_transactions (
            reference_id, invoice_id, user_id, apartment_id, payment_type,
            payment_method, amount, status, receipt_number, idempotency_key, metadata, created_at, updated_at,
            type, transaction_code
        ) VALUES (
            v_invoice.id, v_invoice.id, v_user_id, v_invoice.apartment_id, 'INVOICE',
            v_gateway_method, v_amount, 'OVERPAID', v_receipt_number, v_gateway_tx_id, p_payload, v_now, v_now,
            'INVOICE', v_txn_code
        );

        PERFORM public.fn_credit_overpayment_to_ledger(
            v_invoice.invoice_building_id, v_invoice.apartment_id, v_invoice.id, v_invoice.period, v_amount, v_gateway_tx_id
        );

        RETURN jsonb_build_object('success', true, 'status', 'OVERPAID', 'invoice_id', v_invoice.id, 'credited_excess', v_amount,
            'message', 'Hóa đơn đã thanh toán trước đó. Phần tiền thừa đã tự động ghi Có vào sổ cái căn hộ.');
    END IF;

    -- Cộng dồn các khoản đã thanh toán trước đó (khắc phục lỗi treo hóa đơn khi trả nhiều lần)
    SELECT COALESCE(SUM(amount), 0) INTO v_prior_paid
    FROM public.payment_transactions
    WHERE invoice_id = v_invoice.id
      AND status IN ('SUCCESS', 'PARTIAL_PAID');

    v_cumulative_paid := v_prior_paid + v_amount;

    IF v_cumulative_paid >= v_invoice.total_amount THEN
        UPDATE public.invoices
        SET status = 'paid',
            paid_at = v_now,
            payment_method = LOWER(v_gateway_method),
            payment_reference = v_gateway_tx_id,
            receipt_number = v_receipt_number,
            updated_at = v_now
        WHERE id = v_invoice.id;

        INSERT INTO public.payment_transactions (
            reference_id, invoice_id, user_id, apartment_id, payment_type,
            payment_method, amount, status, receipt_number, idempotency_key, metadata, created_at, updated_at,
            type, transaction_code
        ) VALUES (
            v_invoice.id, v_invoice.id, v_user_id, v_invoice.apartment_id, 'INVOICE',
            v_gateway_method, v_amount, 'SUCCESS', v_receipt_number, v_gateway_tx_id, p_payload, v_now, v_now,
            'INVOICE', v_txn_code
        );

        v_excess := v_cumulative_paid - v_invoice.total_amount;
        IF v_excess > 0 THEN
            PERFORM public.fn_credit_overpayment_to_ledger(
                v_invoice.invoice_building_id, v_invoice.apartment_id, v_invoice.id, v_invoice.period, v_excess, v_gateway_tx_id
            );
        END IF;

        RETURN jsonb_build_object(
            'success', true, 'status', 'SUCCESS', 'invoice_id', v_invoice.id,
            'receipt_number', v_receipt_number, 'credited_excess', v_excess,
            'message', 'Gạch nợ hóa đơn thành công.'
        );
    ELSE
        INSERT INTO public.payment_transactions (
            reference_id, invoice_id, user_id, apartment_id, payment_type,
            payment_method, amount, status, idempotency_key, failure_reason, metadata, created_at, updated_at,
            type, transaction_code
        ) VALUES (
            v_invoice.id, v_invoice.id, v_user_id, v_invoice.apartment_id, 'INVOICE',
            v_gateway_method, v_amount, 'PARTIAL_PAID', v_gateway_tx_id,
            'Nộp một phần: tổng hóa đơn ' || v_invoice.total_amount || ', lũy kế đã nhận ' || v_cumulative_paid,
            p_payload, v_now, v_now, 'INVOICE', v_txn_code
        );

        RETURN jsonb_build_object(
            'success', true, 'status', 'PARTIAL_PAID', 'invoice_id', v_invoice.id,
            'cumulative_paid', v_cumulative_paid, 'expected_amount', v_invoice.total_amount,
            'message', 'Đã ghi nhận thanh toán một phần.'
        );
    END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.process_bank_payment_webhook(JSONB) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.process_bank_payment_webhook(JSONB) TO service_role;

-- 5.4 [P2-M4] RPC Đối soát giao dịch thủ công nguyên tử (ACID) thay thế 2 lệnh UPDATE rời rạc từ Client
CREATE OR REPLACE FUNCTION public.reconcile_unmatched_payment_transaction(
    p_transaction_id UUID,
    p_invoice_id UUID,
    p_note TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_tx RECORD;
    v_inv RECORD;
    v_prior_paid NUMERIC(15,2) := 0;
    v_cumulative NUMERIC(15,2) := 0;
    v_excess NUMERIC(15,2) := 0;
    v_now TIMESTAMPTZ := now();
BEGIN
    SELECT * INTO v_tx FROM public.payment_transactions WHERE id = p_transaction_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Không tìm thấy giao dịch cần đối soát.';
    END IF;

    IF v_tx.status NOT IN ('UNMATCHED', 'PENDING') THEN
        RAISE EXCEPTION 'Giao dịch này đã được đối soát hoặc hoàn tất trước đó (status=%).', v_tx.status;
    END IF;

    SELECT i.*, a.building_id AS invoice_building_id INTO v_inv
    FROM public.invoices i
    JOIN public.apartments a ON a.id = i.apartment_id
    WHERE i.id = p_invoice_id
    FOR UPDATE OF i;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Không tìm thấy hóa đơn mục tiêu.';
    END IF;

    IF NOT public.is_building_staff(v_inv.invoice_building_id, ARRAY['admin', 'management', 'manager', 'owner', 'accountant']) THEN
        RAISE EXCEPTION 'Truy cập bị từ chối: Chỉ Kế toán hoặc Ban Quản Lý tòa nhà mới có quyền đối soát giao dịch.'
            USING ERRCODE = '42501';
    END IF;

    IF v_inv.status IN ('paid', 'cancelled') THEN
        RAISE EXCEPTION 'Hóa đơn đang ở trạng thái % không thể ghép giao dịch.', v_inv.status;
    END IF;

    SELECT COALESCE(SUM(amount), 0) INTO v_prior_paid
    FROM public.payment_transactions
    WHERE invoice_id = p_invoice_id
      AND id != p_transaction_id
      AND status IN ('SUCCESS', 'PARTIAL_PAID');

    v_cumulative := v_prior_paid + COALESCE(v_tx.amount, 0);

    IF v_cumulative >= v_inv.total_amount THEN
        UPDATE public.invoices
        SET status = 'paid',
            paid_at = v_now,
            payment_method = COALESCE(LOWER(v_tx.payment_method), 'vietqr'),
            payment_reference = 'MANUAL_MATCH_' || p_transaction_id::text,
            updated_at = v_now
        WHERE id = p_invoice_id;

        UPDATE public.payment_transactions
        SET status = 'SUCCESS',
            invoice_id = p_invoice_id,
            apartment_id = v_inv.apartment_id,
            confirmed_by = auth.uid(),
            confirmed_at = v_now,
            metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object('reconcile_note', COALESCE(p_note, '')),
            updated_at = v_now
        WHERE id = p_transaction_id;

        v_excess := v_cumulative - v_inv.total_amount;
        IF v_excess > 0 THEN
            PERFORM public.fn_credit_overpayment_to_ledger(
                v_inv.invoice_building_id, v_inv.apartment_id, p_invoice_id, v_inv.period, v_excess, 'MANUAL_MATCH_' || p_transaction_id::text
            );
        END IF;

        RETURN jsonb_build_object('success', true, 'status', 'SUCCESS', 'credited_excess', v_excess, 'message', 'Đối soát và gạch nợ hóa đơn thành công.');
    ELSE
        UPDATE public.payment_transactions
        SET status = 'PARTIAL_PAID',
            invoice_id = p_invoice_id,
            apartment_id = v_inv.apartment_id,
            confirmed_by = auth.uid(),
            confirmed_at = v_now,
            metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object('reconcile_note', COALESCE(p_note, '')),
            updated_at = v_now
        WHERE id = p_transaction_id;

        RETURN jsonb_build_object('success', true, 'status', 'PARTIAL_PAID', 'cumulative_paid', v_cumulative, 'expected_amount', v_inv.total_amount,
            'message', 'Đã ghép giao dịch thanh toán một phần vào hóa đơn.');
    END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.reconcile_unmatched_payment_transaction(UUID, UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.reconcile_unmatched_payment_transaction(UUID, UUID, TEXT) TO authenticated, service_role;

-- ==============================================================================
-- PHẦN 6: HARDENING VIEW, BƯU KIỆN, VÉ KHÁCH, KIẾN NGHỊ, CHỈ SỐ & KÍCH HOẠT [P1-H1, P1-H2, P1-H3]
-- ==============================================================================

-- 6.1 [P1-H2] View v_parcels_secure chạy với security_invoker = true & KHÔNG lộ pickup_pin_hash
DROP VIEW IF EXISTS public.v_parcels_secure;
CREATE VIEW public.v_parcels_secure
WITH (security_invoker = true)
AS
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
    CASE
        WHEN auth.uid() IS NOT NULL AND EXISTS (
            SELECT 1 FROM public.residents_apartments ra
            WHERE ra.apartment_id = p.apartment_id
              AND ra.user_id = auth.uid()
              AND COALESCE(ra.status, 'active') = 'active'
        ) THEN p.pickup_pin
        ELSE '******'
    END AS pickup_pin,
    NULL::TEXT AS pickup_pin_hash,
    p.status,
    p.arrived_at,
    p.received_staff_id,
    p.collected_at,
    p.handover_staff_id,
    p.collected_by,
    p.created_at,
    p.updated_at
FROM public.parcels p;

REVOKE ALL ON public.v_parcels_secure FROM PUBLIC, anon;
GRANT SELECT ON public.v_parcels_secure TO authenticated;

-- 6.2 [P1-H1] Hardening check_in_visitor_pass, check_out_visitor_pass, collect_parcel
CREATE OR REPLACE FUNCTION public.check_in_visitor_pass(
    p_pass_code TEXT,
    p_guard_id UUID DEFAULT NULL,
    p_qr_payload TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_pass public.visitor_access_passes%ROWTYPE;
    v_building_id UUID;
    v_guard_id UUID := auth.uid();
BEGIN
    IF v_guard_id IS NULL THEN
        RAISE EXCEPTION 'Yêu cầu đăng nhập nhân sự bảo vệ/lễ tân.' USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_pass
    FROM public.visitor_access_passes
    WHERE pass_code = UPPER(TRIM(p_pass_code))
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Không tìm thấy vé khách với mã đã quét.');
    END IF;

    SELECT building_id INTO v_building_id FROM public.apartments WHERE id = v_pass.apartment_id;
    IF NOT public.is_building_staff(v_building_id) THEN
        RAISE EXCEPTION 'Truy cập bị từ chối: Chỉ nhân sự tòa nhà mới có quyền check-in vé khách.' USING ERRCODE = '42501';
    END IF;

    IF v_pass.status = 'checked_in' THEN
        RETURN jsonb_build_object('success', false, 'message', 'Cảnh báo bảo mật: Vé khách này đã được check-in trước đó.');
    END IF;
    IF v_pass.status = 'checked_out' THEN
        RETURN jsonb_build_object('success', false, 'message', 'Vé khách này đã check-out và không còn hiệu lực.');
    END IF;
    IF v_pass.status = 'cancelled' THEN
        RETURN jsonb_build_object('success', false, 'message', 'Vé khách này đã bị cư dân hủy bỏ.');
    END IF;
    IF v_pass.expected_departure IS NOT NULL AND timezone('utc'::text, now()) > v_pass.expected_departure THEN
        UPDATE public.visitor_access_passes SET status = 'expired', updated_at = now() WHERE id = v_pass.id;
        RETURN jsonb_build_object('success', false, 'message', 'Vé khách này đã quá hạn hiệu lực.');
    END IF;

    UPDATE public.visitor_access_passes
    SET status = 'checked_in', check_in_at = now(), check_in_guard_id = v_guard_id, updated_at = now()
    WHERE id = v_pass.id;

    RETURN jsonb_build_object(
        'success', true, 'message', 'Check-in thành công. Chào mừng khách viếng thăm!',
        'pass_code', v_pass.pass_code, 'visitor_name', v_pass.visitor_name, 'apartment_id', v_pass.apartment_id
    );
END;
$$;
REVOKE ALL ON FUNCTION public.check_in_visitor_pass(TEXT, UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.check_in_visitor_pass(TEXT, UUID, TEXT) TO authenticated;

CREATE OR REPLACE FUNCTION public.check_out_visitor_pass(
    p_pass_code TEXT,
    p_guard_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_pass public.visitor_access_passes%ROWTYPE;
    v_building_id UUID;
    v_guard_id UUID := auth.uid();
BEGIN
    IF v_guard_id IS NULL THEN
        RAISE EXCEPTION 'Yêu cầu đăng nhập nhân sự bảo vệ/lễ tân.' USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_pass
    FROM public.visitor_access_passes
    WHERE pass_code = UPPER(TRIM(p_pass_code))
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Không tìm thấy vé khách với mã đã quét.');
    END IF;

    SELECT building_id INTO v_building_id FROM public.apartments WHERE id = v_pass.apartment_id;
    IF NOT public.is_building_staff(v_building_id) THEN
        RAISE EXCEPTION 'Truy cập bị từ chối: Chỉ nhân sự tòa nhà mới có quyền check-out vé khách.' USING ERRCODE = '42501';
    END IF;

    IF v_pass.status = 'checked_out' THEN
        RETURN jsonb_build_object('success', false, 'message', 'Khách này đã check-out rời tòa nhà rồi.');
    END IF;

    UPDATE public.visitor_access_passes
    SET status = 'checked_out', check_out_at = now(), check_out_guard_id = v_guard_id, updated_at = now()
    WHERE id = v_pass.id;

    RETURN jsonb_build_object('success', true, 'message', 'Check-out hoàn tất.', 'pass_code', v_pass.pass_code, 'visitor_name', v_pass.visitor_name);
END;
$$;
REVOKE ALL ON FUNCTION public.check_out_visitor_pass(TEXT, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.check_out_visitor_pass(TEXT, UUID) TO authenticated;

CREATE OR REPLACE FUNCTION public.collect_parcel(
    p_parcel_id UUID,
    p_pickup_pin TEXT,
    p_staff_id UUID DEFAULT NULL,
    p_collected_by TEXT DEFAULT 'Cư dân'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_catalog
AS $$
DECLARE
    v_parcel public.parcels%ROWTYPE;
    v_building_id UUID;
    v_staff_id UUID := auth.uid();
    v_input_hash TEXT;
BEGIN
    IF v_staff_id IS NULL THEN
        RAISE EXCEPTION 'Yêu cầu đăng nhập nhân sự lễ tân.' USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_parcel FROM public.parcels WHERE id = p_parcel_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Không tìm thấy kiện hàng yêu cầu.');
    END IF;

    SELECT building_id INTO v_building_id FROM public.apartments WHERE id = v_parcel.apartment_id;
    IF NOT public.is_building_staff(v_building_id) THEN
        RAISE EXCEPTION 'Truy cập bị từ chối: Chỉ nhân sự tòa nhà mới có quyền xác nhận bàn giao bưu kiện.' USING ERRCODE = '42501';
    END IF;

    IF v_parcel.status = 'collected' THEN
        RETURN jsonb_build_object('success', false, 'message', 'Kiện hàng này đã được bàn giao trước đó.');
    END IF;

    v_input_hash := encode(digest(TRIM(COALESCE(p_pickup_pin, '')), 'sha256'), 'hex');
    IF v_parcel.pickup_pin_hash IS NOT NULL AND v_parcel.pickup_pin_hash != '' THEN
        IF v_input_hash != v_parcel.pickup_pin_hash THEN
            RETURN jsonb_build_object('success', false, 'message', 'Mã PIN nhận hàng không chính xác!');
        END IF;
    ELSIF TRIM(COALESCE(p_pickup_pin, '')) != v_parcel.pickup_pin THEN
        RETURN jsonb_build_object('success', false, 'message', 'Mã PIN nhận hàng không chính xác!');
    END IF;

    UPDATE public.parcels
    SET status = 'collected', collected_at = now(), handover_staff_id = v_staff_id,
        collected_by = COALESCE(p_collected_by, 'Cư dân'), updated_at = now()
    WHERE id = v_parcel.id;

    RETURN jsonb_build_object('success', true, 'message', 'Bàn giao bưu kiện thành công.',
        'parcel_code', v_parcel.parcel_code, 'tracking_number', v_parcel.tracking_number);
END;
$$;
REVOKE ALL ON FUNCTION public.collect_parcel(UUID, TEXT, UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.collect_parcel(UUID, TEXT, UUID, TEXT) TO authenticated;

-- 6.3 [P1-H1] Hardening submit_poll_vote, endorse_petition, update_petition_response, record_meter_reading
CREATE OR REPLACE FUNCTION public.submit_poll_vote(
    p_poll_id UUID,
    p_apartment_id UUID,
    p_option_ids UUID[],
    p_voter_user_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_poll RECORD;
    v_apt RECORD;
    v_calculated_weight NUMERIC(10,2);
    v_vote_id UUID;
    v_voter_id UUID := auth.uid();
    v_relation_role TEXT;
BEGIN
    IF v_voter_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Yêu cầu đăng nhập tài khoản để tham gia biểu quyết.');
    END IF;

    SELECT * INTO v_poll FROM public.polls WHERE id = p_poll_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Cuộc biểu quyết không tồn tại.');
    END IF;

    IF v_poll.status != 'active' OR now() < v_poll.start_time OR now() > v_poll.end_time THEN
        RETURN jsonb_build_object('success', false, 'message', 'Cuộc biểu quyết hiện không trong thời gian tiếp nhận phiếu.');
    END IF;

    SELECT id, building_id, area INTO v_apt FROM public.apartments WHERE id = p_apartment_id;
    IF NOT FOUND OR (v_poll.building_id IS NOT NULL AND v_apt.building_id IS DISTINCT FROM v_poll.building_id) THEN
        RETURN jsonb_build_object('success', false, 'message', 'Căn hộ không thuộc tòa nhà tổ chức cuộc biểu quyết này.');
    END IF;

    SELECT relation_role::TEXT INTO v_relation_role
    FROM public.residents_apartments
    WHERE apartment_id = p_apartment_id AND user_id = v_voter_id AND COALESCE(status, 'active') = 'active'
    LIMIT 1;

    IF v_relation_role IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Bạn không có quyền biểu quyết đại diện cho căn hộ này.');
    END IF;

    IF v_poll.poll_type = 'official_assembly' AND LOWER(v_relation_role) != 'owner' THEN
        RETURN jsonb_build_object('success', false,
            'message', 'Theo Điều 102 Luật Nhà ở 2023, chỉ chủ sở hữu căn hộ (owner) mới có quyền biểu quyết tại Hội nghị nhà chung cư.');
    END IF;

    IF EXISTS (SELECT 1 FROM public.poll_votes WHERE poll_id = p_poll_id AND apartment_id = p_apartment_id) THEN
        RETURN jsonb_build_object('success', false, 'message', 'Căn hộ này đã tham gia biểu quyết rồi.');
    END IF;

    v_calculated_weight := CASE WHEN v_poll.vote_weight_type = 'by_area' THEN COALESCE(v_apt.area, 50.0) ELSE 1.0 END;

    INSERT INTO public.poll_votes (poll_id, apartment_id, voter_user_id, selected_option_ids, vote_weight, voted_at)
    VALUES (p_poll_id, p_apartment_id, v_voter_id, p_option_ids, v_calculated_weight, now())
    RETURNING id INTO v_vote_id;

    RETURN jsonb_build_object('success', true, 'message', 'Gửi phiếu biểu quyết thành công.', 'vote_id', v_vote_id, 'weight', v_calculated_weight);
END;
$$;
REVOKE ALL ON FUNCTION public.submit_poll_vote(UUID, UUID, UUID[], UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_poll_vote(UUID, UUID, UUID[], UUID) TO authenticated;

CREATE OR REPLACE FUNCTION public.endorse_petition(
    p_petition_id UUID,
    p_apartment_id UUID,
    p_user_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_petition RECORD;
    v_apt_building_id UUID;
    v_new_count INT;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Yêu cầu đăng nhập tài khoản để đồng thuận kiến nghị.');
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.residents_apartments
        WHERE apartment_id = p_apartment_id AND user_id = v_user_id AND COALESCE(status, 'active') = 'active'
    ) THEN
        RETURN jsonb_build_object('success', false, 'message', 'Bạn không phải cư dân đang cư trú tại căn hộ này.');
    END IF;

    SELECT id, building_id INTO v_petition FROM public.resident_petitions WHERE id = p_petition_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Kiến nghị không tồn tại.');
    END IF;

    SELECT building_id INTO v_apt_building_id FROM public.apartments WHERE id = p_apartment_id;
    IF v_petition.building_id IS NOT NULL AND v_apt_building_id IS DISTINCT FROM v_petition.building_id THEN
        RETURN jsonb_build_object('success', false, 'message', 'Căn hộ không thuộc tòa nhà của kiến nghị này.');
    END IF;

    IF EXISTS (SELECT 1 FROM public.petition_endorsements WHERE petition_id = p_petition_id AND apartment_id = p_apartment_id) THEN
        RETURN jsonb_build_object('success', false, 'message', 'Căn hộ của bạn đã bấm đồng thuận kiến nghị này rồi.');
    END IF;

    INSERT INTO public.petition_endorsements (petition_id, apartment_id, user_id)
    VALUES (p_petition_id, p_apartment_id, v_user_id);

    UPDATE public.resident_petitions
    SET endorsement_count = endorsement_count + 1, updated_at = now()
    WHERE id = p_petition_id
    RETURNING endorsement_count INTO v_new_count;

    RETURN jsonb_build_object('success', true, 'message', 'Đã ghi nhận sự đồng thuận của bạn.', 'endorsement_count', v_new_count);
END;
$$;
REVOKE ALL ON FUNCTION public.endorse_petition(UUID, UUID, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.endorse_petition(UUID, UUID, UUID) TO authenticated;

CREATE OR REPLACE FUNCTION public.update_petition_response(
    p_petition_id UUID,
    p_status VARCHAR(20),
    p_response TEXT,
    p_staff_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_staff_id UUID := auth.uid();
    v_building_id UUID;
BEGIN
    IF v_staff_id IS NULL THEN
        RAISE EXCEPTION 'Yêu cầu đăng nhập nhân sự Ban Quản Lý.' USING ERRCODE = '42501';
    END IF;

    SELECT building_id INTO v_building_id FROM public.resident_petitions WHERE id = p_petition_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Kiến nghị không tồn tại.');
    END IF;

    IF NOT public.is_building_staff(v_building_id, ARRAY['admin', 'management', 'manager', 'owner']) THEN
        RAISE EXCEPTION 'Truy cập bị từ chối: Chỉ Ban Quản Lý tòa nhà mới có quyền phản hồi kiến nghị.' USING ERRCODE = '42501';
    END IF;

    UPDATE public.resident_petitions
    SET status = p_status, official_response = p_response,
        responded_by_staff_id = v_staff_id, responded_at = now(), updated_at = now()
    WHERE id = p_petition_id;

    RETURN jsonb_build_object('success', true, 'message', 'Cập nhật phản hồi kiến nghị thành công.');
END;
$$;
REVOKE ALL ON FUNCTION public.update_petition_response(UUID, VARCHAR, TEXT, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_petition_response(UUID, VARCHAR, TEXT, UUID) TO authenticated;

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
        RAISE EXCEPTION 'Yêu cầu đăng nhập để ghi nhận chỉ số điện nước' USING ERRCODE = '42501';
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

    IF v_elec < 0 OR v_water < 0 THEN
        RAISE EXCEPTION 'Chỉ số điện và nước không được mang giá trị âm.' USING ERRCODE = '22023';
    END IF;

    IF NOT public.can_access_apartment(v_apt_id) THEN
        RAISE EXCEPTION 'Truy cập bị từ chối: Bạn không có quyền ghi nhận chỉ số cho căn hộ này.' USING ERRCODE = '42501';
    END IF;

    INSERT INTO public.meter_reading_submissions (
        apartment_id, submitted_by, period, electric_reading, water_reading,
        electric_image_url, water_image_url, status, anomaly_reason, created_at, updated_at
    ) VALUES (
        v_apt_id, auth.uid(), v_prd, v_elec, v_water,
        v_elec_img, v_water_img, 'pending', v_nt, NOW(), NOW()
    ) RETURNING id INTO v_submission_id;

    RETURN jsonb_build_object('success', true, 'id', v_submission_id, 'message', 'Đã ghi nhận chỉ số điện nước thành công');
END;
$$;

-- 6.4 [P1-H3] Hardening verify_activation_otp & complete_resident_activation (OTP rate-limit, expiry, auth.uid(), Vivona branding)
ALTER TABLE public.resident_activations
    ADD COLUMN IF NOT EXISTS otp_attempts INT DEFAULT 0;

CREATE OR REPLACE FUNCTION public.verify_activation_otp(
    p_phone TEXT,
    p_activation_code TEXT,
    p_otp_code TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_catalog
AS $$
DECLARE
    v_norm_phone TEXT;
    v_norm_code TEXT;
    v_norm_otp TEXT;
    v_code_hash TEXT;
    v_act RECORD;
BEGIN
    v_norm_phone := REGEXP_REPLACE(TRIM(COALESCE(p_phone, '')), '[^0-9]', '', 'g');
    v_norm_code := UPPER(TRIM(COALESCE(p_activation_code, '')));
    v_norm_otp := TRIM(COALESCE(p_otp_code, ''));
    v_code_hash := encode(digest(v_norm_code, 'sha256'), 'hex');

    SELECT * INTO v_act
    FROM public.resident_activations
    WHERE phone = v_norm_phone
      AND status = 'otp_sent'
      AND (
          (activation_code_hash IS NOT NULL AND activation_code_hash = v_code_hash)
          OR (activation_code_hash IS NULL AND UPPER(activation_code) = v_norm_code)
      )
    ORDER BY created_at DESC
    LIMIT 1
    FOR UPDATE;

    IF v_act IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Phiên xác thực không hợp lệ hoặc đã hết hạn.');
    END IF;

    IF COALESCE(v_act.otp_attempts, 0) >= 5 THEN
        UPDATE public.resident_activations SET status = 'locked', updated_at = CURRENT_TIMESTAMP WHERE id = v_act.id;
        RETURN jsonb_build_object('success', FALSE, 'message', 'Mã OTP đã bị khóa do nhập sai quá 5 lần. Vui lòng liên hệ BQL.');
    END IF;

    IF v_act.otp_expires_at IS NOT NULL AND v_act.otp_expires_at < CURRENT_TIMESTAMP THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Mã xác thực OTP đã hết hạn. Vui lòng yêu cầu gửi lại mã mới.');
    END IF;

    IF v_act.otp_code IS DISTINCT FROM v_norm_otp THEN
        UPDATE public.resident_activations
        SET otp_attempts = COALESCE(otp_attempts, 0) + 1, updated_at = CURRENT_TIMESTAMP
        WHERE id = v_act.id;
        RETURN jsonb_build_object('success', FALSE, 'message', 'Mã xác thực OTP không chính xác.');
    END IF;

    RETURN jsonb_build_object('success', TRUE, 'message', 'Xác thực OTP thành công. Vui lòng thiết lập mật khẩu đăng nhập mới.');
END;
$$;

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
SET search_path = public, extensions, pg_catalog
AS $$
DECLARE
    v_norm_phone TEXT;
    v_norm_code TEXT;
    v_norm_otp TEXT;
    v_code_hash TEXT;
    v_act RECORD;
    v_old_user RECORD;
    v_apt_code TEXT;
    v_effective_auth_id UUID;
BEGIN
    v_norm_phone := REGEXP_REPLACE(TRIM(COALESCE(p_phone, '')), '[^0-9]', '', 'g');
    v_norm_code := UPPER(TRIM(COALESCE(p_activation_code, '')));
    v_norm_otp := TRIM(COALESCE(p_otp_code, ''));
    v_code_hash := encode(digest(v_norm_code, 'sha256'), 'hex');

    -- Bắt buộc auth.uid() khớp p_auth_user_id (trừ service_role) để chống chiếm đoạt hồ sơ cư dân
    IF COALESCE(auth.jwt() ->> 'role', '') = 'service_role' THEN
        v_effective_auth_id := p_auth_user_id;
    ELSE
        IF auth.uid() IS NULL THEN
            RETURN jsonb_build_object('success', FALSE, 'message', 'Phiên xác thực chưa được thiết lập. Vui lòng thử lại.');
        END IF;
        IF p_auth_user_id IS NOT NULL AND p_auth_user_id != auth.uid() THEN
            RAISE EXCEPTION 'Truy cập bị từ chối: Mã định danh tài khoản không khớp phiên đăng nhập.' USING ERRCODE = '42501';
        END IF;
        v_effective_auth_id := auth.uid();
    END IF;

    IF v_effective_auth_id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Thiếu thông tin nhận diện tài khoản xác thực.');
    END IF;

    SELECT * INTO v_act
    FROM public.resident_activations
    WHERE phone = v_norm_phone
      AND status = 'otp_sent'
      AND (
          (activation_code_hash IS NOT NULL AND activation_code_hash = v_code_hash)
          OR (activation_code_hash IS NULL AND UPPER(activation_code) = v_norm_code)
      )
    ORDER BY created_at DESC
    LIMIT 1
    FOR UPDATE;

    IF v_act IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Phiên kích hoạt không hợp lệ hoặc đã hết hạn.');
    END IF;

    IF COALESCE(v_act.otp_attempts, 0) >= 5 THEN
        UPDATE public.resident_activations SET status = 'locked', updated_at = CURRENT_TIMESTAMP WHERE id = v_act.id;
        RETURN jsonb_build_object('success', FALSE, 'message', 'Mã OTP đã bị khóa do nhập sai quá 5 lần.');
    END IF;

    IF v_act.otp_expires_at IS NOT NULL AND v_act.otp_expires_at < CURRENT_TIMESTAMP THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Mã xác thực OTP đã hết hạn.');
    END IF;

    IF v_act.otp_code IS DISTINCT FROM v_norm_otp THEN
        UPDATE public.resident_activations
        SET otp_attempts = COALESCE(otp_attempts, 0) + 1, updated_at = CURRENT_TIMESTAMP
        WHERE id = v_act.id;
        RETURN jsonb_build_object('success', FALSE, 'message', 'Mã xác thực OTP không chính xác.');
    END IF;

    SELECT * INTO v_old_user FROM public.users WHERE id = v_act.user_id;
    SELECT code INTO v_apt_code FROM public.apartments WHERE id = v_act.apartment_id;

    IF v_effective_auth_id != v_act.user_id THEN
        INSERT INTO public.users (id, full_name, phone, role, email, is_active, created_at, updated_at)
        VALUES (
            v_effective_auth_id,
            COALESCE(v_old_user.full_name, 'Cư dân'),
            v_norm_phone,
            'resident',
            COALESCE(p_email, v_old_user.email, v_norm_phone || '@vivona.vn'),
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

        UPDATE public.residents_apartments
        SET user_id = v_effective_auth_id, updated_at = CURRENT_TIMESTAMP
        WHERE user_id = v_act.user_id;

        UPDATE public.apartments SET is_empty = FALSE, updated_at = CURRENT_TIMESTAMP WHERE id = v_act.apartment_id;
        DELETE FROM public.users WHERE id = v_act.user_id AND role = 'resident' AND COALESCE(is_active, FALSE) = FALSE;
    ELSE
        UPDATE public.users
        SET is_active = TRUE,
            email = COALESCE(p_email, email, v_norm_phone || '@vivona.vn'),
            updated_at = CURRENT_TIMESTAMP
        WHERE id = v_effective_auth_id;

        UPDATE public.apartments SET is_empty = FALSE, updated_at = CURRENT_TIMESTAMP WHERE id = v_act.apartment_id;
    END IF;

    UPDATE public.resident_activations
    SET status = 'activated', user_id = v_effective_auth_id, otp_attempts = 0, updated_at = CURRENT_TIMESTAMP
    WHERE id = v_act.id;

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Kích hoạt tài khoản thành công! Chào mừng bạn đến với Vivona.',
        'apartment_code', v_apt_code,
        'user_id', v_effective_auth_id
    );
END;
$$;

-- ==============================================================================
-- PHẦN 7: BẢO MẬT STORAGE, PDPL SERVER-SIDE & CHUẨN HÓA THƯƠNG HIỆU [P1-H5, P2-M1, P2-M5, P2-M6]
-- ==============================================================================

-- 7.1 [P1-H5] Thu hẹp bucket vehicle-docs thành private & khóa quyền đọc/xóa chéo
UPDATE storage.buckets SET public = false WHERE id = 'vehicle-docs';

DROP POLICY IF EXISTS "Cho phép đọc ảnh giấy tờ xe" ON storage.objects;
DROP POLICY IF EXISTS "Cho phép xóa ảnh giấy tờ xe" ON storage.objects;
DROP POLICY IF EXISTS "Cho phép người dùng đã xác thực upload ảnh giấy tờ xe" ON storage.objects;

CREATE POLICY "vehicle_docs_insert_scoped" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (
        bucket_id = 'vehicle-docs'
        AND (
            owner = auth.uid()
            OR public.is_staff_or_management()
        )
    );

CREATE POLICY "vehicle_docs_select_scoped" ON storage.objects
    FOR SELECT TO authenticated
    USING (
        bucket_id = 'vehicle-docs'
        AND (
            owner = auth.uid()
            OR public.is_super_admin()
            OR (
                (storage.foldername(name))[1] ~ '^[0-9a-fA-F-]{36}$'
                AND public.can_access_apartment(((storage.foldername(name))[1])::uuid)
            )
        )
    );

CREATE POLICY "vehicle_docs_delete_scoped" ON storage.objects
    FOR DELETE TO authenticated
    USING (
        bucket_id = 'vehicle-docs'
        AND (
            owner = auth.uid()
            OR public.is_super_admin()
            OR (
                (storage.foldername(name))[1] ~ '^[0-9a-fA-F-]{36}$'
                AND public.is_building_staff(
                    (SELECT a.building_id FROM public.apartments a WHERE a.id = ((storage.foldername(name))[1])::uuid),
                    ARRAY['admin', 'management', 'manager', 'owner']
                )
            )
        )
    );

-- Khóa quyền đọc chéo trên handover-docs
DROP POLICY IF EXISTS "handover_docs_read_policy" ON storage.objects;
CREATE POLICY "handover_docs_read_scoped" ON storage.objects
    FOR SELECT TO authenticated
    USING (
        bucket_id = 'handover-docs'
        AND (
            owner = auth.uid()
            OR public.is_super_admin()
            OR EXISTS (
                SELECT 1 FROM public.apartment_handovers h
                WHERE (
                    h.staff_signature_url = storage.objects.name
                    OR h.resident_signature_url = storage.objects.name
                    OR storage.objects.name LIKE 'photos/' || h.id::text || '/%'
                    OR storage.objects.name LIKE 'signatures/' || h.id::text || '_%'
                )
                AND (
                    h.conducted_by = auth.uid()
                    OR h.resident_id = auth.uid()
                    OR public.can_access_apartment(h.apartment_id)
                )
            )
        )
    );

-- 7.2 [P2-M1] Bảng lưu vết pháp lý chấp thuận PDPL 2026 phía Server (Luật 91/2025/QH15)
CREATE TABLE IF NOT EXISTS public.user_pdpl_consents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    consent_version VARCHAR(32) NOT NULL DEFAULT 'v1.0-2026',
    accepted BOOLEAN NOT NULL,
    device_info TEXT,
    consented_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_user_pdpl_consents_user ON public.user_pdpl_consents(user_id, consented_at DESC);
ALTER TABLE public.user_pdpl_consents ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "pdpl_consents_read_own_or_admin" ON public.user_pdpl_consents;
CREATE POLICY "pdpl_consents_read_own_or_admin" ON public.user_pdpl_consents
    FOR SELECT TO authenticated
    USING (user_id = auth.uid() OR public.is_super_admin());

DROP POLICY IF EXISTS "pdpl_consents_insert_own" ON public.user_pdpl_consents;
CREATE POLICY "pdpl_consents_insert_own" ON public.user_pdpl_consents
    FOR INSERT TO authenticated
    WITH CHECK (user_id = auth.uid());

CREATE OR REPLACE FUNCTION public.record_pdpl_consent(
    p_consent_version TEXT DEFAULT 'v1.0-2026',
    p_accepted BOOLEAN DEFAULT TRUE,
    p_device_info TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_id UUID;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Yêu cầu đăng nhập để ghi nhận chấp thuận PDPL.' USING ERRCODE = '42501';
    END IF;

    INSERT INTO public.user_pdpl_consents (user_id, consent_version, accepted, device_info, consented_at)
    VALUES (v_uid, COALESCE(NULLIF(TRIM(p_consent_version), ''), 'v1.0-2026'), p_accepted, p_device_info, now())
    RETURNING id INTO v_id;

    INSERT INTO public.audit_logs (actor_id, action, entity_name, entity_id, details, created_at)
    VALUES (
        v_uid,
        CASE WHEN p_accepted THEN 'PDPL_CONSENT_ACCEPTED' ELSE 'PDPL_CONSENT_REVOKED' END,
        'users',
        v_uid,
        jsonb_build_object('consent_id', v_id, 'consent_version', p_consent_version, 'accepted', p_accepted, 'device_info', p_device_info),
        now()
    );

    RETURN jsonb_build_object('success', true, 'consent_id', v_id, 'consented_at', now());
END;
$$;

REVOKE ALL ON FUNCTION public.record_pdpl_consent(TEXT, BOOLEAN, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.record_pdpl_consent(TEXT, BOOLEAN, TEXT) TO authenticated;

-- 7.3 [P2-M5, P2-M6] Nâng entropy mã tra cứu lookup_code lên 12 ký tự hex & chuẩn hóa thương hiệu Vivona
CREATE OR REPLACE FUNCTION public.ensure_invoice_lookup_code()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, extensions, pg_catalog
AS $$
DECLARE
    v_period TEXT;
    v_rand TEXT;
BEGIN
    IF NEW.lookup_code IS NULL OR trim(NEW.lookup_code) = '' THEN
        v_period := regexp_replace(COALESCE(NEW.period, to_char(COALESCE(NEW.created_at, now()), 'YYYYMM')), '[^0-9]', '', 'g');
        IF length(v_period) < 6 THEN
            v_period := to_char(now() AT TIME ZONE 'Asia/Ho_Chi_Minh', 'YYYYMM');
        ELSE
            v_period := substr(v_period, 1, 6);
        END IF;

        v_rand := upper(encode(gen_random_bytes(6), 'hex'));
        NEW.lookup_code := 'INV-' || v_period || '-' || v_rand;
    ELSE
        NEW.lookup_code := upper(trim(NEW.lookup_code));
    END IF;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.verify_document_lookup(p_lookup_code TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_clean_code TEXT;
    v_rec RECORD;
    v_document_type TEXT;
    v_document_type_display TEXT;
    v_issuer TEXT;
BEGIN
    v_clean_code := upper(trim(COALESCE(p_lookup_code, '')));

    IF v_clean_code = '' OR length(v_clean_code) < 8 THEN
        RETURN jsonb_build_object('valid', false, 'lookup_code', v_clean_code, 'message', 'Mã tra cứu không hợp lệ');
    END IF;

    SELECT
        inv.id AS invoice_id,
        inv.lookup_code,
        inv.period,
        inv.due_date,
        inv.paid_at,
        inv.payment_method,
        inv.total_amount,
        inv.status,
        apt.code AS apartment_code,
        COALESCE(bld.name, 'Tòa nhà Vivona') AS building_name,
        COALESCE(org.name, 'Đơn vị Quản lý Vận hành Vivona') AS organization_name
    INTO v_rec
    FROM public.invoices inv
    JOIN public.apartments apt ON apt.id = inv.apartment_id
    LEFT JOIN public.buildings bld ON bld.id = apt.building_id
    LEFT JOIN public.organizations org ON org.id = bld.organization_id
    WHERE upper(trim(inv.lookup_code)) = v_clean_code
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('valid', false, 'lookup_code', v_clean_code, 'message', 'Không tìm thấy chứng từ với mã tra cứu tương ứng');
    END IF;

    IF v_rec.status = 'paid' THEN
        v_document_type := 'RECEIPT';
        v_document_type_display := 'Biên lai thu tiền điện tử';
    ELSE
        v_document_type := 'INVOICE';
        v_document_type_display := 'Hóa đơn dịch vụ chung cư';
    END IF;

    v_issuer := COALESCE(v_rec.building_name, v_rec.organization_name, 'Ban Quản Lý Tòa Nhà');

    RETURN jsonb_build_object(
        'valid', true,
        'lookup_code', v_rec.lookup_code,
        'document_type', v_document_type,
        'document_type_display', v_document_type_display,
        'invoice_id', v_rec.invoice_id,
        'period', v_rec.period,
        'due_date', v_rec.due_date,
        'paid_at', v_rec.paid_at,
        'payment_method', v_rec.payment_method,
        'total_amount', v_rec.total_amount,
        'status', v_rec.status,
        'apartment_code', v_rec.apartment_code,
        'building_name', v_rec.building_name,
        'organization_name', v_rec.organization_name,
        'issuer', v_issuer,
        'verified_at', now(),
        'message', 'Chứng từ hợp lệ và có nguồn gốc chính thức từ hệ thống Vivona'
    );
END;
$$;

-- 7.4 Khóa SET search_path = public, pg_catalog cho toàn bộ các hàm SECURITY DEFINER còn lại
DO $$
DECLARE
    v_fn RECORD;
BEGIN
    FOR v_fn IN
        SELECT p.oid::regprocedure AS fn_sig
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public'
          AND p.prosecdef = true
          AND (p.proconfig IS NULL OR NOT EXISTS (
              SELECT 1 FROM unnest(p.proconfig) cfg WHERE cfg LIKE 'search_path=%'
          ))
    LOOP
        EXECUTE format('ALTER FUNCTION %s SET search_path = public, pg_catalog', v_fn.fn_sig);
    END LOOP;
END $$;

NOTIFY pgrst, 'reload schema';
