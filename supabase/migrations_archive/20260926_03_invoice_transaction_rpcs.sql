-- Migration: Transaction-safe RPCs for creating and updating invoices with items
-- Đảm bảo tính toàn vẹn dữ liệu (Atomic Transaction): Nếu một bước thất bại, toàn bộ thao tác tự động Rollback.

CREATE OR REPLACE FUNCTION public.create_invoice_with_items(
    p_apartment_id UUID,
    p_period VARCHAR,
    p_due_date DATE,
    p_items JSONB
)
RETURNS UUID AS $$
DECLARE
    v_invoice_id UUID;
    v_item JSONB;
BEGIN
    -- 1. Tạo hóa đơn
    INSERT INTO public.invoices (apartment_id, period, due_date, status)
    VALUES (p_apartment_id, p_period, p_due_date, 'unpaid'::public.invoice_status)
    RETURNING id INTO v_invoice_id;

    -- 2. Chèn từng hạng mục chi phí nếu có
    IF p_items IS NOT NULL AND jsonb_array_length(p_items) > 0 THEN
        FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
        LOOP
            INSERT INTO public.invoice_items (
                invoice_id,
                fee_type,
                unit_price,
                quantity
            ) VALUES (
                v_invoice_id,
                v_item->>'fee_type',
                COALESCE((v_item->>'unit_price')::DECIMAL, 0),
                COALESCE((v_item->>'quantity')::DECIMAL, 1)
            );
        END LOOP;
    END IF;

    RETURN v_invoice_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.update_invoice_with_items(
    p_invoice_id UUID,
    p_period VARCHAR,
    p_due_date DATE,
    p_items JSONB,
    p_apartment_id UUID DEFAULT NULL,
    p_status VARCHAR DEFAULT NULL
)
RETURNS VOID AS $$
DECLARE
    v_item JSONB;
BEGIN
    -- 1. Cập nhật thông tin hóa đơn
    UPDATE public.invoices
    SET 
        period = p_period,
        due_date = p_due_date,
        apartment_id = COALESCE(p_apartment_id, apartment_id),
        status = CASE 
            WHEN p_status IS NOT NULL THEN p_status::public.invoice_status 
            ELSE status 
        END,
        updated_at = NOW()
    WHERE id = p_invoice_id;

    -- 2. Xóa các mục chi phí cũ
    DELETE FROM public.invoice_items WHERE invoice_id = p_invoice_id;

    -- 3. Chèn lại các mục chi phí mới trong cùng transaction
    IF p_items IS NOT NULL AND jsonb_array_length(p_items) > 0 THEN
        FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
        LOOP
            INSERT INTO public.invoice_items (
                invoice_id,
                fee_type,
                unit_price,
                quantity
            ) VALUES (
                p_invoice_id,
                v_item->>'fee_type',
                COALESCE((v_item->>'unit_price')::DECIMAL, 0),
                COALESCE((v_item->>'quantity')::DECIMAL, 1)
            );
        END LOOP;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
