-- ==============================================================================
-- 1. MỞ RỘNG ENUM user_role ĐA VAI TRÒ
-- Lưu ý: Lệnh ALTER TYPE ... ADD VALUE phải chạy riêng biệt trong file này vì
-- PostgreSQL không cho phép sử dụng giá trị enum mới trong cùng một transaction.
-- ==============================================================================
ALTER TYPE public.user_role ADD VALUE IF NOT EXISTS 'admin';
ALTER TYPE public.user_role ADD VALUE IF NOT EXISTS 'accountant';
ALTER TYPE public.user_role ADD VALUE IF NOT EXISTS 'technician';
