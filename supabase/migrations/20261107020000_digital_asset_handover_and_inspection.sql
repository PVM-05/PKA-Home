-- ==============================================================================
-- Migration: 20261107020000_digital_asset_handover_and_inspection.sql
-- Module: Biên bản bàn giao & kiểm kê tài sản căn hộ số hóa (Move-in / Move-out)
-- ==============================================================================

-- 1. BẢNG DANH MỤC TÀI SẢN CĂN HỘ (apartment_assets)
CREATE TABLE IF NOT EXISTS public.apartment_assets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    apartment_id UUID NOT NULL REFERENCES public.apartments(id) ON DELETE CASCADE,
    building_id UUID NOT NULL REFERENCES public.buildings(id) ON DELETE CASCADE,
    room_area VARCHAR(50) NOT NULL DEFAULT 'living_room', -- living_room, bedroom, kitchen, bathroom, balcony, other
    name VARCHAR(100) NOT NULL,
    asset_code VARCHAR(50),
    quantity INT NOT NULL DEFAULT 1,
    condition VARCHAR(30) NOT NULL DEFAULT 'good' CHECK (condition IN ('brand_new', 'good', 'worn', 'damaged', 'missing')),
    replacement_price NUMERIC(12, 2) NOT NULL DEFAULT 0,
    note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_apt_assets_apt ON public.apartment_assets(apartment_id);
CREATE INDEX IF NOT EXISTS idx_apt_assets_bld ON public.apartment_assets(building_id);

-- 2. BẢNG BIÊN BẢN BÀN GIAO TỔNG THỂ (apartment_handovers)
CREATE TABLE IF NOT EXISTS public.apartment_handovers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    apartment_id UUID NOT NULL REFERENCES public.apartments(id) ON DELETE RESTRICT,
    building_id UUID NOT NULL REFERENCES public.buildings(id) ON DELETE RESTRICT,
    resident_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    contract_id UUID REFERENCES public.residents_apartments(id) ON DELETE SET NULL,
    handover_type VARCHAR(20) NOT NULL CHECK (handover_type IN ('move_in', 'move_out')),
    report_code VARCHAR(30) NOT NULL UNIQUE,
    handover_date DATE NOT NULL DEFAULT CURRENT_DATE,
    conducted_by UUID NOT NULL REFERENCES public.users(id),
    initial_electricity_reading NUMERIC(10, 2) NOT NULL DEFAULT 0,
    initial_water_reading NUMERIC(10, 2) NOT NULL DEFAULT 0,
    deposit_held NUMERIC(12, 2) NOT NULL DEFAULT 0,
    total_deduction NUMERIC(12, 2) NOT NULL DEFAULT 0,
    deposit_refund NUMERIC(12, 2) NOT NULL DEFAULT 0,
    status VARCHAR(30) NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'pending_resident', 'confirmed', 'disputed', 'cancelled')),
    staff_signature_url TEXT,
    staff_signed_at TIMESTAMPTZ,
    resident_signature_url TEXT,
    resident_signed_at TIMESTAMPTZ,
    resident_notes TEXT,
    staff_notes TEXT,
    pdf_url TEXT,
    lookup_code VARCHAR(32) NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_handovers_apt ON public.apartment_handovers(apartment_id);
CREATE INDEX IF NOT EXISTS idx_handovers_bld ON public.apartment_handovers(building_id);
CREATE INDEX IF NOT EXISTS idx_handovers_resident ON public.apartment_handovers(resident_id);
CREATE INDEX IF NOT EXISTS idx_handovers_code ON public.apartment_handovers(report_code);
CREATE INDEX IF NOT EXISTS idx_handovers_status ON public.apartment_handovers(status);

-- 3. BẢNG HẠNG MỤC KIỂM KÊ CHI TIẾT (handover_items)
CREATE TABLE IF NOT EXISTS public.handover_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    handover_id UUID NOT NULL REFERENCES public.apartment_handovers(id) ON DELETE CASCADE,
    asset_id UUID REFERENCES public.apartment_assets(id) ON DELETE SET NULL,
    item_name VARCHAR(100) NOT NULL,
    room_area VARCHAR(50) NOT NULL DEFAULT 'living_room',
    quantity INT NOT NULL DEFAULT 1,
    condition VARCHAR(30) NOT NULL DEFAULT 'good' CHECK (condition IN ('good', 'minor_scratch', 'damaged', 'missing')),
    repair_cost NUMERIC(12, 2) NOT NULL DEFAULT 0,
    note TEXT,
    photos JSONB NOT NULL DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_handover_items_parent ON public.handover_items(handover_id);

-- 4. SEQUENCE VÀ TRIGGERS TỰ ĐỘNG HÓA
CREATE SEQUENCE IF NOT EXISTS public.handover_report_code_seq START 1;

CREATE OR REPLACE FUNCTION public.fn_generate_handover_report_code()
RETURNS TRIGGER AS $$
DECLARE
    v_year_month VARCHAR(6);
    v_seq_num INT;
BEGIN
    IF NEW.report_code IS NULL OR NEW.report_code = '' THEN
        v_year_month := to_char(CURRENT_DATE, 'YYYYMM');
        v_seq_num := nextval('public.handover_report_code_seq');
        NEW.report_code := 'HO-' || v_year_month || '-' || LPAD(v_seq_num::TEXT, 5, '0');
    END IF;

    IF NEW.lookup_code IS NULL OR NEW.lookup_code = '' THEN
        NEW.lookup_code := 'HK-' || upper(substr(md5(random()::text || clock_timestamp()::text), 1, 10));
    END IF;

    -- Tự động tính tiền cọc hoàn lại nếu chưa tính
    IF NEW.handover_type = 'move_out' THEN
        NEW.deposit_refund := GREATEST(0, NEW.deposit_held - NEW.total_deduction);
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_generate_handover_report_code ON public.apartment_handovers;
CREATE TRIGGER trg_generate_handover_report_code
    BEFORE INSERT ON public.apartment_handovers
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_generate_handover_report_code();

