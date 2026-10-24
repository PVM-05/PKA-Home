-- ==============================================================================
-- PKA-HOME: SCRIPT XÓA TOÀN BỘ DỮ LIỆU MẪU (RESET DATA CLEAN SLATE)
-- Hướng dẫn: Mở Supabase SQL Editor -> Dán toàn bộ nội dung file này -> Bấm Run
-- ==============================================================================

-- BƯỚC 1: XÓA SẠCH DỮ LIỆU CÁC BẢNG NGHIỆP VỤ PHÁT SINH
-- Lệnh TRUNCATE ... CASCADE giúp xóa cực nhanh và tự động xử lý ràng buộc khóa ngoại
TRUNCATE TABLE 
    public.payment_transactions,
    public.invoice_items,
    public.invoices,
    public.meter_reading_submissions,
    public.issue_ratings,
    public.issue_images,
    public.issue_reports,
    public.amenity_bookings,
    public.equipment_maintenance_tasks,
    public.notifications,
    public.user_fcm_tokens,
    public.role_change_log,
    public.role_delegations,
    public.apartment_link_requests,
    public.vehicles,
    public.residents_apartments
CASCADE;

-- BƯỚC 2: XÓA SẠCH TÀI KHOẢN NGƯỜI DÙNG CŨ
-- Xóa cả ở tầng Auth (auth.users) và tầng Application (public.users)
-- Điều này giúp giải phóng hoàn toàn email cũ, tránh lỗi "User already registered" khi nạp lại seed
TRUNCATE TABLE public.users CASCADE;
DELETE FROM auth.users;

-- BƯỚC 3: RESET LẠI TRẠNG THÁI CĂN HỘ VỀ TRỐNG (is_empty = true, chỉ số = 0)
UPDATE public.apartments 
SET is_empty = true,
    electric_reading = 0,
    water_reading = 0,
    updated_at = now();

-- GHI CHÚ:
-- 1. Sau khi chạy script này, cơ sở dữ liệu sẽ sạch 100% dữ liệu mẫu nhưng vẫn GIỮ NGUYÊN
--    toàn bộ Cấu trúc bảng, Khóa chính, RLS Policies, Triggers và 150 Căn hộ.
-- 2. Nếu muốn nạp lại bộ dữ liệu chuẩn mới (các tài khoản @gmail.com và 40 xe hợp lệ):
--    Bạn chỉ cần mở tiếp file `supabase/seed.sql` và bấm Run trong SQL Editor.
