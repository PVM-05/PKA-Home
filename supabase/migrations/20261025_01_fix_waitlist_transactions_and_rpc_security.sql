-- ==============================================================================
-- Migration: 20261025_01_fix_waitlist_transactions_and_rpc_security.sql
-- Mục tiêu: 
-- 1. Vá dứt điểm lỗi thanh toán mô phỏng (cho phép status 'PENDING', thêm updated_at)
-- 2. Thống nhất RPC simulate_unified_payment, loại bỏ overload cũ gây lỗi cột ảo
-- 3. Đồng bộ toàn bộ 6 RPCs pending requests correction và kiểm tra bảo trì chuẩn
-- 4. Siết chặt phân quyền toàn bộ RPC SECURITY DEFINER (confirm_payment, helper functions)
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. NÂNG CẤP BẢNG PAYMENT_TRANSACTIONS
-- ------------------------------------------------------------------------------

-- 1.1 Bổ sung cột updated_at
ALTER TABLE public.payment_transactions 
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

-- 1.2 Mở rộng check constraint cho phép trạng thái 'PENDING'
ALTER TABLE public.payment_transactions 
  DROP CONSTRAINT IF EXISTS payment_transactions_status_check;
ALTER TABLE public.payment_transactions 
  ADD CONSTRAINT payment_transactions_status_check 
  CHECK (status IN ('PENDING', 'SUCCESS', 'FAILED', 'CANCELLED'));

-- 1.3 Đảm bảo check constraint payment_transactions_type_check hỗ trợ INVOICE và SERVICE
ALTER TABLE public.payment_transactions 
  DROP CONSTRAINT IF EXISTS payment_transactions_type_check;
ALTER TABLE public.payment_transactions 
  ADD CONSTRAINT payment_transactions_type_check 
  CHECK (type IN ('INVOICE', 'SERVICE'));

-- 1.4 Bổ sung các cột nâng cao cho building_amenities nếu chưa có
ALTER TABLE public.building_amenities
  ADD COLUMN IF NOT EXISTS booking_type VARCHAR(20) NOT NULL DEFAULT 'exclusive',
  ADD COLUMN IF NOT EXISTS max_capacity INT NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS slot_duration_minutes INT NOT NULL DEFAULT 90,
  ADD COLUMN IF NOT EXISTS fee_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS deposit_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS requires_deposit BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT true;

-- 1.5 Nâng cấp ràng buộc trạng thái amenity_bookings hỗ trợ waitlist và pending_payment
ALTER TABLE public.amenity_bookings 
  DROP CONSTRAINT IF EXISTS amenity_bookings_status_check;
ALTER TABLE public.amenity_bookings 
  ADD CONSTRAINT amenity_bookings_status_check 
  CHECK (status IN ('confirmed', 'waitlist', 'cancelled', 'completed', 'no_show', 'pending_payment'));


-- ------------------------------------------------------------------------------
-- 2. ĐỒNG BỘ LƯỢC ĐỒ 4 PHÂN HỆ HỖ TRỢ TRẠNG THÁI 'CANCELLED'
-- ------------------------------------------------------------------------------

-- 2.1 Bảng vehicles
ALTER TABLE public.vehicles DROP CONSTRAINT IF EXISTS vehicles_status_check;
ALTER TABLE public.vehicles ADD CONSTRAINT vehicles_status_check 
  CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled'));

-- 2.2 Bảng meter_reading_submissions
ALTER TABLE public.meter_reading_submissions DROP CONSTRAINT IF EXISTS meter_reading_submissions_status_check;
ALTER TABLE public.meter_reading_submissions ADD CONSTRAINT meter_reading_submissions_status_check 
  CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled'));

-- 2.3 Bảng apartment_link_requests
DROP INDEX IF EXISTS public.uq_apartment_link_requests_user_pending;
DROP POLICY IF EXISTS "Resident tạo yêu cầu mới" ON public.apartment_link_requests;
DROP POLICY IF EXISTS "Resident tạo yêu cầu" ON public.apartment_link_requests;

ALTER TABLE public.apartment_link_requests ALTER COLUMN status DROP DEFAULT;
ALTER TABLE public.apartment_link_requests ALTER COLUMN status TYPE VARCHAR(20) USING status::text;
ALTER TABLE public.apartment_link_requests ALTER COLUMN status SET DEFAULT 'pending';

ALTER TABLE public.apartment_link_requests DROP CONSTRAINT IF EXISTS apartment_link_requests_status_check;
ALTER TABLE public.apartment_link_requests ADD CONSTRAINT apartment_link_requests_status_check 
  CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled'));

ALTER TABLE public.apartment_link_requests DROP CONSTRAINT IF EXISTS apartment_link_requests_user_id_apartment_id_key;

-- Dọn trùng link_requests lịch sử trước khi tạo unique index
WITH duplicates AS (
    SELECT id,
           ROW_NUMBER() OVER (
               PARTITION BY user_id, apartment_id 
               ORDER BY (CASE WHEN status = 'approved' THEN 1 ELSE 2 END), created_at DESC
           ) as rn
    FROM public.apartment_link_requests
    WHERE status IN ('pending', 'approved')
)
UPDATE public.apartment_link_requests
SET status = 'cancelled', updated_at = NOW()
WHERE id IN (SELECT id FROM duplicates WHERE rn > 1);

CREATE UNIQUE INDEX IF NOT EXISTS uq_link_requests_active 
ON public.apartment_link_requests(user_id, apartment_id) 
WHERE status IN ('pending', 'approved');

DROP POLICY IF EXISTS "Resident tạo yêu cầu" ON public.apartment_link_requests;
CREATE POLICY "Resident tạo yêu cầu" 
ON public.apartment_link_requests FOR INSERT 
WITH CHECK (user_id = auth.uid() AND status = 'pending');


