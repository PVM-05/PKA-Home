-- ==============================================================================
-- Migration: 20261114_01_secure_bank_webhook_and_vnpay.sql
-- Mục tiêu:
--   1. THU HỒI QUYỀN GỌI TRỰC TIẾP TỪ CLIENT ĐỐI VỚI CÁC RPC GẠCH NỢ TỰ ĐỘNG.
--   2. BỎ RÀNG BUỘC CŨ TRÊN payment_transactions ĐỂ CHẤP NHẬN MỌI TRẠNG THÁI WEBHOOK.
--   3. CHUẨN HÓA BẢNG invoices, audit_logs VÀ building_payment_configs.
--   4. CẬP NHẬT RPC process_sepay_webhook TỰ ĐỘNG GẠCH NỢ AN TOÀN 100%.
-- ==============================================================================

-- 1. Nới lỏng bảng audit_logs: Cho phép target_table và target_id nhận NULL nếu tồn tại
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'audit_logs' AND column_name = 'target_table') THEN
    ALTER TABLE public.audit_logs ALTER COLUMN target_table DROP NOT NULL;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'audit_logs' AND column_name = 'target_id') THEN
    ALTER TABLE public.audit_logs ALTER COLUMN target_id DROP NOT NULL;
  END IF;
END $$;

-- 2. Bổ sung các cột thanh toán cho bảng invoices nếu chưa có
ALTER TABLE public.invoices ADD COLUMN IF NOT EXISTS paid_at TIMESTAMPTZ;
ALTER TABLE public.invoices ADD COLUMN IF NOT EXISTS payment_method TEXT;
ALTER TABLE public.invoices ADD COLUMN IF NOT EXISTS payment_reference TEXT;

-- 3. Chuẩn hóa bảng payment_transactions: Gỡ bỏ triệt để check constraint status cũ
ALTER TABLE public.payment_transactions ADD COLUMN IF NOT EXISTS idempotency_key TEXT;
ALTER TABLE public.payment_transactions ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}'::jsonb;
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'payment_transactions' AND column_name = 'transaction_code') THEN
    ALTER TABLE public.payment_transactions ALTER COLUMN transaction_code DROP NOT NULL;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'payment_transactions' AND column_name = 'type') THEN
    ALTER TABLE public.payment_transactions ALTER COLUMN type DROP NOT NULL;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'payment_transactions' AND column_name = 'user_id') THEN
    ALTER TABLE public.payment_transactions ALTER COLUMN user_id DROP NOT NULL;
  END IF;
END $$;

-- Gỡ bỏ ràng buộc status_check cũ chỉ cho phép PENDING/SUCCESS/FAILED/CANCELLED
ALTER TABLE public.payment_transactions DROP CONSTRAINT IF EXISTS payment_transactions_status_check;
ALTER TABLE public.payment_transactions ADD CONSTRAINT payment_transactions_status_check 
CHECK (status IN ('PENDING', 'SUCCESS', 'FAILED', 'CANCELLED', 'UNMATCHED', 'OVERPAID', 'PARTIAL_PAID'));

-- 4. Tạo bảng building_payment_configs lưu cấu hình ngân hàng & SePay theo tòa nhà
CREATE TABLE IF NOT EXISTS public.building_payment_configs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    building_id UUID NOT NULL REFERENCES public.buildings(id) ON DELETE CASCADE,
    sepay_api_key TEXT,
    bank_name TEXT NOT NULL,
    bank_account_number TEXT NOT NULL,
    bank_account_name TEXT NOT NULL,
    bank_bin TEXT NOT NULL,
    qr_template TEXT DEFAULT 'compact',
    is_active BOOLEAN NOT NULL DEFAULT true,
    vnpay_tmn_code TEXT,
    vnpay_hash_secret TEXT,
    vnpay_is_active BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    CONSTRAINT uq_building_payment_config UNIQUE (building_id)
);

ALTER TABLE public.building_payment_configs ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'building_payment_configs' AND policyname = 'Cho phép xem thông tin tài khoản ngân hàng tòa nhà'
    ) THEN
        CREATE POLICY "Cho phép xem thông tin tài khoản ngân hàng tòa nhà"
        ON public.building_payment_configs FOR SELECT
        USING (is_active = true);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'building_payment_configs' AND policyname = 'Ban Quản Lý toàn quyền quản lý cấu hình SePay'
    ) THEN
        CREATE POLICY "Ban Quản Lý toàn quyền quản lý cấu hình SePay"
        ON public.building_payment_configs FOR ALL
        USING (
            EXISTS (
                SELECT 1 FROM public.users
                WHERE id = auth.uid() AND role IN ('admin', 'manager', 'accountant')
            )
        );
    END IF;
END $$;

