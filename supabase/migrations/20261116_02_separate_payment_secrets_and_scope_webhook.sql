-- Migration: 20261116_02_separate_payment_secrets_and_scope_webhook.sql
-- Mục tiêu: Khắc phục triệt để lỗ hổng rò rỉ khóa bí mật SePay Webhook API Key và Cross-Tenant Spoofing:
-- 1. Tách biệt hoàn toàn bảng bí mật `building_payment_secrets` khỏi bảng công khai `building_payment_configs`.
-- 2. Xóa bỏ vĩnh viễn cột `sepay_api_key` và `vnpay_hash_secret` khỏi `building_payment_configs` để cư dân không thể đọc lén qua API.
-- 3. Xoay vòng khóa bí mật (Secret Rotation) cho các key cũ đã bị lộ sáng.
-- 4. Bật RLS nghiêm ngặt trên `building_payment_secrets`: Cấm tuyệt đối `anon` và `resident`, chỉ cho phép `service_role` và `admin`.
-- 5. Nâng cấp RPC `process_sepay_webhook`: Ràng buộc đối chiếu `p_api_key` chính xác theo từng Tòa nhà (Tenant-Scoped),
--    ngăn chặn triệt để lỗ hổng dùng API Key của Tòa nhà A để gạch nợ hóa đơn Tòa nhà B.

-- ==============================================================================
-- BƯỚC 1: TẠO BẢNG BÍ MẬT BUILDING_PAYMENT_SECRETS
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.building_payment_secrets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    building_id UUID NOT NULL REFERENCES public.buildings(id) ON DELETE CASCADE,
    sepay_api_key TEXT,
    vnpay_hash_secret TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    CONSTRAINT uq_building_payment_secrets_building UNIQUE (building_id)
);

-- Kích hoạt Row Level Security (RLS) bảo vệ đa tầng
ALTER TABLE public.building_payment_secrets ENABLE ROW LEVEL SECURITY;

-- Thu hồi toàn bộ quyền truy cập công khai
REVOKE ALL ON public.building_payment_secrets FROM PUBLIC, anon, authenticated;
GRANT ALL ON public.building_payment_secrets TO service_role;

-- Chỉ duy nhất Quản trị viên cấp cao (Admin) mới có quyền đọc/ghi cấu hình bảo mật
DROP POLICY IF EXISTS "Chỉ Quản trị viên cấp cao mới xem được payment secrets" ON public.building_payment_secrets;
CREATE POLICY "Chỉ Quản trị viên cấp cao mới xem được payment secrets"
ON public.building_payment_secrets
FOR ALL
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.users
        WHERE id = auth.uid() AND role = 'admin'
    )
);

-- ==============================================================================
-- BƯỚC 2: DI CHUYỂN DỮ LIỆU BÍ MẬT & XOAY VÒNG KHÓA (SECRET ROTATION)
-- ==============================================================================
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'building_payment_configs' 
          AND column_name = 'sepay_api_key'
    ) THEN
        INSERT INTO public.building_payment_secrets (building_id, sepay_api_key, vnpay_hash_secret)
        SELECT 
            building_id, 
            sepay_api_key, 
            COALESCE(
                (SELECT vnpay_hash_secret FROM public.building_payment_configs sub WHERE sub.id = main.id), 
                NULL
            )
        FROM public.building_payment_configs main
        WHERE sepay_api_key IS NOT NULL
        ON CONFLICT (building_id) DO UPDATE 
        SET sepay_api_key = EXCLUDED.sepay_api_key,
            updated_at = now();
    END IF;
END $$;

-- Xoay vòng khóa SePay cũ đã từng bị lộ sáng qua API cư dân
UPDATE public.building_payment_secrets
SET sepay_api_key = 'sec_pka_' || encode(gen_random_bytes(16), 'hex'),
    updated_at = now();

-- ==============================================================================
-- BƯỚC 3: XÓA CỘT BÍ MẬT KHỎI BẢNG CÔNG KHAI BUILDING_PAYMENT_CONFIGS
-- ==============================================================================
ALTER TABLE public.building_payment_configs DROP COLUMN IF EXISTS sepay_api_key;
ALTER TABLE public.building_payment_configs DROP COLUMN IF EXISTS vnpay_hash_secret;

-- ==============================================================================
-- BƯỚC 4: NÂNG CẤP RPC PROCESS_SEPAY_WEBHOOK RÀNG BUỘC THEO TÒA NHÀ (TENANT-SCOPED)
-- ==============================================================================
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
    v_expected_key TEXT;
    v_account_number TEXT;
    v_target_building_id UUID;