-- ------------------------------------------------------------------------------
-- 3. XỬ LÝ TRIỆT ĐỂ RPC SIMULATE_UNIFIED_PAYMENT (GIẢI QUYẾT LỖI THANH TOÁN DEMO)
-- ------------------------------------------------------------------------------

-- Xóa toàn bộ các overload cũ gây xung đột tham số
DROP FUNCTION IF EXISTS public.simulate_unified_payment(varchar, uuid, varchar, varchar, text);
DROP FUNCTION IF EXISTS public.simulate_unified_payment(text, uuid, text, text, text);
DROP FUNCTION IF EXISTS public.simulate_unified_payment(text, uuid, text);

CREATE OR REPLACE FUNCTION public.simulate_unified_payment(
  p_payment_type text DEFAULT 'INVOICE',
  p_reference_id uuid DEFAULT NULL,
  p_payment_method text DEFAULT 'DEMO',
  p_type text DEFAULT NULL,
  p_outcome text DEFAULT 'SUCCESS',
  p_failure_reason text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_user_id uuid;
  v_user_role text;
  v_clean_type text;
  v_clean_method text;
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
  -- 1. Xác thực người dùng
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Bạn chưa đăng nhập vào hệ thống';
  END IF;

  SELECT role INTO v_user_role FROM public.users WHERE id = v_user_id;

  -- Hỗ trợ linh hoạt cả p_payment_type và p_type từ client
  v_clean_type := UPPER(COALESCE(p_payment_type, p_type, 'INVOICE'));
  v_clean_method := UPPER(COALESCE(p_payment_method, 'DEMO'));
  IF v_clean_method NOT IN ('DEMO', 'VIETQR', 'BANK_TRANSFER', 'CASH') THEN
    v_clean_method := 'DEMO';
  END IF;

  -- 2. Xử lý thanh toán HÓA ĐƠN (INVOICE)
  IF v_clean_type = 'INVOICE' THEN
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

    -- Kiểm soát quyền sở hữu: cư dân thuộc căn hộ hoặc Ban quản lý
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

    -- Kiểm tra giao dịch PENDING đang chờ (Idempotency)
    SELECT id, transaction_code, amount, payment_method
    INTO v_existing_id, v_existing_code, v_existing_amount, v_existing_method
    FROM public.payment_transactions
    WHERE invoice_id = p_reference_id AND status = 'PENDING'
    ORDER BY created_at DESC
    LIMIT 1;

    IF v_existing_id IS NOT NULL THEN
      IF v_existing_method <> v_clean_method THEN
        UPDATE public.payment_transactions
        SET payment_method = v_clean_method, updated_at = NOW()
        WHERE id = v_existing_id;
      END IF;

      RETURN jsonb_build_object(
        'success', true,
        'is_pending', true,
        'status', 'PENDING',
        'transaction_code', v_existing_code,
        'amount', v_existing_amount,
        'payment_method', v_clean_method,
        'is_reused', true,
        'message', 'Yêu cầu thanh toán hóa đơn đang chờ Ban quản lý xác nhận'
      );
    END IF;

    v_txn_code := 'INV' || to_char(now(), 'YYYYMMDDHH24MISS') || UPPER(SUBSTRING(gen_random_uuid()::text, 1, 4));

    INSERT INTO public.payment_transactions (
      invoice_id,
      apartment_id,
      amount,
      payment_method,
      status,
      transaction_code,
      title,
      type,
      user_id,
      created_at,
      updated_at
    ) VALUES (
      p_reference_id,
      v_apt_id,
      v_amount,
      v_clean_method,
      'PENDING',
      v_txn_code,
      v_title,
      'INVOICE',
      v_user_id,
      NOW(),
      NOW()
    );

    UPDATE public.invoices
    SET status = 'pending_confirmation',
        updated_at = NOW()
    WHERE id = p_reference_id;

    RETURN jsonb_build_object(
      'success', true,
      'is_pending', true,
      'status', 'PENDING',
      'transaction_code', v_txn_code,
      'amount', v_amount,
      'payment_method', v_clean_method,
      'message', 'Giao dịch thanh toán hóa đơn đã được tiếp nhận và đang chờ BQL xác nhận'
    );

  -- 3. Xử lý thanh toán TIỆN ÍCH DỊCH VỤ (SERVICE)
  ELSIF v_clean_type = 'SERVICE' THEN
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
      SET status = 'confirmed', updated_at = NOW()
      WHERE id = p_reference_id;

      RETURN jsonb_build_object(
        'success', true,
        'is_pending', false,
        'status', 'SUCCESS',
        'message', 'Lịch đặt tiện ích miễn phí đã được xác nhận tự động'
      );
    END IF;

    -- Kiểm tra giao dịch PENDING đang chờ cho booking
    SELECT id, transaction_code, amount, payment_method
    INTO v_existing_id, v_existing_code, v_existing_amount, v_existing_method
    FROM public.payment_transactions
    WHERE booking_id = p_reference_id AND status = 'PENDING'
    ORDER BY created_at DESC
    LIMIT 1;

    IF v_existing_id IS NOT NULL THEN
      IF v_existing_method <> v_clean_method THEN
        UPDATE public.payment_transactions
        SET payment_method = v_clean_method, updated_at = NOW()
        WHERE id = v_existing_id;
      END IF;

      RETURN jsonb_build_object(
        'success', true,
        'is_pending', true,
        'status', 'PENDING',
        'transaction_code', v_existing_code,
        'amount', v_existing_amount,
        'payment_method', v_clean_method,
        'is_reused', true,
        'message', 'Yêu cầu thanh toán dịch vụ tiện ích đang chờ Ban quản lý xác nhận'
      );
    END IF;

    v_title := 'Thanh toán dịch vụ ' || COALESCE(v_title, 'tiện ích');
    v_txn_code := 'SVC' || to_char(now(), 'YYYYMMDDHH24MISS') || UPPER(SUBSTRING(gen_random_uuid()::text, 1, 4));

    INSERT INTO public.payment_transactions (
      booking_id,
      apartment_id,
      amount,
      payment_method,
      status,
      transaction_code,
      title,
      type,
      user_id,
      created_at,
      updated_at
    ) VALUES (
      p_reference_id,
      v_apt_id,
      v_amount,
      v_clean_method,
      'PENDING',
      v_txn_code,
      v_title,
      'SERVICE',
      v_user_id,
      NOW(),
      NOW()
    );

    UPDATE public.amenity_bookings
    SET status = 'pending_payment', updated_at = NOW()
    WHERE id = p_reference_id;

    RETURN jsonb_build_object(
      'success', true,
      'is_pending', true,
      'status', 'PENDING',
      'transaction_code', v_txn_code,
      'amount', v_amount,
      'payment_method', v_clean_method,
      'message', 'Yêu cầu thanh toán tiện ích đã được gửi, vui lòng chờ Ban quản lý xác nhận'
    );
  ELSE
    RAISE EXCEPTION 'Loại thanh toán không hợp lệ: %. Chỉ hỗ trợ INVOICE hoặc SERVICE', v_clean_type;
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.simulate_unified_payment(text, uuid, text, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.simulate_unified_payment(text, uuid, text, text, text, text) TO authenticated;


-- ------------------------------------------------------------------------------
-- 4. RPC RESCHEDULE_AMENITY_BOOKING & SỬA LỖI KIỂM TRA LỊCH BẢO TRÌ
-- ------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.reschedule_amenity_booking(
    p_booking_id UUID,
    p_new_date DATE,
    p_new_time_slot VARCHAR,
    p_new_guests_count INT DEFAULT NULL,
    p_new_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_user_id UUID;
    v_booking RECORD;
    v_amenity RECORD;
    v_h_old BIGINT;
    v_h_new BIGINT;
    v_lock1 BIGINT;
    v_lock2 BIGINT;
    v_now_vn TIMESTAMP := (now() AT TIME ZONE 'Asia/Ho_Chi_Minh');
    v_slot_start_time TIME;
    v_slot_end_time TIME;
    v_open_start TIME;
    v_open_end TIME;
    v_final_guests INT;
    v_current_slot_capacity INT := 0;
    v_is_same_slot BOOLEAN := false;
    v_next_waitlist RECORD;
    v_new_fee NUMERIC;
    v_old_slot_used_guests INT := 0;
    v_old_slot_used_count INT := 0;
    v_old_slot_avail INT := 0;
    v_waitlist_promoted BOOLEAN := false;
    v_promoted_fee NUMERIC := 0;
    v_promoted_deposit NUMERIC := 0;
    v_existing_tx_id UUID;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Bạn chưa đăng nhập vào hệ thống';
    END IF;

    PERFORM set_config('pka.in_reschedule', 'true', true);

    SELECT * INTO v_booking
    FROM public.amenity_bookings
    WHERE id = p_booking_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Lượt đặt tiện ích không tồn tại';
    END IF;

    IF v_booking.booked_by != v_user_id AND NOT public.is_staff() THEN
        RAISE EXCEPTION 'Bạn không có quyền đổi lịch cho lượt đặt tiện ích này.';
    END IF;

    IF v_booking.status NOT IN ('confirmed', 'pending_payment', 'waitlist') THEN
        RAISE EXCEPTION 'Chỉ có thể đổi lịch cho các lượt đặt đang xác nhận, chờ thanh toán hoặc trong hàng đợi.';
    END IF;

    SELECT * INTO v_amenity
    FROM public.building_amenities
    WHERE id = v_booking.amenity_id AND is_active = true;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Tiện ích không tồn tại hoặc đã ngừng hoạt động';
    END IF;

    -- Kiểm tra định dạng khung giờ mới
    IF p_new_time_slot !~ '^([01][0-9]|2[0-3]):[0-5][0-9]\s*-\s*([01][0-9]|2[0-3]):[0-5][0-9]$' THEN
        RAISE EXCEPTION 'Định dạng khung giờ không hợp lệ. Yêu cầu định dạng HH:mm - HH:mm (VD: 08:00 - 10:00).';
    END IF;

    v_slot_start_time := TRIM(SPLIT_PART(p_new_time_slot, '-', 1))::time;
    v_slot_end_time := TRIM(SPLIT_PART(p_new_time_slot, '-', 2))::time;

    IF v_slot_start_time >= v_slot_end_time THEN
        RAISE EXCEPTION 'Khung giờ không hợp lệ: giờ bắt đầu (%) phải nhỏ hơn giờ kết thúc (%).', 
            v_slot_start_time, v_slot_end_time;
    END IF;

    -- Kiểm tra giờ mở cửa
    IF v_amenity.open_hours IS NOT NULL THEN
        IF v_amenity.open_hours !~ '^([01][0-9]|2[0-3]):[0-5][0-9]\s*-\s*([01][0-9]|2[0-3]):[0-5][0-9]$' THEN
            RAISE EXCEPTION 'Giờ mở cửa của tiện ích (%) không đúng định dạng chuẩn HH:mm - HH:mm.', v_amenity.open_hours;
        END IF;

        v_open_start := TRIM(SPLIT_PART(v_amenity.open_hours, '-', 1))::time;
        v_open_end := TRIM(SPLIT_PART(v_amenity.open_hours, '-', 2))::time;

        IF v_open_start >= v_open_end THEN
            RAISE EXCEPTION 'Giờ mở cửa của tiện ích không hợp lệ (giờ mở phải trước giờ đóng): %', v_amenity.open_hours;
        END IF;

        IF v_slot_start_time < v_open_start OR v_slot_end_time > v_open_end THEN
            RAISE EXCEPTION 'Khung giờ mới (%) nằm ngoài giờ mở cửa của tiện ích (%).',
                p_new_time_slot, v_amenity.open_hours;
        END IF;
    END IF;

    -- Kiểm tra ngày và giờ quá khứ
    IF v_booking.booking_date < (v_now_vn::date) THEN
        RAISE EXCEPTION 'Lượt đặt tiện ích này đã diễn ra trong quá khứ, không thể đổi lịch.';
    ELSIF v_booking.booking_date = (v_now_vn::date) THEN
        IF (v_now_vn::time) >= (TRIM(SPLIT_PART(v_booking.time_slot, '-', 1))::time) THEN
            RAISE EXCEPTION 'Lượt đặt hiện tại (%) đã bắt đầu hoặc đã qua, không thể đổi lịch.', v_booking.time_slot;
        END IF;
    END IF;

    IF p_new_date < (v_now_vn::date) THEN
        RAISE EXCEPTION 'Không thể dời lịch sang ngày trong quá khứ.';
    ELSIF p_new_date = (v_now_vn::date) THEN
        IF (v_now_vn::time) >= v_slot_start_time THEN
            RAISE EXCEPTION 'Khung giờ mới (%) đã bắt đầu hoặc đã qua trong hôm nay.', p_new_time_slot;
        END IF;
    END IF;

    -- SỬA LỖI TÊN CỘT: So khớp với start_time và end_time của amenity_maintenance_windows
    IF EXISTS (
        SELECT 1 FROM public.amenity_maintenance_windows
        WHERE amenity_id = v_booking.amenity_id
          AND (p_new_date >= (start_time AT TIME ZONE 'Asia/Ho_Chi_Minh')::date 
               AND p_new_date <= (end_time AT TIME ZONE 'Asia/Ho_Chi_Minh')::date)
    ) THEN
        RAISE EXCEPTION 'Tiện ích đang trong thời gian bảo trì vào ngày đã chọn.';
    END IF;

    -- Khóa Advisory chống Deadlock
    v_h_old := hashtext(v_booking.amenity_id::text || '_' || v_booking.booking_date::text || '_' || v_booking.time_slot);
    v_h_new := hashtext(v_booking.amenity_id::text || '_' || p_new_date::text || '_' || p_new_time_slot);
    v_lock1 := LEAST(v_h_old, v_h_new);
    v_lock2 := GREATEST(v_h_old, v_h_new);

    PERFORM pg_advisory_xact_lock(v_lock1);
    IF v_lock1 <> v_lock2 THEN
        PERFORM pg_advisory_xact_lock(v_lock2);
    END IF;

    v_is_same_slot := (v_booking.booking_date = p_new_date AND v_booking.time_slot = p_new_time_slot);

    -- Xác định số khách
    IF v_booking.status = 'confirmed' THEN
        v_final_guests := v_booking.guests_count;
    ELSE
        v_final_guests := COALESCE(p_new_guests_count, v_booking.guests_count, 1);
        IF v_final_guests < 1 THEN v_final_guests := 1; END IF;
        IF v_final_guests > v_amenity.max_capacity THEN
            RAISE EXCEPTION 'Số lượng người (% người) vượt quá sức chứa tối đa của tiện ích (% người)', 
                v_final_guests, v_amenity.max_capacity;
        END IF;
    END IF;

    -- Kiểm tra sức chứa tại slot mới
    IF v_amenity.booking_type = 'exclusive' THEN
        SELECT COUNT(*) INTO v_current_slot_capacity
        FROM public.amenity_bookings
        WHERE amenity_id = v_booking.amenity_id
          AND booking_date = p_new_date
          AND time_slot = p_new_time_slot
          AND status IN ('confirmed', 'pending_payment')
          AND id <> p_booking_id;

        IF v_current_slot_capacity > 0 THEN
            RAISE EXCEPTION 'Khung giờ mới đã có người đặt trước (Độc quyền).';
        END IF;
    ELSE
        SELECT COALESCE(SUM(guests_count), 0) INTO v_current_slot_capacity
        FROM public.amenity_bookings
        WHERE amenity_id = v_booking.amenity_id
          AND booking_date = p_new_date
          AND time_slot = p_new_time_slot
          AND status IN ('confirmed', 'pending_payment')
          AND id <> p_booking_id;

        IF (v_current_slot_capacity + v_final_guests) > v_amenity.max_capacity THEN
            RAISE EXCEPTION 'Khung giờ mới không đủ chỗ cho % khách (chỉ còn trống % chỗ).',
                v_final_guests, (v_amenity.max_capacity - v_current_slot_capacity);
        END IF;
    END IF;

    -- Điều chỉnh trạng thái nếu từ waitlist chuyển sang slot trống
    IF v_booking.status = 'waitlist' THEN
        IF COALESCE(v_amenity.fee_amount, 0) > 0 OR COALESCE(v_amenity.deposit_amount, 0) > 0 THEN
            v_booking.status := 'pending_payment';
        ELSE
            v_booking.status := 'confirmed';
        END IF;
    ELSIF v_booking.status = 'pending_payment' AND v_amenity.booking_type = 'shared' THEN
        v_new_fee := COALESCE(v_amenity.fee_amount, 0) * v_final_guests;
        UPDATE public.amenity_bookings
        SET fee_amount = v_new_fee
        WHERE id = p_booking_id;

        UPDATE public.payment_transactions
        SET amount = (v_new_fee + COALESCE(v_booking.deposit_amount, 0)),
            updated_at = NOW()
        WHERE (booking_id = p_booking_id OR invoice_id = p_booking_id::text)
          AND status = 'PENDING';
    END IF;

    UPDATE public.amenity_bookings
    SET booking_date = p_new_date,
        time_slot = p_new_time_slot,
        guests_count = v_final_guests,
        notes = COALESCE(p_new_notes, notes),
        status = v_booking.status,
        updated_at = NOW()
    WHERE id = p_booking_id;

    -- Đôn Waitlist cho slot cũ theo quy tắc Strict FIFO
    IF NOT v_is_same_slot THEN
        SELECT COALESCE(SUM(guests_count), 0), COUNT(*) 
        INTO v_old_slot_used_guests, v_old_slot_used_count
        FROM public.amenity_bookings
        WHERE amenity_id = v_booking.amenity_id
          AND booking_date = v_booking.booking_date
          AND time_slot = v_booking.time_slot
          AND status IN ('confirmed', 'pending_payment');

        v_old_slot_avail := v_amenity.max_capacity - v_old_slot_used_guests;

        SELECT * INTO v_next_waitlist
        FROM public.amenity_bookings
        WHERE amenity_id = v_booking.amenity_id
          AND booking_date = v_booking.booking_date
          AND time_slot = v_booking.time_slot
          AND status = 'waitlist'
        ORDER BY created_at ASC
        LIMIT 1
        FOR UPDATE;

        IF FOUND THEN
            IF (v_amenity.booking_type = 'exclusive' AND v_old_slot_used_count = 0)
               OR (v_amenity.booking_type = 'shared' AND v_next_waitlist.guests_count <= v_old_slot_avail) THEN
                
                v_promoted_fee := COALESCE(v_amenity.fee_amount, 0) * v_next_waitlist.guests_count;
                v_promoted_deposit := COALESCE(v_amenity.deposit_amount, 0);

                IF (v_promoted_fee + v_promoted_deposit) > 0 THEN
                    UPDATE public.amenity_bookings
                    SET status = 'pending_payment',
                        fee_amount = v_promoted_fee,
                        deposit_amount = v_promoted_deposit,
                        deposit_status = CASE WHEN v_promoted_deposit > 0 THEN 'pending' ELSE 'none' END,
                        updated_at = NOW()
                    WHERE id = v_next_waitlist.id;

                    SELECT id INTO v_existing_tx_id
                    FROM public.payment_transactions
                    WHERE booking_id = v_next_waitlist.id AND status = 'PENDING'
                    LIMIT 1;

                    IF v_existing_tx_id IS NOT NULL THEN
                        UPDATE public.payment_transactions
                        SET amount = (v_promoted_fee + v_promoted_deposit),
                            updated_at = NOW()
                        WHERE id = v_existing_tx_id;
                    ELSE
                        INSERT INTO public.payment_transactions (
                            booking_id,
                            user_id,
                            apartment_id,
                            amount,
                            payment_method,
                            status,
                            transaction_code,
                            type,
                            title,
                            created_at,
                            updated_at
                        ) VALUES (
                            v_next_waitlist.id,
                            v_next_waitlist.booked_by,
                            v_next_waitlist.apartment_id,
                            (v_promoted_fee + v_promoted_deposit),
                            'DEMO',
                            'PENDING',
                            'SVC' || to_char(now(), 'YYYYMMDDHH24MISS') || UPPER(SUBSTRING(gen_random_uuid()::text, 1, 4)),
                            'SERVICE',
                            v_amenity.name || ' (' || v_booking.time_slot || ')',
                            NOW(),
                            NOW()
                        );
                    END IF;
                ELSE
                    UPDATE public.amenity_bookings
                    SET status = 'confirmed', updated_at = NOW()
                    WHERE id = v_next_waitlist.id;
                END IF;

                v_waitlist_promoted := true;
            END IF;
        END IF;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'action', CASE 
            WHEN v_booking.status = 'confirmed' THEN 'rescheduled_confirmed'
            ELSE 'rescheduled_pending_payment'
        END,
        'status', v_booking.status,
        'waitlist_promoted', v_waitlist_promoted,
        'message', 'Đổi lịch đặt tiện ích thành công',
        'booking_id', p_booking_id,
        'new_date', p_new_date,
        'new_time_slot', p_new_time_slot
    );
END;
$$;

REVOKE ALL ON FUNCTION public.reschedule_amenity_booking(UUID, DATE, VARCHAR, INT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.reschedule_amenity_booking(UUID, DATE, VARCHAR, INT, TEXT) TO authenticated;


-- ------------------------------------------------------------------------------
-- 5. CẬP NHẬT TRIGGER HỦY ĐẶT CHỖ (ĐỒNG BỘ GIAO DỊCH PENDING CHO WAITLIST)
-- ------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.handle_amenity_booking_cancellation()
RETURNS TRIGGER AS $$
DECLARE
    v_amenity RECORD;
    v_waitlist_rec RECORD;
    v_available_capacity INT;
    v_current_confirmed_count INT;
    v_promoted_fee NUMERIC := 0;
    v_promoted_deposit NUMERIC := 0;
    v_existing_tx_id UUID;
BEGIN
    IF OLD.status <> 'cancelled' AND NEW.status = 'cancelled' THEN
        SELECT * INTO v_amenity FROM public.building_amenities WHERE id = NEW.amenity_id;
        IF NOT FOUND THEN RETURN NEW; END IF;

        IF v_amenity.booking_type = 'per_slot' OR v_amenity.booking_type = 'exclusive' THEN
            v_current_confirmed_count := 0;
        ELSE
            SELECT COALESCE(SUM(guests_count), 0) INTO v_current_confirmed_count
            FROM public.amenity_bookings
            WHERE amenity_id = NEW.amenity_id
              AND booking_date = NEW.booking_date
              AND time_slot = NEW.time_slot
              AND status = 'confirmed';
        END IF;

        v_available_capacity := v_amenity.max_capacity - v_current_confirmed_count;

        FOR v_waitlist_rec IN
            SELECT id, booked_by, guests_count, apartment_id
            FROM public.amenity_bookings
            WHERE amenity_id = NEW.amenity_id
              AND booking_date = NEW.booking_date
              AND time_slot = NEW.time_slot
              AND status = 'waitlist'
              AND guests_count <= v_available_capacity
            ORDER BY created_at ASC
            FOR UPDATE SKIP LOCKED
        LOOP
            v_promoted_fee := COALESCE(v_amenity.fee_amount, 0) * v_waitlist_rec.guests_count;
            v_promoted_deposit := COALESCE(v_amenity.deposit_amount, 0);

            IF (v_promoted_fee + v_promoted_deposit) > 0 THEN
                UPDATE public.amenity_bookings
                SET status = 'pending_payment',
                    fee_amount = v_promoted_fee,
                    deposit_amount = v_promoted_deposit,
                    deposit_status = CASE WHEN v_promoted_deposit > 0 THEN 'pending' ELSE 'none' END,
                    updated_at = NOW()
                WHERE id = v_waitlist_rec.id;

                SELECT id INTO v_existing_tx_id
                FROM public.payment_transactions
                WHERE booking_id = v_waitlist_rec.id AND status = 'PENDING'
                LIMIT 1;

                IF v_existing_tx_id IS NOT NULL THEN
                    UPDATE public.payment_transactions
                    SET amount = (v_promoted_fee + v_promoted_deposit),
                        updated_at = NOW()
                    WHERE id = v_existing_tx_id;
                ELSE
                    INSERT INTO public.payment_transactions (
                        booking_id,
                        user_id,
                        apartment_id,
                        amount,
                        payment_method,
                        status,
                        transaction_code,
                        type,
                        title,
                        created_at,
                        updated_at
                    ) VALUES (
                        v_waitlist_rec.id,
                        v_waitlist_rec.booked_by,
                        v_waitlist_rec.apartment_id,
                        (v_promoted_fee + v_promoted_deposit),
                        'DEMO',
                        'PENDING',
                        'SVC' || to_char(now(), 'YYYYMMDDHH24MISS') || UPPER(SUBSTRING(gen_random_uuid()::text, 1, 4)),
                        'SERVICE',
                        v_amenity.name || ' (' || NEW.time_slot || ')',
                        NOW(),
                        NOW()
                    );
                END IF;
            ELSE
                UPDATE public.amenity_bookings
                SET status = 'confirmed', updated_at = NOW()
                WHERE id = v_waitlist_rec.id;
            END IF;

            INSERT INTO public.notifications (user_id, title, body, type, payload)
            VALUES (
                v_waitlist_rec.booked_by,
                'Đã có chỗ trống tiện ích ' || v_amenity.name,
                'Lượt đặt chỗ ngày ' || to_char(NEW.booking_date, 'DD/MM/YYYY') || ' khung giờ ' || NEW.time_slot || ' của bạn đã chuyển sang trạng thái Chờ thanh toán.',
                'amenity_promoted',
                jsonb_build_object('booking_id', v_waitlist_rec.id, 'amenity_id', NEW.amenity_id)
            );

            v_available_capacity := v_available_capacity - v_waitlist_rec.guests_count;
            IF v_available_capacity <= 0 THEN
                EXIT;
            END IF;
        END LOOP;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_catalog;


-- ------------------------------------------------------------------------------
-- 6. CÁC RPC SỬA SAI & HỦY YÊU CẦU CHO DUYỆT (PHƯƠNG TIỆN, ĐIỆN NƯỚC, LIÊN KẾT)
-- ------------------------------------------------------------------------------

-- 6.1 Hủy phương tiện
CREATE OR REPLACE FUNCTION public.cancel_pending_vehicle(p_vehicle_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_user_id UUID;
    v_updated_count INT;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Bạn chưa đăng nhập vào hệ thống';
    END IF;

    UPDATE public.vehicles
    SET status = 'cancelled', updated_at = NOW()
    WHERE id = p_vehicle_id 
      AND status = 'pending'
      AND (user_id = v_user_id OR registered_by = v_user_id OR public.is_staff());

    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    IF v_updated_count = 0 THEN
        RAISE EXCEPTION 'Không tìm thấy phương tiện đang chờ duyệt hoặc bạn không có quyền hủy bản ghi này.';
    END IF;

    RETURN jsonb_build_object('success', true, 'message', 'Đã hủy đăng ký phương tiện thành công', 'vehicle_id', p_vehicle_id);
END;
$$;
REVOKE ALL ON FUNCTION public.cancel_pending_vehicle(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cancel_pending_vehicle(UUID) TO authenticated;

-- 6.2 Cập nhật phương tiện
CREATE OR REPLACE FUNCTION public.update_pending_vehicle(
    p_vehicle_id UUID,
    p_license_plate VARCHAR,
    p_vehicle_type VARCHAR,
    p_brand_model VARCHAR DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_user_id UUID;
    v_vehicle RECORD;
    v_clean_plate VARCHAR;
    v_active_motorbikes INT;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Bạn chưa đăng nhập vào hệ thống';
    END IF;

    SELECT * INTO v_vehicle
    FROM public.vehicles
    WHERE id = p_vehicle_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Phương tiện không tồn tại';
    END IF;

    IF v_vehicle.status != 'pending' THEN
        RAISE EXCEPTION 'Chỉ có thể chỉnh sửa phương tiện đang ở trạng thái chờ duyệt (pending).';
    END IF;

    IF v_vehicle.user_id != v_user_id 
       AND v_vehicle.registered_by != v_user_id 
       AND NOT public.is_staff() THEN
        RAISE EXCEPTION 'Bạn không có quyền chỉnh sửa thông tin phương tiện này.';
    END IF;

    v_clean_plate := UPPER(TRIM(p_license_plate));
    IF v_clean_plate IS NULL OR v_clean_plate = '' THEN
        RAISE EXCEPTION 'Biển số xe không được để trống.';
    END IF;

    PERFORM pg_advisory_xact_lock(hashtext('vehicle_limit_' || v_vehicle.apartment_id::text));

    IF p_vehicle_type = 'motorbike' THEN
        SELECT COUNT(*) INTO v_active_motorbikes
        FROM public.vehicles
        WHERE apartment_id = v_vehicle.apartment_id
          AND vehicle_type = 'motorbike'
          AND status IN ('pending', 'approved')
          AND id <> p_vehicle_id;

        IF v_active_motorbikes >= 2 THEN
            RAISE EXCEPTION 'Mỗi căn hộ chỉ được đăng ký tối đa 2 xe máy theo quy định của tòa nhà.';
        END IF;
    END IF;

    UPDATE public.vehicles
    SET license_plate = v_clean_plate,
        plate_number = v_clean_plate,
        vehicle_type = p_vehicle_type,
        brand_model = TRIM(p_brand_model),
        updated_at = NOW()
    WHERE id = p_vehicle_id AND status = 'pending';

    RETURN jsonb_build_object('success', true, 'message', 'Cập nhật thông tin phương tiện thành công', 'vehicle_id', p_vehicle_id);
END;
$$;
REVOKE ALL ON FUNCTION public.update_pending_vehicle(UUID, VARCHAR, VARCHAR, VARCHAR) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_pending_vehicle(UUID, VARCHAR, VARCHAR, VARCHAR) TO authenticated;

-- 6.3 Cập nhật phiếu chỉ số điện nước
CREATE OR REPLACE FUNCTION public.update_pending_meter_reading(
    p_submission_id UUID,
    p_electric_reading NUMERIC,
    p_water_reading NUMERIC,
    p_electric_image_url TEXT DEFAULT NULL,
    p_water_image_url TEXT DEFAULT NULL,
    p_clear_electric_image BOOLEAN DEFAULT FALSE,
    p_clear_water_image BOOLEAN DEFAULT FALSE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_user_id UUID;
    v_sub RECORD;
    v_new_elec_img TEXT;
    v_new_water_img TEXT;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Bạn chưa đăng nhập vào hệ thống';
    END IF;

    IF p_electric_reading < 0 OR p_water_reading < 0 THEN
        RAISE EXCEPTION 'Chỉ số điện và nước không được mang giá trị âm.';
    END IF;

    SELECT * INTO v_sub
    FROM public.meter_reading_submissions
    WHERE id = p_submission_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Phiếu khai báo chỉ số không tồn tại';
    END IF;

    IF v_sub.status != 'pending' THEN
        RAISE EXCEPTION 'Chỉ có thể chỉnh sửa phiếu chỉ số đang ở trạng thái chờ duyệt (pending).';
    END IF;

    IF v_sub.submitted_by != v_user_id AND NOT public.is_staff() THEN
        RAISE EXCEPTION 'Bạn không có quyền chỉnh sửa phiếu chỉ số này.';
    END IF;

    IF p_clear_electric_image THEN
        v_new_elec_img := NULL;
    ELSIF p_electric_image_url IS NOT NULL THEN
        v_new_elec_img := p_electric_image_url;
    ELSE
        v_new_elec_img := v_sub.electric_image_url;
    END IF;

    IF p_clear_water_image THEN
        v_new_water_img := NULL;
    ELSIF p_water_image_url IS NOT NULL THEN
        v_new_water_img := p_water_image_url;
    ELSE
        v_new_water_img := v_sub.water_image_url;
    END IF;

    UPDATE public.meter_reading_submissions
    SET electric_reading = p_electric_reading,
        water_reading = p_water_reading,
        electric_image_url = v_new_elec_img,
        water_image_url = v_new_water_img,
        updated_at = NOW()
    WHERE id = p_submission_id AND status = 'pending';

    RETURN jsonb_build_object('success', true, 'message', 'Đã cập nhật chỉ số điện nước thành công', 'submission_id', p_submission_id);
END;
$$;
REVOKE ALL ON FUNCTION public.update_pending_meter_reading(UUID, NUMERIC, NUMERIC, TEXT, TEXT, BOOLEAN, BOOLEAN) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_pending_meter_reading(UUID, NUMERIC, NUMERIC, TEXT, TEXT, BOOLEAN, BOOLEAN) TO authenticated;

-- 6.4 Hủy phiếu chỉ số điện nước
CREATE OR REPLACE FUNCTION public.cancel_pending_meter_reading(p_submission_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_user_id UUID;
    v_updated_count INT;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Bạn chưa đăng nhập vào hệ thống';
    END IF;

    UPDATE public.meter_reading_submissions
    SET status = 'cancelled', updated_at = NOW()
    WHERE id = p_submission_id 
      AND status = 'pending'
      AND (submitted_by = v_user_id OR public.is_staff());

    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    IF v_updated_count = 0 THEN
        RAISE EXCEPTION 'Không tìm thấy phiếu chỉ số đang chờ duyệt hoặc bạn không có quyền hủy.';
    END IF;

    RETURN jsonb_build_object('success', true, 'message', 'Đã hủy phiếu khai báo chỉ số thành công', 'submission_id', p_submission_id);
END;
$$;
REVOKE ALL ON FUNCTION public.cancel_pending_meter_reading(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cancel_pending_meter_reading(UUID) TO authenticated;

-- 6.5 Hủy yêu cầu liên kết căn hộ
CREATE OR REPLACE FUNCTION public.cancel_apartment_link_request(p_request_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_user_id UUID;
    v_updated_count INT;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Bạn chưa đăng nhập vào hệ thống';
    END IF;

    UPDATE public.apartment_link_requests
    SET status = 'cancelled', updated_at = NOW()
    WHERE id = p_request_id AND user_id = v_user_id AND status = 'pending';

    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    IF v_updated_count = 0 THEN
        RAISE EXCEPTION 'Không tìm thấy yêu cầu liên kết đang chờ duyệt để hủy.';
    END IF;

    RETURN jsonb_build_object('success', true, 'message', 'Đã hủy yêu cầu liên kết căn hộ thành công', 'request_id', p_request_id);
END;
$$;
REVOKE ALL ON FUNCTION public.cancel_apartment_link_request(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cancel_apartment_link_request(UUID) TO authenticated;

-- 6.6 Phê duyệt liên kết căn hộ
CREATE OR REPLACE FUNCTION public.approve_link_request(p_request_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_user_id UUID;
  v_apartment_id UUID;
  v_status VARCHAR(20);
  v_requested_role public.relation_type;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Chỉ Quản trị viên mới có quyền duyệt yêu cầu liên kết căn hộ.';
  END IF;

  SELECT user_id, apartment_id, status, requested_relation_role 
  INTO v_user_id, v_apartment_id, v_status, v_requested_role 
  FROM public.apartment_link_requests 
  WHERE id = p_request_id;

  IF v_status IS NULL THEN
    RAISE EXCEPTION 'Không tìm thấy yêu cầu liên kết.';
  END IF;

  IF v_status != 'pending' THEN
    RAISE EXCEPTION 'Yêu cầu này đã được xử lý.';
  END IF;

  UPDATE public.apartment_link_requests
  SET status = 'approved', updated_at = NOW()
  WHERE id = p_request_id;

  INSERT INTO public.residents_apartments (user_id, apartment_id, relation_role)
  VALUES (v_user_id, v_apartment_id, v_requested_role)
  ON CONFLICT (user_id, apartment_id) DO NOTHING;

  UPDATE public.apartments
  SET is_empty = false
  WHERE id = v_apartment_id;
END;
$$;
REVOKE ALL ON FUNCTION public.approve_link_request(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.approve_link_request(UUID) TO authenticated;


-- ------------------------------------------------------------------------------
-- 7. SIẾT CHẶT QUYỀN VÀ SEARCH_PATH CHO CONFIRM_PAYMENT & HELPER FUNCTIONS
-- ------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.confirm_payment(p_invoice_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_total NUMERIC;
BEGIN
  IF NOT (public.is_admin() OR public.is_accountant()) THEN
    RAISE EXCEPTION 'Chỉ Ban Quản Lý hoặc Kế toán mới có quyền xác nhận thanh toán hóa đơn.';
  END IF;

  SELECT total_amount INTO v_total FROM public.invoices WHERE id = p_invoice_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Không tìm thấy hóa đơn cần xác nhận thanh toán.';
  END IF;

  UPDATE public.invoices
  SET status = 'paid', updated_at = NOW()
  WHERE id = p_invoice_id;

  UPDATE public.payment_transactions
  SET status = 'SUCCESS', updated_at = NOW(), confirmed_at = NOW(), confirmed_by = auth.uid()
  WHERE invoice_id = p_invoice_id AND status = 'PENDING';
END;
$$;
REVOKE ALL ON FUNCTION public.confirm_payment(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.confirm_payment(UUID) TO authenticated;

-- Củng cố search_path cho các hàm helper phân quyền
ALTER FUNCTION public.is_admin() SET search_path = public, pg_catalog;
ALTER FUNCTION public.is_accountant() SET search_path = public, pg_catalog;
ALTER FUNCTION public.is_admin_or_accountant() SET search_path = public, pg_catalog;
ALTER FUNCTION public.is_staff() SET search_path = public, pg_catalog;
ALTER FUNCTION public.is_technician() SET search_path = public, pg_catalog;
ALTER FUNCTION public.is_management() SET search_path = public, pg_catalog;

CREATE OR REPLACE FUNCTION public.is_staff_or_management()
RETURNS boolean
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
  SELECT public.is_staff() OR public.is_management();
$$;
REVOKE ALL ON FUNCTION public.is_staff_or_management() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_staff_or_management() TO authenticated;

CREATE OR REPLACE FUNCTION public.check_amenity_booking_resident_update()
RETURNS TRIGGER AS $$
BEGIN
  IF current_setting('pka.in_reschedule', true) = 'true' THEN
    RETURN NEW;
  END IF;

  IF NOT public.is_staff_or_management() THEN
    IF NOT (
      NEW.status = 'cancelled' OR
      (NEW.status = 'confirmed' AND OLD.status IN ('pending', 'pending_payment', 'waitlist')) OR
      (NEW.status = 'pending_payment' AND OLD.status = 'waitlist')
    ) THEN
      RAISE EXCEPTION 'Cư dân chỉ được phép hủy lịch hoặc hoàn tất thanh toán đặt chỗ tiện ích';
    END IF;

    IF NEW.amenity_id IS DISTINCT FROM OLD.amenity_id OR
       NEW.booking_date IS DISTINCT FROM OLD.booking_date OR
       NEW.time_slot IS DISTINCT FROM OLD.time_slot OR
       NEW.fee_amount IS DISTINCT FROM OLD.fee_amount OR
       NEW.booked_by IS DISTINCT FROM OLD.booked_by OR
       NEW.apartment_id IS DISTINCT FROM OLD.apartment_id THEN
      RAISE EXCEPTION 'Không được phép thay đổi thông tin cốt lõi của lượt đặt chỗ';
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_catalog;
