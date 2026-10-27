-- ==============================================================================
-- PKA-Home: Baseline Database Schema (Single Consolidated Migration)
-- Migration ID: 20261027_01_baseline_schema
-- Created: 2026-10-27
-- Description: Consolidated canonical schema replacing previous 58 migrations.
--              Includes Core Entities, Enums, Dynamic Fee Schedules, Security Helpers,
--              Row-Level Security (RLS), Triggers, Storage Policies, and Canonical RPCs.
-- ==============================================================================

-- ==============================================================================
-- PART 1: EXTENSIONS & ENUMS
-- ==============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_role') THEN
        CREATE TYPE public.user_role AS ENUM ('admin', 'management', 'staff', 'resident');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'apartment_relation_role') THEN
        CREATE TYPE public.apartment_relation_role AS ENUM ('owner', 'tenant', 'member');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'vehicle_type') THEN
        CREATE TYPE public.vehicle_type AS ENUM ('motorcycle', 'car', 'bicycle', 'electric_bike');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'vehicle_status') THEN
        CREATE TYPE public.vehicle_status AS ENUM ('pending', 'approved', 'rejected');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'invoice_status') THEN
        CREATE TYPE public.invoice_status AS ENUM ('pending', 'paid', 'overdue', 'cancelled', 'under_review');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'invoice_item_fee_type') THEN
        CREATE TYPE public.invoice_item_fee_type AS ENUM ('management', 'electricity', 'water', 'parking', 'maintenance', 'other');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'payment_method') THEN
        CREATE TYPE public.payment_method AS ENUM ('DEMO', 'cash', 'bank_transfer', 'vnpay', 'momo');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'amenity_booking_type') THEN
        CREATE TYPE public.amenity_booking_type AS ENUM ('exclusive', 'shared');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'amenity_booking_status') THEN
        CREATE TYPE public.amenity_booking_status AS ENUM ('pending_payment', 'confirmed', 'cancelled', 'waitlist', 'completed');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'meter_type') THEN
        CREATE TYPE public.meter_type AS ENUM ('electricity', 'water');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'meter_submission_status') THEN
        CREATE TYPE public.meter_submission_status AS ENUM ('pending', 'approved', 'rejected');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'issue_status') THEN
        CREATE TYPE public.issue_status AS ENUM ('reported', 'acknowledged', 'in_progress', 'resolved', 'cancelled');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'equipment_maintenance_status') THEN
        CREATE TYPE public.equipment_maintenance_status AS ENUM ('pending', 'in_progress', 'completed', 'skipped');
    END IF;
END $$;

-- ==============================================================================
-- PART 2: CORE TABLES
-- ==============================================================================

-- 1. Users
CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT NOT NULL,
    phone TEXT,
    email TEXT,
    role public.user_role NOT NULL DEFAULT 'resident',
    is_active BOOLEAN NOT NULL DEFAULT true,
    is_locked BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. Apartments
CREATE TABLE IF NOT EXISTS public.apartments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(10) NOT NULL UNIQUE,
    block VARCHAR(10),
    floor INT,
    room VARCHAR(10),
    area NUMERIC(10,2) NOT NULL DEFAULT 50.0,
    is_empty BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. Residents <-> Apartments Relation
CREATE TABLE IF NOT EXISTS public.residents_apartments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    apartment_id UUID NOT NULL REFERENCES public.apartments(id) ON DELETE CASCADE,
    relation_role public.apartment_relation_role NOT NULL DEFAULT 'member',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(user_id, apartment_id)
);

-- 4. Apartment Link Requests
CREATE TABLE IF NOT EXISTS public.apartment_link_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    apartment_id UUID NOT NULL REFERENCES public.apartments(id) ON DELETE CASCADE,
    requested_relation_role public.apartment_relation_role NOT NULL DEFAULT 'member',
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    rejection_reason TEXT,
    reviewed_by UUID REFERENCES public.users(id),
    reviewed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 5. Invoices
CREATE TABLE IF NOT EXISTS public.invoices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    apartment_id UUID NOT NULL REFERENCES public.apartments(id) ON DELETE RESTRICT,
    period VARCHAR(7) NOT NULL,
    due_date DATE NOT NULL,
    total_amount NUMERIC(12,2) NOT NULL DEFAULT 0.0,
    status public.invoice_status NOT NULL DEFAULT 'pending',
    payment_method TEXT,
    paid_at TIMESTAMPTZ,
    payment_proof_url TEXT,
    note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 6. Invoice Items
CREATE TABLE IF NOT EXISTS public.invoice_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invoice_id UUID NOT NULL REFERENCES public.invoices(id) ON DELETE CASCADE,
    fee_type public.invoice_item_fee_type NOT NULL,
    unit_price NUMERIC(12,2) NOT NULL DEFAULT 0.0,
    quantity NUMERIC(10,2) NOT NULL DEFAULT 1.0,
    subtotal NUMERIC(12,2) GENERATED ALWAYS AS (unit_price * quantity) STORED,
    note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 7. Vehicles
CREATE TABLE IF NOT EXISTS public.vehicles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    apartment_id UUID NOT NULL REFERENCES public.apartments(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    license_plate VARCHAR(20) NOT NULL,
    vehicle_type public.vehicle_type NOT NULL DEFAULT 'motorcycle',
    brand TEXT,
    model TEXT,
    status public.vehicle_status NOT NULL DEFAULT 'pending',
    rejection_reason TEXT,
    approved_at TIMESTAMPTZ,
    approved_by UUID REFERENCES public.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(license_plate)
);

-- 8. Building Amenities
CREATE TABLE IF NOT EXISTS public.building_amenities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    location TEXT,
    open_time TIME NOT NULL DEFAULT '06:00:00',
    close_time TIME NOT NULL DEFAULT '22:00:00',
    slot_duration_minutes INT NOT NULL DEFAULT 60,
    booking_type public.amenity_booking_type NOT NULL DEFAULT 'shared',
    max_capacity INT NOT NULL DEFAULT 10,
    fee_amount NUMERIC(12,2) NOT NULL DEFAULT 0.0,
    deposit_amount NUMERIC(12,2) NOT NULL DEFAULT 0.0,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 9. Amenity Bookings
CREATE TABLE IF NOT EXISTS public.amenity_bookings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    amenity_id UUID NOT NULL REFERENCES public.building_amenities(id) ON DELETE RESTRICT,
    apartment_id UUID NOT NULL REFERENCES public.apartments(id) ON DELETE RESTRICT,
    booked_by UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    booking_date DATE NOT NULL,
    time_slot VARCHAR(20) NOT NULL,
    guests_count INT NOT NULL DEFAULT 1,
    status public.amenity_booking_status NOT NULL DEFAULT 'confirmed',
    fee_amount NUMERIC(12,2) NOT NULL DEFAULT 0.0,
    deposit_amount NUMERIC(12,2) NOT NULL DEFAULT 0.0,
    deposit_status TEXT NOT NULL DEFAULT 'none',
    payment_status TEXT NOT NULL DEFAULT 'unpaid',
    qr_code_hash TEXT,
    check_in_time TIMESTAMPTZ,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 10. Amenity Maintenance Windows
