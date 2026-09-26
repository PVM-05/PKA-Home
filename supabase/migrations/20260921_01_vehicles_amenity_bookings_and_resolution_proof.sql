-- ==============================================================================
-- Migration: 20260921_01_vehicles_amenity_bookings_and_resolution_proof.sql
-- Mô tả:
-- 1. Bảng public.vehicles: Quản lý đăng ký xe căn hộ (giới hạn tối đa 2 xe máy/căn hộ).
-- 2. Bảng public.amenity_bookings: Đặt lịch tiện ích chung (ngăn trùng slot bằng partial unique index).
-- 3. Cột public.issue_images.image_role: Phân loại ảnh báo cáo ('report') và ảnh nghiệm thu ('resolution_proof').
-- ==============================================================================

-- 1. BẢNG VEHICLES (Phương tiện giao thông của căn hộ)
CREATE TABLE IF NOT EXISTS public.vehicles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    apartment_id UUID NOT NULL REFERENCES public.apartments(id) ON DELETE CASCADE,
    plate_number VARCHAR(20) NOT NULL,
    vehicle_type VARCHAR(20) NOT NULL CHECK (vehicle_type IN ('motorbike', 'car')),
    registered_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Chỉ mục tìm kiếm theo căn hộ và biển số
CREATE INDEX IF NOT EXISTS idx_vehicles_apartment_id ON public.vehicles(apartment_id);
CREATE INDEX IF NOT EXISTS idx_vehicles_plate_number ON public.vehicles(plate_number);

-- Ràng buộc logic nghiệp vụ: Tối đa 2 xe máy trên mỗi căn hộ
CREATE OR REPLACE FUNCTION public.check_vehicle_limits()
RETURNS TRIGGER AS $$
DECLARE
    current_motorbike_count INT;
BEGIN
    IF NEW.vehicle_type = 'motorbike' THEN
        SELECT count(*) INTO current_motorbike_count
        FROM public.vehicles
        WHERE apartment_id = NEW.apartment_id 
          AND vehicle_type = 'motorbike'
          AND id != COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000'::uuid);

        IF current_motorbike_count >= 2 THEN
            RAISE EXCEPTION 'Mỗi căn hộ chỉ được đăng ký tối đa 2 xe máy theo quy định của tòa nhà.';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_check_vehicle_limits ON public.vehicles;
CREATE TRIGGER trg_check_vehicle_limits
BEFORE INSERT OR UPDATE ON public.vehicles
FOR EACH ROW EXECUTE FUNCTION public.check_vehicle_limits();

-- Trigger cập nhật updated_at
DROP TRIGGER IF EXISTS trg_vehicles_modtime ON public.vehicles;
CREATE TRIGGER trg_vehicles_modtime
BEFORE UPDATE ON public.vehicles
FOR EACH ROW EXECUTE FUNCTION public.update_modified_column();

-- RLS cho bảng vehicles
ALTER TABLE public.vehicles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Cư dân xem xe căn hộ mình" ON public.vehicles;
CREATE POLICY "Cư dân xem xe căn hộ mình" ON public.vehicles
FOR SELECT USING (
    apartment_id IN (
        SELECT apartment_id FROM public.residents_apartments WHERE user_id = auth.uid()
    ) OR public.is_staff()
);

DROP POLICY IF EXISTS "Cư dân đăng ký xe cho căn hộ mình" ON public.vehicles;
CREATE POLICY "Cư dân đăng ký xe cho căn hộ mình" ON public.vehicles
FOR INSERT WITH CHECK (
    apartment_id IN (
        SELECT apartment_id FROM public.residents_apartments WHERE user_id = auth.uid()
    ) OR public.is_staff()
);

DROP POLICY IF EXISTS "Cư dân xóa xe căn hộ mình" ON public.vehicles;
CREATE POLICY "Cư dân xóa xe căn hộ mình" ON public.vehicles
FOR DELETE USING (
    apartment_id IN (
        SELECT apartment_id FROM public.residents_apartments WHERE user_id = auth.uid()
    ) OR public.is_staff()
);

