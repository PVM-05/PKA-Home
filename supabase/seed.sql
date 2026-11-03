-- ==============================================================================
-- PKA-HOME: DỮ LIỆU MẪU MÔI TRƯỜNG DEV / TEST / DEMO (SEED.SQL)
-- Tách biệt hoàn toàn khỏi Migration CSDL Production
-- Sử dụng: supabase db reset --with-seed HOẶC chạy thủ công khi cần demo
-- ==============================================================================

-- 1. TỔ CHỨC & TÒA NHÀ MẪU
INSERT INTO public.organizations (id, name, tax_code, email, phone)
VALUES (
    '00000000-0000-0000-0000-000000000001',
    'Tập đoàn Quản lý Bất động sản PKA Holdings',
    '0101234567',
    'contact@pkaholdings.vn',
    '02438889999'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.buildings (
    id,
    organization_id,
    name,
    address,
    bank_bin,
    bank_name,
    bank_account_number,
    bank_account_name
) VALUES (
    '00000000-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-000000000001',
    'Chung cư Cao cấp PKA Landmark Tower',
    'Số 1 Đại Cồ Việt, Phường Bách Khoa, Quận Hai Bà Trưng, Hà Nội',
    '970418',
    'Ngân hàng TMCP Đầu tư và Phát triển Việt Nam (BIDV)',
    '1234567890',
    'BQL TOA NHA LANDMARK PKA'
) ON CONFLICT (id) DO UPDATE SET
    bank_bin = EXCLUDED.bank_bin,
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name;

-- 2. QUỸ BẢO TRÌ MẪU 2.45 TỶ ĐỒNG (DÀNH CHO DEMO PITCHING / SHOWCASE)
INSERT INTO public.maintenance_funds (
    building_id,
    total_balance,
    annual_interest_earned,
    interest_rate_percent,
    collected_percent,
    bank_name,
    bank_account_number
) VALUES (
    '00000000-0000-0000-0000-000000000002',
    2450000000.00,
    127400000.00,
    5.20,
    98.50,
    'Ngân hàng TMCP Đầu tư và Phát triển Việt Nam (BIDV)',
    '1234567890'
) ON CONFLICT DO NOTHING;

-- 3. CĂN HỘ MẪU ĐỊNH DẠNG CHUẨN (A0110, A0201, A0305, A0412)
INSERT INTO public.apartments (id, building_id, code, area, is_empty)
VALUES 
    ('00000000-0000-0000-0000-000000000010', '00000000-0000-0000-0000-000000000002', 'a0110', 85.50, false),
    ('00000000-0000-0000-0000-000000000011', '00000000-0000-0000-0000-000000000002', 'a0201', 72.00, false),
    ('00000000-0000-0000-0000-000000000012', '00000000-0000-0000-0000-000000000002', 'a0305', 95.00, false),
    ('00000000-0000-0000-0000-000000000013', '00000000-0000-0000-0000-000000000002', 'a0412', 120.00, true)
ON CONFLICT (id) DO NOTHING;

-- 4. BIỂU PHÍ ĐIỆN NƯỚC EVN 6 BẬC & QUẢN LÝ DỊCH VỤ
INSERT INTO public.fee_schedules (fee_type, unit_price, effective_from, is_active)
VALUES 
    ('management', 12000.00, '2026-01-01', true),
    ('parking_car', 1200000.00, '2026-01-01', true),
    ('parking_motorcycle', 100000.00, '2026-01-01', true),
    ('water_baseline', 8500.00, '2026-01-01', true)
ON CONFLICT DO NOTHING;
