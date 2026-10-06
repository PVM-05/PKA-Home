-- ==============================================================================
-- Migration: 20261006_02_vehicle_rejection_reason_and_limit_fix.sql
-- Mô tả:
-- 1. Bổ sung cột rejection_reason cho bảng vehicles để lưu lý do BQL từ chối.
-- 2. Cập nhật trigger check_vehicle_limits() kiểm tra cả INSERT và UPDATE,
--    chỉ tính hạn mức 2 xe máy cho xe đang hoạt động (status IN ('pending', 'approved')),
--    giải phóng hạn mức cho xe đã bị từ chối (status = 'rejected').
-- ==============================================================================

-- 1. Thêm cột rejection_reason
ALTER TABLE public.vehicles 
ADD COLUMN IF NOT EXISTS rejection_reason TEXT;

-- 2. Cập nhật trigger kiểm tra hạn mức 2 xe máy
CREATE OR REPLACE FUNCTION public.check_vehicle_limits()
RETURNS TRIGGER AS $$
DECLARE
    current_motorbike_count INT;
BEGIN
    -- Chỉ kiểm tra khi là xe máy và bản ghi mới có trạng thái đang hoạt động (pending hoặc approved)
    IF NEW.vehicle_type = 'motorbike' AND NEW.status != 'rejected' THEN
        SELECT count(*) INTO current_motorbike_count
        FROM public.vehicles
        WHERE apartment_id = NEW.apartment_id 
          AND vehicle_type = 'motorbike'
          AND status IN ('pending', 'approved')
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
