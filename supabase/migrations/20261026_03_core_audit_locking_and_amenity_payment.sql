-- ==============================================================================
-- Migration: 20261026_03_core_audit_locking_and_amenity_payment.sql
-- Description:
-- 1. Bổ sung bảng audit_logs lưu vết nhật ký kiểm toán bất biến cho BQL gạch nợ
-- 2. Thêm Partial Unique Index chống gửi trùng giao dịch PENDING cho Hóa đơn & Tiện ích
-- 3. Nâng cấp RPC book_amenity_slot: Khóa tuần tự hóa pg_advisory_xact_lock và FOR UPDATE chống Overbooking
-- 4. Nâng cấp RPC confirm_payment & record_manual_amenity_payment ghi tự động vào audit_logs
-- ==============================================================================

-- 1. BẢNG AUDIT_LOGS
CREATE TABLE IF NOT EXISTS public.audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    action VARCHAR(100) NOT NULL,
    target_table VARCHAR(100) NOT NULL,
    target_id UUID NOT NULL,
    actor_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    amount NUMERIC(12,2),
    old_status VARCHAR(50),
    new_status VARCHAR(50),
    details TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "BQL xem audit_logs" ON public.audit_logs;
CREATE POLICY "BQL xem audit_logs" ON public.audit_logs
    FOR SELECT TO authenticated
    USING (public.is_admin_or_accountant() OR public.is_staff());

-- 2. PARTIAL UNIQUE INDEX CHỐNG GỬI TRÙNG GIAO DỊCH PENDING
CREATE UNIQUE INDEX IF NOT EXISTS uq_one_pending_payment_per_invoice
ON public.payment_transactions (invoice_id)
WHERE invoice_id IS NOT NULL AND status = 'PENDING';

CREATE UNIQUE INDEX IF NOT EXISTS uq_one_pending_payment_per_booking
ON public.payment_transactions (booking_id)
WHERE booking_id IS NOT NULL AND status = 'PENDING';

