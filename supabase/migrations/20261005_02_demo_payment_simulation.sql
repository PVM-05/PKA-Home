-- Migration: 20261005_02_demo_payment_simulation.sql
-- Hệ thống cổng thanh toán mô phỏng (Demo Payment Gateway & Transactions)

-- 1. Bảng lưu lịch sử giao dịch thanh toán
CREATE TABLE IF NOT EXISTS public.payment_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invoice_id UUID NOT NULL REFERENCES public.invoices(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    apartment_id UUID NOT NULL REFERENCES public.apartments(id) ON DELETE CASCADE,
    amount NUMERIC(12,2) NOT NULL CHECK (amount >= 0),
    payment_method VARCHAR(50) NOT NULL DEFAULT 'DEMO',
    status VARCHAR(20) NOT NULL CHECK (status IN ('SUCCESS', 'FAILED', 'CANCELLED')),
    transaction_code VARCHAR(100) NOT NULL UNIQUE,
    failure_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_payment_transactions_invoice ON public.payment_transactions(invoice_id);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_apartment ON public.payment_transactions(apartment_id);

-- 2. Kích hoạt RLS cho payment_transactions
ALTER TABLE public.payment_transactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Cư dân xem giao dịch căn hộ mình" ON public.payment_transactions;
CREATE POLICY "Cư dân xem giao dịch căn hộ mình" ON public.payment_transactions
FOR SELECT USING (
    apartment_id IN (
        SELECT apartment_id FROM public.residents_apartments WHERE user_id = auth.uid()
    ) OR public.is_staff()
);

DROP POLICY IF EXISTS "BQL quản lý giao dịch thanh toán" ON public.payment_transactions;
CREATE POLICY "BQL quản lý giao dịch thanh toán" ON public.payment_transactions
FOR ALL USING (public.is_staff());

-- 3. Nâng cấp bảng public.invoices bổ sung thông tin giao dịch
ALTER TABLE public.invoices
ADD COLUMN IF NOT EXISTS payment_method VARCHAR(50) DEFAULT NULL,
ADD COLUMN IF NOT EXISTS transaction_code VARCHAR(100) DEFAULT NULL,
ADD COLUMN IF NOT EXISTS paid_at TIMESTAMPTZ DEFAULT NULL;

-- 4. Bật Realtime cho payment_transactions
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
        AND schemaname = 'public' 
        AND tablename = 'payment_transactions'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.payment_transactions;
    END IF;
END $$;

ALTER TABLE public.payment_transactions REPLICA IDENTITY FULL;

-- 5. RPC Xử lý thanh toán mô phỏng an toàn (Atomic Transaction)
CREATE OR REPLACE FUNCTION public.simulate_invoice_payment(
    p_invoice_id UUID,
    p_outcome VARCHAR DEFAULT 'SUCCESS'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_invoice RECORD;
    v_transaction_code VARCHAR(100);
    v_has_access BOOLEAN := false;
BEGIN
    -- 1. Kiểm tra đăng nhập
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Bạn cần đăng nhập để thực hiện thanh toán.';
    END IF;

    -- 2. Khóa dòng hóa đơn và lấy thông tin căn hộ
    SELECT i.*, a.code AS apartment_code 
    INTO v_invoice 
    FROM public.invoices i
    JOIN public.apartments a ON i.apartment_id = a.id
    WHERE i.id = p_invoice_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Hóa đơn không tồn tại hoặc đã bị xóa.';
    END IF;

    -- 3. Kiểm tra quyền hạn (phải là cư dân căn hộ này hoặc BQL)
    IF public.is_staff() THEN
        v_has_access := true;
    ELSE
        SELECT EXISTS (
            SELECT 1 FROM public.residents_apartments 
            WHERE user_id = v_user_id AND apartment_id = v_invoice.apartment_id
        ) INTO v_has_access;
    END IF;

    IF NOT v_has_access THEN
        RAISE EXCEPTION 'Bạn không có quyền thanh toán cho hóa đơn của căn hộ này.';
    END IF;

    -- 4. Kiểm tra trạng thái hiện tại của hóa đơn
    IF v_invoice.status = 'paid' THEN
        RAISE EXCEPTION 'Hóa đơn này đã được thanh toán trước đó.';
    END IF;

    -- 5. Sinh mã giao dịch chuẩn hóa: PAY-YYYYMMDD-XXXXXX
    v_transaction_code := 'PAY-' || to_char(NOW(), 'YYYYMMDD') || '-' || upper(substr(md5(random()::text), 1, 6));

    -- 6. Xử lý theo kịch bản (SUCCESS, FAILED, CANCELLED)
    IF p_outcome = 'SUCCESS' THEN
        -- Ghi nhận bảng giao dịch
        INSERT INTO public.payment_transactions (
            invoice_id,
            user_id,
            apartment_id,
            amount,
            payment_method,
            status,
            transaction_code,
            created_at
        ) VALUES (
            p_invoice_id,
            v_user_id,
            v_invoice.apartment_id,
            v_invoice.total_amount,
            'DEMO',
            'SUCCESS',
            v_transaction_code,
            NOW()
        );

        -- Cập nhật hóa đơn
        UPDATE public.invoices
        SET status = 'paid',
            payment_method = 'DEMO',
            transaction_code = v_transaction_code,
            paid_at = NOW(),
            updated_at = NOW()
        WHERE id = p_invoice_id;

        -- Gửi thông báo cho cư dân
        INSERT INTO public.notifications (
            user_id,
            title,
            content,
            type,
            created_at
        ) VALUES (
            v_user_id,
            'Thanh toán hóa đơn thành công',
            format('Hóa đơn kỳ %s căn hộ %s (Số tiền: %s đ) đã thanh toán thành công qua Cổng mô phỏng. Mã GD: %s.', 
                   v_invoice.period, v_invoice.apartment_code, to_char(v_invoice.total_amount, 'FM999,999,999,999'), v_transaction_code),
            'invoice',
            NOW()
        );

        -- Ghi nhận lịch sử kiểm toán nếu bảng audit_logs tồn tại
        BEGIN
            INSERT INTO public.audit_logs (user_id, action, target_table, target_id, details)
            VALUES (
                v_user_id,
                'INVOICE_PAID_SIMULATION',
                'invoices',
                p_invoice_id,
                jsonb_build_object(
                    'transaction_code', v_transaction_code,
                    'amount', v_invoice.total_amount,
                    'period', v_invoice.period,
                    'method', 'DEMO'
                )
            );
        EXCEPTION WHEN undefined_table THEN
            -- Bỏ qua nếu audit_logs không tồn tại
            NULL;
        END;

        RETURN jsonb_build_object(
            'success', true,
            'status', 'paid',
            'transaction_code', v_transaction_code,
            'amount', v_invoice.total_amount,
            'message', 'Thanh toán hóa đơn thành công qua Cổng Demo.'
        );

    ELSIF p_outcome = 'FAILED' THEN
        -- Ghi nhận thất bại
        INSERT INTO public.payment_transactions (
            invoice_id,
            user_id,
            apartment_id,
            amount,
            payment_method,
            status,
            transaction_code,
            failure_reason,
            created_at
        ) VALUES (
            p_invoice_id,
            v_user_id,
            v_invoice.apartment_id,
            v_invoice.total_amount,
            'DEMO',
            'FAILED',
            v_transaction_code,
            'Giao dịch bị từ chối bởi cổng thanh toán mô phỏng (Demo).',
            NOW()
        );

        -- Hóa đơn giữ nguyên unpaid
        RETURN jsonb_build_object(
            'success', false,
            'status', v_invoice.status,
            'transaction_code', v_transaction_code,
            'message', 'Giao dịch thanh toán thất bại (Thử nghiệm).'
        );

    ELSE
        -- Hủy giao dịch (CANCELLED)
        INSERT INTO public.payment_transactions (
            invoice_id,
            user_id,
            apartment_id,
            amount,
            payment_method,
            status,
            transaction_code,
            failure_reason,
            created_at
        ) VALUES (
            p_invoice_id,
            v_user_id,
            v_invoice.apartment_id,
            v_invoice.total_amount,
            'DEMO',
            'CANCELLED',
            v_transaction_code,
            'Người dùng đã hủy giao dịch thanh toán.',
            NOW()
        );

        RETURN jsonb_build_object(
            'success', false,
            'status', v_invoice.status,
            'transaction_code', v_transaction_code,
            'message', 'Đã hủy giao dịch thanh toán.'
        );
    END IF;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.simulate_invoice_payment(UUID, VARCHAR) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.simulate_invoice_payment(UUID, VARCHAR) TO authenticated;
