-- Migration: 20261005_03_unified_payment_simulation.sql
-- Mở rộng bảng payment_transactions và tạo RPC simulate_unified_payment dùng chung cho cả Hóa đơn và Dịch vụ

-- 1. Nâng cấp cấu trúc bảng payment_transactions
ALTER TABLE public.payment_transactions
ADD COLUMN IF NOT EXISTS type VARCHAR(20) NOT NULL DEFAULT 'INVOICE' CHECK (type IN ('INVOICE', 'SERVICE')),
ADD COLUMN IF NOT EXISTS booking_id UUID REFERENCES public.amenity_bookings(id) ON DELETE CASCADE,
ADD COLUMN IF NOT EXISTS title TEXT,
ALTER COLUMN invoice_id DROP NOT NULL;

CREATE INDEX IF NOT EXISTS idx_payment_transactions_booking ON public.payment_transactions(booking_id);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_type ON public.payment_transactions(type);

-- Cập nhật policy RLS cho cư dân: cư dân xem được giao dịch căn hộ mình hoặc của chính mình
DROP POLICY IF EXISTS "Cư dân xem giao dịch căn hộ mình" ON public.payment_transactions;
CREATE POLICY "Cư dân xem giao dịch căn hộ mình" ON public.payment_transactions
FOR SELECT USING (
    user_id = auth.uid()
    OR apartment_id IN (
        SELECT apartment_id FROM public.residents_apartments WHERE user_id = auth.uid()
    ) 
    OR public.is_staff()
);

-- 2. RPC Nguyên Tử: public.simulate_unified_payment
CREATE OR REPLACE FUNCTION public.simulate_unified_payment(
    p_type VARCHAR,            -- 'INVOICE' hoặc 'SERVICE'
    p_reference_id UUID,       -- invoice_id hoặc booking_id
    p_outcome VARCHAR DEFAULT 'SUCCESS'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_apt_id UUID;
    v_amount NUMERIC(12,2);
    v_tx_code VARCHAR;
    v_title TEXT;
    v_tx_id UUID;
    v_invoice RECORD;
    v_booking RECORD;
BEGIN
    -- Kiểm tra xác thực
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Người dùng chưa được xác thực (auth.uid() is null)';
    END IF;

    -- Kiểm tra loại thanh toán hợp lệ
    IF p_type NOT IN ('INVOICE', 'SERVICE') THEN
        RAISE EXCEPTION 'Loại giao dịch không hợp lệ: %', p_type;
    END IF;

    -- Sinh mã giao dịch chuẩn DEMO-YYYYMMDD-XXXX (4 số ngẫu nhiên)
    v_tx_code := 'DEMO-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0');

    IF p_type = 'INVOICE' THEN
        SELECT id, apartment_id, total_amount, period, status
        INTO v_invoice
        FROM public.invoices 
        WHERE id = p_reference_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Không tìm thấy hóa đơn có ID %', p_reference_id;
        END IF;

        IF v_invoice.status = 'paid' THEN
            RAISE EXCEPTION 'Hóa đơn này đã được thanh toán trước đó';
        END IF;

        v_apt_id := v_invoice.apartment_id;
        v_amount := v_invoice.total_amount;
        v_title := 'Hóa đơn tháng ' || v_invoice.period;

        -- Kiểm tra quyền căn hộ nếu không phải BQL
        IF NOT public.is_staff() THEN
            IF NOT EXISTS (
                SELECT 1 FROM public.residents_apartments 
                WHERE apartment_id = v_apt_id AND user_id = v_user_id
            ) THEN
                RAISE EXCEPTION 'Bạn không có quyền thanh toán hóa đơn của căn hộ này';
            END IF;
        END IF;

        IF p_outcome = 'SUCCESS' THEN
            UPDATE public.invoices
            SET status = 'paid',
                payment_method = 'Demo Payment',
                transaction_code = v_tx_code,
                paid_at = NOW(),
                updated_at = NOW()
            WHERE id = p_reference_id;
        END IF;

        INSERT INTO public.payment_transactions (
            invoice_id,
            user_id,
            apartment_id,
            amount,
            payment_method,
            status,
            transaction_code,
            type,
            title,
            failure_reason
        ) VALUES (
            p_reference_id,
            v_user_id,
            v_apt_id,
            v_amount,
            'Demo Payment',
            p_outcome,
            v_tx_code,
            'INVOICE',
            v_title,
            CASE WHEN p_outcome = 'FAILED' THEN 'Mô phỏng lỗi giao dịch từ người dùng' ELSE NULL END
        ) RETURNING id INTO v_tx_id;

    ELSIF p_type = 'SERVICE' THEN
        SELECT b.id, b.apartment_id, b.time_slot, b.fee_amount, b.deposit_amount, b.status, a.name AS amenity_name
        INTO v_booking
        FROM public.amenity_bookings b
        JOIN public.building_amenities a ON a.id = b.amenity_id
        WHERE b.id = p_reference_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Không tìm thấy lịch đặt dịch vụ có ID %', p_reference_id;
        END IF;

        v_apt_id := v_booking.apartment_id;
        v_amount := COALESCE(v_booking.fee_amount, 0) + COALESCE(v_booking.deposit_amount, 0);
        v_title := v_booking.amenity_name || ' (' || v_booking.time_slot || ')';

        IF p_outcome = 'SUCCESS' THEN
            UPDATE public.amenity_bookings
            SET status = 'confirmed',
                deposit_status = CASE WHEN COALESCE(v_booking.deposit_amount, 0) > 0 THEN 'received' ELSE 'none' END,
                updated_at = NOW()
            WHERE id = p_reference_id;
        END IF;

        INSERT INTO public.payment_transactions (
            booking_id,
            user_id,
            apartment_id,
            amount,
            payment_method,
            status,
            transaction_code,
            type,
            title,
            failure_reason
        ) VALUES (
            p_reference_id,
            v_user_id,
            v_apt_id,
            v_amount,
            'Demo Payment',
            p_outcome,
            v_tx_code,
            'SERVICE',
            v_title,
            CASE WHEN p_outcome = 'FAILED' THEN 'Mô phỏng lỗi giao dịch từ người dùng' ELSE NULL END
        ) RETURNING id INTO v_tx_id;
    END IF;

    RETURN jsonb_build_object(
        'success', (p_outcome = 'SUCCESS'),
        'transaction_code', v_tx_code,
        'transaction_id', v_tx_id,
        'amount', v_amount,
        'title', v_title,
        'paid_at', NOW()
    );
END;
$$;
