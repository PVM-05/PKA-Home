-- Migration: 20261026_02_remove_invoice_same_month_restriction.sql
-- Description: Loại bỏ ràng buộc duy nhất (UNIQUE) ngăn tạo nhiều hóa đơn cho cùng một căn hộ trong cùng một tháng/kỳ.
-- Cho phép Ban Quản Lý tạo nhiều hóa đơn trong cùng một tháng (ví dụ: hóa đơn bổ sung, hóa đơn phát sinh, hóa đơn tiền dịch vụ riêng biệt).

-- 1. Xóa các ràng buộc UNIQUE trên bảng invoices (apartment_id, period)
ALTER TABLE public.invoices DROP CONSTRAINT IF EXISTS unique_apartment_period;
ALTER TABLE public.invoices DROP CONSTRAINT IF EXISTS uq_invoice_apartment_period;

-- 2. Xóa các chỉ mục UNIQUE tương ứng nếu còn sót lại
DROP INDEX IF EXISTS public.unique_apartment_period;
DROP INDEX IF EXISTS public.uq_invoice_apartment_period;

-- 3. Tạo chỉ mục thông thường (non-unique) để tối ưu hiệu năng truy vấn theo căn hộ và kỳ thu
CREATE INDEX IF NOT EXISTS idx_invoices_apartment_period ON public.invoices (apartment_id, period);
