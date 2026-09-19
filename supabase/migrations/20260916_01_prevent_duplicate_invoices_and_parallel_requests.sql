-- ==============================================================================
-- 1. RÀNG BUỘC CHỐNG TRÙNG HÓA ĐƠN CÙNG KỲ CHO MỘT CĂN HỘ
-- ==============================================================================
-- Ngăn chặn việc tạo 2 hóa đơn cho cùng một căn hộ trong cùng một kỳ (ví dụ: '09/2026')
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'uq_invoice_apartment_period'
    ) THEN
        ALTER TABLE public.invoices 
        ADD CONSTRAINT uq_invoice_apartment_period UNIQUE (apartment_id, period);
    END IF;
END $$;

-- ==============================================================================
-- 2. RÀNG BUỘC NGĂN CHẶN NHIỀU YÊU CẦU LIÊN KẾT PENDING SONG SONG
-- ==============================================================================
-- Đảm bảo mỗi cư dân chỉ có tối đa 1 yêu cầu liên kết đang ở trạng thái 'pending'
CREATE UNIQUE INDEX IF NOT EXISTS uq_apartment_link_requests_user_pending 
ON public.apartment_link_requests (user_id) 
WHERE status = 'pending';