-- TRIGGER KHÓA BẤT BIẾN KHI BIÊN BẢN ĐÃ XÁC NHẬN (CONFIRMED)
CREATE OR REPLACE FUNCTION public.fn_enforce_handover_immutability()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_TABLE_NAME = 'apartment_handovers' THEN
        IF OLD.status = 'confirmed' THEN
            -- Cho phép duy nhất cập nhật pdf_url nếu ban đầu chưa sinh kịp
            IF (NEW.pdf_url IS DISTINCT FROM OLD.pdf_url) AND 
               (NEW.status = OLD.status) AND 
               (NEW.resident_signature_url = OLD.resident_signature_url) AND 
               (NEW.staff_signature_url = OLD.staff_signature_url) THEN
                RETURN NEW;
            END IF;
            RAISE EXCEPTION 'Biên bản bàn giao đã xác nhận không thể thay đổi thông tin pháp lý.';
        END IF;
        IF TG_OP = 'DELETE' AND OLD.status = 'confirmed' THEN
            RAISE EXCEPTION 'Không thể xóa biên bản bàn giao đã xác nhận thành công.';
        END IF;
    ELSIF TG_TABLE_NAME = 'handover_items' THEN
        IF EXISTS (
            SELECT 1 FROM public.apartment_handovers h 
            WHERE h.id = OLD.handover_id AND h.status = 'confirmed'
        ) THEN
            RAISE EXCEPTION 'Không thể chỉnh sửa hạng mục kiểm kê của biên bản đã xác nhận.';
        END IF;
    END IF;
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_enforce_handover_immutability ON public.apartment_handovers;
CREATE TRIGGER trg_enforce_handover_immutability
    BEFORE UPDATE OR DELETE ON public.apartment_handovers
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_enforce_handover_immutability();

DROP TRIGGER IF EXISTS trg_enforce_handover_items_immutability ON public.handover_items;
CREATE TRIGGER trg_enforce_handover_items_immutability
    BEFORE UPDATE OR DELETE ON public.handover_items
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_enforce_handover_immutability();

-- 5. THIẾT LẬP SUPABASE STORAGE BUCKET (handover-docs)
INSERT INTO storage.buckets (id, name, public)
VALUES ('handover-docs', 'handover-docs', false)
ON CONFLICT (id) DO UPDATE SET public = false;

-- 6. ROW LEVEL SECURITY (RLS) POLICIES
ALTER TABLE public.apartment_assets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.apartment_handovers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.handover_items ENABLE ROW LEVEL SECURITY;

-- Policies cho apartment_assets:
CREATE POLICY "assets_select_policy" ON public.apartment_assets
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.users u 
            WHERE u.id = auth.uid() AND u.role IN ('admin', 'management')
        )
        OR
        EXISTS (
            SELECT 1 FROM public.residents_apartments ra 
            WHERE ra.apartment_id = apartment_assets.apartment_id 
              AND ra.user_id = auth.uid()
              AND ra.status = 'active'
        )
    );

CREATE POLICY "assets_modify_policy" ON public.apartment_assets
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.users u 
            WHERE u.id = auth.uid() AND u.role IN ('admin', 'management')
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.users u 
            WHERE u.id = auth.uid() AND u.role IN ('admin', 'management')
        )
    );

-- Policies cho apartment_handovers:
CREATE POLICY "handovers_select_policy" ON public.apartment_handovers
    FOR SELECT TO authenticated
    USING (
        conducted_by = auth.uid()
        OR resident_id = auth.uid()
        OR EXISTS (
            SELECT 1 FROM public.users u 
            WHERE u.id = auth.uid() AND u.role IN ('admin', 'management')
        )
        OR EXISTS (
            SELECT 1 FROM public.residents_apartments ra 
            WHERE ra.apartment_id = apartment_handovers.apartment_id 
              AND ra.user_id = auth.uid()
        )
    );

CREATE POLICY "handovers_insert_policy" ON public.apartment_handovers
    FOR INSERT TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.users u 
            WHERE u.id = auth.uid() AND u.role IN ('admin', 'management')
        )
    );

CREATE POLICY "handovers_update_policy" ON public.apartment_handovers
    FOR UPDATE TO authenticated
    USING (
        resident_id = auth.uid()
        OR conducted_by = auth.uid()
        OR EXISTS (
            SELECT 1 FROM public.users u 
            WHERE u.id = auth.uid() AND u.role IN ('admin', 'management')
        )
    );

-- Policies cho handover_items:
CREATE POLICY "handover_items_select_policy" ON public.handover_items
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.apartment_handovers h 
            WHERE h.id = handover_items.handover_id 
              AND (
                  h.conducted_by = auth.uid() 
                  OR h.resident_id = auth.uid()
                  OR EXISTS (SELECT 1 FROM public.users u WHERE u.id = auth.uid() AND u.role IN ('admin', 'management'))
              )
        )
    );

CREATE POLICY "handover_items_modify_policy" ON public.handover_items
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.users u 
            WHERE u.id = auth.uid() AND u.role IN ('admin', 'management')
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.users u 
            WHERE u.id = auth.uid() AND u.role IN ('admin', 'management')
        )
    );

-- Policies cho storage.objects trong handover-docs:
CREATE POLICY "handover_docs_read_policy" ON storage.objects
    FOR SELECT TO authenticated
    USING (bucket_id = 'handover-docs');

CREATE POLICY "handover_docs_insert_policy" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'handover-docs');

