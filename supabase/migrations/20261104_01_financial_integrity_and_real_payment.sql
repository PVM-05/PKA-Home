-- ==============================================================================
-- Migration: 20261104_01_financial_integrity_and_real_payment.sql
-- Mục tiêu: Khắc phục triệt để các lỗ hổng P0 về tính toàn vẹn tài chính & thanh toán
--   1. Thu hồi quyền gọi simulate_unified_payment từ authenticated/public.
--   2. Khởi tạo Sequence và ràng buộc chống trùng số chứng từ sổ quỹ bảo trì 2%.
--   3. Củng cố hàm record_maintenance_fund_transaction (auth.uid() + has_building_role + sequence).
--   4. Ban hành RPC create_payment_intent chuẩn an toàn PENDING cho thanh toán thật.
-- ==============================================================================

-- 1. THU HỒI QUYỀN GỌI simulate_unified_payment TỪ AUTHENTICATED & PUBLIC
-- Ngăn chặn triệt để việc client tự truyền outcome = 'SUCCESS' để tự gạch nợ hóa đơn
REVOKE EXECUTE ON FUNCTION public.simulate_unified_payment(UUID, TEXT, TEXT, TEXT, TEXT) FROM authenticated, anon, PUBLIC;

-- 2. KHỞI TẠO SEQUENCES VÀ RÀNG BUỘC CHỐNG TRÙNG SỐ CHỨNG TỪ SỔ QUỸ BẢO TRÌ 2%
CREATE SEQUENCE IF NOT EXISTS public.maintenance_fund_pt_seq START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE IF NOT EXISTS public.maintenance_fund_pc_seq START WITH 1 INCREMENT BY 1;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'uq_maintenance_fund_building_voucher'
    ) THEN
        ALTER TABLE public.maintenance_fund_transactions
        ADD CONSTRAINT uq_maintenance_fund_building_voucher UNIQUE (building_id, voucher_number);
    END IF;
END $$;

