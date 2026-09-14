-- Migration: Chuyển đổi invoice_items.subtotal sang GENERATED ALWAYS AS STORED
-- Đảm bảo toàn vẹn dữ liệu tài chính, không phụ thuộc vào tính toán từ client

ALTER TABLE public.invoice_items DROP COLUMN IF EXISTS subtotal;
ALTER TABLE public.invoice_items 
  ADD COLUMN subtotal DECIMAL GENERATED ALWAYS AS (unit_price * quantity) STORED;
