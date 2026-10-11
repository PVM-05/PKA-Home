-- Migration: 20261011_04_resident_payment_submission_workflow.sql
-- Mô tả: Hoàn thiện quy trình thanh toán mô phỏng 2 bước (Two-step Simulated Payment)
-- 1. Cho phép trạng thái 'PENDING' trong payment_transactions_status_check
-- 2. Thêm cột confirmed_by và confirmed_at để truy vết kiểm toán
-- 3. Cập nhật simulate_unified_payment: cư dân gửi thông báo thanh toán -> chuyển hóa đơn sang pending_confirmation, lưu giao dịch PENDING, chống gửi lặp (idempotent), khóa FOR UPDATE
-- 4. Cập nhật record_manual_payment: BQL xác nhận thu tiền -> nếu có giao dịch PENDING thì cập nhật chính giao dịch đó sang SUCCESS giữ nguyên transaction_code, chuyển hóa đơn sang paid trong cùng transaction nguyên tử

-- 1. CẬP NHẬT RÀNG BUỘC TRẠNG THÁI GIAO DỊCH (CHO PHÉP 'PENDING')
ALTER TABLE public.payment_transactions 
DROP CONSTRAINT IF EXISTS payment_transactions_status_check;

ALTER TABLE public.payment_transactions 
ADD CONSTRAINT payment_transactions_status_check 
CHECK (status IN ('SUCCESS', 'PENDING', 'FAILED', 'CANCELLED'));

-- 2. BỔ SUNG CỘT TRUY VẾT KIỂM TOÁN NGƯỜI XÁC NHẬN
ALTER TABLE public.payment_transactions
ADD COLUMN IF NOT EXISTS confirmed_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS confirmed_at TIMESTAMPTZ DEFAULT NULL;