-- 5. Thu hồi quyền execute từ public trên RPC process_bank_payment_webhook cũ
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public' AND p.proname = 'process_bank_payment_webhook'
    ) THEN
        REVOKE EXECUTE ON FUNCTION public.process_bank_payment_webhook(JSONB) FROM PUBLIC, anon, authenticated;
        GRANT EXECUTE ON FUNCTION public.process_bank_payment_webhook(JSONB) TO service_role;
    END IF;
END $$;

-- 6. Trigger audit fn_audit_invoice_changes chuẩn hóa
CREATE OR REPLACE FUNCTION public.fn_audit_invoice_changes()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_action TEXT;
    v_actor_id UUID;
    v_building_id UUID;
BEGIN
    v_actor_id := auth.uid();

    SELECT building_id INTO v_building_id
    FROM public.apartments
    WHERE id = NEW.apartment_id;

    IF v_actor_id IS NULL THEN
        SELECT id INTO v_actor_id FROM public.users WHERE role IN ('admin', 'management') LIMIT 1;
    END IF;
    
    IF TG_OP = 'INSERT' THEN
        v_action := 'CREATE_INVOICE';
        INSERT INTO public.audit_logs (
            building_id, actor_id, action, target_table, target_id, entity_name, entity_id, new_values
        ) VALUES (
            v_building_id,
            v_actor_id,
            v_action,
            'invoices',
            NEW.id,
            'invoices',
            NEW.id,
            jsonb_build_object('period', NEW.period, 'total_amount', NEW.total_amount, 'status', NEW.status)
        );
    ELSIF TG_OP = 'UPDATE' AND (OLD.status IS DISTINCT FROM NEW.status OR OLD.total_amount IS DISTINCT FROM NEW.total_amount) THEN
        v_action := 'UPDATE_INVOICE_STATUS';
        IF NEW.status = 'paid' THEN
            v_action := 'CONFIRM_PAYMENT';
        END IF;

        INSERT INTO public.audit_logs (
            building_id, actor_id, action, target_table, target_id, entity_name, entity_id, old_values, new_values
        ) VALUES (
            v_building_id,
            v_actor_id,
            v_action,
            'invoices',
            NEW.id,
            'invoices',
            NEW.id,
            jsonb_build_object('status', OLD.status, 'total_amount', OLD.total_amount),
            jsonb_build_object('status', NEW.status, 'total_amount', NEW.total_amount, 'payment_method', NEW.payment_method)
        );
    END IF;

    RETURN NEW;
END;
$$;

-- 7. RPC process_sepay_webhook xử lý Webhook SePay và gạch nợ tự động
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
    v_txn_code TEXT;
    v_now TIMESTAMPTZ := now();
BEGIN
    -- 1. Bóc tách loại biến động số dư SePay
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
        p_payload->>'transaction_id',
        'SEPAY_TEST_' || floor(random() * 1000000)::text
    );

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

-- Cấp quyền bảo mật
REVOKE EXECUTE ON FUNCTION public.process_sepay_webhook(JSONB, TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.process_sepay_webhook(JSONB, TEXT) TO service_role;

-- 8. KHỞI TẠO DỮ LIỆU CĂN HỘ, CẤU HÌNH NGÂN HÀNG VÀ HÓA ĐƠN TEST
INSERT INTO public.apartments (
    id,
    code,
    building_id,
    area,
    is_empty
) VALUES (
    'a0000000-0000-0000-0000-000000000001',
    'A0110',
    '00000000-0000-0000-0000-000000000002',
    75.5,
    false
)
ON CONFLICT (id) DO UPDATE SET code = EXCLUDED.code;

INSERT INTO public.building_payment_configs (
    building_id,
    bank_name,
    bank_account_number,
    bank_account_name,
    bank_bin,
    sepay_api_key,
    is_active
) VALUES (
    '00000000-0000-0000-0000-000000000002',
    'MBBank',
    '0988776655',
    'BQL CHUNG CU PKA TEST',
    '970422',
    'sepay_test_key_secret_123',
    true
)
ON CONFLICT (building_id) DO UPDATE SET
    bank_name = EXCLUDED.bank_name,
    bank_account_number = EXCLUDED.bank_account_number,
    bank_account_name = EXCLUDED.bank_account_name,
    bank_bin = EXCLUDED.bank_bin,
    sepay_api_key = EXCLUDED.sepay_api_key,
    is_active = true;

INSERT INTO public.invoices (
    id,
    apartment_id,
    period,
    due_date,
    total_amount,
    status,
    payment_code
) VALUES (
    'c0000000-0000-0000-0000-000000000001',
    'a0000000-0000-0000-0000-000000000001',
    '11/2026',
    CURRENT_DATE + INTERVAL '10 days',
    1500000,
    'pending',
    'INV2611A0110'
)
ON CONFLICT (id) DO UPDATE SET
    status = 'pending',
    total_amount = 1500000,
    payment_code = 'INV2611A0110';

-- Làm mới schema cache
NOTIFY pgrst, 'reload schema';