CREATE TABLE IF NOT EXISTS public.amenity_maintenance_windows (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    amenity_id UUID NOT NULL REFERENCES public.building_amenities(id) ON DELETE CASCADE,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ NOT NULL,
    reason TEXT NOT NULL,
    created_by UUID REFERENCES public.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 11. Meter Reading Submissions
CREATE TABLE IF NOT EXISTS public.meter_reading_submissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    apartment_id UUID NOT NULL REFERENCES public.apartments(id) ON DELETE CASCADE,
    submitted_by UUID NOT NULL REFERENCES public.users(id),
    meter_type public.meter_type NOT NULL DEFAULT 'electricity',
    period VARCHAR(7) NOT NULL,
    reading_value NUMERIC(10,2) NOT NULL,
    previous_value NUMERIC(10,2),
    image_url TEXT,
    status public.meter_submission_status NOT NULL DEFAULT 'pending',
    rejection_reason TEXT,
    approved_by UUID REFERENCES public.users(id),
    approved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 12. Payment Transactions
CREATE TABLE IF NOT EXISTS public.payment_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reference_id UUID NOT NULL,
    booking_id UUID REFERENCES public.amenity_bookings(id) ON DELETE SET NULL,
    invoice_id UUID REFERENCES public.invoices(id) ON DELETE SET NULL,
    user_id UUID NOT NULL REFERENCES public.users(id),
    apartment_id UUID REFERENCES public.apartments(id),
    payment_type TEXT NOT NULL,
    payment_method TEXT NOT NULL DEFAULT 'DEMO',
    amount NUMERIC(12,2) NOT NULL DEFAULT 0.0,
    status TEXT NOT NULL DEFAULT 'PENDING',
    receipt_number TEXT UNIQUE,
    idempotency_key TEXT UNIQUE,
    failure_reason TEXT,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 13. Announcements
CREATE TABLE IF NOT EXISTS public.announcements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    is_urgent BOOLEAN NOT NULL DEFAULT false,
    target_role TEXT DEFAULT 'all',
    target_block TEXT DEFAULT 'all',
    target_floor TEXT DEFAULT 'all',
    created_by UUID REFERENCES public.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 14. Issue Reports
CREATE TABLE IF NOT EXISTS public.issue_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    apartment_id UUID NOT NULL REFERENCES public.apartments(id) ON DELETE CASCADE,
    reporter_id UUID NOT NULL REFERENCES public.users(id),
    assigned_staff_id UUID REFERENCES public.users(id),
    category TEXT NOT NULL DEFAULT 'other',
    description TEXT NOT NULL,
    status public.issue_status NOT NULL DEFAULT 'reported',
    priority TEXT NOT NULL DEFAULT 'medium',
    resolution_proof_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 15. Issue Images
CREATE TABLE IF NOT EXISTS public.issue_images (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    issue_report_id UUID NOT NULL REFERENCES public.issue_reports(id) ON DELETE CASCADE,
    image_url TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 16. Equipment Maintenance Tasks
CREATE TABLE IF NOT EXISTS public.equipment_maintenance_tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    equipment_name TEXT NOT NULL,
    location TEXT NOT NULL,
    scheduled_date DATE NOT NULL,
    assigned_to UUID REFERENCES public.users(id),
    status public.equipment_maintenance_status NOT NULL DEFAULT 'pending',
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 17. Audit Logs
CREATE TABLE IF NOT EXISTS public.audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_id UUID REFERENCES public.users(id),
    action TEXT NOT NULL,
    entity_name TEXT NOT NULL,
    entity_id UUID,
    details JSONB DEFAULT '{}'::jsonb,
    ip_address TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 18. Service Ratings
CREATE TABLE IF NOT EXISTS public.service_ratings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    issue_report_id UUID REFERENCES public.issue_reports(id) ON DELETE CASCADE,
    amenity_booking_id UUID REFERENCES public.amenity_bookings(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.users(id),
    rating INT NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 19. Issue Comments
CREATE TABLE IF NOT EXISTS public.issue_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    issue_report_id UUID NOT NULL REFERENCES public.issue_reports(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.users(id),
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ==============================================================================
-- PART 3: DYNAMIC FEE SCHEDULES & TARIFF TABLES
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.fee_schedules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fee_type TEXT NOT NULL,
    name TEXT NOT NULL,
    unit TEXT NOT NULL,
    unit_price NUMERIC(12,2) NOT NULL,
    effective_from DATE NOT NULL DEFAULT CURRENT_DATE,
    effective_to DATE,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.tiered_tariffs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fee_type TEXT NOT NULL,
    tier_number INT NOT NULL,
    tier_from NUMERIC(10,2) NOT NULL,
    tier_to NUMERIC(10,2),
    price NUMERIC(12,2) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ==============================================================================
-- PART 4: INDEXES
-- ==============================================================================

CREATE INDEX IF NOT EXISTS idx_users_role ON public.users(role);
CREATE INDEX IF NOT EXISTS idx_apartments_code ON public.apartments(code);
CREATE INDEX IF NOT EXISTS idx_residents_apartments_user ON public.residents_apartments(user_id);
CREATE INDEX IF NOT EXISTS idx_residents_apartments_apt ON public.residents_apartments(apartment_id);
CREATE INDEX IF NOT EXISTS idx_invoices_apt_period ON public.invoices(apartment_id, period);
CREATE INDEX IF NOT EXISTS idx_invoices_status ON public.invoices(status);
CREATE INDEX IF NOT EXISTS idx_invoice_items_invoice ON public.invoice_items(invoice_id);
CREATE INDEX IF NOT EXISTS idx_vehicles_apartment ON public.vehicles(apartment_id);
CREATE INDEX IF NOT EXISTS idx_amenity_bookings_slot ON public.amenity_bookings(amenity_id, booking_date, time_slot);
CREATE INDEX IF NOT EXISTS idx_meter_submissions_apt ON public.meter_reading_submissions(apartment_id, period);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_ref ON public.payment_transactions(reference_id);
CREATE INDEX IF NOT EXISTS idx_issue_reports_apt ON public.issue_reports(apartment_id);
CREATE INDEX IF NOT EXISTS idx_announcements_urgent ON public.announcements(is_urgent, created_at DESC);

-- ==============================================================================
-- PART 5: SECURITY HELPER FUNCTIONS
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.get_current_user_role()
RETURNS text
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public, pg_catalog
AS $$
    SELECT role::text FROM public.users WHERE id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION public.is_staff_or_management()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public, pg_catalog
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.users
        WHERE id = auth.uid()
          AND role IN ('admin', 'management', 'staff')
          AND is_active = true
          AND is_locked = false
    );
$$;

CREATE OR REPLACE FUNCTION public.check_user_active_and_unlocked()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public, pg_catalog
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.users
        WHERE id = auth.uid()
          AND is_active = true
          AND is_locked = false
    );
$$;

-- ==============================================================================
-- PART 6: ROW-LEVEL SECURITY (RLS) POLICIES
-- ==============================================================================

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.apartments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.residents_apartments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.apartment_link_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoice_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.building_amenities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.amenity_bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.amenity_maintenance_windows ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.meter_reading_submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.issue_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.issue_images ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.equipment_maintenance_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.service_ratings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.issue_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fee_schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tiered_tariffs ENABLE ROW LEVEL SECURITY;

-- 1. Users policies
CREATE POLICY "users_read_all_authenticated" ON public.users
    FOR SELECT TO authenticated USING (true);

CREATE POLICY "users_update_own_or_admin" ON public.users
    FOR UPDATE TO authenticated
    USING (id = auth.uid() OR public.is_staff_or_management())
    WITH CHECK (id = auth.uid() OR public.is_staff_or_management());

-- 2. Apartments policies
CREATE POLICY "apartments_read_authenticated" ON public.apartments
    FOR SELECT TO authenticated USING (true);

CREATE POLICY "apartments_write_admin" ON public.apartments
    FOR ALL TO authenticated
    USING (public.is_staff_or_management())
    WITH CHECK (public.is_staff_or_management());

-- 3. Residents Apartments policies
CREATE POLICY "residents_apartments_read" ON public.residents_apartments
    FOR SELECT TO authenticated
    USING (user_id = auth.uid() OR public.is_staff_or_management());

CREATE POLICY "residents_apartments_write_admin" ON public.residents_apartments
    FOR ALL TO authenticated
    USING (public.is_staff_or_management())
    WITH CHECK (public.is_staff_or_management());

-- 4. Apartment Link Requests policies
CREATE POLICY "link_requests_read" ON public.apartment_link_requests
    FOR SELECT TO authenticated
    USING (user_id = auth.uid() OR public.is_staff_or_management());

CREATE POLICY "link_requests_insert_resident" ON public.apartment_link_requests
    FOR INSERT TO authenticated
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "link_requests_update_admin" ON public.apartment_link_requests
    FOR UPDATE TO authenticated
    USING (public.is_staff_or_management())
    WITH CHECK (public.is_staff_or_management());

-- 5. Invoices policies
CREATE POLICY "invoices_read" ON public.invoices
    FOR SELECT TO authenticated
    USING (
        public.is_staff_or_management() OR
        EXISTS (
            SELECT 1 FROM public.residents_apartments ra
            WHERE ra.apartment_id = invoices.apartment_id AND ra.user_id = auth.uid()
        )
    );

CREATE POLICY "invoices_write_admin" ON public.invoices
    FOR ALL TO authenticated
    USING (public.is_staff_or_management())
    WITH CHECK (public.is_staff_or_management());

-- 6. Invoice items policies
CREATE POLICY "invoice_items_read" ON public.invoice_items
    FOR SELECT TO authenticated
    USING (
        public.is_staff_or_management() OR
        EXISTS (
            SELECT 1 FROM public.invoices inv
            JOIN public.residents_apartments ra ON ra.apartment_id = inv.apartment_id
            WHERE inv.id = invoice_items.invoice_id AND ra.user_id = auth.uid()
        )
    );

CREATE POLICY "invoice_items_write_admin" ON public.invoice_items
    FOR ALL TO authenticated
    USING (public.is_staff_or_management())
    WITH CHECK (public.is_staff_or_management());

-- 7. Vehicles policies
CREATE POLICY "vehicles_read" ON public.vehicles
    FOR SELECT TO authenticated
    USING (
        public.is_staff_or_management() OR
        user_id = auth.uid() OR
        EXISTS (
            SELECT 1 FROM public.residents_apartments ra
            WHERE ra.apartment_id = vehicles.apartment_id AND ra.user_id = auth.uid()
        )
    );

CREATE POLICY "vehicles_insert_resident" ON public.vehicles
    FOR INSERT TO authenticated
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "vehicles_manage_admin" ON public.vehicles
    FOR ALL TO authenticated
    USING (public.is_staff_or_management())
    WITH CHECK (public.is_staff_or_management());

-- 8. Building Amenities policies
CREATE POLICY "amenities_read_all" ON public.building_amenities
    FOR SELECT TO authenticated USING (true);

CREATE POLICY "amenities_manage_admin" ON public.building_amenities
    FOR ALL TO authenticated
    USING (public.is_staff_or_management())
    WITH CHECK (public.is_staff_or_management());

-- 9. Amenity Bookings policies
CREATE POLICY "amenity_bookings_read" ON public.amenity_bookings
    FOR SELECT TO authenticated
    USING (booked_by = auth.uid() OR public.is_staff_or_management());

CREATE POLICY "amenity_bookings_insert_resident" ON public.amenity_bookings
    FOR INSERT TO authenticated
    WITH CHECK (booked_by = auth.uid());

CREATE POLICY "amenity_bookings_update" ON public.amenity_bookings
    FOR UPDATE TO authenticated
    USING (booked_by = auth.uid() OR public.is_staff_or_management())
    WITH CHECK (booked_by = auth.uid() OR public.is_staff_or_management());

-- 10. Amenity Maintenance Windows policies
CREATE POLICY "maintenance_windows_read" ON public.amenity_maintenance_windows
    FOR SELECT TO authenticated USING (true);

CREATE POLICY "maintenance_windows_write_admin" ON public.amenity_maintenance_windows
    FOR ALL TO authenticated
    USING (public.is_staff_or_management())
    WITH CHECK (public.is_staff_or_management());

-- 11. Meter Reading Submissions policies
CREATE POLICY "meter_submissions_read" ON public.meter_reading_submissions
    FOR SELECT TO authenticated
    USING (
        public.is_staff_or_management() OR
        submitted_by = auth.uid() OR
        EXISTS (
            SELECT 1 FROM public.residents_apartments ra
            WHERE ra.apartment_id = meter_reading_submissions.apartment_id AND ra.user_id = auth.uid()
        )
    );

CREATE POLICY "meter_submissions_insert" ON public.meter_reading_submissions
    FOR INSERT TO authenticated
    WITH CHECK (submitted_by = auth.uid() OR public.is_staff_or_management());

CREATE POLICY "meter_submissions_update_admin" ON public.meter_reading_submissions
    FOR UPDATE TO authenticated
    USING (public.is_staff_or_management())
    WITH CHECK (public.is_staff_or_management());

-- 12. Payment Transactions policies
CREATE POLICY "payment_transactions_read" ON public.payment_transactions
    FOR SELECT TO authenticated
    USING (user_id = auth.uid() OR public.is_staff_or_management());

CREATE POLICY "payment_transactions_insert" ON public.payment_transactions
    FOR INSERT TO authenticated
    WITH CHECK (user_id = auth.uid() OR public.is_staff_or_management());

CREATE POLICY "payment_transactions_manage_admin" ON public.payment_transactions
    FOR UPDATE TO authenticated
    USING (public.is_staff_or_management())
    WITH CHECK (public.is_staff_or_management());

-- 13. Announcements policies
CREATE POLICY "announcements_read_all" ON public.announcements
    FOR SELECT TO authenticated USING (true);

CREATE POLICY "announcements_write_admin" ON public.announcements
    FOR ALL TO authenticated
    USING (public.is_staff_or_management())
    WITH CHECK (public.is_staff_or_management());

-- 14. Issue Reports policies
CREATE POLICY "issue_reports_read" ON public.issue_reports
    FOR SELECT TO authenticated
    USING (
        public.is_staff_or_management() OR
        reporter_id = auth.uid() OR
        EXISTS (
            SELECT 1 FROM public.residents_apartments ra
            WHERE ra.apartment_id = issue_reports.apartment_id AND ra.user_id = auth.uid()
        )
    );

CREATE POLICY "issue_reports_insert" ON public.issue_reports
    FOR INSERT TO authenticated
    WITH CHECK (reporter_id = auth.uid());

CREATE POLICY "issue_reports_update" ON public.issue_reports
    FOR UPDATE TO authenticated
    USING (reporter_id = auth.uid() OR public.is_staff_or_management())
    WITH CHECK (reporter_id = auth.uid() OR public.is_staff_or_management());

-- 15. Issue Images policies
CREATE POLICY "issue_images_read" ON public.issue_images
    FOR SELECT TO authenticated USING (true);

CREATE POLICY "issue_images_insert" ON public.issue_images
    FOR INSERT TO authenticated WITH CHECK (true);

-- 16. Fee schedules policies
CREATE POLICY "fee_schedules_read" ON public.fee_schedules
    FOR SELECT TO authenticated USING (true);

CREATE POLICY "fee_schedules_manage_admin" ON public.fee_schedules
    FOR ALL TO authenticated
    USING (public.is_staff_or_management())
    WITH CHECK (public.is_staff_or_management());

CREATE POLICY "tiered_tariffs_read" ON public.tiered_tariffs
    FOR SELECT TO authenticated USING (true);

CREATE POLICY "tiered_tariffs_manage_admin" ON public.tiered_tariffs
    FOR ALL TO authenticated
    USING (public.is_staff_or_management())
    WITH CHECK (public.is_staff_or_management());

-- ==============================================================================
-- PART 7: TRIGGERS & AUTOMATION
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_set_updated_at_users ON public.users;
CREATE TRIGGER trigger_set_updated_at_users
    BEFORE UPDATE ON public.users
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trigger_set_updated_at_invoices ON public.invoices;
CREATE TRIGGER trigger_set_updated_at_invoices
    BEFORE UPDATE ON public.invoices
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trigger_set_updated_at_amenities ON public.building_amenities;
CREATE TRIGGER trigger_set_updated_at_amenities
    BEFORE UPDATE ON public.building_amenities
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trigger_set_updated_at_amenity_bookings ON public.amenity_bookings;
CREATE TRIGGER trigger_set_updated_at_amenity_bookings
    BEFORE UPDATE ON public.amenity_bookings
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Trigger tự động đồng bộ khi có user mới từ Supabase Auth
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
BEGIN
    INSERT INTO public.users (id, full_name, email, role, phone, is_active, is_locked)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'full_name', 'Cư dân mới'),
        NEW.email,
        COALESCE((NEW.raw_user_meta_data->>'role')::public.user_role, 'resident'),
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

-- ==============================================================================
-- PART 8: CANONICAL RPC BUSINESS FUNCTIONS
-- ==============================================================================

-- 1. simulate_unified_payment (Canonical Signature)
CREATE OR REPLACE FUNCTION public.simulate_unified_payment(
    p_reference_id UUID,
    p_payment_type TEXT DEFAULT 'INVOICE',
    p_payment_method TEXT DEFAULT 'DEMO',
    p_outcome TEXT DEFAULT 'SUCCESS',
    p_failure_reason TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_user_id UUID;
    v_booking RECORD;
    v_invoice RECORD;
    v_target_apartment UUID;
    v_tx_id UUID;
    v_now TIMESTAMPTZ := now();
    v_tx_code TEXT;
    v_effective_type TEXT;
    v_amount NUMERIC(12,2) := 0.0;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Chưa đăng nhập';
    END IF;

    v_effective_type := UPPER(COALESCE(p_payment_type, 'INVOICE'));

    IF v_effective_type = 'INVOICE' THEN
        SELECT * INTO v_invoice
        FROM public.invoices
        WHERE id = p_reference_id
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Không tìm thấy hóa đơn';
        END IF;

        IF v_invoice.status = 'paid' THEN
            RETURN jsonb_build_object('success', false, 'message', 'Hóa đơn này đã được thanh toán trước đó.');
        END IF;

        v_target_apartment := v_invoice.apartment_id;
        v_amount := v_invoice.total_amount;
        v_tx_code := 'INV-' || to_char(v_now, 'YYYYMMDD') || '-' || upper(substring(gen_random_uuid()::text, 1, 6));

        IF UPPER(p_outcome) = 'SUCCESS' THEN
            UPDATE public.invoices
            SET status = 'paid',
                paid_at = v_now,
                payment_method = p_payment_method,
                updated_at = v_now
            WHERE id = p_reference_id;

            INSERT INTO public.payment_transactions (
                reference_id, invoice_id, user_id, apartment_id, payment_type,
                payment_method, amount, status, receipt_number, created_at, updated_at
            ) VALUES (
                p_reference_id, p_reference_id, v_user_id, v_target_apartment, 'INVOICE',
                p_payment_method, v_amount, 'SUCCESS', v_tx_code, v_now, v_now
            ) RETURNING id INTO v_tx_id;

            RETURN jsonb_build_object(
                'success', true,
                'transaction_id', v_tx_id,
                'receipt_number', v_tx_code,
                'message', 'Thanh toán hóa đơn thành công'
            );
        ELSE
            INSERT INTO public.payment_transactions (
                reference_id, invoice_id, user_id, apartment_id, payment_type,
                payment_method, amount, status, failure_reason, created_at, updated_at
            ) VALUES (
                p_reference_id, p_reference_id, v_user_id, v_target_apartment, 'INVOICE',
                p_payment_method, v_amount, 'FAILED', COALESCE(p_failure_reason, 'Giao dịch thất bại'), v_now, v_now
            ) RETURNING id INTO v_tx_id;

            RETURN jsonb_build_object(
                'success', false,
                'transaction_id', v_tx_id,
                'message', COALESCE(p_failure_reason, 'Giao dịch thất bại')
            );
        END IF;

    ELSIF v_effective_type IN ('AMENITY', 'SERVICE') THEN
        SELECT * INTO v_booking
        FROM public.amenity_bookings
        WHERE id = p_reference_id
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Không tìm thấy lượt đặt tiện ích';
        END IF;

        IF v_booking.status = 'confirmed' AND v_booking.payment_status = 'paid' THEN
            RETURN jsonb_build_object('success', false, 'message', 'Lịch đặt này đã được thanh toán và xác nhận.');
        END IF;

        v_target_apartment := v_booking.apartment_id;
        v_amount := COALESCE(v_booking.fee_amount, 0) + COALESCE(v_booking.deposit_amount, 0);
        v_tx_code := 'AMN-' || to_char(v_now, 'YYYYMMDD') || '-' || upper(substring(gen_random_uuid()::text, 1, 6));

        IF UPPER(p_outcome) = 'SUCCESS' THEN
            UPDATE public.amenity_bookings
            SET status = 'confirmed',
                payment_status = 'paid',
                deposit_status = CASE WHEN COALESCE(deposit_amount, 0) > 0 THEN 'paid' ELSE deposit_status END,
                updated_at = v_now
            WHERE id = p_reference_id;

            INSERT INTO public.payment_transactions (
                reference_id, booking_id, user_id, apartment_id, payment_type,
                payment_method, amount, status, receipt_number, created_at, updated_at
            ) VALUES (
                p_reference_id, p_reference_id, v_user_id, v_target_apartment, 'AMENITY',
                p_payment_method, v_amount, 'SUCCESS', v_tx_code, v_now, v_now
            ) RETURNING id INTO v_tx_id;

            RETURN jsonb_build_object(
                'success', true,
                'transaction_id', v_tx_id,
                'receipt_number', v_tx_code,
                'message', 'Thanh toán tiện ích thành công'
            );
        ELSE
            INSERT INTO public.payment_transactions (
                reference_id, booking_id, user_id, apartment_id, payment_type,
                payment_method, amount, status, failure_reason, created_at, updated_at
            ) VALUES (
                p_reference_id, p_reference_id, v_user_id, v_target_apartment, 'AMENITY',
                p_payment_method, v_amount, 'FAILED', COALESCE(p_failure_reason, 'Giao dịch thất bại'), v_now, v_now
            ) RETURNING id INTO v_tx_id;

            RETURN jsonb_build_object(
                'success', false,
                'transaction_id', v_tx_id,
                'message', COALESCE(p_failure_reason, 'Giao dịch thất bại')
            );
        END IF;
    ELSE
        RAISE EXCEPTION 'Loại thanh toán không hợp lệ: %', p_payment_type;
    END IF;
END;
$$;

-- 2. reschedule_amenity_booking (Canonical Definition & Fix Column Reference)
CREATE OR REPLACE FUNCTION public.reschedule_amenity_booking(
    p_booking_id UUID,
    p_new_date DATE,
    p_new_time_slot VARCHAR,
    p_new_guests_count INT DEFAULT NULL,
    p_new_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_user_id UUID;
    v_booking RECORD;
    v_amenity RECORD;
    v_day_start TIMESTAMPTZ;
    v_day_end TIMESTAMPTZ;
    v_final_guests INT;
    v_current_slot_capacity INT;
    v_lock_id BIGINT;
    v_new_fee NUMERIC(12,2);
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Chưa đăng nhập vào hệ thống.';
    END IF;

    SELECT * INTO v_booking
    FROM public.amenity_bookings
    WHERE id = p_booking_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Không tìm thấy lượt đặt tiện ích này.';
    END IF;

    IF v_booking.booked_by <> v_user_id AND NOT public.is_staff_or_management() THEN
        RAISE EXCEPTION 'Bạn không có quyền đổi lịch của người khác.';
    END IF;

    IF v_booking.status = 'cancelled' THEN
        RAISE EXCEPTION 'Lịch đặt đã bị hủy, không thể đổi lịch.';
    END IF;

    IF v_booking.status = 'completed' THEN
        RAISE EXCEPTION 'Lịch đặt đã hoàn thành sử dụng, không thể đổi lịch.';
    END IF;

    IF p_new_date < CURRENT_DATE THEN
        RAISE EXCEPTION 'Không thể đổi lịch sang ngày trong quá khứ.';
    END IF;

    SELECT * INTO v_amenity
    FROM public.building_amenities
    WHERE id = v_booking.amenity_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Không tìm thấy tiện ích tương ứng.';
    END IF;

    -- Kiểm tra bảo trì chuẩn TIMESTAMPTZ start_time / end_time
    v_day_start := p_new_date::timestamp at time zone 'Asia/Ho_Chi_Minh';
    v_day_end := (p_new_date + 1)::timestamp at time zone 'Asia/Ho_Chi_Minh' - interval '1 second';

    IF EXISTS (
        SELECT 1 FROM public.amenity_maintenance_windows
        WHERE amenity_id = v_booking.amenity_id
          AND start_time <= v_day_end
          AND end_time >= v_day_start
    ) THEN
        RAISE EXCEPTION 'Tiện ích đang trong thời gian bảo trì vào ngày đã chọn.';
    END IF;

    -- Khóa Advisory chống race condition
    v_lock_id := hashtext(v_booking.amenity_id::text || '_' || p_new_date::text || '_' || p_new_time_slot);
    PERFORM pg_advisory_xact_lock(v_lock_id);

    v_final_guests := COALESCE(p_new_guests_count, v_booking.guests_count, 1);
    IF v_final_guests < 1 THEN v_final_guests := 1; END IF;
    IF v_final_guests > v_amenity.max_capacity THEN
        RAISE EXCEPTION 'Số khách vượt quá sức chứa tối đa của tiện ích (% người)', v_amenity.max_capacity;
    END IF;

    -- Kiểm tra dung lượng còn trống
    IF v_amenity.booking_type = 'exclusive' THEN
        SELECT COUNT(*) INTO v_current_slot_capacity
        FROM public.amenity_bookings
        WHERE amenity_id = v_booking.amenity_id
          AND booking_date = p_new_date
          AND time_slot = p_new_time_slot
          AND status IN ('confirmed', 'pending_payment', 'completed')
          AND id <> p_booking_id;

        IF v_current_slot_capacity > 0 THEN
            RAISE EXCEPTION 'Khung giờ mới đã có người đặt trước (Độc quyền).';
        END IF;
    ELSE
        SELECT COALESCE(SUM(guests_count), 0) INTO v_current_slot_capacity
        FROM public.amenity_bookings
        WHERE amenity_id = v_booking.amenity_id
          AND booking_date = p_new_date
          AND time_slot = p_new_time_slot
          AND status IN ('confirmed', 'pending_payment', 'completed')
          AND id <> p_booking_id;

        IF (v_current_slot_capacity + v_final_guests) > v_amenity.max_capacity THEN
            RAISE EXCEPTION 'Khung giờ mới không đủ chỗ cho % khách (chỉ còn trống % chỗ).',
                v_final_guests, (v_amenity.max_capacity - v_current_slot_capacity);
        END IF;
    END IF;

    -- Cập nhật booking
    v_new_fee := CASE 
        WHEN v_amenity.booking_type = 'shared' THEN COALESCE(v_amenity.fee_amount, 0) * v_final_guests
        ELSE COALESCE(v_amenity.fee_amount, 0)
    END;

    UPDATE public.amenity_bookings
    SET booking_date = p_new_date,
        time_slot = p_new_time_slot,
        guests_count = v_final_guests,
        fee_amount = v_new_fee,
        notes = COALESCE(p_new_notes, notes),
        updated_at = now()
    WHERE id = p_booking_id;

    -- Cập nhật giao dịch PENDING nếu có (sửa lỗi so sánh UUID với text)
    UPDATE public.payment_transactions
    SET amount = (v_new_fee + COALESCE(v_booking.deposit_amount, 0)),
        updated_at = now()
    WHERE booking_id = p_booking_id
      AND status = 'PENDING';

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Đổi lịch tiện ích thành công.',
        'booking_id', p_booking_id
    );
END;
$$;

-- 3. book_amenity_slot (Canonical Definition with Advisory Locking)
CREATE OR REPLACE FUNCTION public.book_amenity_slot(
    p_amenity_id UUID,
    p_apartment_id UUID,
    p_booking_date DATE,
    p_time_slot VARCHAR,
    p_guests_count INT DEFAULT 1,
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_user_id UUID;
    v_amenity RECORD;
    v_day_start TIMESTAMPTZ;
    v_day_end TIMESTAMPTZ;
    v_current_slot_capacity INT := 0;
    v_lock_id BIGINT;
    v_booking_id UUID;
    v_status public.amenity_booking_status := 'confirmed';
    v_fee NUMERIC(12,2) := 0.0;
    v_deposit NUMERIC(12,2) := 0.0;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Chưa đăng nhập vào hệ thống.';
    END IF;

    IF p_booking_date < CURRENT_DATE THEN
        RAISE EXCEPTION 'Không thể đặt lịch ngày trong quá khứ.';
    END IF;

    SELECT * INTO v_amenity
    FROM public.building_amenities
    WHERE id = p_amenity_id;

    IF NOT FOUND OR NOT v_amenity.is_active THEN
        RAISE EXCEPTION 'Tiện ích không tồn tại hoặc đang tạm ngưng phục vụ.';
    END IF;

    -- Kiểm tra bảo trì
    v_day_start := p_booking_date::timestamp at time zone 'Asia/Ho_Chi_Minh';
    v_day_end := (p_booking_date + 1)::timestamp at time zone 'Asia/Ho_Chi_Minh' - interval '1 second';

    IF EXISTS (
        SELECT 1 FROM public.amenity_maintenance_windows
        WHERE amenity_id = p_amenity_id
          AND start_time <= v_day_end
          AND end_time >= v_day_start
    ) THEN
        RAISE EXCEPTION 'Tiện ích đang trong thời gian bảo trì vào ngày này.';
    END IF;

    -- Khóa Advisory Transaction để tránh race condition
    v_lock_id := hashtext(p_amenity_id::text || '_' || p_booking_date::text || '_' || p_time_slot);
    PERFORM pg_advisory_xact_lock(v_lock_id);

    -- Đếm số chỗ đã dùng (không dùng FOR UPDATE trên hàm aggregate)
    IF v_amenity.booking_type = 'exclusive' THEN
        SELECT COUNT(*) INTO v_current_slot_capacity
        FROM public.amenity_bookings
        WHERE amenity_id = p_amenity_id
          AND booking_date = p_booking_date
          AND time_slot = p_time_slot
          AND status IN ('confirmed', 'pending_payment', 'completed');

        IF v_current_slot_capacity > 0 THEN
            v_status := 'waitlist';
        END IF;
    ELSE
        SELECT COALESCE(SUM(guests_count), 0) INTO v_current_slot_capacity
        FROM public.amenity_bookings
        WHERE amenity_id = p_amenity_id
          AND booking_date = p_booking_date
          AND time_slot = p_time_slot
          AND status IN ('confirmed', 'pending_payment', 'completed');

        IF (v_current_slot_capacity + p_guests_count) > v_amenity.max_capacity THEN
            v_status := 'waitlist';
        END IF;
    END IF;

    -- Tính phí
    IF v_status <> 'waitlist' THEN
        v_fee := CASE 
            WHEN v_amenity.booking_type = 'shared' THEN COALESCE(v_amenity.fee_amount, 0) * p_guests_count
            ELSE COALESCE(v_amenity.fee_amount, 0)
        END;
        v_deposit := COALESCE(v_amenity.deposit_amount, 0);

        IF (v_fee + v_deposit) > 0 THEN
            v_status := 'pending_payment';
        ELSE
            v_status := 'confirmed';
        END IF;
    END IF;

    INSERT INTO public.amenity_bookings (
        amenity_id, apartment_id, booked_by, booking_date, time_slot,
        guests_count, status, fee_amount, deposit_amount, deposit_status,
        payment_status, notes, created_at, updated_at
    ) VALUES (
        p_amenity_id, p_apartment_id, v_user_id, p_booking_date, p_time_slot,
        p_guests_count, v_status, v_fee, v_deposit,
        CASE WHEN v_deposit > 0 THEN 'pending' ELSE 'none' END,
        CASE WHEN (v_fee + v_deposit) > 0 THEN 'unpaid' ELSE 'none' END,
        p_notes, now(), now()
    ) RETURNING id INTO v_booking_id;

    RETURN jsonb_build_object(
        'success', true,
        'booking_id', v_booking_id,
        'status', v_status,
        'fee_amount', v_fee,
        'deposit_amount', v_deposit,
        'message', CASE 
            WHEN v_status = 'waitlist' THEN 'Khung giờ đã kín chỗ, bạn đã được thêm vào danh sách chờ.'
            WHEN v_status = 'pending_payment' THEN 'Đặt chỗ thành công! Vui lòng thanh toán phí dịch vụ.'
            ELSE 'Đặt tiện ích thành công!'
        END
    );
END;
$$;

-- 4. cancel_amenity_booking (Canonical Definition)
CREATE OR REPLACE FUNCTION public.cancel_amenity_booking(p_booking_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_user_id UUID;
    v_booking RECORD;
    v_lock_id BIGINT;
    v_amenity RECORD;
    v_next_waitlist RECORD;
    v_slot_avail INT;
    v_slot_used INT;
    v_promoted_fee NUMERIC(12,2);
    v_promoted_deposit NUMERIC(12,2);
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Chưa đăng nhập.';
    END IF;

    SELECT * INTO v_booking
    FROM public.amenity_bookings
    WHERE id = p_booking_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Không tìm thấy lịch đặt.';
    END IF;

    IF v_booking.booked_by <> v_user_id AND NOT public.is_staff_or_management() THEN
        RAISE EXCEPTION 'Không có quyền hủy lịch này.';
    END IF;

    IF v_booking.status = 'cancelled' THEN
        RETURN jsonb_build_object('success', false, 'message', 'Lịch này đã được hủy trước đó.');
    END IF;

    SELECT * INTO v_amenity
    FROM public.building_amenities
    WHERE id = v_booking.amenity_id;

    v_lock_id := hashtext(v_booking.amenity_id::text || '_' || v_booking.booking_date::text || '_' || v_booking.time_slot);
    PERFORM pg_advisory_xact_lock(v_lock_id);

    UPDATE public.amenity_bookings
    SET status = 'cancelled', updated_at = now()
    WHERE id = p_booking_id;

    -- Đôn slot cho danh sách chờ (Waitlist FIFO)
    IF v_booking.status IN ('confirmed', 'pending_payment') THEN
        SELECT COALESCE(SUM(guests_count), 0) INTO v_slot_used
        FROM public.amenity_bookings
        WHERE amenity_id = v_booking.amenity_id
          AND booking_date = v_booking.booking_date
          AND time_slot = v_booking.time_slot
          AND status IN ('confirmed', 'pending_payment');

        v_slot_avail := v_amenity.max_capacity - v_slot_used;

        SELECT * INTO v_next_waitlist
        FROM public.amenity_bookings
        WHERE amenity_id = v_booking.amenity_id
          AND booking_date = v_booking.booking_date
          AND time_slot = v_booking.time_slot
          AND status = 'waitlist'
        ORDER BY created_at ASC
        LIMIT 1
        FOR UPDATE;

        IF FOUND THEN
            IF (v_amenity.booking_type = 'exclusive') OR (v_next_waitlist.guests_count <= v_slot_avail) THEN
                v_promoted_fee := CASE 
                    WHEN v_amenity.booking_type = 'shared' THEN COALESCE(v_amenity.fee_amount, 0) * v_next_waitlist.guests_count
                    ELSE COALESCE(v_amenity.fee_amount, 0)
                END;
                v_promoted_deposit := COALESCE(v_amenity.deposit_amount, 0);

                UPDATE public.amenity_bookings
                SET status = CASE WHEN (v_promoted_fee + v_promoted_deposit) > 0 THEN 'pending_payment' ELSE 'confirmed' END,
                    fee_amount = v_promoted_fee,
                    deposit_amount = v_promoted_deposit,
                    updated_at = now()
                WHERE id = v_next_waitlist.id;
            END IF;
        END IF;
    END IF;

    RETURN jsonb_build_object('success', true, 'message', 'Đã hủy lịch đặt thành công.');
END;
$$;

-- 5. confirm_payment (Management Manual Invoice Settlement)
CREATE OR REPLACE FUNCTION public.confirm_payment(p_invoice_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_user_id UUID;
    v_invoice RECORD;
    v_tx_code TEXT;
    v_now TIMESTAMPTZ := now();
    v_tx_id UUID;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL OR NOT public.is_staff_or_management() THEN
        RAISE EXCEPTION 'Chỉ Ban Quản Lý mới có quyền xác nhận thanh toán.';
    END IF;

    SELECT * INTO v_invoice
    FROM public.invoices
    WHERE id = p_invoice_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Không tìm thấy hóa đơn.';
    END IF;

    IF v_invoice.status = 'paid' THEN
        RETURN jsonb_build_object('success', false, 'message', 'Hóa đơn này đã được xác nhận thanh toán trước đó.');
    END IF;

    v_tx_code := 'MAN-' || to_char(v_now, 'YYYYMMDD') || '-' || upper(substring(gen_random_uuid()::text, 1, 6));

    UPDATE public.invoices
    SET status = 'paid',
        paid_at = v_now,
        payment_method = COALESCE(payment_method, 'cash'),
        updated_at = v_now
    WHERE id = p_invoice_id;

    INSERT INTO public.payment_transactions (
        reference_id, invoice_id, user_id, apartment_id, payment_type,
        payment_method, amount, status, receipt_number, created_at, updated_at
    ) VALUES (
        p_invoice_id, p_invoice_id, v_user_id, v_invoice.apartment_id, 'INVOICE',
        COALESCE(v_invoice.payment_method, 'cash'), v_invoice.total_amount, 'SUCCESS',
        v_tx_code, v_now, v_now
    ) RETURNING id INTO v_tx_id;

    RETURN jsonb_build_object(
        'success', true,
        'transaction_id', v_tx_id,
        'receipt_number', v_tx_code,
        'message', 'Đã xác nhận gạch nợ hóa đơn thành công.'
    );
END;
$$;

-- 6. record_manual_amenity_payment (Management Manual Amenity Settlement)
CREATE OR REPLACE FUNCTION public.record_manual_amenity_payment(
    p_booking_id UUID,
    p_amount NUMERIC,
    p_payment_method TEXT DEFAULT 'cash',
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_user_id UUID;
    v_booking RECORD;
    v_tx_code TEXT;
    v_now TIMESTAMPTZ := now();
    v_tx_id UUID;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL OR NOT public.is_staff_or_management() THEN
        RAISE EXCEPTION 'Chỉ Ban Quản Lý mới có quyền xác nhận thanh toán tiện ích.';
    END IF;

    SELECT * INTO v_booking
    FROM public.amenity_bookings
    WHERE id = p_booking_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Không tìm thấy lịch đặt tiện ích.';
    END IF;

    v_tx_code := 'MAM-' || to_char(v_now, 'YYYYMMDD') || '-' || upper(substring(gen_random_uuid()::text, 1, 6));

    UPDATE public.amenity_bookings
    SET status = 'confirmed',
        payment_status = 'paid',
        deposit_status = CASE WHEN COALESCE(deposit_amount, 0) > 0 THEN 'paid' ELSE deposit_status END,
        notes = CASE WHEN p_notes IS NOT NULL THEN COALESCE(notes, '') || ' | ' || p_notes ELSE notes END,
        updated_at = v_now
    WHERE id = p_booking_id;

    INSERT INTO public.payment_transactions (
        reference_id, booking_id, user_id, apartment_id, payment_type,
        payment_method, amount, status, receipt_number, created_at, updated_at
    ) VALUES (
        p_booking_id, p_booking_id, v_user_id, v_booking.apartment_id, 'AMENITY',
        p_payment_method, p_amount, 'SUCCESS', v_tx_code, v_now, v_now
    ) RETURNING id INTO v_tx_id;

    RETURN jsonb_build_object(
        'success', true,
        'transaction_id', v_tx_id,
        'receipt_number', v_tx_code,
        'message', 'Đã ghi nhận thanh toán tiền mặt tiện ích thành công.'
    );
END;
$$;

-- 7. approve_meter_reading & reject_meter_reading
CREATE OR REPLACE FUNCTION public.approve_meter_reading(p_submission_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_user_id UUID;
    v_sub RECORD;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL OR NOT public.is_staff_or_management() THEN
        RAISE EXCEPTION 'Chỉ nhân viên hoặc BQL mới có quyền duyệt chỉ số công tơ.';
    END IF;

    SELECT * INTO v_sub
    FROM public.meter_reading_submissions
    WHERE id = p_submission_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Không tìm thấy bản ghi chỉ số công tơ.';
    END IF;

    IF v_sub.status = 'approved' THEN
        RETURN jsonb_build_object('success', false, 'message', 'Chỉ số này đã được duyệt trước đó.');
    END IF;

    UPDATE public.meter_reading_submissions
    SET status = 'approved',
        approved_by = v_user_id,
        approved_at = now(),
        updated_at = now()
    WHERE id = p_submission_id;

    RETURN jsonb_build_object('success', true, 'message', 'Đã phê duyệt chỉ số công tơ thành công.');
END;
$$;

CREATE OR REPLACE FUNCTION public.reject_meter_reading(
    p_submission_id UUID,
    p_reason TEXT DEFAULT 'Chỉ số không hợp lý hoặc hình ảnh mờ'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_user_id UUID;
    v_sub RECORD;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL OR NOT public.is_staff_or_management() THEN
        RAISE EXCEPTION 'Chỉ nhân viên hoặc BQL mới có quyền từ chối chỉ số.';
    END IF;

    SELECT * INTO v_sub
    FROM public.meter_reading_submissions
    WHERE id = p_submission_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Không tìm thấy bản ghi chỉ số công tơ.';
    END IF;

    UPDATE public.meter_reading_submissions
    SET status = 'rejected',
        rejection_reason = p_reason,
        approved_by = v_user_id,
        approved_at = now(),
        updated_at = now()
    WHERE id = p_submission_id;

    RETURN jsonb_build_object('success', true, 'message', 'Đã từ chối chỉ số công tơ.');
END;
$$;

-- 8. find_apartment_by_code & submit_apartment_link_request
CREATE OR REPLACE FUNCTION public.find_apartment_by_code(p_code VARCHAR)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_apt RECORD;
BEGIN
    SELECT id, code, block, floor, room, area, is_empty
    INTO v_apt
    FROM public.apartments
    WHERE UPPER(code) = UPPER(TRIM(p_code));

    IF NOT FOUND THEN
        RETURN jsonb_build_object('found', false);
    END IF;

    RETURN jsonb_build_object(
        'found', true,
        'id', v_apt.id,
        'code', v_apt.code,
        'block', v_apt.block,
        'floor', v_apt.floor,
        'room', v_apt.room,
        'area', v_apt.area,
        'is_empty', v_apt.is_empty
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.submit_apartment_link_request(
    p_apartment_id UUID,
    p_relation_role public.apartment_relation_role DEFAULT 'member'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_user_id UUID;
    v_req_id UUID;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Chưa đăng nhập.';
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.residents_apartments
        WHERE user_id = v_user_id AND apartment_id = p_apartment_id
    ) THEN
        RETURN jsonb_build_object('success', false, 'message', 'Bạn đã là cư dân của căn hộ này.');
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.apartment_link_requests
        WHERE user_id = v_user_id AND apartment_id = p_apartment_id AND status = 'pending'
    ) THEN
        RETURN jsonb_build_object('success', false, 'message', 'Yêu cầu liên kết đang chờ Ban Quản Lý xét duyệt.');
    END IF;

    INSERT INTO public.apartment_link_requests (
        user_id, apartment_id, requested_relation_role, status, created_at, updated_at
    ) VALUES (
        v_user_id, p_apartment_id, p_relation_role, 'pending', now(), now()
    ) RETURNING id INTO v_req_id;

    RETURN jsonb_build_object('success', true, 'request_id', v_req_id, 'message', 'Gửi yêu cầu liên kết thành công.');
END;
$$;

-- 9. User Admin RPCs
CREATE OR REPLACE FUNCTION public.admin_toggle_user_status(
    p_target_user_id UUID,
    p_is_active BOOLEAN,
    p_is_locked BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
BEGIN
    IF NOT public.is_staff_or_management() THEN
        RAISE EXCEPTION 'Chỉ Quản trị viên mới có quyền cập nhật trạng thái người dùng.';
    END IF;

    UPDATE public.users
    SET is_active = p_is_active,
        is_locked = p_is_locked,
        updated_at = now()
    WHERE id = p_target_user_id;

    RETURN jsonb_build_object('success', true, 'message', 'Cập nhật trạng thái người dùng thành công.');
END;
$$;

-- ==============================================================================
-- PART 9: STORAGE BUCKETS SETUP
-- ==============================================================================

INSERT INTO storage.buckets (id, name, public)
VALUES 
    ('issue-images', 'issue-images', true),
    ('meter-readings', 'meter-readings', true),
    ('avatars', 'avatars', true)
ON CONFLICT (id) DO UPDATE SET public = EXCLUDED.public;

-- Cấu hình Storage Policies
CREATE POLICY "Public Read issue-images" ON storage.objects
    FOR SELECT USING (bucket_id = 'issue-images');

CREATE POLICY "Authenticated Insert issue-images" ON storage.objects
    FOR INSERT TO authenticated WITH CHECK (bucket_id = 'issue-images');

CREATE POLICY "Public Read meter-readings" ON storage.objects
    FOR SELECT USING (bucket_id = 'meter-readings');

CREATE POLICY "Authenticated Insert meter-readings" ON storage.objects
    FOR INSERT TO authenticated WITH CHECK (bucket_id = 'meter-readings');

CREATE POLICY "Public Read avatars" ON storage.objects
    FOR SELECT USING (bucket_id = 'avatars');

CREATE POLICY "Authenticated Insert avatars" ON storage.objects
    FOR INSERT TO authenticated WITH CHECK (bucket_id = 'avatars');
