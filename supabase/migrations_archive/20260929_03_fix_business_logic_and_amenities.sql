-- ==============================================================================
-- BẢN VÁ LỖI LOGIC NGHIỆP VỤ: XE, ĐẶT LỊCH TIỆN ÍCH VÀ RÀNG BUỘC (PHASE 2)
-- Migration: 20260929_03_fix_business_logic_and_amenities.sql
-- ==============================================================================

-- 1. RÀNG BUỘC DUY NHẤT BIỂN SỐ XE (UNIQUE PLATE NUMBER)
-- ------------------------------------------------------------------------------
-- Biển số xe không được trùng lặp trong toàn bộ khu chung cư (chống phân bổ trùng)
CREATE UNIQUE INDEX IF NOT EXISTS uq_vehicles_plate_number 
ON public.vehicles (upper(trim(plate_number)));


-- 2. BẢO VỆ DỮ LIỆU ĐẶT LỊCH TIỆN ÍCH (AMENITY BOOKINGS UPDATE RESTRICTION)
-- ------------------------------------------------------------------------------
-- Cư dân chỉ được phép cập nhật status (thao tác hủy lịch), không được đổi ngày/giờ/tiện ích
CREATE OR REPLACE FUNCTION public.check_amenity_booking_update()
RETURNS TRIGGER AS $$
BEGIN
    -- Nếu không phải ban quản lý (staff), chỉ được phép thay đổi cột status
    IF NOT public.is_staff() THEN
        IF NEW.amenity_id <> OLD.amenity_id OR 
           NEW.apartment_id <> OLD.apartment_id OR 
           NEW.booked_by <> OLD.booked_by OR 
           NEW.booking_date <> OLD.booking_date OR 
           NEW.time_slot <> OLD.time_slot THEN
            RAISE EXCEPTION 'Cư dân chỉ được phép cập nhật trạng thái hủy lịch, không được sửa đổi thời gian hoặc tiện ích.';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_check_amenity_booking_update ON public.amenity_bookings;
CREATE TRIGGER trg_check_amenity_booking_update
BEFORE UPDATE ON public.amenity_bookings
FOR EACH ROW EXECUTE FUNCTION public.check_amenity_booking_update();


-- 3. RPC SECURITY DEFINER: LẤY LỊCH ĐẶT TIỆN ÍCH KÈM MÃ CĂN HỘ (TRÁNH RLS NULLED)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_amenity_bookings(p_amenity_id UUID, p_date DATE)
RETURNS TABLE(
    id UUID,
    amenity_id UUID,
    apartment_id UUID,
    booked_by UUID,
    booking_date DATE,
    time_slot VARCHAR,
    status VARCHAR,
    apartment_code VARCHAR,
    booker_name TEXT
)
LANGUAGE sql SECURITY DEFINER SET search_path = public, pg_catalog AS $$
  SELECT 
    b.id,
    b.amenity_id,
    b.apartment_id,
    b.booked_by,
    b.booking_date,
    b.time_slot,
    b.status,
    a.code as apartment_code,
    u.full_name as booker_name
  FROM public.amenity_bookings b
  LEFT JOIN public.apartments a ON a.id = b.apartment_id
  LEFT JOIN public.users u ON u.id = b.booked_by
  WHERE b.amenity_id = p_amenity_id 
    AND b.booking_date = p_date 
    AND b.status = 'confirmed';
$$;

REVOKE EXECUTE ON FUNCTION public.get_amenity_bookings(UUID, DATE) FROM anon;
