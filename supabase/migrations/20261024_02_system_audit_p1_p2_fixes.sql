-- ==============================================================================
-- Migration: 20261024_02_system_audit_p1_p2_fixes.sql
-- Mục tiêu: Khắc phục triệt để các lỗ hổng P1/P2 về CSDL, RLS và toàn vẹn tài chính:
-- 1. Bổ sung cột notes cho amenity_bookings
-- 2. Siết RLS amenity_bookings: Không cho cư dân đọc dữ liệu đặt chỗ của người khác
-- 3. Tạo RPC get_amenity_slot_availability ẩn danh hóa thông tin PII
-- 4. Idempotent simulate_unified_payment: Chống tạo nhiều PENDING và thêm Partial Unique Index
-- 5. Hoàn thiện nghiệp vụ book_amenity_slot: Khung giờ VN, bảo trì, sức chứa exclusive, đa căn hộ
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. BỔ SUNG CỘT NOTES VÀO AMENITY_BOOKINGS
-- ------------------------------------------------------------------------------
ALTER TABLE public.amenity_bookings 
ADD COLUMN IF NOT EXISTS notes TEXT;

-- ------------------------------------------------------------------------------
-- 2. DỌN DẸP GIAO DỊCH PENDING TRÙNG VÀ BỔ SUNG UNIQUE PARTIAL INDEXES
-- ------------------------------------------------------------------------------
-- Xóa an toàn các giao dịch PENDING trùng lặp cũ (nếu có), chỉ giữ lại bản ghi mới nhất
DELETE FROM public.payment_transactions pt1
WHERE pt1.status = 'PENDING'
  AND pt1.invoice_id IS NOT NULL
  AND pt1.id NOT IN (
    SELECT DISTINCT ON (invoice_id) id
    FROM public.payment_transactions
    WHERE status = 'PENDING' AND invoice_id IS NOT NULL
    ORDER BY invoice_id, created_at DESC
  );

DELETE FROM public.payment_transactions pt1
WHERE pt1.status = 'PENDING'
  AND pt1.booking_id IS NOT NULL
  AND pt1.id NOT IN (
    SELECT DISTINCT ON (booking_id) id
    FROM public.payment_transactions
    WHERE status = 'PENDING' AND booking_id IS NOT NULL
    ORDER BY booking_id, created_at DESC
  );

DROP INDEX IF EXISTS public.uq_pending_invoice_transaction;
CREATE UNIQUE INDEX uq_pending_invoice_transaction
ON public.payment_transactions (invoice_id)
WHERE status = 'PENDING' AND invoice_id IS NOT NULL;

DROP INDEX IF EXISTS public.uq_pending_booking_transaction;
CREATE UNIQUE INDEX uq_pending_booking_transaction
ON public.payment_transactions (booking_id)
WHERE status = 'PENDING' AND booking_id IS NOT NULL;

-- ------------------------------------------------------------------------------
-- 3. SIẾT CHẶT RLS AMENITY_BOOKINGS (CHỐNG LỘ DỮ LIỆU CƯ DÂN)
-- ------------------------------------------------------------------------------
ALTER TABLE public.amenity_bookings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Mọi người xem lịch tiện ích" ON public.amenity_bookings;
DROP POLICY IF EXISTS "Cư dân chỉ xem lịch của mình hoặc BQL xem tất cả" ON public.amenity_bookings;

CREATE POLICY "Cư dân chỉ xem lịch của mình hoặc BQL xem tất cả" ON public.amenity_bookings
FOR SELECT USING (
    booked_by = auth.uid()
    OR apartment_id IN (
        SELECT apartment_id FROM public.residents_apartments WHERE user_id = auth.uid()
    )
    OR public.is_staff()
);

