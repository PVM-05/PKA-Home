-- =========================================================================
-- BỔ SUNG CỘT building_code VÀ floor_number CHO BẢNG apartments
-- =========================================================================

-- 1. Thêm 2 cột nếu chưa tồn tại
ALTER TABLE public.apartments 
ADD COLUMN IF NOT EXISTS building_code VARCHAR,
ADD COLUMN IF NOT EXISTS floor_number INTEGER;

-- 2. Tự động trích xuất building_code và floor_number từ mã code căn hộ hiện có
-- Định dạng chuẩn: <Block><Tầng 2 chữ số><Phòng 2 chữ số> (ví dụ: A0101 -> building_code='A', floor_number=1)
UPDATE public.apartments
SET 
    building_code = COALESCE(building_code, SUBSTRING(code FROM 1 FOR 1)),
    floor_number = COALESCE(floor_number, NULLIF(SUBSTRING(code FROM 2 FOR 2), '')::integer)
WHERE building_code IS NULL OR floor_number IS NULL;

-- 3. Tạo index phục vụ tìm kiếm và nhóm căn hộ theo tòa/tầng
CREATE INDEX IF NOT EXISTS idx_apartments_building_floor ON public.apartments(building_code, floor_number);
