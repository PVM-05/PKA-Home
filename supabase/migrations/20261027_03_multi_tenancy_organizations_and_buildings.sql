-- ==============================================================================
-- PKA-HOME: MULTI-TENANCY ORGANIZATIONS & BUILDINGS MIGRATION
-- Migration: 20261027_03_multi_tenancy_organizations_and_buildings.sql
-- ==============================================================================

-- 1. Create organizations table
CREATE TABLE IF NOT EXISTS public.organizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    slug TEXT NOT NULL UNIQUE,
    logo_url TEXT,
    contact_phone TEXT,
    contact_email TEXT,
    status TEXT NOT NULL DEFAULT 'active',
    settings JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "organizations_read_authenticated" ON public.organizations;
CREATE POLICY "organizations_read_authenticated" ON public.organizations
    FOR SELECT TO authenticated USING (true);

-- 2. Create buildings table
CREATE TABLE IF NOT EXISTS public.buildings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    code TEXT NOT NULL UNIQUE,
    address TEXT,
    total_floors INT NOT NULL DEFAULT 20,
    total_units INT NOT NULL DEFAULT 200,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.buildings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "buildings_read_authenticated" ON public.buildings;
CREATE POLICY "buildings_read_authenticated" ON public.buildings
    FOR SELECT TO authenticated USING (true);

-- 3. Create building_staff table
CREATE TABLE IF NOT EXISTS public.building_staff (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    building_id UUID NOT NULL REFERENCES public.buildings(id) ON DELETE CASCADE,
    assigned_role TEXT NOT NULL DEFAULT 'staff',
    is_primary BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(user_id, building_id)
);

ALTER TABLE public.building_staff ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "building_staff_read_authenticated" ON public.building_staff;
CREATE POLICY "building_staff_read_authenticated" ON public.building_staff
    FOR SELECT TO authenticated USING (true);

-- 4. Seed Canonical Organization & Canonical Default Building
INSERT INTO public.organizations (id, name, slug, contact_email, status)
VALUES (
    '00000000-0000-0000-0000-000000000001',
    'Công ty Quản lý Vận hành Bất động sản PKA',
    'pka-corp',
    'admin@pka.vn',
    'active'
)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    slug = EXCLUDED.slug;

INSERT INTO public.buildings (id, organization_id, name, code, address, total_floors, total_units)
VALUES (
    '00000000-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-000000000001',
    'Tòa nhà Landmark PKA',
    'PKAL',
    'Số 1 Đại Cồ Việt, Hai Bà Trưng, Hà Nội',
    25,
    300
)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    code = EXCLUDED.code;

-- 5. Add building_id column & backfill canonical building to existing tables

-- 5.1 apartments
ALTER TABLE public.apartments 
    ADD COLUMN IF NOT EXISTS building_id UUID REFERENCES public.buildings(id) ON DELETE CASCADE;

UPDATE public.apartments 
SET building_id = '00000000-0000-0000-0000-000000000002' 
WHERE building_id IS NULL;

ALTER TABLE public.apartments 
    ALTER COLUMN building_id SET DEFAULT '00000000-0000-0000-0000-000000000002';

-- Drop single-column UNIQUE(code) constraint on apartments if present
DO $$
DECLARE
    v_constraint_name TEXT;
BEGIN
    SELECT conname INTO v_constraint_name
    FROM pg_constraint c
    JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = ANY(c.conkey)
    WHERE c.conrelid = 'public.apartments'::regclass
      AND c.contype = 'u'
      AND a.attname = 'code'
      AND array_length(c.conkey, 1) = 1;

    IF v_constraint_name IS NOT NULL THEN
        EXECUTE 'ALTER TABLE public.apartments DROP CONSTRAINT ' || quote_ident(v_constraint_name);
    END IF;
END $$;

-- Add composite UNIQUE (building_id, code) constraint
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'public.apartments'::regclass
          AND conname = 'uq_apartments_building_code'
    ) THEN
        ALTER TABLE public.apartments ADD CONSTRAINT uq_apartments_building_code UNIQUE (building_id, code);
    END IF;
END $$;

-- 5.2 announcements
ALTER TABLE public.announcements 
    ADD COLUMN IF NOT EXISTS building_id UUID REFERENCES public.buildings(id) ON DELETE CASCADE;

UPDATE public.announcements 
SET building_id = '00000000-0000-0000-0000-000000000002' 
WHERE building_id IS NULL;

ALTER TABLE public.announcements 
    ALTER COLUMN building_id SET DEFAULT '00000000-0000-0000-0000-000000000002';

-- 5.3 building_amenities
ALTER TABLE public.building_amenities 
    ADD COLUMN IF NOT EXISTS building_id UUID REFERENCES public.buildings(id) ON DELETE CASCADE;

UPDATE public.building_amenities 
SET building_id = '00000000-0000-0000-0000-000000000002' 
WHERE building_id IS NULL;

ALTER TABLE public.building_amenities 
    ALTER COLUMN building_id SET DEFAULT '00000000-0000-0000-0000-000000000002';

-- 5.4 fee_schedules
ALTER TABLE public.fee_schedules 
    ADD COLUMN IF NOT EXISTS building_id UUID REFERENCES public.buildings(id) ON DELETE CASCADE;

UPDATE public.fee_schedules 
SET building_id = '00000000-0000-0000-0000-000000000002' 
WHERE building_id IS NULL;

ALTER TABLE public.fee_schedules 
    ALTER COLUMN building_id SET DEFAULT '00000000-0000-0000-0000-000000000002';

-- 5.5 maintenance_funds
ALTER TABLE public.maintenance_funds 
    ADD COLUMN IF NOT EXISTS building_id UUID REFERENCES public.buildings(id) ON DELETE CASCADE;

UPDATE public.maintenance_funds 
SET building_id = '00000000-0000-0000-0000-000000000002' 
WHERE building_id IS NULL;

ALTER TABLE public.maintenance_funds 
    ALTER COLUMN building_id SET DEFAULT '00000000-0000-0000-0000-000000000002';

-- 5.6 Backfill building_staff for all existing management and staff users
INSERT INTO public.building_staff (user_id, building_id, assigned_role, is_primary)
SELECT u.id, '00000000-0000-0000-0000-000000000002'::uuid, u.role::text, true
FROM public.users u
WHERE u.role IN ('admin', 'manager', 'accountant', 'technician')
ON CONFLICT (user_id, building_id) DO NOTHING;
