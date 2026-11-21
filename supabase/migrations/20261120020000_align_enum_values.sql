-- ==============================================================================
-- Vivona Production Commercial SaaS: Migration 20261120020000_align_enum_values.sql
-- Mục tiêu: Bổ sung các giá trị enum tương thích giữa Backend Supabase và Flutter Models
-- Lưu ý kỹ thuật: File này tách riêng biệt để ALTER TYPE ADD VALUE được commit hoàn toàn
-- trước khi các hàm và bảng ở migration kế tiếp (20261120_03) tham chiếu đến chúng.
-- ==============================================================================

-- 1. invoice_status: thêm 'unpaid', 'pending_confirmation'
ALTER TYPE public.invoice_status ADD VALUE IF NOT EXISTS 'unpaid';
ALTER TYPE public.invoice_status ADD VALUE IF NOT EXISTS 'pending_confirmation';

-- 2. issue_status: thêm 'pending'
ALTER TYPE public.issue_status ADD VALUE IF NOT EXISTS 'pending';

-- 3. user_role: thêm 'accountant', 'technician'
ALTER TYPE public.user_role ADD VALUE IF NOT EXISTS 'accountant';
ALTER TYPE public.user_role ADD VALUE IF NOT EXISTS 'technician';

-- 4. vehicle_type: thêm 'motorbike', 'electric_bicycle'
ALTER TYPE public.vehicle_type ADD VALUE IF NOT EXISTS 'motorbike';
ALTER TYPE public.vehicle_type ADD VALUE IF NOT EXISTS 'electric_bicycle';

