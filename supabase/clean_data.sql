-- ==============================================================================
-- PKA-HOME: SCRIPT XÓA TOÀN BỘ DỮ LIỆU MẪU (RESET DATA CLEAN SLATE)
-- CẢNH BÁO AN TOÀN: Để thực thi script này, bạn BẮT BUỘC phải mở comment dòng sau:
-- SET pka.confirm_reset_data = 'YES_I_WANT_TO_RESET_ALL_DATA';
-- ==============================================================================

DO $$
BEGIN
    IF current_setting('pka.confirm_reset_data', true) IS DISTINCT FROM 'YES_I_WANT_TO_RESET_ALL_DATA' THEN
        RAISE EXCEPTION 'CẢNH BÁO AN TOÀN: Thao tác này sẽ xóa sạch toàn bộ dữ liệu tài khoản và giao dịch! Nếu chắc chắn muốn thực thi trên môi trường Test/Dev, vui lòng bỏ comment dòng lệnh: SET pka.confirm_reset_data = ''YES_I_WANT_TO_RESET_ALL_DATA''; ở đầu file trước khi Run.';
    END IF;
END $$;

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