BEGIN
    -- 0. THẨM ĐỊNH BẢO MẬT API KEY BẮT BUỘC BAN ĐẦU (FAIL-CLOSED)
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

    -- 3. Tìm kiếm hóa đơn khớp theo payment_code hoặc lookup_code KÈM THEO BUILDING_ID
    SELECT i.*, a.building_id AS invoice_building_id
    INTO v_invoice
    FROM public.invoices i
    JOIN public.apartments a ON i.apartment_id = a.id
    WHERE (
        i.payment_code IS NOT NULL AND 
        v_content ILIKE '%' || i.payment_code || '%'
    ) OR (
        i.lookup_code IS NOT NULL AND
        v_content ILIKE '%' || i.lookup_code || '%'
    ) OR (
        p_payload->>'invoice_id' IS NOT NULL AND i.id::text = p_payload->>'invoice_id'
    )
    ORDER BY i.created_at DESC
    LIMIT 1
    FOR UPDATE OF i;

    -- 4. KIỂM TRA ĐỐI CHIẾU API KEY THEO TÒA NHÀ (TENANT-SCOPED SECURITY VERIFICATION)
    IF FOUND THEN
        -- ĐỐI CHIẾU VỚI BẢNG BÍ MẬT BUILDING_PAYMENT_SECRETS CỦA CHÍNH TÒA NHÀ CÓ HÓA ĐƠN
        SELECT sepay_api_key INTO v_expected_key
        FROM public.building_payment_secrets
        WHERE building_id = v_invoice.invoice_building_id;

        IF v_expected_key IS NULL OR trim(p_api_key) != trim(v_expected_key) THEN
            INSERT INTO public.audit_logs (
                actor_id, action, entity_name, details, created_at
            ) VALUES (
                NULL,
                'SEPAY_WEBHOOK_CROSS_TENANT_UNAUTHORIZED',
                'invoices',
                jsonb_build_object(
                    'reason', 'API Key không khớp với cấu hình SePay của tòa nhà chứa hóa đơn (Cross-Tenant Violation)',
                    'invoice_id', v_invoice.id,
                    'invoice_building_id', v_invoice.invoice_building_id,
                    'attempted_key_prefix', substring(trim(p_api_key), 1, 6) || '***',
                    'severity', 'CRITICAL',
                    'timestamp', v_now
                ),
                v_now
            );
            RAISE EXCEPTION '401 Unauthorized: API Key không khớp với cấu hình SePay của tòa nhà chứa hóa đơn.';
        END IF;
    ELSE
        -- TRƯỜNG HỢP GIAO DỊCH UNMATCHED (Không tìm thấy hóa đơn khớp)
        -- Thẩm định API Key thông qua số tài khoản ngân hàng thụ hưởng nhận tiền
        v_account_number := COALESCE(
            p_payload->>'accountNumber',
            p_payload->>'bank_account_number',
            p_payload->>'subAccount'
        );

        SELECT building_id INTO v_target_building_id
        FROM public.building_payment_configs
        WHERE is_active = true 
          AND v_account_number IS NOT NULL
          AND replace(bank_account_number, ' ', '') = replace(v_account_number, ' ', '')
        LIMIT 1;

        IF v_target_building_id IS NOT NULL THEN
            SELECT sepay_api_key INTO v_expected_key
            FROM public.building_payment_secrets
            WHERE building_id = v_target_building_id;
        END IF;

        IF v_target_building_id IS NULL OR v_expected_key IS NULL OR trim(p_api_key) != trim(v_expected_key) THEN
            INSERT INTO public.audit_logs (
                actor_id, action, entity_name, details, created_at
            ) VALUES (
                NULL,
                'SEPAY_WEBHOOK_UNAUTHORIZED',
                'invoices',
                jsonb_build_object(
                    'reason', 'API Key không hợp lệ hoặc số tài khoản ngân hàng không thuộc tòa nhà nào trong hệ thống',
                    'target_account', v_account_number,
                    'attempted_key_prefix', substring(trim(p_api_key), 1, 6) || '***',
                    'severity', 'CRITICAL',
                    'timestamp', v_now
                ),
                v_now
            );
            RAISE EXCEPTION '401 Unauthorized: API Key không hợp lệ hoặc số tài khoản ngân hàng không khớp.';
        END IF;

        -- Ghi nhận giao dịch chưa khớp UNMATCHED để BQL đối soát
        SELECT id INTO v_user_id FROM public.users WHERE role IN ('admin', 'manager') LIMIT 1;

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
        SELECT id INTO v_user_id FROM public.users WHERE role IN ('admin', 'manager') LIMIT 1;
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

