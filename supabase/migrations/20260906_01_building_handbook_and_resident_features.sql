-- ==============================================================================
-- Migration: Cẩm Nang Tòa Nhà (Đường Dây Nóng, Nội Quy, Tiện Ích) & Tính Năng Bổ Trợ
-- Ngày: 06/09/2026
-- ==============================================================================

-- 1. Bảng emergency_contacts (Đường dây nóng / Liên hệ khẩn cấp)
CREATE TABLE IF NOT EXISTS public.emergency_contacts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR NOT NULL,
    phone VARCHAR NOT NULL,
    contact_type VARCHAR DEFAULT 'security', -- 'security', 'fire', 'management', 'technical'
    display_order INT DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Bảng building_rules (Nội quy chung cư)
CREATE TABLE IF NOT EXISTS public.building_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR NOT NULL,
    content TEXT NOT NULL,
    display_order INT DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Bảng building_amenities (Tiện ích tòa nhà)
CREATE TABLE IF NOT EXISTS public.building_amenities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR NOT NULL,
    description TEXT,
    open_hours VARCHAR,
    display_order INT DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. Triggers cập nhật updated_at
DROP TRIGGER IF EXISTS update_emergency_contacts_modtime ON public.emergency_contacts;
CREATE TRIGGER update_emergency_contacts_modtime
    BEFORE UPDATE ON public.emergency_contacts
    FOR EACH ROW
    EXECUTE FUNCTION public.update_modified_column();

DROP TRIGGER IF EXISTS update_building_rules_modtime ON public.building_rules;
CREATE TRIGGER update_building_rules_modtime
    BEFORE UPDATE ON public.building_rules
    FOR EACH ROW
    EXECUTE FUNCTION public.update_modified_column();

DROP TRIGGER IF EXISTS update_building_amenities_modtime ON public.building_amenities;
CREATE TRIGGER update_building_amenities_modtime
    BEFORE UPDATE ON public.building_amenities
    FOR EACH ROW
    EXECUTE FUNCTION public.update_modified_column();

-- 5. Bật RLS
ALTER TABLE public.emergency_contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.building_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.building_amenities ENABLE ROW LEVEL SECURITY;

-- 6. RLS Policies
DROP POLICY IF EXISTS "Mọi user đăng nhập xem emergency_contacts" ON public.emergency_contacts;
CREATE POLICY "Mọi user đăng nhập xem emergency_contacts" 
ON public.emergency_contacts FOR SELECT 
USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Management toàn quyền emergency_contacts" ON public.emergency_contacts;
CREATE POLICY "Management toàn quyền emergency_contacts" 
ON public.emergency_contacts FOR ALL 
USING (public.is_management());

DROP POLICY IF EXISTS "Mọi user đăng nhập xem building_rules" ON public.building_rules;
CREATE POLICY "Mọi user đăng nhập xem building_rules" 
ON public.building_rules FOR SELECT 
USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Management toàn quyền building_rules" ON public.building_rules;
CREATE POLICY "Management toàn quyền building_rules" 
ON public.building_rules FOR ALL 
USING (public.is_management());

DROP POLICY IF EXISTS "Mọi user đăng nhập xem building_amenities" ON public.building_amenities;
CREATE POLICY "Mọi user đăng nhập xem building_amenities" 
ON public.building_amenities FOR SELECT 
USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Management toàn quyền building_amenities" ON public.building_amenities;
CREATE POLICY "Management toàn quyền building_amenities" 
ON public.building_amenities FOR ALL 
USING (public.is_management());

-- 7. Cho phép user cập nhật thông tin cá nhân của chính mình trên bảng users
DO $$ BEGIN
    CREATE POLICY "Users có thể cập nhật thông tin của chính mình" 
    ON public.users FOR UPDATE 
    USING (auth.uid() = id) 
    WITH CHECK (auth.uid() = id);
EXCEPTION WHEN duplicate_object THEN null;
END $$;

-- 8. Thêm vào publication supabase_realtime
ALTER PUBLICATION supabase_realtime ADD TABLE public.emergency_contacts;
ALTER PUBLICATION supabase_realtime ADD TABLE public.building_rules;
ALTER PUBLICATION supabase_realtime ADD TABLE public.building_amenities;

-- 9. Dữ liệu mẫu ban đầu (Seed data)
INSERT INTO public.emergency_contacts (name, phone, contact_type, display_order) VALUES
('Bảo vệ sảnh A (24/7)', '02431234567', 'security', 1),
('Bảo vệ sảnh B (24/7)', '02431234568', 'security', 2),
('Văn phòng Ban Quản Lý (Giờ HC)', '0901234567', 'management', 3),
('Đội Kỹ Thuật & Điện Nước Trực Ban', '0912345678', 'technical', 4),
('Cảnh sát PCCC & Cứu nạn cứu hộ', '114', 'fire', 5)
ON CONFLICT DO NOTHING;

INSERT INTO public.building_rules (title, content, display_order) VALUES
('Quy định về tiếng ồn và giờ giấc sinh hoạt', 'Không gây ồn ào, mở nhạc lớn, khoan đục sau 22:00 đêm và trước 07:00 sáng. Các ngày cuối tuần chỉ thi công từ 08:30 đến 11:30 và từ 14:00 đến 17:00.', 1),
('Quy định về rác thải và vệ sinh môi trường', 'Cư dân phân loại rác theo quy định. Rác sinh hoạt buộc kín trong túi và bỏ vào phòng rác tầng. Tuyệt đối không để rác ở hành lang chung hoặc vứt tàn thuốc qua ban công.', 2),
('Quy định về nuôi giữ vật nuôi', 'Vật nuôi phải được đăng ký với Ban Quản Lý và tiêm phòng dại đầy đủ. Khi ra khu vực công cộng phải đeo rọ mõm và có dây xích kiểm soát.', 3),
('Quy định phòng cháy chữa cháy', 'Không che chắn tủ chữa cháy và họng nước cứu hỏa. Nghiêm cấm đốt vàng mã ngoài khu vực lò đốt quy định tại sân thượng hoặc chân tòa nhà.', 4)
ON CONFLICT DO NOTHING;

INSERT INTO public.building_amenities (name, description, open_hours, display_order) VALUES
('Hồ bơi ngoài trời (Tầng 5)', 'Miễn phí cho cư dân có thẻ. Vui lòng mặc trang phục bơi quy định và tắm tráng trước khi xuống hồ.', '06:00 - 21:00', 1),
('Phòng Gym & Yoga (Tầng 4)', 'Trang bị máy tập hiện đại. Cư dân tự mang khăn cá nhân và xếp gọn tạ sau khi sử dụng.', '05:30 - 22:00', 2),
('Phòng sinh hoạt cộng đồng (Tầng 1)', 'Khu vực họp cư dân, đọc sách và tổ chức sự kiện gia đình (cần đăng ký trước với BQL).', '08:00 - 21:30', 3)
ON CONFLICT DO NOTHING;
