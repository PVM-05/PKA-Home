-- Migration: 20261011_05_fix_amenity_payment_and_method_sync.sql
-- Mô tả: Khắc phục các lỗi trong thanh toán tiện ích và đồng bộ phương thức thanh toán
-- 1. Bổ sung các cột fee_amount, deposit_amount, deposit_status cho amenity_bookings nếu chưa có
-- 2. Cập nhật RPC book_amenity_slot: tính toán và lưu chính xác fee_amount, deposit_amount vào bản ghi đặt chỗ
-- 3. Cập nhật RPC simulate_unified_payment nhánh SERVICE: kiểm tra trạng thái booking (từ chối cancelled, waitlist), tính đúng tổng phí từ fee_amount + deposit_amount
-- 4. Bổ sung RPC record_manual_amenity_payment: BQL xác nhận thu phí dịch vụ / tiền cọc nguyên tử, cập nhật giao dịch PENDING sang SUCCESS giữ nguyên mã ổn định

-- 1. NÂNG CẤP CẤU TRÚC BẢNG amenity_bookings
ALTER TABLE public.amenity_bookings
ADD COLUMN IF NOT EXISTS guests_count INT NOT NULL DEFAULT 1 CHECK (guests_count >= 1),
ADD COLUMN IF NOT EXISTS fee_amount NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (fee_amount >= 0),
ADD COLUMN IF NOT EXISTS deposit_amount NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (deposit_amount >= 0),
ADD COLUMN IF NOT EXISTS deposit_status VARCHAR(20) NOT NULL DEFAULT 'none' 
    CHECK (deposit_status IN ('none', 'pending', 'received', 'refunded', 'forfeited')),
ADD COLUMN IF NOT EXISTS deposit_notes TEXT;

-- Nâng cấp ràng buộc trạng thái amenity_bookings
ALTER TABLE public.amenity_bookings 
DROP CONSTRAINT IF EXISTS amenity_bookings_status_check;

ALTER TABLE public.amenity_bookings 
ADD CONSTRAINT amenity_bookings_status_check 
CHECK (status IN ('confirmed', 'waitlist', 'cancelled', 'completed', 'no_show', 'pending_payment'));