-- 3. CỦNG CỐ HÀM GHI SỔ QUỸ BẢO TRÌ (RECORD_MAINTENANCE_FUND_TRANSACTION)
CREATE OR REPLACE FUNCTION public.record_maintenance_fund_transaction(
    p_building_id UUID,
    p_transaction_type TEXT,
    p_amount NUMERIC(15,2),
    p_category TEXT,
    p_description TEXT,
    p_receipt_url TEXT DEFAULT NULL,
    p_reference_id UUID DEFAULT NULL,
    p_created_by UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_user_id UUID;
    v_fund_id UUID;
    v_current_balance NUMERIC(15,2);
    v_new_balance NUMERIC(15,2);
    v_period TEXT;
    v_prefix TEXT;
    v_seq BIGINT;
    v_voucher_number TEXT;
    v_tx_id UUID;
BEGIN
    -- 1. Xác thực danh tính người tạo an toàn từ auth.uid()
    v_user_id := COALESCE(auth.uid(), p_created_by);
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Yêu cầu đăng nhập để thực hiện ghi sổ quỹ bảo trì.';
    END IF;

    -- 2. Kiểm tra thẩm quyền kế toán tại tòa nhà tương ứng
    IF NOT public.has_building_role(p_building_id, ARRAY['accountant', 'manager', 'admin', 'head_of_management']) THEN
        RAISE EXCEPTION 'Bạn không có quyền kế toán hoặc quản trị để ghi sổ quỹ bảo trì tại tòa nhà này.';
    END IF;

    -- 3. Kiểm tra tính hợp lệ của số tiền
    IF p_amount <= 0 THEN
        RAISE EXCEPTION 'Số tiền giao dịch phải lớn hơn 0.';
    END IF;

    -- 4. Tìm và khóa bản ghi quỹ bảo trì của tòa nhà (FOR UPDATE chống race condition)
    SELECT id, total_balance INTO v_fund_id, v_current_balance
    FROM public.maintenance_funds
    WHERE building_id = p_building_id
    LIMIT 1
    FOR UPDATE;

    IF v_fund_id IS NULL THEN
        INSERT INTO public.maintenance_funds (building_id, total_balance)
        VALUES (p_building_id, 0.00)
        RETURNING id, total_balance INTO v_fund_id, v_current_balance;
    END IF;

    -- 5. Tính số dư mới và chọn tiền tố chứng từ
    SELECT to_char(CURRENT_DATE, 'YYYYMM') INTO v_period;

    IF p_transaction_type = 'INCOME' THEN
        v_new_balance := v_current_balance + p_amount;
        v_prefix := 'PT-';
        v_seq := nextval('public.maintenance_fund_pt_seq');
    ELSIF p_transaction_type = 'EXPENSE' THEN
        IF v_current_balance < p_amount THEN
            RAISE EXCEPTION 'Số dư quỹ bảo trì không đủ để chi (Số dư hiện tại: %, Cần chi: %)', v_current_balance, p_amount;
        END IF;
        v_new_balance := v_current_balance - p_amount;
        v_prefix := 'PC-';
        v_seq := nextval('public.maintenance_fund_pc_seq');
    ELSE
        RAISE EXCEPTION 'Loại giao dịch không hợp lệ: %', p_transaction_type;
    END IF;

    -- 6. Sinh số chứng từ an toàn từ Sequence
    v_voucher_number := v_prefix || v_period || '-' || LPAD(v_seq::text, 5, '0');

    -- 7. Cập nhật số dư bảng chính
    UPDATE public.maintenance_funds
    SET total_balance = v_new_balance,
        updated_at = now()
    WHERE id = v_fund_id;

    -- 8. Ghi sổ giao dịch với người tạo được xác thực an toàn
    INSERT INTO public.maintenance_fund_transactions (
        building_id,
        transaction_type,
        amount,
        balance_after,
        category,
        description,
        voucher_number,
        receipt_url,
        reference_id,
        created_by
    ) VALUES (
        p_building_id,
        p_transaction_type,
        p_amount,
        v_new_balance,
        p_category,
        p_description,
        v_voucher_number,
        p_receipt_url,
        p_reference_id,
        v_user_id
    ) RETURNING id INTO v_tx_id;

    RETURN jsonb_build_object(
        'success', true,
        'transaction_id', v_tx_id,
        'voucher_number', v_voucher_number,
        'new_balance', v_new_balance,
        'message', 'Ghi sổ quỹ bảo trì thành công.'
    );
END;
$$;

-- 4. BAN HÀNH RPC TẠO Ý ĐỊNH THANH TOÁN THỰC TẾ (CREATE_PAYMENT_INTENT)
-- Trả về trạng thái PENDING kèm thông tin VietQR/Đối soát, không bao giờ tự động đổi hóa đơn sang paid
CREATE OR REPLACE FUNCTION public.create_payment_intent(
    p_reference_id UUID,
    p_payment_type TEXT DEFAULT 'INVOICE',
    p_payment_method TEXT DEFAULT 'VIETQR'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_user_id UUID;
    v_invoice RECORD;
    v_booking RECORD;
    v_tx_id UUID;
    v_now TIMESTAMPTZ := now();
    v_reference_code TEXT;
    v_amount NUMERIC(15,2);
    v_effective_type TEXT;
BEGIN
    -- 1. Xác thực người dùng
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Yêu cầu đăng nhập để thực hiện thanh toán.';
    END IF;

    v_effective_type := UPPER(COALESCE(p_payment_type, 'INVOICE'));

    -- 2. Xử lý thanh toán hóa đơn (INVOICE)
    IF v_effective_type = 'INVOICE' THEN
        SELECT * INTO v_invoice
        FROM public.invoices
        WHERE id = p_reference_id
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Không tìm thấy hóa đơn yêu cầu thanh toán.';
        END IF;

        IF v_invoice.status = 'paid' THEN
            RETURN jsonb_build_object(
                'success', false,
                'status', 'ALREADY_PAID',
                'is_pending', false,
                'message', 'Hóa đơn này đã được thanh toán trước đó.'
            );
        END IF;

        v_amount := v_invoice.total_amount;
        v_reference_code := COALESCE(v_invoice.payment_code, v_invoice.lookup_code, 'INV-' || to_char(v_now, 'YYYYMMDD') || '-' || upper(substring(p_reference_id::text, 1, 6)));

        -- Tạo bản ghi giao dịch chờ thanh toán (PENDING)
        INSERT INTO public.payment_transactions (
            reference_id,
            invoice_id,
            user_id,
            apartment_id,
            payment_type,
            payment_method,
            amount,
            status,
            idempotency_key,
            created_at,
            updated_at
        ) VALUES (
            p_reference_id,
            p_reference_id,
            v_user_id,
            v_invoice.apartment_id,
            'INVOICE',
            UPPER(p_payment_method),
            v_amount,
            'PENDING',
            gen_random_uuid()::text,
            v_now,
            v_now
        ) RETURNING id INTO v_tx_id;

        RETURN jsonb_build_object(
            'success', true,
            'status', 'PENDING',
            'is_pending', true,
            'transaction_id', v_tx_id,
            'reference_code', v_reference_code,
            'amount', v_amount,
            'message', 'Đã khởi tạo giao dịch chờ thanh toán. Vui lòng chuyển khoản đúng nội dung.'
        );

    -- 3. Xử lý thanh toán đặt tiện ích / dịch vụ (AMENITY / SERVICE)
    ELSIF v_effective_type IN ('AMENITY', 'SERVICE') THEN
        SELECT * INTO v_booking
        FROM public.amenity_bookings
        WHERE id = p_reference_id
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Không tìm thấy lịch đặt tiện ích yêu cầu thanh toán.';
        END IF;

        IF v_booking.status = 'confirmed' AND v_booking.payment_status = 'paid' THEN
            RETURN jsonb_build_object(
                'success', false,
                'status', 'ALREADY_PAID',
                'is_pending', false,
                'message', 'Lịch đặt tiện ích này đã được thanh toán và xác nhận.'
            );
        END IF;

        v_amount := COALESCE(v_booking.fee_amount, 0) + COALESCE(v_booking.deposit_amount, 0);
        v_reference_code := 'AMN-' || to_char(v_now, 'YYYYMMDD') || '-' || upper(substring(p_reference_id::text, 1, 6));

        INSERT INTO public.payment_transactions (
            reference_id,
            user_id,
            apartment_id,
            payment_type,
            payment_method,
            amount,
            status,
            idempotency_key,
            created_at,
            updated_at
        ) VALUES (
            p_reference_id,
            v_user_id,
            v_booking.apartment_id,
            'SERVICE',
            UPPER(p_payment_method),
            v_amount,
            'PENDING',
            gen_random_uuid()::text,
            v_now,
            v_now
        ) RETURNING id INTO v_tx_id;

        RETURN jsonb_build_object(
            'success', true,
            'status', 'PENDING',
            'is_pending', true,
            'transaction_id', v_tx_id,
            'reference_code', v_reference_code,
            'amount', v_amount,
            'message', 'Đã khởi tạo giao dịch đặt tiện ích chờ thanh toán.'
        );
    ELSE
        RAISE EXCEPTION 'Loại giao dịch thanh toán không được hỗ trợ: %', p_payment_type;
    END IF;
END;
$$;

-- Cấp quyền thực thi create_payment_intent cho authenticated
GRANT EXECUTE ON FUNCTION public.create_payment_intent(UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_maintenance_fund_transaction(UUID, TEXT, NUMERIC, TEXT, TEXT, TEXT, UUID, UUID) TO authenticated;