-- 3. NÂNG CẤP BOOK_AMENITY_SLOT: ADVISORY XACT LOCK & ROW LEVEL LOCKING
CREATE OR REPLACE FUNCTION public.book_amenity_slot(
    p_amenity_id uuid,
    p_booking_date date,
    p_time_slot character varying,
    p_guests_count integer DEFAULT 1,
    p_apartment_id uuid DEFAULT NULL::uuid,
    p_allow_waitlist boolean DEFAULT true,
    p_notes text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
    v_user_id UUID := auth.uid();
    v_amenity RECORD;
    v_target_apartment UUID;
    v_today DATE;
    v_current_occupancy INT := 0;
    v_booking_id UUID;
    v_status VARCHAR;
    v_is_waitlist BOOLEAN := false;
    v_fee NUMERIC(12,2) := 0;
    v_deposit NUMERIC(12,2) := 0;
    v_deposit_status VARCHAR(20) := 'none';
    v_max_capacity INT := 1;
BEGIN
    -- 1. Xác thực người dùng
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Yêu cầu đăng nhập để thực hiện đặt chỗ';
    END IF;

    -- 2. KHÓA ĐỒNG THỜI (CONCURRENCY LOCK):
    -- Sử dụng pg_advisory_xact_lock băm theo (amenity_id + date + time_slot)
    -- Tự động giải phóng khi transaction kết thúc (commit hoặc rollback).
    -- Ngăn chặn triệt để 2 giao dịch cùng đặt slot cuối cùng ở cùng 1 mili-giây.
    PERFORM pg_advisory_xact_lock(hashtext(p_amenity_id::text || p_booking_date::text || p_time_slot));

    -- 3. Xác định căn hộ của người đặt
    IF p_apartment_id IS NOT NULL THEN
        v_target_apartment := p_apartment_id;
    ELSE
        SELECT apartment_id INTO v_target_apartment
        FROM public.residents_apartments
        WHERE user_id = v_user_id
        ORDER BY created_at ASC
        LIMIT 1;
    END IF;

    IF v_target_apartment IS NULL THEN
        RAISE EXCEPTION 'Bạn chưa liên kết với căn hộ nào để thực hiện đặt chỗ';
    END IF;

    -- 4. Kiểm tra ngày đặt chỗ không ở quá khứ
    v_today := (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date;
    IF p_booking_date < v_today THEN
        RAISE EXCEPTION 'Không thể đặt lịch cho ngày trong quá khứ';
    END IF;

    -- 5. Khóa và kiểm tra thông tin tiện ích
    SELECT * INTO v_amenity 
    FROM public.building_amenities 
    WHERE id = p_amenity_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Tiện ích không tồn tại';
    END IF;

    IF NOT COALESCE(v_amenity.is_active, true) THEN
        RAISE EXCEPTION 'Tiện ích này hiện đang tạm ngưng phục vụ';
    END IF;

    v_max_capacity := GREATEST(COALESCE(v_amenity.max_capacity, 1), 1);

    IF COALESCE(p_guests_count, 1) > v_max_capacity THEN
        RAISE EXCEPTION 'Số lượng người đặt (% người) vượt quá sức chứa tối đa của tiện ích (% người)', 
            COALESCE(p_guests_count, 1), v_max_capacity;
    END IF;

    -- 6. Kiểm tra người dùng đã có lượt đặt còn hiệu lực trong khung giờ này chưa
    IF EXISTS (
        SELECT 1 FROM public.amenity_bookings
        WHERE amenity_id = p_amenity_id
          AND booking_date = p_booking_date
          AND time_slot = p_time_slot
          AND booked_by = v_user_id
          AND status IN ('confirmed', 'pending_payment', 'waitlist', 'pending')
    ) THEN
        RAISE EXCEPTION 'Bạn đã có lượt đặt trong khung giờ này. Vui lòng hủy lịch hiện tại trước nếu muốn đặt lại.';
    END IF;

    -- 7. Kiểm tra xung đột lịch bảo trì nếu có
    IF EXISTS (
        SELECT 1 FROM public.amenity_maintenance_windows
        WHERE amenity_id = p_amenity_id
          AND start_time::date <= p_booking_date
          AND end_time::date >= p_booking_date
    ) THEN
        RAISE EXCEPTION 'Tiện ích đang trong khung giờ bảo trì vào ngày này';
    END IF;

    -- 8. Tính toán lượng chiếm dụng hiện tại trong khung giờ
    IF COALESCE(v_amenity.booking_type, 'exclusive') = 'exclusive' THEN
        SELECT COUNT(*) INTO v_current_occupancy
        FROM public.amenity_bookings
        WHERE amenity_id = p_amenity_id
          AND booking_date = p_booking_date
          AND time_slot = p_time_slot
          AND status IN ('confirmed', 'pending_payment');
    ELSE
        SELECT COALESCE(SUM(guests_count), 0) INTO v_current_occupancy
        FROM public.amenity_bookings
        WHERE amenity_id = p_amenity_id
          AND booking_date = p_booking_date
          AND time_slot = p_time_slot
          AND status IN ('confirmed', 'pending_payment');
    END IF;

    -- 9. Tính toán phí dịch vụ và tiền cọc theo công thức chuẩn
    v_fee := COALESCE(v_amenity.fee_amount, 0) * GREATEST(COALESCE(p_guests_count, 1), 1);
    IF COALESCE(v_amenity.requires_deposit, false) THEN
        v_deposit := COALESCE(v_amenity.deposit_amount, 0);
        v_deposit_status := 'pending';
    END IF;

    -- 10. Đánh giá khả dụng hoặc xếp vào danh sách chờ
    IF (v_current_occupancy + GREATEST(COALESCE(p_guests_count, 1), 1)) > v_max_capacity THEN
        IF p_allow_waitlist THEN
            v_status := 'waitlist';
            v_is_waitlist := true;
        ELSE
            RAISE EXCEPTION 'Khung giờ này đã kín chỗ. Vui lòng chọn khung giờ khác.';
        END IF;
    ELSE
        IF (v_fee + v_deposit) > 0 THEN
            v_status := 'pending_payment';
        ELSE
            v_status := 'confirmed';
        END IF;
    END IF;

    -- 11. Tạo bản ghi đặt chỗ
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
        v_user_id,
        p_booking_date,
        p_time_slot,
        GREATEST(COALESCE(p_guests_count, 1), 1),
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
$function$;

REVOKE ALL ON FUNCTION public.book_amenity_slot(uuid, date, character varying, integer, uuid, boolean, text) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.book_amenity_slot(uuid, date, character varying, integer, uuid, boolean, text) TO authenticated;

-- 4. NÂNG CẤP CONFIRM_PAYMENT: GHI NHẬT KÝ AUDIT_LOGS
CREATE OR REPLACE FUNCTION public.confirm_payment(p_invoice_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
  v_total NUMERIC;
  v_period VARCHAR;
  v_staff_id UUID := auth.uid();
BEGIN
  IF NOT (public.is_admin() OR public.is_accountant()) THEN
    RAISE EXCEPTION 'Chỉ Ban Quản Lý hoặc Kế toán mới có quyền xác nhận thanh toán hóa đơn.';
  END IF;

  SELECT total_amount, period INTO v_total, v_period 
  FROM public.invoices 
  WHERE id = p_invoice_id FOR UPDATE;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Không tìm thấy hóa đơn cần xác nhận thanh toán.';
  END IF;

  UPDATE public.invoices
  SET status = 'paid', updated_at = NOW()
  WHERE id = p_invoice_id;

  UPDATE public.payment_transactions
  SET status = 'SUCCESS', updated_at = NOW(), confirmed_at = NOW(), confirmed_by = v_staff_id
  WHERE invoice_id = p_invoice_id AND status = 'PENDING';

  INSERT INTO public.audit_logs (
      action,
      target_table,
      target_id,
      actor_id,
      amount,
      old_status,
      new_status,
      details
  ) VALUES (
      'CONFIRM_INVOICE_PAYMENT',
      'invoices',
      p_invoice_id,
      v_staff_id,
      v_total,
      'unpaid',
      'paid',
      'Ban Quản Lý xác nhận thanh toán thành công hóa đơn kỳ ' || COALESCE(v_period, '')
  );
END;
$function$;

-- 5. NÂNG CẤP RECORD_MANUAL_AMENITY_PAYMENT: GHI NHẬT KÝ AUDIT_LOGS
CREATE OR REPLACE FUNCTION public.record_manual_amenity_payment(
    p_booking_id uuid,
    p_payment_method character varying DEFAULT 'CASH'::character varying,
    p_notes text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
    v_booking RECORD;
    v_txn_id UUID;
    v_txn_code VARCHAR(100);
    v_existing_success_txn RECORD;
    v_pending_txn RECORD;
    v_staff_id UUID := auth.uid();
    v_total_fee NUMERIC(12,2) := 0;
BEGIN
    IF NOT (public.is_admin_or_accountant() OR public.is_staff()) THEN
        RAISE EXCEPTION 'Bạn không có quyền xác nhận thu phí dịch vụ tiện ích';
    END IF;

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

    SELECT * INTO v_existing_success_txn
    FROM public.payment_transactions
    WHERE booking_id = p_booking_id AND status = 'SUCCESS'
    ORDER BY created_at DESC
    LIMIT 1
    FOR UPDATE;

    IF FOUND THEN
        RETURN jsonb_build_object(
            'success', true,
            'message', 'Lịch đặt tiện ích này đã được xác nhận thanh toán trước đó',
            'already_paid', true,
            'booking_id', p_booking_id,
            'transaction_id', v_existing_success_txn.id,
            'transaction_code', v_existing_success_txn.transaction_code
        );
    END IF;

    v_total_fee := COALESCE(v_booking.fee_amount, 0) + COALESCE(v_booking.deposit_amount, 0);
    IF v_total_fee <= 0 THEN
        v_total_fee := (COALESCE(v_booking.a_fee, 0) * GREATEST(COALESCE(v_booking.guests_count, 1), 1))
            + (CASE WHEN COALESCE(v_booking.a_req_deposit, false) THEN COALESCE(v_booking.a_deposit, 0) ELSE 0 END);
    END IF;

    SELECT * INTO v_pending_txn
    FROM public.payment_transactions
    WHERE booking_id = p_booking_id AND status = 'PENDING'
    ORDER BY created_at DESC
    LIMIT 1
    FOR UPDATE;

    IF FOUND THEN
        v_txn_code := v_pending_txn.transaction_code;
        v_txn_id := v_pending_txn.id;

        UPDATE public.payment_transactions
        SET status = 'SUCCESS',
            payment_method = COALESCE(p_payment_method, v_pending_txn.payment_method),
            title = COALESCE(p_notes, 'Thanh toán dịch vụ ' || v_booking.amenity_name),
            confirmed_by = v_staff_id,
            confirmed_at = NOW(),
            failure_reason = NULL,
            updated_at = NOW()
        WHERE id = v_txn_id;
    ELSE
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
            confirmed_at,
            created_at,
            updated_at
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
            NOW(),
            NOW(),
            NOW()
        ) RETURNING id INTO v_txn_id;
    END IF;

    UPDATE public.amenity_bookings
    SET status = 'confirmed',
        deposit_status = CASE 
            WHEN COALESCE(deposit_amount, 0) > 0 OR COALESCE(v_booking.a_deposit, 0) > 0 THEN 'received' 
            ELSE deposit_status 
        END,
        deposit_notes = COALESCE(p_notes, deposit_notes),
        updated_at = NOW()
    WHERE id = p_booking_id;

    INSERT INTO public.audit_logs (
        action,
        target_table,
        target_id,
        actor_id,
        amount,
        old_status,
        new_status,
        details
    ) VALUES (
        'CONFIRM_AMENITY_PAYMENT',
        'amenity_bookings',
        p_booking_id,
        v_staff_id,
        v_total_fee,
        v_booking.status,
        'confirmed',
        'Ban Quản Lý thu phí dịch vụ ' || v_booking.amenity_name || ' (' || p_payment_method || ')'
    );

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Xác nhận thu phí dịch vụ tiện ích thành công',
        'already_paid', false,
        'booking_id', p_booking_id,
        'transaction_id', v_txn_id,
        'transaction_code', v_txn_code
    );
END;
$function$;