-- 2. CẬP NHẬT RPC: book_amenity_slot (TÍNH VÀ LƯU ĐÚNG PHÍ VÀ TIỀN CỌC)
CREATE OR REPLACE FUNCTION public.book_amenity_slot(
    p_amenity_id UUID,
    p_booking_date DATE,
    p_time_slot VARCHAR,
    p_guests_count INT DEFAULT 1,
    p_apartment_id UUID DEFAULT NULL,
    p_allow_waitlist BOOLEAN DEFAULT TRUE,
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_amenity RECORD;
    v_total_bookings INT;
    v_booking_id UUID;
    v_status VARCHAR;
    v_today DATE;
    v_target_apartment UUID;
    v_is_waitlist BOOLEAN := false;
    v_fee NUMERIC(12,2) := 0;
    v_deposit NUMERIC(12,2) := 0;
    v_deposit_status VARCHAR(20) := 'none';
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Yêu cầu đăng nhập để thực hiện đặt chỗ';
    END IF;

    -- Xác định căn hộ của người đặt
    IF p_apartment_id IS NOT NULL THEN
        v_target_apartment := p_apartment_id;
    ELSE
        SELECT apartment_id INTO v_target_apartment
        FROM public.residents_apartments
        WHERE user_id = auth.uid()
        LIMIT 1;
    END IF;

    IF v_target_apartment IS NULL THEN
        RAISE EXCEPTION 'Bạn chưa liên kết với căn hộ nào để thực hiện đặt chỗ';
    END IF;

    -- Kiểm tra ngày đặt chỗ không ở quá khứ
    v_today := (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date;
    IF p_booking_date < v_today THEN
        RAISE EXCEPTION 'Không thể đặt lịch cho ngày trong quá khứ';
    END IF;

    -- Khóa và kiểm tra thông tin tiện ích
    SELECT * INTO v_amenity FROM public.building_amenities WHERE id = p_amenity_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Tiện ích không tồn tại';
    END IF;

    IF NOT COALESCE(v_amenity.is_active, true) THEN
        RAISE EXCEPTION 'Tiện ích này hiện đang tạm ngưng phục vụ';
    END IF;

    -- Kiểm tra xung đột lịch bảo trì nếu có
    IF EXISTS (
        SELECT 1 FROM public.amenity_maintenance_windows
        WHERE amenity_id = p_amenity_id
          AND start_time::date <= p_booking_date
          AND end_time::date >= p_booking_date
    ) THEN
        RAISE EXCEPTION 'Tiện ích đang trong khung giờ bảo trì vào ngày này';
    END IF;

    -- Kiểm tra số lượng lượt đặt trong khung giờ
    SELECT COUNT(*) INTO v_total_bookings
    FROM public.amenity_bookings
    WHERE amenity_id = p_amenity_id
      AND booking_date = p_booking_date
      AND time_slot = p_time_slot
      AND status IN ('confirmed', 'completed', 'pending_payment');

    -- Tính toán phí dịch vụ và tiền cọc theo công thức chuẩn
    v_fee := COALESCE(v_amenity.fee_amount, 0) * GREATEST(COALESCE(p_guests_count, 1), 1);
    IF COALESCE(v_amenity.requires_deposit, false) THEN
        v_deposit := COALESCE(v_amenity.deposit_amount, 0);
        v_deposit_status := 'pending';
    END IF;

    IF v_total_bookings > 0 THEN
        IF p_allow_waitlist THEN
            v_status := 'waitlist';
            v_is_waitlist := true;
        ELSE
            RAISE EXCEPTION 'Khung giờ này đã kín chỗ. Vui lòng chọn khung giờ khác.';
        END IF;
    ELSE
        -- Khung giờ còn trống
        IF (v_fee + v_deposit) > 0 THEN
            v_status := 'pending_payment';
        ELSE
            v_status := 'confirmed';
        END IF;
    END IF;

    -- Tạo bản ghi đặt chỗ lưu đầy đủ fee_amount, deposit_amount và deposit_status
    INSERT INTO public.amenity_bookings (
        amenity_id,
        apartment_id,
        booked_by,
        booking_date,
        time_slot,
        guests_count,
        fee_amount,
        deposit_amount,
        deposit_status,
        status,
        notes,
        created_at,
        updated_at
    ) VALUES (
        p_amenity_id,
        v_target_apartment,
        auth.uid(),
        p_booking_date,
        p_time_slot,
        COALESCE(p_guests_count, 1),
        v_fee,
        v_deposit,
        v_deposit_status,
        v_status,
        p_notes,
        NOW(),
        NOW()
    ) RETURNING id INTO v_booking_id;

    RETURN jsonb_build_object(
        'success', true,
        'message', CASE 
            WHEN v_is_waitlist THEN 'Đã thêm vào danh sách chờ thành công'
            WHEN v_status = 'pending_payment' THEN 'Đã tạo lịch đặt, đang chờ thanh toán'
            ELSE 'Đặt lịch tiện ích thành công'
        END,
        'booking_id', v_booking_id,
        'status', v_status,
        'is_waitlist', v_is_waitlist,
        'fee_amount', v_fee,
        'deposit_amount', v_deposit,
        'total_amount', (v_fee + v_deposit)
    );
END;
$$;

REVOKE ALL ON FUNCTION public.book_amenity_slot(UUID, DATE, VARCHAR, INT, UUID, BOOLEAN, TEXT) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.book_amenity_slot(UUID, DATE, VARCHAR, INT, UUID, BOOLEAN, TEXT) TO authenticated;


-- 3. CẬP NHẬT RPC: simulate_unified_payment (SỬA NHÁNH SERVICE TÍNH ĐÚNG PHÍ & KIỂM TRA TRẠNG THÁI)
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
    v_amenity RECORD;
    v_tx_code VARCHAR(100);
    v_tx_id UUID;
    v_pending_txn RECORD;
    v_success_txn RECORD;
    v_has_access BOOLEAN := false;
    v_total_service_fee NUMERIC(12,2) := 0;
BEGIN
    -- 1. Kiểm tra xác thực
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Yêu cầu đăng nhập để thực hiện thao tác';
    END IF;

    -- =========================================================================
    -- LUỒNG THANH TOÁN HÓA ĐƠN (INVOICE)
    -- =========================================================================
    IF upper(p_type) = 'INVOICE' THEN
        SELECT i.*, a.code AS apartment_code
        INTO v_invoice
        FROM public.invoices i
        JOIN public.apartments a ON i.apartment_id = a.id
        WHERE i.id = p_reference_id
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Hóa đơn không tồn tại hoặc đã bị xóa';
        END IF;

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

        IF v_invoice.status = 'paid' THEN
            RAISE EXCEPTION 'Hóa đơn này đã được thanh toán trước đó';
        END IF;

        -- Xử lý chống gửi lặp (Idempotency) khi hóa đơn đang pending_confirmation
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

        v_tx_code := 'PENDING-INV-' || to_char(NOW(), 'YYYYMMDDHH24MISS') || '-' || upper(substr(gen_random_uuid()::text, 1, 6));

        UPDATE public.invoices
        SET status = 'pending_confirmation',
            payment_method = p_payment_method,
            transaction_code = v_tx_code,
            updated_at = NOW()
        WHERE id = p_reference_id;

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
        SELECT b.*, a.name AS amenity_name, a.fee_amount AS amenity_unit_fee, a.deposit_amount AS amenity_unit_deposit, a.requires_deposit AS amenity_req_deposit
        INTO v_booking
        FROM public.amenity_bookings b
        JOIN public.building_amenities a ON b.amenity_id = a.id
        WHERE b.id = p_reference_id
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Lịch đặt tiện ích không tồn tại hoặc đã bị xóa';
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

        -- Từ chối rõ ràng các trạng thái không hợp lệ
        IF v_booking.status = 'cancelled' THEN
            RAISE EXCEPTION 'Lịch đặt tiện ích đã bị hủy, không thể thanh toán';
        END IF;

        IF v_booking.status = 'waitlist' THEN
            RAISE EXCEPTION 'Lịch đặt đang ở danh sách chờ, chỉ có thể thanh toán khi đã được xếp chỗ chính thức';
        END IF;

        IF v_booking.status = 'completed' THEN
            RAISE EXCEPTION 'Lịch đặt tiện ích này đã hoàn thành sử dụng';
        END IF;

        -- Kiểm tra xem đã có giao dịch SUCCESS chưa
        SELECT * INTO v_success_txn
        FROM public.payment_transactions
        WHERE booking_id = p_reference_id AND status = 'SUCCESS'
        LIMIT 1;

        IF FOUND THEN
            RAISE EXCEPTION 'Dịch vụ này đã được thanh toán và xác nhận thành công trước đó';
        END IF;

        -- Tính tổng chi phí (dùng fee_amount + deposit_amount từ booking, fallback từ amenity nếu chưa ghi)
        v_total_service_fee := COALESCE(v_booking.fee_amount, 0) + COALESCE(v_booking.deposit_amount, 0);
        IF v_total_service_fee <= 0 THEN
            v_total_service_fee := (COALESCE(v_booking.amenity_unit_fee, 0) * GREATEST(COALESCE(v_booking.guests_count, 1), 1))
                + (CASE WHEN COALESCE(v_booking.amenity_req_deposit, false) THEN COALESCE(v_booking.amenity_unit_deposit, 0) ELSE 0 END);
        END IF;

        IF v_total_service_fee <= 0 THEN
            RAISE EXCEPTION 'Lịch đặt này không phát sinh phí cần thanh toán';
        END IF;

        -- Kiểm tra giao dịch PENDING trùng (Idempotency)
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
                'message', 'Yêu cầu thanh toán dịch vụ đã được ghi nhận và đang chờ Ban Quản Lý duyệt',
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
            v_total_service_fee,
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
            'amount', v_total_service_fee,
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


-- 4. BỔ SUNG RPC: record_manual_amenity_payment (BQL XÁC NHẬN THU PHÍ TIỆN ÍCH / TIỀN CỌC NGUYÊN TỬ)
CREATE OR REPLACE FUNCTION public.record_manual_amenity_payment(
    p_booking_id UUID,
    p_payment_method VARCHAR DEFAULT 'CASH',
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_booking RECORD;
    v_amenity RECORD;
    v_txn_id UUID;
    v_txn_code VARCHAR(100);
    v_pending_txn RECORD;
    v_staff_id UUID := auth.uid();
    v_total_fee NUMERIC(12,2) := 0;
BEGIN
    -- 1. Kiểm tra quyền Ban Quản Lý hoặc Nhân viên
    IF NOT (public.is_admin_or_accountant() OR public.is_staff()) THEN
        RAISE EXCEPTION 'Bạn không có quyền xác nhận thu phí dịch vụ tiện ích';
    END IF;

    -- 2. Khóa dòng booking FOR UPDATE
    SELECT b.*, a.name AS amenity_name, a.fee_amount AS a_fee, a.deposit_amount AS a_deposit, a.requires_deposit AS a_req_deposit
    INTO v_booking
    FROM public.amenity_bookings b
    JOIN public.building_amenities a ON b.amenity_id = a.id
    WHERE b.id = p_booking_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Lịch đặt tiện ích không tồn tại: %', p_booking_id;
    END IF;

    IF v_booking.status = 'cancelled' THEN
        RAISE EXCEPTION 'Lịch đặt này đã bị hủy, không thể xác nhận thu tiền';
    END IF;

    -- Tính tổng phí cần thu
    v_total_fee := COALESCE(v_booking.fee_amount, 0) + COALESCE(v_booking.deposit_amount, 0);
    IF v_total_fee <= 0 THEN
        v_total_fee := (COALESCE(v_booking.a_fee, 0) * GREATEST(COALESCE(v_booking.guests_count, 1), 1))
            + (CASE WHEN COALESCE(v_booking.a_req_deposit, false) THEN COALESCE(v_booking.a_deposit, 0) ELSE 0 END);
    END IF;

    -- 3. Tìm giao dịch PENDING đang chờ của booking này
    SELECT * INTO v_pending_txn
    FROM public.payment_transactions
    WHERE booking_id = p_booking_id AND status = 'PENDING'
    ORDER BY created_at DESC
    LIMIT 1
    FOR UPDATE;

    IF FOUND THEN
        -- TRƯỜNG HỢP 1: CƯ DÂN ĐÃ GỬI YÊU CẦU PENDING TRƯỚC ĐÓ
        -- Cập nhật chính giao dịch này thành SUCCESS, GIỮ NGUYÊN transaction_code ổn định
        v_txn_code := v_pending_txn.transaction_code;
        v_txn_id := v_pending_txn.id;

        UPDATE public.payment_transactions
        SET status = 'SUCCESS',
            payment_method = COALESCE(p_payment_method, v_pending_txn.payment_method),
            title = COALESCE(p_notes, 'Thanh toán dịch vụ ' || v_booking.amenity_name),
            confirmed_by = v_staff_id,
            confirmed_at = NOW(),
            failure_reason = NULL
        WHERE id = v_txn_id;
    ELSE
        -- TRƯỜNG HỢP 2: BQL THU TRỰC TIẾP TẠI QUẦY (CHƯA CÓ YÊU CẦU PENDING)
        v_txn_code := 'MANUAL-SRV-' || to_char(NOW(), 'YYYYMMDDHH24MISS') || '-' || upper(substr(gen_random_uuid()::text, 1, 8));

        INSERT INTO public.payment_transactions (
            transaction_code,
            booking_id,
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
            p_booking_id,
            v_booking.apartment_id,
            v_total_fee,
            p_payment_method,
            'SERVICE',
            'SUCCESS',
            COALESCE(p_notes, 'Thanh toán trực tiếp dịch vụ ' || v_booking.amenity_name),
            v_staff_id,
            NOW()
        ) RETURNING id INTO v_txn_id;
    END IF;

    -- Cập nhật trạng thái đặt chỗ sang confirmed và tiền cọc sang received (nếu có cọc)
    UPDATE public.amenity_bookings
    SET status = 'confirmed',
        deposit_status = CASE 
            WHEN COALESCE(deposit_amount, 0) > 0 OR COALESCE(v_booking.a_deposit, 0) > 0 THEN 'received' 
            ELSE deposit_status 
        END,
        deposit_notes = COALESCE(p_notes, deposit_notes),
        updated_at = NOW()
    WHERE id = p_booking_id;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Xác nhận thu phí dịch vụ tiện ích thành công',
        'booking_id', p_booking_id,
        'transaction_id', v_txn_id,
        'transaction_code', v_txn_code
    );
END;
$$;

REVOKE ALL ON FUNCTION public.record_manual_amenity_payment(UUID, VARCHAR, TEXT) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.record_manual_amenity_payment(UUID, VARCHAR, TEXT) TO authenticated;