-- 3. CẬP NHẬT RPC: simulate_unified_payment
-- Cư dân gửi thông báo thanh toán (Chuyển khoản mô phỏng hoặc Tiền mặt)
-- Hệ thống ghi nhận yêu cầu và giao dịch PENDING, KHÔNG ghi nhận thành công giả và KHÔNG trừ tiền thật
CREATE OR REPLACE FUNCTION public.simulate_unified_payment(
    p_type VARCHAR,
    p_reference_id UUID,
    p_payment_method VARCHAR DEFAULT 'bank_transfer',
    p_outcome VARCHAR DEFAULT 'SUCCESS',
    p_failure_reason TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_invoice RECORD;
    v_booking RECORD;
    v_tx_code VARCHAR(100);
    v_tx_id UUID;
    v_pending_txn RECORD;
    v_has_access BOOLEAN := false;
BEGIN
    -- 1. Kiểm tra xác thực
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Yêu cầu đăng nhập để thực hiện thao tác';
    END IF;

    -- =========================================================================
    -- LUỒNG THANH TOÁN HÓA ĐƠN (INVOICE)
    -- =========================================================================
    IF upper(p_type) = 'INVOICE' THEN
        -- Khóa hàng hóa đơn để đảm bảo tính nhất quán và chống race condition
        SELECT i.*, a.code AS apartment_code
        INTO v_invoice
        FROM public.invoices i
        JOIN public.apartments a ON i.apartment_id = a.id
        WHERE i.id = p_reference_id
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Hóa đơn không tồn tại hoặc đã bị xóa';
        END IF;

        -- Kiểm tra quyền: Cư dân phải thuộc căn hộ này hoặc là Ban Quản Lý
        IF public.is_staff() THEN
            v_has_access := true;
        ELSE
            SELECT EXISTS (
                SELECT 1 FROM public.residents_apartments
                WHERE user_id = v_user_id AND apartment_id = v_invoice.apartment_id
            ) INTO v_has_access;
        END IF;

        IF NOT v_has_access THEN
            RAISE EXCEPTION 'Bạn không có quyền thanh toán cho hóa đơn của căn hộ này';
        END IF;

        -- Nếu hóa đơn đã thanh toán xong
        IF v_invoice.status = 'paid' THEN
            RAISE EXCEPTION 'Hóa đơn này đã được thanh toán trước đó';
        END IF;

        -- Nếu hóa đơn đã ở trạng thái chờ xác nhận -> Xử lý chống gửi lặp (Idempotency)
        IF v_invoice.status = 'pending_confirmation' THEN
            SELECT * INTO v_pending_txn
            FROM public.payment_transactions
            WHERE invoice_id = p_reference_id AND status = 'PENDING'
            ORDER BY created_at DESC
            LIMIT 1;

            IF FOUND THEN
                RETURN jsonb_build_object(
                    'success', true,
                    'is_pending', true,
                    'status', 'PENDING',
                    'message', 'Yêu cầu thanh toán của bạn đã được tiếp nhận và đang chờ Ban Quản Lý xác nhận',
                    'transaction_id', v_pending_txn.id,
                    'transaction_code', v_pending_txn.transaction_code,
                    'amount', v_pending_txn.amount,
                    'title', v_pending_txn.title,
                    'paid_at', v_pending_txn.created_at
                );
            END IF;
        END IF;

        -- Tạo mã giao dịch PENDING ổn định
        v_tx_code := 'PENDING-INV-' || to_char(NOW(), 'YYYYMMDDHH24MISS') || '-' || upper(substr(gen_random_uuid()::text, 1, 6));

        -- Cập nhật hóa đơn sang pending_confirmation
        UPDATE public.invoices
        SET status = 'pending_confirmation',
            payment_method = p_payment_method,
            transaction_code = v_tx_code,
            updated_at = NOW()
        WHERE id = p_reference_id;

        -- Chèn giao dịch PENDING vào bảng payment_transactions
        INSERT INTO public.payment_transactions (
            transaction_code,
            invoice_id,
            user_id,
            apartment_id,
            amount,
            payment_method,
            type,
            status,
            title
        ) VALUES (
            v_tx_code,
            p_reference_id,
            v_user_id,
            v_invoice.apartment_id,
            v_invoice.total_amount,
            p_payment_method,
            'INVOICE',
            'PENDING',
            'Yêu cầu thanh toán hóa đơn kỳ ' || v_invoice.period
        ) RETURNING id INTO v_tx_id;

        RETURN jsonb_build_object(
            'success', true,
            'is_pending', true,
            'status', 'PENDING',
            'message', 'Đã gửi thông báo thanh toán. Vui lòng chờ Ban Quản Lý đối soát và xác nhận.',
            'transaction_id', v_tx_id,
            'transaction_code', v_tx_code,
            'amount', v_invoice.total_amount,
            'title', 'Yêu cầu thanh toán hóa đơn kỳ ' || v_invoice.period,
            'paid_at', NOW()
        );

    -- =========================================================================
    -- LUỒNG THANH TOÁN DỊCH VỤ TIỆN ÍCH (SERVICE)
    -- =========================================================================
    ELSIF upper(p_type) = 'SERVICE' THEN
        SELECT b.*, a.name AS amenity_name
        INTO v_booking
        FROM public.amenity_bookings b
        JOIN public.building_amenities a ON b.amenity_id = a.id
        WHERE b.id = p_reference_id
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Lịch đặt tiện ích không tồn tại hoặc đã bị hủy';
        END IF;

        -- Kiểm tra quyền
        IF public.is_staff() THEN
            v_has_access := true;
        ELSIF v_booking.booked_by = v_user_id THEN
            v_has_access := true;
        ELSE
            SELECT EXISTS (
                SELECT 1 FROM public.residents_apartments
                WHERE user_id = v_user_id AND apartment_id = v_booking.apartment_id
            ) INTO v_has_access;
        END IF;

        IF NOT v_has_access THEN
            RAISE EXCEPTION 'Bạn không có quyền thanh toán cho lịch đặt tiện ích này';
        END IF;

        -- Kiểm tra giao dịch PENDING trùng
        SELECT * INTO v_pending_txn
        FROM public.payment_transactions
        WHERE booking_id = p_reference_id AND status = 'PENDING'
        ORDER BY created_at DESC
        LIMIT 1;

        IF FOUND THEN
            RETURN jsonb_build_object(
                'success', true,
                'is_pending', true,
                'status', 'PENDING',
                'message', 'Yêu cầu thanh toán dịch vụ đã được ghi nhận và đang chờ duyệt',
                'transaction_id', v_pending_txn.id,
                'transaction_code', v_pending_txn.transaction_code,
                'amount', v_pending_txn.amount,
                'title', v_pending_txn.title,
                'paid_at', v_pending_txn.created_at
            );
        END IF;

        v_tx_code := 'PENDING-SRV-' || to_char(NOW(), 'YYYYMMDDHH24MISS') || '-' || upper(substr(gen_random_uuid()::text, 1, 6));

        INSERT INTO public.payment_transactions (
            transaction_code,
            booking_id,
            user_id,
            apartment_id,
            amount,
            payment_method,
            type,
            status,
            title
        ) VALUES (
            v_tx_code,
            p_reference_id,
            v_user_id,
            v_booking.apartment_id,
            COALESCE(v_booking.total_fee, 0),
            p_payment_method,
            'SERVICE',
            'PENDING',
            'Yêu cầu thanh toán đăng ký dịch vụ ' || v_booking.amenity_name
        ) RETURNING id INTO v_tx_id;

        RETURN jsonb_build_object(
            'success', true,
            'is_pending', true,
            'status', 'PENDING',
            'message', 'Đã gửi thông báo thanh toán dịch vụ. Vui lòng chờ Ban Quản Lý xác nhận.',
            'transaction_id', v_tx_id,
            'transaction_code', v_tx_code,
            'amount', COALESCE(v_booking.total_fee, 0),
            'title', 'Yêu cầu thanh toán đăng ký dịch vụ ' || v_booking.amenity_name,
            'paid_at', NOW()
        );
    ELSE
        RAISE EXCEPTION 'Loại thanh toán không hợp lệ: %', p_type;
    END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.simulate_unified_payment(VARCHAR, UUID, VARCHAR, VARCHAR, TEXT) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.simulate_unified_payment(VARCHAR, UUID, VARCHAR, VARCHAR, TEXT) FROM anon;
GRANT EXECUTE ON FUNCTION public.simulate_unified_payment(VARCHAR, UUID, VARCHAR, VARCHAR, TEXT) TO authenticated;


-- 4. CẬP NHẬT RPC: record_manual_payment
-- Ban Quản Lý xác nhận thu tiền:
-- - Nếu hóa đơn có giao dịch PENDING trước đó: cập nhật chính giao dịch đó thành SUCCESS,
--   giữ nguyên transaction_code ổn định, ghi nhận confirmed_by & confirmed_at.
-- - Nếu BQL thu tiền trực tiếp chưa có yêu cầu: tạo giao dịch SUCCESS mới với tiền tố MANUAL-...
CREATE OR REPLACE FUNCTION public.record_manual_payment(
    p_invoice_id UUID,
    p_payment_method VARCHAR DEFAULT 'CASH',
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_inv RECORD;
    v_txn_id UUID;
    v_txn_code VARCHAR(100);
    v_pending_txn RECORD;
    v_staff_id UUID := auth.uid();
BEGIN
    -- 1. Kiểm tra quyền Ban Quản Lý (Admin hoặc Kế toán)
    IF NOT public.is_admin_or_accountant() THEN
        RAISE EXCEPTION 'Bạn không có quyền xác nhận thu tiền';
    END IF;

    -- 2. Khóa dòng hóa đơn FOR UPDATE
    SELECT * INTO v_inv FROM public.invoices WHERE id = p_invoice_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Hóa đơn không tồn tại: %', p_invoice_id;
    END IF;

    IF v_inv.status = 'paid' THEN
        RAISE EXCEPTION 'Hóa đơn đã được thanh toán trước đó';
    END IF;

    -- 3. Tìm giao dịch PENDING đang chờ của hóa đơn này
    SELECT * INTO v_pending_txn
    FROM public.payment_transactions
    WHERE invoice_id = p_invoice_id AND status = 'PENDING'
    ORDER BY created_at DESC
    LIMIT 1
    FOR UPDATE;

    IF FOUND THEN
        -- TRƯỜNG HỢP 1: CƯ DÂN ĐÃ GỬI YÊU CẦU TRƯỚC ĐÓ
        -- Cập nhật chính giao dịch PENDING này thành SUCCESS, GIỮ NGUYÊN transaction_code ổn định
        v_txn_code := v_pending_txn.transaction_code;
        v_txn_id := v_pending_txn.id;

        UPDATE public.payment_transactions
        SET status = 'SUCCESS',
            payment_method = COALESCE(p_payment_method, v_pending_txn.payment_method),
            title = COALESCE(p_notes, 'Thanh toán hóa đơn kỳ ' || v_inv.period),
            confirmed_by = v_staff_id,
            confirmed_at = NOW(),
            failure_reason = NULL
        WHERE id = v_txn_id;

        UPDATE public.invoices
        SET status = 'paid',
            payment_method = COALESCE(p_payment_method, v_pending_txn.payment_method),
            transaction_code = v_txn_code,
            paid_at = NOW(),
            updated_at = NOW()
        WHERE id = p_invoice_id;
    ELSE
        -- TRƯỜNG HỢP 2: BQL THU TRỰC TIẾP TẠI QUẦY (CHƯA CÓ YÊU CẦU PENDING)
        v_txn_code := 'MANUAL-' || to_char(NOW(), 'YYYYMMDDHH24MISS') || '-' || upper(substr(gen_random_uuid()::text, 1, 8));

        UPDATE public.invoices
        SET status = 'paid',
            payment_method = p_payment_method,
            transaction_code = v_txn_code,
            paid_at = NOW(),
            updated_at = NOW()
        WHERE id = p_invoice_id;

        INSERT INTO public.payment_transactions (
            transaction_code,
            invoice_id,
            apartment_id,
            amount,
            payment_method,
            type,
            status,
            title,
            confirmed_by,
            confirmed_at
        ) VALUES (
            v_txn_code,
            p_invoice_id,
            v_inv.apartment_id,
            v_inv.total_amount,
            p_payment_method,
            'INVOICE',
            'SUCCESS',
            COALESCE(p_notes, 'Thanh toán trực tiếp hóa đơn kỳ ' || v_inv.period),
            v_staff_id,
            NOW()
        ) RETURNING id INTO v_txn_id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Xác nhận thu tiền thành công',
        'invoice_id', p_invoice_id,
        'transaction_id', v_txn_id,
        'transaction_code', v_txn_code
    );
END;
$$;

REVOKE ALL ON FUNCTION public.record_manual_payment(UUID, VARCHAR, TEXT) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.record_manual_payment(UUID, VARCHAR, TEXT) TO authenticated;
