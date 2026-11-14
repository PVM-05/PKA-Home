-- ==============================================================================
-- Migration: 20261114_01_secure_bank_webhook_and_vnpay.sql
-- Mục tiêu:
--   1. THU HỒI QUYỀN GỌI TRỰC TIẾP TỪ CLIENT ĐỐI VỚI CÁC RPC GẠCH NỢ TỰ ĐỘNG.
--      Chỉ cho phép role 'service_role' (gọi qua Supabase Edge Function) thực thi.
--   2. BỔ SUNG CẤU HÌNH CỔNG THANH TOÁN VNPAY TRÊN BẢNG building_payment_configs.
-- ==============================================================================

-- 1. Thu hồi quyền execute từ public, anon, authenticated trên hàm process_bank_payment_webhook
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public' AND p.proname = 'process_bank_payment_webhook'
    ) THEN
        REVOKE EXECUTE ON FUNCTION public.process_bank_payment_webhook(JSONB) FROM PUBLIC, anon, authenticated;
        GRANT EXECUTE ON FUNCTION public.process_bank_payment_webhook(JSONB) TO service_role;
        RAISE NOTICE 'Đã khóa RPC process_bank_payment_webhook chỉ cho phép service_role.';
    END IF;
END $$;

-- 2. Thu hồi quyền execute trên hàm process_sepay_webhook
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public' AND p.proname = 'process_sepay_webhook'
    ) THEN
        REVOKE EXECUTE ON FUNCTION public.process_sepay_webhook(JSONB, TEXT) FROM PUBLIC, anon, authenticated;
        GRANT EXECUTE ON FUNCTION public.process_sepay_webhook(JSONB, TEXT) TO service_role;
        RAISE NOTICE 'Đã khóa RPC process_sepay_webhook chỉ cho phép service_role.';
    END IF;
END $$;

-- 3. Mở rộng bảng building_payment_configs để hỗ trợ cổng thanh toán VNPay
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = 'building_payment_configs'
    ) THEN
        -- Mã định danh merchant VNPay (Terminal ID / TmnCode)
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' AND table_name = 'building_payment_configs' AND column_name = 'vnpay_tmn_code'
        ) THEN
            ALTER TABLE public.building_payment_configs ADD COLUMN vnpay_tmn_code TEXT;
        END IF;

        -- Khóa bí mật băm chữ ký số HMAC-SHA512 (Hash Secret)
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' AND table_name = 'building_payment_configs' AND column_name = 'vnpay_hash_secret'
        ) THEN
            ALTER TABLE public.building_payment_configs ADD COLUMN vnpay_hash_secret TEXT;
        END IF;

        -- Trạng thái kích hoạt cổng VNPay cho tòa nhà
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' AND table_name = 'building_payment_configs' AND column_name = 'vnpay_is_active'
        ) THEN
            ALTER TABLE public.building_payment_configs ADD COLUMN vnpay_is_active BOOLEAN DEFAULT false;
        END IF;
    END IF;
END $$;

