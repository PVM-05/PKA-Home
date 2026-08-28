-- =========================================================================
-- TẠO DỮ LIỆU CĂN HỘ HÀNG LOẠT (SEED APARTMENTS)
-- =========================================================================

-- Tạo danh sách các căn hộ cho 3 tòa (A, B, C)
-- Mỗi tòa có 10 tầng (từ tầng 1 đến tầng 10)
-- Mỗi tầng có 5 căn hộ (từ 01 đến 05)
-- Diện tích ngẫu nhiên từ 60.0m2 đến 100.0m2
-- Bổ sung trường building_code và floor_number theo schema mới
-- Trạng thái mặc định là is_empty = true (chưa có người ở)

INSERT INTO public.apartments (code, building_code, floor_number, area, is_empty)
SELECT 
    b.building || f.floor || lpad(r.room::text, 2, '0') AS code,
    b.building AS building_code,
    f.floor AS floor_number,
    ROUND((60.0 + (random() * 40.0))::numeric, 1) AS area,
    true AS is_empty
FROM 
    unnest(ARRAY['A', 'B', 'C']) AS b(building),
    generate_series(1, 10) AS f(floor),
    generate_series(1, 5) AS r(room)
ON CONFLICT (code) DO NOTHING;
