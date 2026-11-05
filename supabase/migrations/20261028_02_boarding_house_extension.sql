-- ==============================================================================
-- PKA-HOME: BOARDING HOUSE EXTENSION & SEED SCRIPT
-- Migration: 20261028_02_boarding_house_extension.sql
-- ==============================================================================

-- 1. Bổ sung các trường phục vụ mô hình phòng trọ vào bảng apartments
ALTER TABLE public.apartments 
    ADD COLUMN IF NOT EXISTS rent_price NUMERIC(12,2) DEFAULT 0,
    ADD COLUMN IF NOT EXISTS deposit_amount NUMERIC(12,2) DEFAULT 0,
    ADD COLUMN IF NOT EXISTS max_occupants INT DEFAULT 2,
    ADD COLUMN IF NOT EXISTS has_own_electric_meter BOOLEAN DEFAULT true,
    ADD COLUMN IF NOT EXISTS has_own_water_meter BOOLEAN DEFAULT false,
    ADD COLUMN IF NOT EXISTS contract_start_date DATE,
    ADD COLUMN IF NOT EXISTS contract_end_date DATE;

-- 2. Thêm trường property_type vào buildings để phân biệt Chung cư vs Phòng trọ
ALTER TABLE public.buildings
    ADD COLUMN IF NOT EXISTS property_type TEXT NOT NULL DEFAULT 'apartment' 
    CHECK (property_type IN ('apartment', 'boarding_house'));

-- 3. Kịch bản mẫu khởi tạo cơ sở phòng trọ khi triển khai cho đơn vị mới
-- (Có thể chạy độc lập trong Supabase SQL Editor khi tạo tổ chức phòng trọ đầu tiên)
DO $$
DECLARE
    v_org_id UUID;
    v_building_id UUID;
    v_room_101_id UUID;
    v_fee_schedule_id UUID;
BEGIN
    -- Kiểm tra nếu chưa có cơ sở phòng trọ mẫu thì tạo mới
    SELECT id INTO v_building_id FROM public.buildings WHERE code = 'TRO_KIMMA' LIMIT 1;
    
    IF v_building_id IS NULL THEN
        -- Lấy tổ chức mặc định hoặc tạo mới
        SELECT id INTO v_org_id FROM public.organizations WHERE slug = 'pka-corp' LIMIT 1;
        IF v_org_id IS NULL THEN
            SELECT id INTO v_org_id FROM public.organizations LIMIT 1;
        END IF;

        IF v_org_id IS NOT NULL THEN
            INSERT INTO public.buildings (
                organization_id, name, code, address, total_floors, total_units, property_type
            ) VALUES (
                v_org_id,
                'Nhà trọ Kim Mã Cơ sở 1',
                'TRO_KIMMA',
                'Số 12 ngõ 45 Kim Mã, Ba Đình, Hà Nội',
                4,
                16,
                'boarding_house'
            ) RETURNING id INTO v_building_id;

            -- Tạo phòng trọ mẫu P101
            INSERT INTO public.apartments (
                building_id, code, block, floor, room, area, rent_price, deposit_amount,
                max_occupants, is_empty, has_own_electric_meter, has_own_water_meter
            ) VALUES (
                v_building_id, 'P101', 'CS01', 1, '101', 22.5, 3500000, 3500000,
                3, false, true, false
            ) RETURNING id INTO v_room_101_id;

            -- Tạo các biểu phí dịch vụ phòng trọ mẫu
            INSERT INTO public.fee_schedules (building_id, fee_type, name, unit, unit_price, effective_from, is_active)
            VALUES 
                (v_building_id, 'electricity', 'Tiền điện sinh hoạt', 'kWh', 3800.00, '2026-01-01', true),
                (v_building_id, 'water', 'Tiền nước khoán', 'người/tháng', 30000.00, '2026-01-01', true),
                (v_building_id, 'trash', 'Phí vệ sinh rác thải', 'phòng/tháng', 30000.00, '2026-01-01', true),
                (v_building_id, 'internet', 'Internet Wifi', 'phòng/tháng', 100000.00, '2026-01-01', true),
                (v_building_id, 'parking_motorcycle', 'Phí gửi xe máy', 'xe/tháng', 80000.00, '2026-01-01', true);
        END IF;
    END IF;
END $$;
