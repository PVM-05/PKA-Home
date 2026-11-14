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

-- 4. Cho phép payment_transactions.user_id nhận giá trị NULL cho giao dịch vãng lai chưa khớp (UNMATCHED)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'payment_transactions' 
          AND column_name = 'user_id' AND is_nullable = 'NO'
    ) THEN
        ALTER TABLE public.payment_transactions ALTER COLUMN user_id DROP NOT NULL;
    END IF;
END $$;

-- 5. Cập nhật RPC process_sepay_webhook an toàn tuyệt đối (không bị lỗi foreign key khi chưa có admin)
CREATE OR REPLACE FUNCTION public.process_sepay_webhook(
    p_payload JSONB,
    p_api_key TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_sepay_id TEXT;
    v_transfer_type TEXT;
    v_content TEXT;
    v_amount NUMERIC(15,2);
    v_invoice RECORD;
    v_user_id UUID;
    v_receipt_number TEXT;
    v_now TIMESTAMPTZ := now();
    v_account_number TEXT;
BEGIN
    -- 1. Bóc tách loại biến động số dư SePay (transferType: 'in' là tiền vào, 'out' là tiền ra)
    v_transfer_type := LOWER(COALESCE(p_payload->>'transferType', 'in'));
    IF v_transfer_type = 'out' THEN
        RETURN jsonb_build_object(
            'success', true,
            'status', 'IGNORED_OUTGOING',
            'message', 'Giao dịch chi tiền ra khỏi tài khoản, bỏ qua an toàn.'
        );
    END IF;

    -- 2. Trích xuất mã giao dịch SePay (Idempotency Key)
    v_sepay_id := COALESCE(
        p_payload->>'id',
        p_payload->>'referenceCode',
        p_payload->>'gateway_transaction_id',
        p_payload->>'transaction_id'
    );

    IF v_sepay_id IS NULL OR v_sepay_id = '' THEN
        RAISE EXCEPTION 'Webhook payload SePay thiếu thông tin định danh giao dịch (id hoặc referenceCode)';
    END IF;

    -- Kiểm tra giao dịch đã được gạch nợ thành công trước đó chưa (Chống lặp Idempotency)
    IF EXISTS (
        SELECT 1 FROM public.payment_transactions
        WHERE idempotency_key = v_sepay_id AND status = 'SUCCESS'
    ) THEN
        RETURN jsonb_build_object(
            'success', true,
            'status', 'DUPLICATE',
            'message', 'Giao dịch SePay này đã được ghi nhận và gạch nợ trước đó.'
        );
    END IF;

    v_content := COALESCE(p_payload->>'content', p_payload->>'description', '');
    v_amount := COALESCE(
        (p_payload->>'transferAmount')::NUMERIC,
        (p_payload->>'amount')::NUMERIC,
        0.0
    );
    v_account_number := COALESCE(p_payload->>'accountNumber', '');

    -- 3. Tìm kiếm hóa đơn tương ứng dựa vào payment_code trong nội dung chuyển khoản
    SELECT * INTO v_invoice
    FROM public.invoices
    WHERE (
        payment_code IS NOT NULL AND 
        v_content ILIKE '%' || payment_code || '%'
    ) OR (
        lookup_code IS NOT NULL AND
        v_content ILIKE '%' || lookup_code || '%'
    ) OR (
        p_payload->>'invoice_id' IS NOT NULL AND id::text = p_payload->>'invoice_id'
    )
    ORDER BY created_at DESC
    LIMIT 1
    FOR UPDATE;

    -- 4. Nếu không tìm thấy hóa đơn khớp (Cư dân gõ sai cú pháp nội dung chuyển khoản)
    IF NOT FOUND THEN
        SELECT id INTO v_user_id FROM public.users WHERE role IN ('admin', 'management') LIMIT 1;

        INSERT INTO public.payment_transactions (
            reference_id, user_id, payment_type, payment_method,
            amount, status, idempotency_key, failure_reason, metadata, created_at, updated_at
        ) VALUES (
            gen_random_uuid(),
            v_user_id,
            'INVOICE', 'VIETQR',
            v_amount, 'UNMATCHED', v_sepay_id,
            'Không tìm thấy hóa đơn khớp với nội dung chuyển khoản SePay: ' || v_content,
            p_payload, v_now, v_now
        );

        RETURN jsonb_build_object(
            'success', false,
            'status', 'UNMATCHED',
            'message', 'Không tìm thấy hóa đơn khớp với nội dung chuyển khoản SePay. Giao dịch được chuyển vào hàng đợi đối soát thủ công.'
        );
    END IF;

    -- 5. Tìm user_id đại diện căn hộ
    SELECT user_id INTO v_user_id
    FROM public.residents_apartments
    WHERE apartment_id = v_invoice.apartment_id
    LIMIT 1;

    IF v_user_id IS NULL THEN
        SELECT id INTO v_user_id FROM public.users WHERE role IN ('admin', 'management') LIMIT 1;
    END IF;

    -- 6. Sinh số chứng từ biên lai điện tử
    v_receipt_number := 'REC-' || to_char(v_now, 'YYYYMMDD') || '-' || upper(substring(gen_random_uuid()::text, 1, 6));

    -- 7. Xử lý gạch nợ theo số tiền
    IF v_invoice.status = 'paid' THEN
        -- Đã trả trước đó: Ghi nhận giao dịch nộp thừa/trùng
        INSERT INTO public.payment_transactions (
            reference_id, invoice_id, user_id, apartment_id, payment_type,
            payment_method, amount, status, receipt_number, idempotency_key, metadata, created_at, updated_at
        ) VALUES (
            v_invoice.id, v_invoice.id, v_user_id, v_invoice.apartment_id, 'INVOICE',
            'VIETQR', v_amount, 'OVERPAID', v_receipt_number, v_sepay_id, p_payload, v_now, v_now
        );

        RETURN jsonb_build_object(
            'success', true,
            'status', 'OVERPAID',
            'invoice_id', v_invoice.id,
            'message', 'Hóa đơn đã được thanh toán trước đó. Giao dịch SePay được ghi nhận để đối soát hoàn tiền.'
        );
    ELSIF v_amount >= v_invoice.total_amount THEN
        -- Nộp đủ hoặc thừa tiền: GẠCH NỢ THÀNH CÔNG TỰ ĐỘNG
        UPDATE public.invoices
        SET status = 'paid',
            paid_at = v_now,
            payment_method = 'vietqr',
            payment_reference = v_sepay_id,
            receipt_number = v_receipt_number,
            updated_at = v_now
        WHERE id = v_invoice.id;

        INSERT INTO public.payment_transactions (
            reference_id, invoice_id, user_id, apartment_id, payment_type,
            payment_method, amount, status, receipt_number, idempotency_key, metadata, created_at, updated_at
        ) VALUES (
            v_invoice.id, v_invoice.id, v_user_id, v_invoice.apartment_id, 'INVOICE',
            'VIETQR', v_amount, 'SUCCESS', v_receipt_number, v_sepay_id, p_payload, v_now, v_now
        );

        RETURN jsonb_build_object(
            'success', true,
            'status', 'SUCCESS',
            'invoice_id', v_invoice.id,
            'receipt_number', v_receipt_number,
            'message', 'Gạch nợ hóa đơn tự động qua SePay Webhook thành công.'
        );
    ELSE
        -- Nộp thiếu tiền: Cập nhật một phần
        INSERT INTO public.payment_transactions (
            reference_id, invoice_id, user_id, apartment_id, payment_type,
            payment_method, amount, status, receipt_number, idempotency_key, metadata, created_at, updated_at
        ) VALUES (
            v_invoice.id, v_invoice.id, v_user_id, v_invoice.apartment_id, 'INVOICE',
            'VIETQR', v_amount, 'PARTIAL_PAID', v_receipt_number, v_sepay_id, p_payload, v_now, v_now
        );

        RETURN jsonb_build_object(
            'success', false,
            'status', 'PARTIAL_PAID',
            'invoice_id', v_invoice.id,
            'received_amount', v_amount,
            'expected_amount', v_invoice.total_amount,
            'message', 'Số tiền thanh toán SePay chưa đủ so với tổng giá trị hóa đơn.'
        );
    END IF;
END;
$$;

-- Đảm bảo service_role có quyền gọi RPC vừa cập nhật
REVOKE EXECUTE ON FUNCTION public.process_sepay_webhook(JSONB, TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.process_sepay_webhook(JSONB, TEXT) TO service_role;


