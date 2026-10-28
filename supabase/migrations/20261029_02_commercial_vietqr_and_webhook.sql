-- ==============================================================================
-- Migration: 20261029_02_commercial_vietqr_and_webhook.sql
-- Description: Cổng thanh toán VietQR động chuẩn Napas 247 và RPC xử lý
--              Webhook biến động số dư ngân hàng tự động gạch nợ.
-- ==============================================================================

-- 1. BỔ SUNG CỘT CHO BẢNG INVOICES VÀ BUILDINGS
ALTER TABLE public.invoices
    ADD COLUMN IF NOT EXISTS payment_code VARCHAR(30);

CREATE UNIQUE INDEX IF NOT EXISTS idx_invoices_payment_code ON public.invoices(payment_code);

ALTER TABLE public.buildings
    ADD COLUMN IF NOT EXISTS bank_bin VARCHAR(10) DEFAULT '970422'; -- Mã BIN ngân hàng (VD: 970422 - MBBank, 970436 - Vietcombank)


-- 2. TRIGGER TỰ ĐỘNG SINH PAYMENT_CODE CHO HÓA ĐƠN
CREATE OR REPLACE FUNCTION public.fn_generate_invoice_payment_code()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.payment_code IS NULL OR NEW.payment_code = '' THEN
        NEW.payment_code := 'INV' || to_char(COALESCE(NEW.period, CURRENT_DATE), 'YYMM') || upper(substring(NEW.id::text, 1, 6));
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_generate_invoice_payment_code ON public.invoices;
CREATE TRIGGER trg_generate_invoice_payment_code
    BEFORE INSERT ON public.invoices
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_generate_invoice_payment_code();

-- Nạp mã payment_code cho các hóa đơn cũ chưa có
UPDATE public.invoices
SET payment_code = 'INV' || to_char(COALESCE(period, CURRENT_DATE), 'YYMM') || upper(substring(id::text, 1, 6))
WHERE payment_code IS NULL;


