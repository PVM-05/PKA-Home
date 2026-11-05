-- ==============================================================================
-- PKA-HOME: PRODUCT HARDENING (PHASE 0) - TENANT ISOLATION & MEMBERSHIPS
-- Migration: 20261103_05_tenant_isolation_and_memberships.sql
-- Mục tiêu:
--   1. Xóa bỏ hoàn toàn RLS USING (true) lỏng lẻo gây lộ dữ liệu giữa các tenant
--   2. Tạo bảng organization_memberships & building_memberships đa tầng
--   3. Cài đặt các hàm bảo mật kiểm tra quyền tập trung (get_user_accessible_buildings, has_building_role)
--   4. Bảo vệ sổ quỹ bảo trì & dữ liệu tòa nhà theo đúng ranh giới tenant
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. BẢNG ORGANIZATION_MEMBERSHIPS (Cấp Tổ Chức / Công Ty Quản Lý)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.organization_memberships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    org_role VARCHAR(30) NOT NULL DEFAULT 'member', -- 'owner', 'admin', 'member'
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(organization_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_org_mem_user ON public.organization_memberships(user_id);
CREATE INDEX IF NOT EXISTS idx_org_mem_org ON public.organization_memberships(organization_id);

ALTER TABLE public.organization_memberships ENABLE ROW LEVEL SECURITY;

-- ------------------------------------------------------------------------------
-- 2. BẢNG BUILDING_MEMBERSHIPS (Cấp Tòa Nhà / Cơ Sở Cụ Thể)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.building_memberships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    building_id UUID NOT NULL REFERENCES public.buildings(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    building_role VARCHAR(30) NOT NULL DEFAULT 'resident', 
    role VARCHAR(30) GENERATED ALWAYS AS (building_role) STORED,
    -- Các vai trò: 'manager', 'accountant', 'technician', 'security', 'receptionist', 'board_member', 'resident'
    apartment_id UUID REFERENCES public.apartments(id) ON DELETE SET NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    expires_at TIMESTAMPTZ DEFAULT NULL, -- Hết hạn ủy quyền / hợp đồng thuê
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Ràng buộc chống trùng lặp thành viên cùng vai trò tại cùng tòa/căn hộ
CREATE UNIQUE INDEX IF NOT EXISTS idx_bm_unique_role 
ON public.building_memberships (building_id, user_id, building_role, COALESCE(apartment_id, '00000000-0000-0000-0000-000000000000'::uuid));

CREATE INDEX IF NOT EXISTS idx_bm_user_building ON public.building_memberships(user_id, building_id);
CREATE INDEX IF NOT EXISTS idx_bm_active ON public.building_memberships(is_active) WHERE is_active = true;

ALTER TABLE public.building_memberships ENABLE ROW LEVEL SECURITY;

-- ------------------------------------------------------------------------------
-- 3. HÀM BẢO MẬT PHÂN QUYỀN TẬP TRUNG (SECURITY DEFINER, STABLE)
-- ------------------------------------------------------------------------------

-- 3.1. Lấy danh sách tổ chức người dùng được quyền truy cập
CREATE OR REPLACE FUNCTION public.get_user_accessible_organizations(p_user_id UUID DEFAULT auth.uid())
RETURNS SETOF UUID
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
BEGIN
    IF p_user_id IS NULL THEN
        RETURN;
    END IF;

    -- Kiểm tra nếu là Super Admin nền tảng
    IF EXISTS (
        SELECT 1 FROM public.users 
        WHERE id = p_user_id AND role = 'admin'
    ) THEN
        RETURN QUERY SELECT id FROM public.organizations;
        RETURN;
    END IF;

    -- Trả về các tổ chức có membership đang kích hoạt
    RETURN QUERY
    SELECT organization_id
    FROM public.organization_memberships
    WHERE user_id = p_user_id AND is_active = true;
END;
$$;

-- 3.2. Lấy danh sách tòa nhà người dùng được quyền truy cập
CREATE OR REPLACE FUNCTION public.get_user_accessible_buildings(p_user_id UUID DEFAULT auth.uid())
RETURNS SETOF UUID
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
BEGIN
    IF p_user_id IS NULL THEN
        RETURN;
    END IF;

    -- Super Admin xem được toàn bộ
    IF EXISTS (
        SELECT 1 FROM public.users 
        WHERE id = p_user_id AND role = 'admin'
    ) THEN
        RETURN QUERY SELECT id FROM public.buildings;
        RETURN;
    END IF;

    RETURN QUERY
    -- Tòa nhà có membership trực tiếp còn hiệu lực
    SELECT DISTINCT bm.building_id
    FROM public.building_memberships bm
    WHERE bm.user_id = p_user_id 
      AND bm.is_active = true
      AND (bm.expires_at IS NULL OR bm.expires_at > now())

    UNION

    -- Tòa nhà thuộc tổ chức mà user là owner hoặc admin
    SELECT DISTINCT b.id
    FROM public.buildings b
    JOIN public.organization_memberships om ON om.organization_id = b.organization_id
    WHERE om.user_id = p_user_id 
      AND om.is_active = true 
      AND om.org_role IN ('owner', 'admin');
END;
$$;

-- 3.3. Kiểm tra người dùng có một trong các vai trò yêu cầu tại tòa nhà cụ thể
CREATE OR REPLACE FUNCTION public.has_building_role(
    p_building_id UUID,
    p_required_roles TEXT[],
    p_user_id UUID DEFAULT auth.uid()
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
BEGIN
    IF p_user_id IS NULL OR p_building_id IS NULL THEN
        RETURN false;
    END IF;

    -- 1. Super Admin luôn có quyền
    IF EXISTS (
        SELECT 1 FROM public.users 
        WHERE id = p_user_id AND role = 'admin'
    ) THEN
        RETURN true;
    END IF;

    -- 2. Owner hoặc Admin của tổ chức sở hữu tòa nhà luôn có quyền quản trị
    IF EXISTS (
        SELECT 1 
        FROM public.buildings b
        JOIN public.organization_memberships om ON om.organization_id = b.organization_id
        WHERE b.id = p_building_id 
          AND om.user_id = p_user_id 
          AND om.is_active = true 
          AND om.org_role IN ('owner', 'admin')
    ) THEN
        RETURN true;
    END IF;

    -- 3. Kiểm tra vai trò trực tiếp trong building_memberships
    RETURN EXISTS (
        SELECT 1 
        FROM public.building_memberships
        WHERE building_id = p_building_id
          AND user_id = p_user_id
          AND is_active = true
          AND (expires_at IS NULL OR expires_at > now())
          AND (building_role = ANY(p_required_roles) OR 'all' = ANY(p_required_roles))
    );
END;
$$;

-- ------------------------------------------------------------------------------
-- 4. DI CHUYỂN DỮ LIỆU CŨ SANG BUILDING_MEMBERSHIPS (IDEMPOTENT DATA MIGRATION)
-- ------------------------------------------------------------------------------

-- Di chuyển từ building_staff
INSERT INTO public.building_memberships (building_id, user_id, building_role, is_active, created_at)
SELECT bs.building_id, bs.user_id, bs.assigned_role, true, bs.created_at
FROM public.building_staff bs
ON CONFLICT DO NOTHING;

-- Di chuyển từ residents_apartments (nếu căn hộ đã gắn với building_id)
INSERT INTO public.building_memberships (building_id, user_id, building_role, apartment_id, is_active, created_at)
SELECT a.building_id, ra.user_id, COALESCE(ra.relation_role, 'resident'), ra.apartment_id, true, ra.created_at
FROM public.residents_apartments ra
JOIN public.apartments a ON a.id = ra.apartment_id
WHERE a.building_id IS NOT NULL
ON CONFLICT DO NOTHING;

-- ------------------------------------------------------------------------------
-- 5. XÓA BỎ CHÍNH SÁCH RLS LỎNG LẺO VÀ THIẾT LẬP RLS CÁCH LY TENANT CHẶT CHẼ
-- ------------------------------------------------------------------------------

-- 5.1. Bảng organizations
DROP POLICY IF EXISTS "organizations_read_authenticated" ON public.organizations;
DROP POLICY IF EXISTS "organizations_read_tenant" ON public.organizations;
CREATE POLICY "organizations_read_tenant" ON public.organizations
    FOR SELECT TO authenticated
    USING (id IN (SELECT public.get_user_accessible_organizations()));

DROP POLICY IF EXISTS "organizations_manage_owner" ON public.organizations;
CREATE POLICY "organizations_manage_owner" ON public.organizations
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.organization_memberships om
            WHERE om.organization_id = id AND om.user_id = auth.uid() AND om.is_active = true AND om.org_role = 'owner'
        )
    );

-- 5.2. Bảng organization_memberships
DROP POLICY IF EXISTS "org_mem_read_policy" ON public.organization_memberships;
CREATE POLICY "org_mem_read_policy" ON public.organization_memberships
    FOR SELECT TO authenticated
    USING (
        organization_id IN (SELECT public.get_user_accessible_organizations())
        OR user_id = auth.uid()
    );

-- 5.3. Bảng buildings
DROP POLICY IF EXISTS "buildings_read_authenticated" ON public.buildings;
DROP POLICY IF EXISTS "buildings_read_tenant" ON public.buildings;
CREATE POLICY "buildings_read_tenant" ON public.buildings
    FOR SELECT TO authenticated
    USING (id IN (SELECT public.get_user_accessible_buildings()));

DROP POLICY IF EXISTS "buildings_manage_admin" ON public.buildings;
CREATE POLICY "buildings_manage_admin" ON public.buildings
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.organization_memberships om
            WHERE om.organization_id = organization_id 
              AND om.user_id = auth.uid() 
              AND om.is_active = true 
              AND om.org_role IN ('owner', 'admin')
        )
    );

