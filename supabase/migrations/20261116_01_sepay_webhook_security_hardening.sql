-- Migration: 20261116_01_sepay_webhook_security_hardening.sql
-- Mục tiêu: Khắc phục triệt để lỗ hổng Webhook SePay (Webhook Spoofing Vulnerability)
-- 1. Yêu cầu p_api_key là tham số BẮT BUỘC trong RPC process_sepay_webhook (Fail-Closed).
-- 2. Thẩm định p_api_key với cấu hình sepay_api_key đang hoạt động trong building_payment_configs.
-- 3. Ghi vết kiểm toán an ninh SEPAY_WEBHOOK_UNAUTHORIZED vào audit_logs khi phát hiện truy cập bất hợp pháp.
-- 4. Thu hồi quyền EXECUTE từ PUBLIC, anon, authenticated; chỉ cho phép service_role (Edge Function) thực thi.

CREATE OR REPLACE FUNCTION public.process_sepay_webhook(
    p_payload JSONB,
    p_api_key TEXT
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
    v_txn_code TEXT;
    v_now TIMESTAMPTZ := now();
BEGIN
    -- 0. THẨM ĐỊNH BẢO MẬT API KEY BẮT BUỘC (FAIL-CLOSED DEFENSE)
    IF p_api_key IS NULL OR trim(p_api_key) = '' THEN
        INSERT INTO public.audit_logs (
            actor_id, action, entity_name, details, created_at
        ) VALUES (
            NULL,
            'SEPAY_WEBHOOK_UNAUTHORIZED',
            'invoices',
            jsonb_build_object(
                'reason', 'Thiếu API Key xác thực khi gọi Webhook SePay',
                'severity', 'CRITICAL',
                'timestamp', v_now
            ),
            v_now
        );
        RAISE EXCEPTION '401 Unauthorized: p_api_key không được cung cấp hoặc để trống.';
    END IF;

    -- Kiểm tra p_api_key có khớp với bất kỳ cấu hình SePay tòa nhà đang kích hoạt trong hệ thống
    IF NOT EXISTS (
        SELECT 1 FROM public.building_payment_configs
        WHERE is_active = true 
          AND sepay_api_key IS NOT NULL 
          AND sepay_api_key = trim(p_api_key)
    ) THEN
        INSERT INTO public.audit_logs (
            actor_id, action, entity_name, details, created_at
        ) VALUES (
            NULL,
            'SEPAY_WEBHOOK_UNAUTHORIZED',
            'invoices',
            jsonb_build_object(
                'reason', 'API Key Webhook không hợp lệ hoặc không khớp với cấu hình tòa nhà',
                'attempted_key_prefix', substring(trim(p_api_key), 1, 6) || '***',
                'severity', 'CRITICAL',
                'timestamp', v_now
            ),
            v_now
        );
        RAISE EXCEPTION '401 Unauthorized: API Key không hợp lệ hoặc chưa được đăng ký trong hệ thống.';
    END IF;

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

    IF v_sepay_id IS NULL OR trim(v_sepay_id) = '' THEN
        RAISE EXCEPTION 'Webhook payload SePay thiếu thông tin định danh giao dịch (id hoặc referenceCode)';
    END IF;

    -- Đảm bảo mã transaction_code luôn duy nhất tuyệt đối
    v_txn_code := 'TXN_' || v_sepay_id || '_' || upper(substring(gen_random_uuid()::text, 1, 8));

    -- Kiểm tra chống trùng lặp Idempotency
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

    -- 3. Tìm kiếm hóa đơn khớp theo payment_code hoặc lookup_code
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

    -- 4. Nếu không tìm thấy hóa đơn khớp (SePay gửi thử nghiệm mẫu hoặc cư dân gõ sai nội dung)
    IF NOT FOUND THEN
        SELECT id INTO v_user_id FROM public.users WHERE role IN ('admin', 'management') LIMIT 1;

        INSERT INTO public.payment_transactions (
            reference_id, user_id, payment_type, payment_method,
            amount, status, idempotency_key, failure_reason, metadata, created_at, updated_at,
            type, transaction_code
        ) VALUES (
            gen_random_uuid(),
            v_user_id,
            'INVOICE', 'VIETQR',
            v_amount, 'PENDING', v_sepay_id,
            'Không tìm thấy hóa đơn khớp với nội dung chuyển khoản SePay: ' || v_content,
            p_payload, v_now, v_now,
            'INVOICE', v_txn_code
        );

        RETURN jsonb_build_object(
            'success', true,
            'status', 'UNMATCHED',
            'message', 'Không tìm thấy hóa đơn khớp với nội dung chuyển khoản SePay. Giao dịch được lưu ở trạng thái PENDING để đối soát.'
        );
    END IF;

    -- 5. Lấy user_id đại diện căn hộ
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
        INSERT INTO public.payment_transactions (
            reference_id, invoice_id, user_id, apartment_id, payment_type,
            payment_method, amount, status, receipt_number, idempotency_key, metadata, created_at, updated_at,
            type, transaction_code
        ) VALUES (
            v_invoice.id, v_invoice.id, v_user_id, v_invoice.apartment_id, 'INVOICE',
            'VIETQR', v_amount, 'SUCCESS', v_receipt_number, v_sepay_id, p_payload, v_now, v_now,
            'INVOICE', v_txn_code
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
            payment_method, amount, status, receipt_number, idempotency_key, metadata, created_at, updated_at,
            type, transaction_code
        ) VALUES (
            v_invoice.id, v_invoice.id, v_user_id, v_invoice.apartment_id, 'INVOICE',
            'VIETQR', v_amount, 'SUCCESS', v_receipt_number, v_sepay_id, p_payload, v_now, v_now,
            'INVOICE', v_txn_code
        );

        RETURN jsonb_build_object(
            'success', true,
            'status', 'SUCCESS',
            'invoice_id', v_invoice.id,
            'receipt_number', v_receipt_number,
            'message', 'Gạch nợ hóa đơn tự động qua SePay Webhook thành công.'
        );
    ELSE
        -- Nộp thiếu tiền
        INSERT INTO public.payment_transactions (
            reference_id, invoice_id, user_id, apartment_id, payment_type,
            payment_method, amount, status, receipt_number, idempotency_key, metadata, created_at, updated_at,
            type, transaction_code
        ) VALUES (
            v_invoice.id, v_invoice.id, v_user_id, v_invoice.apartment_id, 'INVOICE',
            'VIETQR', v_amount, 'PENDING', v_receipt_number, v_sepay_id, p_payload, v_now, v_now,
            'INVOICE', v_txn_code
        );

        RETURN jsonb_build_object(
            'success', true,
            'status', 'PARTIAL_PAID',
            'invoice_id', v_invoice.id,
            'received_amount', v_amount,
            'expected_amount', v_invoice.total_amount,
            'message', 'Số tiền thanh toán SePay chưa đủ so với tổng giá trị hóa đơn.'
        );
    END IF;
END;
$$;

-- Thu hồi quyền từ public/anon/authenticated, chỉ cho phép service_role
REVOKE EXECUTE ON FUNCTION public.process_sepay_webhook(JSONB, TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.process_sepay_webhook(JSONB, TEXT) TO service_role;