-- 3. RPC XỬ LÝ WEBHOOK BIẾN ĐỘNG SỐ DƯ TỰ ĐỘNG GẠCH NỢ (PROCESS_BANK_PAYMENT_WEBHOOK)
CREATE OR REPLACE FUNCTION public.process_bank_payment_webhook(
    p_payload JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_gateway_tx_id TEXT;
    v_content TEXT;
    v_amount NUMERIC(15,2);
    v_invoice RECORD;
    v_user_id UUID;
    v_receipt_number TEXT;
    v_now TIMESTAMPTZ := now();
BEGIN
    -- 1. Trích xuất mã giao dịch cổng thanh toán / ngân hàng (Idempotency Key)
    v_gateway_tx_id := COALESCE(
        p_payload->>'gateway_transaction_id',
        p_payload->>'transaction_id',
        p_payload->>'reference',
        p_payload->>'id'
    );

    IF v_gateway_tx_id IS NULL OR v_gateway_tx_id = '' THEN
        RAISE EXCEPTION 'Webhook payload thiếu thông tin mã giao dịch ngân hàng (gateway_transaction_id)';
    END IF;

    -- Kiểm tra giao dịch đã được xử lý chưa (Chống lặp Idempotency)
    IF EXISTS (
        SELECT 1 FROM public.payment_transactions
        WHERE idempotency_key = v_gateway_tx_id AND status = 'SUCCESS'
    ) THEN
        RETURN jsonb_build_object(
            'success', true,
            'status', 'DUPLICATE',
            'message', 'Giao dịch này đã được ghi nhận và gạch nợ trước đó.'
        );
    END IF;

    v_content := COALESCE(p_payload->>'content', p_payload->>'description', '');
    v_amount := COALESCE((p_payload->>'amount')::NUMERIC, 0.0);

    -- 2. Tìm kiếm hóa đơn tương ứng dựa vào payment_code trong nội dung chuyển khoản
    SELECT * INTO v_invoice
    FROM public.invoices
    WHERE (
        payment_code IS NOT NULL AND 
        v_content ILIKE '%' || payment_code || '%'
    ) OR (
        p_payload->>'invoice_id' IS NOT NULL AND id::text = p_payload->>'invoice_id'
    )
    ORDER BY created_at DESC
    LIMIT 1
    FOR UPDATE;

    -- Nếu không tìm thấy hóa đơn khớp
    IF NOT FOUND THEN
        INSERT INTO public.payment_transactions (
            reference_id, user_id, payment_type, payment_method,
            amount, status, idempotency_key, failure_reason, metadata, created_at, updated_at
        ) VALUES (
            gen_random_uuid(),
            COALESCE((SELECT id FROM public.users WHERE role = 'admin' LIMIT 1), gen_random_uuid()),
            'INVOICE', 'VIETQR',
            v_amount, 'UNMATCHED', v_gateway_tx_id,
            'Không tìm thấy hóa đơn khớp với nội dung: ' || v_content,
            p_payload, v_now, v_now
        );

        RETURN jsonb_build_object(
            'success', false,
            'status', 'UNMATCHED',
            'message', 'Không tìm thấy hóa đơn khớp với nội dung chuyển khoản.'
        );
    END IF;

    -- 3. Tìm user_id đại diện căn hộ
    SELECT user_id INTO v_user_id
    FROM public.residents_apartments
    WHERE apartment_id = v_invoice.apartment_id
    LIMIT 1;

    IF v_user_id IS NULL THEN
        SELECT id INTO v_user_id FROM public.users WHERE role = 'admin' LIMIT 1;
    END IF;

    -- 4. Kiểm tra số tiền và gạch nợ
    v_receipt_number := 'REC-' || to_char(v_now, 'YYYYMMDD') || '-' || upper(substring(gen_random_uuid()::text, 1, 6));

    IF v_invoice.status = 'paid' THEN
        -- Đã trả trước đó, ghi nhận giao dịch nộp thừa/trùng
        INSERT INTO public.payment_transactions (
            reference_id, invoice_id, user_id, apartment_id, payment_type,
            payment_method, amount, status, receipt_number, idempotency_key, metadata, created_at, updated_at
        ) VALUES (
            v_invoice.id, v_invoice.id, v_user_id, v_invoice.apartment_id, 'INVOICE',
            'VIETQR', v_amount, 'OVERPAID', v_receipt_number, v_gateway_tx_id, p_payload, v_now, v_now
        );

        RETURN jsonb_build_object(
            'success', true,
            'status', 'OVERPAID',
            'message', 'Hóa đơn đã được thanh toán trước đó. Giao dịch được ghi nhận để hoàn tiền.'
        );
    ELSIF v_amount >= v_invoice.total_amount THEN
        -- Nộp đủ tiền: Gạch nợ thành công
        UPDATE public.invoices
        SET status = 'paid',
            paid_at = v_now,
            payment_method = 'vietqr',
            payment_reference = v_gateway_tx_id,
            updated_at = v_now
        WHERE id = v_invoice.id;

        INSERT INTO public.payment_transactions (
            reference_id, invoice_id, user_id, apartment_id, payment_type,
            payment_method, amount, status, receipt_number, idempotency_key, metadata, created_at, updated_at
        ) VALUES (
            v_invoice.id, v_invoice.id, v_user_id, v_invoice.apartment_id, 'INVOICE',
            'VIETQR', v_amount, 'SUCCESS', v_receipt_number, v_gateway_tx_id, p_payload, v_now, v_now
        );

        -- Tự động kích hoạt các triggers:
        -- 1. trg_audit_invoice_changes -> Ghi nhật ký kiểm toán CONFIRM_PAYMENT vào audit_logs
        -- 2. trg_notify_on_invoice_paid -> Bắn thông báo và biên lai tới Cư Dân

        RETURN jsonb_build_object(
            'success', true,
            'status', 'SUCCESS',
            'invoice_id', v_invoice.id,
            'receipt_number', v_receipt_number,
            'message', 'Gạch nợ hóa đơn thành công.'
        );
    ELSE
        -- Nộp thiếu tiền: Ghi nhận thanh toán một phần
        INSERT INTO public.payment_transactions (
            reference_id, invoice_id, user_id, apartment_id, payment_type,
            payment_method, amount, status, idempotency_key, failure_reason, metadata, created_at, updated_at
        ) VALUES (
            v_invoice.id, v_invoice.id, v_user_id, v_invoice.apartment_id, 'INVOICE',
            'VIETQR', v_amount, 'PARTIAL_PAID', v_gateway_tx_id,
            'Nộp thiếu tiền: cần ' || v_invoice.total_amount || ', thực nhận ' || v_amount,
            p_payload, v_now, v_now
        );

        RETURN jsonb_build_object(
            'success', false,
            'status', 'PARTIAL_PAID',
            'message', 'Số tiền chuyển khoản chưa đủ để thanh toán toàn bộ hóa đơn.'
        );
    END IF;
END;
$$;