-- ------------------------------------------------------------------------------
-- 4. RPC GET_AMENITY_SLOT_AVAILABILITY (ẨN DANH 100% PII CỦA CƯ DÂN KHÁC)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_amenity_slot_availability(
    p_amenity_id UUID,
    p_date DATE
)
RETURNS TABLE (
    time_slot VARCHAR,
    status VARCHAR,
    guests_count INT,
    is_my_booking BOOLEAN
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
    SELECT 
        b.time_slot,
        b.status,
        b.guests_count,
        (b.booked_by = auth.uid()) AS is_my_booking
    FROM public.amenity_bookings b
    WHERE b.amenity_id = p_amenity_id
      AND b.booking_date = p_date
      AND b.status IN ('confirmed', 'waitlist', 'pending_payment');
$$;

REVOKE ALL ON FUNCTION public.get_amenity_slot_availability(UUID, DATE) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_amenity_slot_availability(UUID, DATE) TO authenticated;

-- ------------------------------------------------------------------------------
-- 5. CẬP NHẬT SIMULATE_UNIFIED_PAYMENT (IDEMPOTENT CHỐNG TRÙNG PENDING)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.simulate_unified_payment(
  p_payment_type text,
  p_reference_id uuid,
  p_payment_method text DEFAULT 'DEMO'::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_user_id uuid;
  v_user_role text;
  v_amount numeric := 0;
  v_apt_id uuid;
  v_booking_user uuid;
  v_booking_status text;
  v_title text;
  v_inv_status invoice_status;
  v_txn_code text;
  v_res_count int;
  v_fee numeric;
  v_deposit numeric;
  v_existing_id uuid;
  v_existing_code text;
  v_existing_amount numeric;
  v_existing_method text;
BEGIN
  -- 1. Kiểm tra xác thực người dùng
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Bạn chưa đăng nhập vào hệ thống';
  END IF;

  SELECT role INTO v_user_role FROM public.users WHERE id = v_user_id;

  -- 2. Kiểm tra phương thức thanh toán
  p_payment_method := UPPER(COALESCE(p_payment_method, 'DEMO'));
  IF p_payment_method NOT IN ('DEMO', 'VIETQR', 'BANK_TRANSFER', 'CASH') THEN
    p_payment_method := 'DEMO';
  END IF;

  -- 3. Xử lý nhánh HÓA ĐƠN (INVOICE)
  IF UPPER(p_payment_type) = 'INVOICE' THEN
    SELECT i.total_amount, i.apartment_id, i.status, 'Hóa đơn tiền phòng kỳ ' || i.period
    INTO v_amount, v_apt_id, v_inv_status, v_title
    FROM public.invoices i
    WHERE i.id = p_reference_id FOR UPDATE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Hóa đơn không tồn tại: %', p_reference_id;
    END IF;

    IF v_inv_status = 'paid' THEN
      RAISE EXCEPTION 'Hóa đơn này đã được thanh toán hoàn tất trước đó';
    END IF;

    -- Kiểm soát quyền sở hữu: cư dân thuộc căn hộ hoặc BQL
    IF COALESCE(v_user_role, 'resident') NOT IN ('admin', 'management', 'accountant') THEN
      SELECT count(*) INTO v_res_count
      FROM public.residents_apartments
      WHERE apartment_id = v_apt_id AND user_id = v_user_id;
      
      IF v_res_count = 0 THEN
        RAISE EXCEPTION 'Bạn không có quyền thanh toán cho hóa đơn của căn hộ này';
      END IF;
    END IF;

    IF v_amount <= 0 THEN
      RAISE EXCEPTION 'Số tiền thanh toán phải lớn hơn 0 (Hiện tại: % đ)', v_amount;
    END IF;

    -- KIỂM TRA IDEMPOTENCY: Nếu đã có giao dịch PENDING cho hóa đơn này
    SELECT id, transaction_code, amount, payment_method
    INTO v_existing_id, v_existing_code, v_existing_amount, v_existing_method
    FROM public.payment_transactions
    WHERE invoice_id = p_reference_id AND status = 'PENDING'
    ORDER BY created_at DESC
    LIMIT 1;

    IF v_existing_id IS NOT NULL THEN
      -- Cập nhật phương thức nếu có thay đổi
      IF v_existing_method <> p_payment_method THEN
        UPDATE public.payment_transactions
        SET payment_method = p_payment_method
        WHERE id = v_existing_id;
      END IF;

      RETURN jsonb_build_object(
        'success', true,
        'is_pending', true,
        'transaction_code', v_existing_code,
        'amount', v_existing_amount,
        'payment_method', p_payment_method,
        'is_reused', true,
        'message', 'Yêu cầu thanh toán hóa đơn đang chờ BQL xác nhận'
      );
    END IF;

    -- Tạo mã giao dịch duy nhất
    v_txn_code := 'INV' || to_char(now(), 'YYYYMMDDHH24MISS') || UPPER(SUBSTRING(gen_random_uuid()::text, 1, 4));

    -- Tạo bản ghi giao dịch thanh toán
    INSERT INTO public.payment_transactions (
      invoice_id,
      apartment_id,
      amount,
      payment_method,
      status,
      transaction_code,
      title,
      type,
      user_id
    ) VALUES (
      p_reference_id,
      v_apt_id,
      v_amount,
      p_payment_method,
      'PENDING',
      v_txn_code,
      v_title,
      'INVOICE',
      v_user_id
    );

    -- Cập nhật trạng thái hóa đơn sang pending_confirmation để BQL đối soát
    UPDATE public.invoices
    SET status = 'pending_confirmation',
        updated_at = now()
    WHERE id = p_reference_id;

    RETURN jsonb_build_object(
      'success', true,
      'is_pending', true,
      'transaction_code', v_txn_code,
      'amount', v_amount,
      'payment_method', p_payment_method,
      'message', 'Giao dịch thanh toán hóa đơn đã được tiếp nhận và đang chờ BQL xác nhận'
    );

  -- 4. Xử lý nhánh TIỆN ÍCH DỊCH VỤ (SERVICE)
  ELSIF UPPER(p_payment_type) = 'SERVICE' THEN
    SELECT b.apartment_id, b.booked_by, b.status, COALESCE(b.fee_amount, 0), COALESCE(b.deposit_amount, 0), a.name 
    INTO v_apt_id, v_booking_user, v_booking_status, v_fee, v_deposit, v_title
    FROM public.amenity_bookings b
    JOIN public.building_amenities a ON a.id = b.amenity_id
    WHERE b.id = p_reference_id FOR UPDATE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Lượt đặt tiện ích không tồn tại: %', p_reference_id;
    END IF;

    IF v_booking_status = 'confirmed' THEN
      RAISE EXCEPTION 'Lượt đặt tiện ích này đã được xác nhận/thanh toán trước đó';
    END IF;
    IF v_booking_status IN ('cancelled', 'rejected') THEN
      RAISE EXCEPTION 'Lượt đặt tiện ích này đã bị hủy hoặc từ chối, không thể thanh toán';
    END IF;

    -- Kiểm soát quyền sở hữu: Người đặt, cư dân cùng căn hộ hoặc BQL
    IF COALESCE(v_user_role, 'resident') NOT IN ('admin', 'management') THEN
      IF v_booking_user != v_user_id AND NOT EXISTS (
        SELECT 1 FROM public.residents_apartments
        WHERE apartment_id = v_apt_id AND user_id = v_user_id
      ) THEN
        RAISE EXCEPTION 'Bạn không có quyền thanh toán cho lượt đặt tiện ích này';
      END IF;
    END IF;

    v_amount := v_fee + v_deposit;
    IF v_amount <= 0 THEN
      UPDATE public.amenity_bookings
      SET status = 'confirmed', updated_at = now()
      WHERE id = p_reference_id;

      RETURN jsonb_build_object(
        'success', true,
        'is_pending', false,
        'message', 'Lịch đặt tiện ích miễn phí đã được xác nhận tự động'
      );
    END IF;

    -- KIỂM TRA IDEMPOTENCY: Nếu đã có giao dịch PENDING cho booking này
    SELECT id, transaction_code, amount, payment_method
    INTO v_existing_id, v_existing_code, v_existing_amount, v_existing_method
    FROM public.payment_transactions
    WHERE booking_id = p_reference_id AND status = 'PENDING'
    ORDER BY created_at DESC
    LIMIT 1;

    IF v_existing_id IS NOT NULL THEN
      IF v_existing_method <> p_payment_method THEN
        UPDATE public.payment_transactions
        SET payment_method = p_payment_method
        WHERE id = v_existing_id;
      END IF;

      RETURN jsonb_build_object(
        'success', true,
        'is_pending', true,
        'transaction_code', v_existing_code,
        'amount', v_existing_amount,
        'payment_method', p_payment_method,
        'is_reused', true,
        'message', 'Yêu cầu thanh toán tiện ích đang chờ BQL xác nhận'
      );
    END IF;

    v_title := 'Thanh toán dịch vụ ' || COALESCE(v_title, 'tiện ích');
    v_txn_code := 'SVC' || to_char(now(), 'YYYYMMDDHH24MISS') || UPPER(SUBSTRING(gen_random_uuid()::text, 1, 4));

    -- Lưu giao dịch thanh toán trạng thái PENDING
    INSERT INTO public.payment_transactions (
      booking_id,
      apartment_id,
      amount,
      payment_method,
      status,
      transaction_code,
      title,
      type,
      user_id
    ) VALUES (
      p_reference_id,
      v_apt_id,
      v_amount,
      p_payment_method,
      'PENDING',
      v_txn_code,
      v_title,
      'SERVICE',
      v_user_id
    );

    -- Chuyển trạng thái booking sang pending_payment
    UPDATE public.amenity_bookings
    SET status = 'pending_payment',
        updated_at = now()
    WHERE id = p_reference_id;

    RETURN jsonb_build_object(
      'success', true,
      'is_pending', true,
      'transaction_code', v_txn_code,
      'amount', v_amount,
      'payment_method', p_payment_method,
      'message', 'Yêu cầu thanh toán tiện ích đã được gửi, vui lòng chờ Ban quản lý xác nhận'
    );

  ELSE
    RAISE EXCEPTION 'Loại thanh toán không được hỗ trợ: %', p_payment_type;
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.simulate_unified_payment(text, uuid, text) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.simulate_unified_payment(text, uuid, text) TO authenticated;

-- ------------------------------------------------------------------------------
-- 6. HOÀN THIỆN TOÀN BỘ NGHIỆP VỤ BOOK_AMENITY_SLOT
-- ------------------------------------------------------------------------------
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
    v_user_id UUID;
    v_amenity RECORD;
    v_target_apartment UUID;
    v_apt_count INT := 0;
    v_status VARCHAR := 'confirmed';
    v_current_guests INT := 0;
    v_is_waitlist BOOLEAN := false;
    v_booking_id UUID;
    v_fee NUMERIC := 0;
    v_deposit NUMERIC := 0;
    v_now_vn TIMESTAMP := (now() AT TIME ZONE 'Asia/Ho_Chi_Minh');
    v_slot_start_str TEXT;
    v_slot_start_time TIME;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Bạn chưa đăng nhập vào hệ thống';
    END IF;

    -- Khóa đồng bộ transaction cấp slot để chống Race Condition đặt trùng
    PERFORM pg_advisory_xact_lock(hashtext(p_amenity_id::text || '_' || p_booking_date::text || '_' || p_time_slot));

    -- 1. Kiểm tra thông tin tiện ích
    SELECT * INTO v_amenity
    FROM public.building_amenities
    WHERE id = p_amenity_id AND is_active = true;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Tiện ích không tồn tại hoặc đã ngừng hoạt động';
    END IF;

    -- 2. Kiểm tra lịch bảo trì định kỳ
    IF EXISTS (
        SELECT 1 FROM public.amenity_maintenance_windows
        WHERE amenity_id = p_amenity_id
          AND p_booking_date BETWEEN start_date AND end_date
    ) THEN
        RAISE EXCEPTION 'Tiện ích đang trong thời gian bảo trì định kỳ, không thể đặt lịch';
    END IF;

    -- 3. Kiểm tra ngày đặt và khung giờ theo múi giờ Việt Nam
    IF p_booking_date < (v_now_vn::date) THEN
        RAISE EXCEPTION 'Không thể đặt tiện ích cho ngày trong quá khứ';
    ELSIF p_booking_date = (v_now_vn::date) THEN
        -- Trích xuất giờ bắt đầu từ p_time_slot (VD: "08:00 - 10:00" -> "08:00")
        v_slot_start_str := TRIM(SPLIT_PART(p_time_slot, '-', 1));
        BEGIN
            v_slot_start_time := v_slot_start_str::time;
            IF (v_now_vn::time) >= v_slot_start_time THEN
                RAISE EXCEPTION 'Khung giờ này (%) đã bắt đầu hoặc đã trôi qua', p_time_slot;
            END IF;
        EXCEPTION 
            WHEN invalid_datetime_format THEN NULL;
            WHEN OTHERS THEN RAISE;
        END;
    END IF;

    -- 4. Xác thực căn hộ
    IF p_apartment_id IS NOT NULL THEN
        IF NOT EXISTS (
            SELECT 1 FROM public.residents_apartments
            WHERE user_id = v_user_id AND apartment_id = p_apartment_id
        ) THEN
            RAISE EXCEPTION 'Bạn không thuộc danh sách cư dân của căn hộ này';
        END IF;
        v_target_apartment := p_apartment_id;
    ELSE
        SELECT count(*), min(apartment_id) INTO v_apt_count, v_target_apartment
        FROM public.residents_apartments
        WHERE user_id = v_user_id;

        IF v_apt_count = 0 THEN
            RAISE EXCEPTION 'Bạn chưa được liên kết với bất kỳ căn hộ nào';
        ELSIF v_apt_count > 1 THEN
            RAISE EXCEPTION 'Bạn đang liên kết với % căn hộ. Vui lòng chọn rõ căn hộ khi đặt tiện ích.', v_apt_count;
        END IF;
    END IF;

    IF p_guests_count < 1 THEN
        p_guests_count := 1;
    END IF;

    -- 5. Kiểm tra sức chứa tối đa
    IF p_guests_count > v_amenity.max_capacity THEN
        RAISE EXCEPTION 'Số lượng người (% người) vượt quá sức chứa tối đa của tiện ích (% người)', p_guests_count, v_amenity.max_capacity;
    END IF;

    -- 6. Tính phí sử dụng và tiền cọc
    IF v_amenity.booking_type = 'shared' THEN
        v_fee := COALESCE(v_amenity.fee_amount, 0) * p_guests_count;
    ELSE
        v_fee := COALESCE(v_amenity.fee_amount, 0);
    END IF;
    v_deposit := COALESCE(v_amenity.deposit_amount, 0);

    -- 7. Kiểm tra tình trạng slot theo loại tiện ích
    IF v_amenity.booking_type = 'exclusive' THEN
        SELECT COUNT(*) INTO v_current_guests
        FROM public.amenity_bookings
        WHERE amenity_id = p_amenity_id
          AND booking_date = p_booking_date
          AND time_slot = p_time_slot
          AND status IN ('confirmed', 'pending_payment');

        IF v_current_guests > 0 THEN
            IF p_allow_waitlist THEN
                v_status := 'waitlist';
                v_is_waitlist := true;
            ELSE
                RAISE EXCEPTION 'Khung giờ này đã có người đặt trước (Độc quyền)';
            END IF;
        ELSE
            IF v_fee > 0 OR v_deposit > 0 THEN
                v_status := 'pending_payment';
            ELSE
                v_status := 'confirmed';
            END IF;
        END IF;
    ELSE
        -- Dạng SHARED: Cộng dồn số khách guests_count
        SELECT COALESCE(SUM(guests_count), 0) INTO v_current_guests
        FROM public.amenity_bookings
        WHERE amenity_id = p_amenity_id
          AND booking_date = p_booking_date
          AND time_slot = p_time_slot
          AND status IN ('confirmed', 'pending_payment');

        IF (v_current_guests + p_guests_count) > v_amenity.max_capacity THEN
            IF p_allow_waitlist THEN
                v_status := 'waitlist';
                v_is_waitlist := true;
            ELSE
                RAISE EXCEPTION 'Khung giờ này đã đủ số lượng đặt tối đa (Hết chỗ)';
            END IF;
        ELSE
            IF v_fee > 0 OR v_deposit > 0 THEN
                v_status := 'pending_payment';
            ELSE
                v_status := 'confirmed';
            END IF;
        END IF;
    END IF;

    -- 8. Chèn bản ghi đặt chỗ chuẩn schema (bao gồm cột notes)
    INSERT INTO public.amenity_bookings (
        amenity_id,
        booked_by,
        apartment_id,
        booking_date,
        time_slot,
        guests_count,
        status,
        notes,
        fee_amount,
        deposit_amount,
        deposit_status,
        created_at,
        updated_at
    ) VALUES (
        p_amenity_id,
        v_user_id,
        v_target_apartment,
        p_booking_date,
        p_time_slot,
        p_guests_count,
        v_status,
        p_notes,
        v_fee,
        v_deposit,
        CASE WHEN v_deposit > 0 THEN 'pending' ELSE 'none' END,
        now(),
        now()
    ) RETURNING id INTO v_booking_id;

    RETURN jsonb_build_object(
        'success', true,
        'booking_id', v_booking_id,
        'status', v_status,
        'is_waitlist', v_is_waitlist,
        'fee_amount', v_fee,
        'deposit_amount', v_deposit,
        'message', CASE 
            WHEN v_is_waitlist THEN 'Đã thêm bạn vào danh sách chờ của khung giờ này'
            WHEN v_status = 'pending_payment' THEN 'Đặt chỗ thành công, vui lòng hoàn tất thanh toán'
            ELSE 'Đặt tiện ích thành công!'
        END
    );
END;
$$;

REVOKE ALL ON FUNCTION public.book_amenity_slot(UUID, DATE, VARCHAR, INT, UUID, BOOLEAN, TEXT) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.book_amenity_slot(UUID, DATE, VARCHAR, INT, UUID, BOOLEAN, TEXT) TO authenticated;
