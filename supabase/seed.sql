-- Lưu ý: Supabase khuyến cáo không nên insert trực tiếp vào auth.users bằng SQL thông thường vì password cần được mã hóa pgcrypto.
-- Để test cục bộ hiệu quả, bạn nên tạo user qua Supabase Auth UI hoặc gọi API signIn.
-- Tuy nhiên, vì mục đích tạo seed data mẫu để test RLS, chúng ta tạo một hàm giả lập insert auth.users.

-- =========================================================================
-- 1. Tạo Users mẫu (Giả lập việc đăng ký thành công)
-- =========================================================================
-- Insert vào auth.users (Tạo 3 người dùng: 1 quản lý, 2 cư dân)
INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, role, confirmation_token, email_change, email_change_token_new, recovery_token)
VALUES
('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000', 'admin@pkahome.com', crypt('password123', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"full_name":"Quản lý Tòa nhà","role":"management"}', now(), now(), 'authenticated', '', '', '', ''),
('00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000000', 'resident1@pkahome.com', crypt('password123', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"full_name":"Cư dân A","role":"resident"}', now(), now(), 'authenticated', '', '', '', ''),
('00000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000000', 'resident2@pkahome.com', crypt('password123', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"full_name":"Cư dân B","role":"resident"}', now(), now(), 'authenticated', '', '', '', '')
ON CONFLICT DO NOTHING;

-- Do bảng public.users đã có trigger handle_new_user nên 3 bản ghi trên sẽ tự động được thêm vào public.users!
-- Lưu ý: Nếu trigger lỗi trên môi trường test, hãy bỏ comment các dòng sau để insert trực tiếp vào public.users:
/*
INSERT INTO public.users (id, full_name, role) VALUES 
('00000000-0000-0000-0000-000000000001', 'Quản lý Tòa nhà', 'management'),
('00000000-0000-0000-0000-000000000002', 'Cư dân A', 'resident'),
('00000000-0000-0000-0000-000000000003', 'Cư dân B', 'resident')
ON CONFLICT (id) DO NOTHING;
*/

-- =========================================================================
-- 2. Tạo Căn hộ (Apartments)
-- =========================================================================
INSERT INTO public.apartments (id, code, area, is_empty) VALUES 
('11111111-1111-1111-1111-111111111111', 'A101', 65.5, false),
('22222222-2222-2222-2222-222222222222', 'A102', 70.0, false),
('33333333-3333-3333-3333-333333333333', 'B201', 85.0, true)
ON CONFLICT DO NOTHING;

-- =========================================================================
-- 3. Gắn Cư dân vào Căn hộ
-- =========================================================================
INSERT INTO public.residents_apartments (user_id, apartment_id, relation_role) VALUES 
('00000000-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'owner'),  -- Cư dân A sở hữu A101
('00000000-0000-0000-0000-000000000003', '22222222-2222-2222-2222-222222222222', 'tenant') -- Cư dân B thuê A102
ON CONFLICT DO NOTHING;

-- =========================================================================
-- 4. Tạo Hóa đơn (Invoices)
-- =========================================================================
INSERT INTO public.invoices (id, apartment_id, period, due_date, total_amount, status) VALUES 
('44444444-4444-4444-4444-444444444441', '11111111-1111-1111-1111-111111111111', '08/2026', '2026-09-05', 850000, 'unpaid'),
('44444444-4444-4444-4444-444444444442', '22222222-2222-2222-2222-222222222222', '08/2026', '2026-09-05', 1200000, 'paid')
ON CONFLICT DO NOTHING;

-- Chi tiết hóa đơn (Invoice Items)
INSERT INTO public.invoice_items (invoice_id, fee_type, unit_price, quantity, subtotal) VALUES 
-- A101
('44444444-4444-4444-4444-444444444441', 'Phí quản lý', 10000, 65.5, 655000),
('44444444-4444-4444-4444-444444444441', 'Nước sinh hoạt', 15000, 13, 195000),
-- A102
('44444444-4444-4444-4444-444444444442', 'Phí quản lý', 10000, 70.0, 700000),
('44444444-4444-4444-4444-444444444442', 'Điện sinh hoạt', 2500, 200, 500000)
ON CONFLICT DO NOTHING;

-- =========================================================================
-- 5. Tạo Phản ánh (Issue Reports)
-- =========================================================================
INSERT INTO public.issue_reports (id, apartment_id, reporter_id, status, description) VALUES 
('55555555-5555-5555-5555-555555555551', '11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-000000000002', 'pending', 'Bóng đèn hành lang tầng 1 bị cháy'),
('55555555-5555-5555-5555-555555555552', '22222222-2222-2222-2222-222222222222', '00000000-0000-0000-0000-000000000003', 'in_progress', 'Ống nước bồn rửa mặt bị rỉ')
ON CONFLICT DO NOTHING;

-- =========================================================================
-- 6. Tạo Thông báo (Announcements)
-- =========================================================================
INSERT INTO public.announcements (title, content, is_urgent) VALUES 
('Thu phí quản lý tháng 8/2026', 'Kính gửi cư dân, BQL đã phát hành hóa đơn tháng 8. Quý cư dân vui lòng thanh toán trước ngày 05/09/2026.', false),
('CẮT NƯỚC BẢO TRÌ ĐỘT XUẤT', 'BQL xin thông báo sẽ cắt nước toàn khu từ 14h-16h chiều nay để sửa chữa trạm bơm. Xin lỗi vì sự bất tiện này.', true);