DROP POLICY IF EXISTS "BQL toàn quyền quản lý xe" ON public.vehicles;
CREATE POLICY "BQL toàn quyền quản lý xe" ON public.vehicles
FOR ALL USING (public.is_staff());


-- 2. BẢNG AMENITY_BOOKINGS (Đặt lịch tiện ích tòa nhà)
CREATE TABLE IF NOT EXISTS public.amenity_bookings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    amenity_id UUID NOT NULL REFERENCES public.building_amenities(id) ON DELETE CASCADE,
    apartment_id UUID NOT NULL REFERENCES public.apartments(id) ON DELETE CASCADE,
    booked_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
    booking_date DATE NOT NULL,
    time_slot VARCHAR(20) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'confirmed' CHECK (status IN ('confirmed', 'cancelled')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Ngăn chặn đặt trùng slot: Chỉ kiểm tra trùng với các đặt chỗ đang 'confirmed'
DROP INDEX IF EXISTS uq_active_amenity_slot;
CREATE UNIQUE INDEX uq_active_amenity_slot 
ON public.amenity_bookings (amenity_id, booking_date, time_slot) 
WHERE (status = 'confirmed');

CREATE INDEX IF NOT EXISTS idx_amenity_bookings_date ON public.amenity_bookings(amenity_id, booking_date);
CREATE INDEX IF NOT EXISTS idx_amenity_bookings_apartment ON public.amenity_bookings(apartment_id);

-- Trigger cập nhật updated_at
DROP TRIGGER IF EXISTS trg_amenity_bookings_modtime ON public.amenity_bookings;
CREATE TRIGGER trg_amenity_bookings_modtime
BEFORE UPDATE ON public.amenity_bookings
FOR EACH ROW EXECUTE FUNCTION public.update_modified_column();

-- RLS cho amenity_bookings
ALTER TABLE public.amenity_bookings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Mọi người xem lịch tiện ích" ON public.amenity_bookings;
CREATE POLICY "Mọi người xem lịch tiện ích" ON public.amenity_bookings
FOR SELECT USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Cư dân đặt lịch tiện ích" ON public.amenity_bookings;
CREATE POLICY "Cư dân đặt lịch tiện ích" ON public.amenity_bookings
FOR INSERT WITH CHECK (
    apartment_id IN (
        SELECT apartment_id FROM public.residents_apartments WHERE user_id = auth.uid()
    ) OR public.is_staff()
);

DROP POLICY IF EXISTS "Người đặt hoặc BQL hủy lịch tiện ích" ON public.amenity_bookings;
CREATE POLICY "Người đặt hoặc BQL hủy lịch tiện ích" ON public.amenity_bookings
FOR UPDATE USING (
    booked_by = auth.uid() OR public.is_staff()
);

DROP POLICY IF EXISTS "BQL xóa lịch tiện ích" ON public.amenity_bookings;
CREATE POLICY "BQL xóa lịch tiện ích" ON public.amenity_bookings
FOR DELETE USING (public.is_staff());


-- 3. CỘT IMAGE_ROLE TRONG BẢNG ISSUE_IMAGES & RLS BỔ SUNG CHO KỸ THUẬT VIÊN
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'issue_images' 
          AND column_name = 'image_role'
    ) THEN
        ALTER TABLE public.issue_images 
        ADD COLUMN image_role VARCHAR(30) NOT NULL DEFAULT 'report' 
        CHECK (image_role IN ('report', 'resolution_proof'));
    END IF;
END $$;

-- Bổ sung Policy cho phép nhân sự (Staff/Kỹ thuật viên) thêm ảnh resolution_proof
DROP POLICY IF EXISTS "Staff thêm issue_images" ON public.issue_images;
CREATE POLICY "Staff thêm issue_images" ON public.issue_images
FOR INSERT WITH CHECK (public.is_staff());

-- Đăng ký Realtime cho các bảng mới
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.vehicles;
        ALTER PUBLICATION supabase_realtime ADD TABLE public.amenity_bookings;
    END IF;
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;