-- 5.4. Bảng building_staff
DROP POLICY IF EXISTS "building_staff_read_authenticated" ON public.building_staff;
DROP POLICY IF EXISTS "building_staff_read_tenant" ON public.building_staff;
CREATE POLICY "building_staff_read_tenant" ON public.building_staff
    FOR SELECT TO authenticated
    USING (building_id IN (SELECT public.get_user_accessible_buildings()));

-- 5.5. Bảng building_memberships
DROP POLICY IF EXISTS "building_memberships_read_policy" ON public.building_memberships;
CREATE POLICY "building_memberships_read_policy" ON public.building_memberships
    FOR SELECT TO authenticated
    USING (
        building_id IN (SELECT public.get_user_accessible_buildings())
        OR user_id = auth.uid()
    );

DROP POLICY IF EXISTS "building_memberships_manage_policy" ON public.building_memberships;
CREATE POLICY "building_memberships_manage_policy" ON public.building_memberships
    FOR ALL TO authenticated
    USING (
        public.has_building_role(building_id, ARRAY['manager', 'admin', 'owner'])
    );

-- 5.6. Bảng maintenance_funds (Sổ quỹ bảo trì)
DROP POLICY IF EXISTS "maintenance_funds_read" ON public.maintenance_funds;
DROP POLICY IF EXISTS "maintenance_funds_read_tenant" ON public.maintenance_funds;
CREATE POLICY "maintenance_funds_read_tenant" ON public.maintenance_funds
    FOR SELECT TO authenticated
    USING (building_id IS NULL OR building_id IN (SELECT public.get_user_accessible_buildings()));

