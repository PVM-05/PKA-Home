-- ====================================================================
-- Migration: 20261106_01_cleanup_dead_tables_and_seed_data.sql
-- Mục đích:
-- 1. Xóa bỏ 2 bảng dư thừa không còn sử dụng: tiered_tariffs, service_ratings
-- 2. Dọn sạch toàn bộ dữ liệu giao dịch mẫu (hóa đơn, thanh toán, thông báo, sự cố...)
-- 3. Reset các ô đỗ xe về trạng thái trống (available) và dọn sạch xe demo
-- 4. Bảo tồn toàn bộ hạ tầng căn hộ, tòa nhà, biểu giá và tài khoản admin/cư dân
-- ====================================================================

-- 1. XÓA BẢNG DƯ THỪA (DEAD TABLES)
DROP TABLE IF EXISTS public.tiered_tariffs CASCADE;
DROP TABLE IF EXISTS public.service_ratings CASCADE;

-- 2. DỌN SẠCH DỮ LIỆU GIAO DỊCH VÀ NHẬT KÝ MẪU (TRANSACTIONAL DATA)
-- Thông báo hệ thống
TRUNCATE TABLE public.notifications CASCADE;

-- Giao dịch thanh toán & Hóa đơn
TRUNCATE TABLE public.payment_transactions CASCADE;
TRUNCATE TABLE public.invoice_items CASCADE;
TRUNCATE TABLE public.invoices CASCADE;

-- Phản ánh sự cố & Dữ liệu đính kèm
TRUNCATE TABLE public.issue_comments CASCADE;
TRUNCATE TABLE public.issue_ratings CASCADE;
TRUNCATE TABLE public.issue_images CASCADE;
TRUNCATE TABLE public.issue_materials CASCADE;
TRUNCATE TABLE public.issue_reports CASCADE;

-- Đặt chỗ tiện ích, chỉ số công tơ, bảo trì thiết bị
TRUNCATE TABLE public.amenity_bookings CASCADE;
TRUNCATE TABLE public.meter_reading_submissions CASCADE;
TRUNCATE TABLE public.equipment_maintenance_tasks CASCADE;

-- Yêu cầu liên kết căn hộ & Token FCM rác
TRUNCATE TABLE public.apartment_link_requests CASCADE;
TRUNCATE TABLE public.user_fcm_tokens CASCADE;

-- 3. RESET BÃI ĐỖ XE VỀ TRẠNG THÁI TRỐNG
UPDATE public.parking_slots
SET status = 'available',
    assigned_apartment_id = NULL,
    assigned_vehicle_id = NULL,
    updated_at = timezone('utc'::text, now());

-- Dọn sạch xe demo
TRUNCATE TABLE public.vehicles CASCADE;

-- Ghi nhận lịch sử di chuyển schema
INSERT INTO public._applied_migrations (name, applied_at)
VALUES ('20261106_01_cleanup_dead_tables_and_seed_data', timezone('utc'::text, now()))
ON CONFLICT DO NOTHING;