DROP POLICY IF EXISTS "maintenance_funds_update_tenant" ON public.maintenance_funds;
CREATE POLICY "maintenance_funds_update_tenant" ON public.maintenance_funds
    FOR UPDATE TO authenticated
    USING (
        building_id IS NOT NULL AND public.has_building_role(building_id, ARRAY['manager', 'accountant', 'admin'])
    );

-- 5.7. Bảng maintenance_fund_transactions (Biến động sổ quỹ bảo trì)
DROP POLICY IF EXISTS "mft_read_policy" ON public.maintenance_fund_transactions;
DROP POLICY IF EXISTS "mft_read_tenant" ON public.maintenance_fund_transactions;
CREATE POLICY "mft_read_tenant" ON public.maintenance_fund_transactions
    FOR SELECT TO authenticated
    USING (building_id IN (SELECT public.get_user_accessible_buildings()));

DROP POLICY IF EXISTS "mft_admin_manage_policy" ON public.maintenance_fund_transactions;
DROP POLICY IF EXISTS "mft_write_tenant" ON public.maintenance_fund_transactions;
CREATE POLICY "mft_write_tenant" ON public.maintenance_fund_transactions
    FOR INSERT TO authenticated
    WITH CHECK (
        public.has_building_role(building_id, ARRAY['manager', 'accountant', 'admin'])
    );

-- Cấp quyền thực thi hàm bảo mật cho authenticated users
GRANT EXECUTE ON FUNCTION public.get_user_accessible_organizations TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.get_user_accessible_buildings TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.has_building_role TO authenticated, anon;
