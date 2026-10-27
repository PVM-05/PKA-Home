-- ==============================================================================
-- Migration: 20261024_01_system_audit_consolidation.sql
-- Mục tiêu: Chuẩn hóa dứt điểm và hợp nhất toàn bộ RPC tài chính, đặt lịch tiện ích,
-- duyệt chỉ số, dọn dẹp các trigger trùng lặp và siết chặt an ninh hệ thống (RBAC).
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 0. XÓA BỎ TOÀN BỘ CÁC BẢN OVERLOAD CŨ CỦA CÁC RPC GÂY XUNG ĐỘT
-- ------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.simulate_unified_payment(text, uuid, text);
DROP FUNCTION IF EXISTS public.simulate_unified_payment(varchar, uuid, varchar);
DROP FUNCTION IF EXISTS public.book_amenity_slot(UUID, DATE, VARCHAR, INT, TEXT);
DROP FUNCTION IF EXISTS public.book_amenity_slot(UUID, UUID, DATE, VARCHAR, INT, BOOLEAN);
DROP FUNCTION IF EXISTS public.book_amenity_slot(UUID, DATE, VARCHAR, INT, UUID, BOOLEAN, TEXT);
DROP FUNCTION IF EXISTS public.generate_valid_bulk_invoices(TEXT, DATE, NUMERIC, NUMERIC, NUMERIC);
DROP FUNCTION IF EXISTS public.generate_valid_bulk_invoices(TEXT, DATE, NUMERIC, NUMERIC, NUMERIC, UUID[]);
DROP FUNCTION IF EXISTS public.approve_meter_reading(UUID);
DROP FUNCTION IF EXISTS public.approve_meter_reading(UUID, BOOLEAN, DATE);
DROP FUNCTION IF EXISTS public.reject_meter_reading(UUID);
DROP FUNCTION IF EXISTS public.reject_meter_reading(UUID, TEXT);
DROP FUNCTION IF EXISTS public.record_manual_payment(UUID);
DROP FUNCTION IF EXISTS public.record_manual_payment(UUID, VARCHAR, TEXT);
DROP FUNCTION IF EXISTS public.create_invoice_with_items(UUID, VARCHAR, DATE, JSONB);
DROP FUNCTION IF EXISTS public.validate_monthly_bulk_invoices(TEXT, NUMERIC, NUMERIC, NUMERIC);

-- ------------------------------------------------------------------------------
-- 1. RPC CHUẨN: simulate_unified_payment
-- Dùng đúng booked_by, kiểm tra role 'management', hỗ trợ luồng 2 bước PENDING
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
      -- Nếu miễn phí hoàn toàn thì xác nhận ngay
      UPDATE public.amenity_bookings
      SET status = 'confirmed', updated_at = now()
      WHERE id = p_reference_id;

      RETURN jsonb_build_object(
        'success', true,
        'is_pending', false,
        'message', 'Lịch đặt tiện ích miễn phí đã được xác nhận tự động'
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
    RAISE EXCEPTION 'Loại thanh toán không hợp lệ: %. Chỉ hỗ trợ INVOICE hoặc SERVICE', p_payment_type;
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.simulate_unified_payment(text, uuid, text) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.simulate_unified_payment(text, uuid, text) TO authenticated;

-- ------------------------------------------------------------------------------
-- 2. RPC CHUẨN: book_amenity_slot
-- Chuẩn hóa sức chứa tiện ích shared bằng SUM(guests_count), ràng buộc căn hộ
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
    v_status VARCHAR := 'confirmed';
    v_current_guests INT := 0;
    v_is_waitlist BOOLEAN := false;
    v_booking_id UUID;
    v_fee NUMERIC := 0;
    v_deposit NUMERIC := 0;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Bạn chưa đăng nhập vào hệ thống';
    END IF;

    -- Khóa đồng bộ transaction cấp slot để chống Race Condition đặt trùng
    PERFORM pg_advisory_xact_lock(hashtext(p_amenity_id::text || '_' || p_booking_date::text || '_' || p_time_slot));

    -- Kiểm tra thông tin tiện ích
    SELECT * INTO v_amenity
    FROM public.building_amenities
    WHERE id = p_amenity_id AND is_active = true;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Tiện ích không tồn tại hoặc đã ngừng hoạt động';
    END IF;

    -- Kiểm tra ngày đặt không được ở quá khứ
    IF p_booking_date < CURRENT_DATE THEN
        RAISE EXCEPTION 'Không thể đặt tiện ích cho ngày trong quá khứ';
    END IF;

    -- Xác thực căn hộ
    IF p_apartment_id IS NOT NULL THEN
        IF NOT EXISTS (
            SELECT 1 FROM public.residents_apartments
            WHERE user_id = v_user_id AND apartment_id = p_apartment_id
        ) THEN
            RAISE EXCEPTION 'Bạn không thuộc danh sách cư dân của căn hộ này';
        END IF;
        v_target_apartment := p_apartment_id;
    ELSE
        SELECT apartment_id INTO v_target_apartment
        FROM public.residents_apartments
        WHERE user_id = v_user_id
        ORDER BY created_at ASC
        LIMIT 1;

        IF v_target_apartment IS NULL THEN
            RAISE EXCEPTION 'Bạn chưa được liên kết với bất kỳ căn hộ nào';
        END IF;
    END IF;

    IF p_guests_count < 1 THEN
        p_guests_count := 1;
    END IF;

    -- Tính phí sử dụng và tiền cọc
    IF v_amenity.booking_type = 'shared' THEN
        v_fee := COALESCE(v_amenity.fee_amount, 0) * p_guests_count;
    ELSE
        v_fee := COALESCE(v_amenity.fee_amount, 0);
    END IF;
    v_deposit := COALESCE(v_amenity.deposit_amount, 0);

    -- Kiểm tra sức chứa theo loại tiện ích
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

    -- Chèn bản ghi đặt chỗ chuẩn schema
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

-- ------------------------------------------------------------------------------
-- 3. RPC CHUẨN: generate_valid_bulk_invoices
-- Khôi phục p_target_apartment_ids, dùng status = 'unpaid', không chèn subtotal
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.generate_valid_bulk_invoices(
  p_period text,
  p_due_date date,
  p_mgmt_rate numeric default 16500,
  p_electric_rate numeric default 3500,
  p_water_rate numeric default 18000,
  p_target_apartment_ids UUID[] DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_validation jsonb;
  v_results jsonb := '[]'::jsonb;
  v_inv_record record;
  v_new_invoice_id uuid;
  v_created_count integer := 0;
  v_skipped_count integer := 0;
  v_elec_qty numeric;
  v_water_qty numeric;
  v_parking_fee numeric;
  v_total_amount numeric;
  v_res record;
BEGIN
  IF NOT public.is_admin_or_accountant() THEN
    RAISE EXCEPTION 'Chỉ Quản trị viên hoặc Kế toán mới có quyền lập hóa đơn hàng loạt';
  END IF;

  v_validation := public.validate_monthly_bulk_invoices(
    p_period, p_mgmt_rate, p_electric_rate, p_water_rate
  );

  FOR v_inv_record IN
    SELECT 
      (item->>'apartment_id')::uuid as apartment_id,
      item->>'apartment_code' as apartment_code,
      (item->>'area')::numeric as area,
      (item->>'electric_usage')::numeric as electric_usage,
      (item->>'water_usage')::numeric as water_usage,
      (item->>'motorbike_count')::integer as motorbike_count,
      (item->>'car_count')::integer as car_count,
      (item->>'total_amount')::numeric as total_amount
    FROM jsonb_array_elements(v_validation->'valid_items') as item
    WHERE p_target_apartment_ids IS NULL 
       OR (item->>'apartment_id')::uuid = ANY(p_target_apartment_ids)
  LOOP
    IF NOT EXISTS (
      SELECT 1 FROM public.invoices 
      WHERE apartment_id = v_inv_record.apartment_id AND period = p_period
    ) THEN
      v_elec_qty := GREATEST(0, COALESCE(v_inv_record.electric_usage, 0));
      v_water_qty := GREATEST(0, COALESCE(v_inv_record.water_usage, 0));
      
      IF (COALESCE(v_inv_record.motorbike_count, 0) + COALESCE(v_inv_record.car_count, 0)) = 0 THEN
        v_parking_fee := 0;
      ELSE
        v_parking_fee := (COALESCE(v_inv_record.motorbike_count, 0) * 100000) + 
                         (COALESCE(v_inv_record.car_count, 0) * 1200000);
      END IF;
      
      v_total_amount := (COALESCE(v_inv_record.area, 70) * p_mgmt_rate) +
                        (v_elec_qty * p_electric_rate) +
                        (v_water_qty * p_water_rate) +
                        v_parking_fee;

      -- Tạo hóa đơn với trạng thái CHUẨN ENUM là 'unpaid'
      INSERT INTO public.invoices (
        apartment_id,
        period,
        due_date,
        total_amount,
        status,
        created_at,
        updated_at
      ) VALUES (
        v_inv_record.apartment_id,
        p_period,
        p_due_date,
        v_total_amount,
        'unpaid',
        now(),
        now()
      ) RETURNING id INTO v_new_invoice_id;

      -- Thêm các hạng mục (KHÔNG chèn subtotal vì là GENERATED ALWAYS)
      INSERT INTO public.invoice_items (invoice_id, fee_type, unit_price, quantity)
      VALUES (v_new_invoice_id, 'Phí quản lý vận hành', p_mgmt_rate, COALESCE(v_inv_record.area, 70));

      IF v_elec_qty > 0 THEN
        INSERT INTO public.invoice_items (invoice_id, fee_type, unit_price, quantity)
        VALUES (v_new_invoice_id, 'Tiền điện', p_electric_rate, v_elec_qty);
      END IF;

      IF v_water_qty > 0 THEN
        INSERT INTO public.invoice_items (invoice_id, fee_type, unit_price, quantity)
        VALUES (v_new_invoice_id, 'Tiền nước', p_water_rate, v_water_qty);
      END IF;

      IF COALESCE(v_inv_record.motorbike_count, 0) > 0 THEN
        INSERT INTO public.invoice_items (invoice_id, fee_type, unit_price, quantity)
        VALUES (v_new_invoice_id, 'Phí gửi xe máy', 100000, v_inv_record.motorbike_count);
      END IF;

      IF COALESCE(v_inv_record.car_count, 0) > 0 THEN
        INSERT INTO public.invoice_items (invoice_id, fee_type, unit_price, quantity)
        VALUES (v_new_invoice_id, 'Phí gửi ô tô', 1200000, v_inv_record.car_count);
      END IF;

      -- Gửi thông báo đến cư dân thuộc căn hộ
      FOR v_res IN
        SELECT user_id FROM public.residents_apartments WHERE apartment_id = v_inv_record.apartment_id
      LOOP
        INSERT INTO public.notifications (
          user_id,
          apartment_id,
          title,
          body,
          type,
          payload
        ) VALUES (
          v_res.user_id,
          v_inv_record.apartment_id,
          'Hóa đơn dịch vụ mới kỳ ' || p_period,
          'Căn hộ ' || v_inv_record.apartment_code || ' có hóa đơn mới trị giá ' || to_char(v_total_amount, 'FM999,999,999') || ' đ. Hạn nộp: ' || to_char(p_due_date, 'DD/MM/YYYY'),
          'invoice_created',
          jsonb_build_object('invoice_id', v_new_invoice_id, 'period', p_period, 'total_amount', v_total_amount)
        );
      END LOOP;

      v_created_count := v_created_count + 1;
      v_results := v_results || jsonb_build_object(
        'apartment_id', v_inv_record.apartment_id,
        'apartment_code', v_inv_record.apartment_code,
        'invoice_id', v_new_invoice_id,
        'total_amount', v_total_amount
      );
    ELSE
      v_skipped_count := v_skipped_count + 1;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'period', p_period,
    'due_date', p_due_date,
    'created_count', v_created_count,
    'skipped_count', v_skipped_count,
    'invoices', v_results
  );
END;
$$;

REVOKE ALL ON FUNCTION public.generate_valid_bulk_invoices(TEXT, DATE, NUMERIC, NUMERIC, NUMERIC, UUID[]) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.generate_valid_bulk_invoices(TEXT, DATE, NUMERIC, NUMERIC, NUMERIC, UUID[]) TO authenticated;

-- ------------------------------------------------------------------------------
-- 4. RPC CHUẨN: approve_meter_reading & reject_meter_reading
-- Dùng đúng status = 'unpaid', nhận tham số p_reason
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.approve_meter_reading(
    p_submission_id UUID,
    p_generate_invoice BOOLEAN DEFAULT FALSE,
    p_due_date DATE DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_sub RECORD;
    v_apt_code VARCHAR;
    v_area NUMERIC;
    v_invoice_id UUID;
    v_prev_elec NUMERIC := 0;
    v_prev_water NUMERIC := 0;
    v_elec_usage NUMERIC := 0;
    v_water_usage NUMERIC := 0;
    v_motorbike_count INT := 0;
    v_car_count INT := 0;
    v_parking_fee NUMERIC := 0;
    v_total_amount NUMERIC := 0;
    v_res RECORD;
BEGIN
    IF NOT public.is_admin_or_accountant() THEN
        RAISE EXCEPTION 'Chỉ Quản trị viên hoặc Kế toán mới có quyền duyệt chỉ số đồng hồ';
    END IF;

    SELECT * INTO v_sub
    FROM public.meter_reading_submissions
    WHERE id = p_submission_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Bản ghi khai báo không tồn tại';
    END IF;

    IF v_sub.status = 'approved' THEN
        RAISE EXCEPTION 'Bản ghi này đã được phê duyệt trước đó';
    END IF;

    SELECT code, COALESCE(area, 70), COALESCE(electric_reading, 0), COALESCE(water_reading, 0)
    INTO v_apt_code, v_area, v_prev_elec, v_prev_water
    FROM public.apartments
    WHERE id = v_sub.apartment_id;

    -- Tính tiêu thụ
    v_elec_usage := GREATEST(0, v_sub.electric_reading - v_prev_elec);
    v_water_usage := GREATEST(0, v_sub.water_reading - v_prev_water);

    -- Cập nhật trạng thái duyệt
    UPDATE public.meter_reading_submissions
    SET status = 'approved',
        reviewed_by = auth.uid(),
        reviewed_at = now(),
        updated_at = now()
    WHERE id = p_submission_id;

    -- Cập nhật chỉ số mới lên căn hộ
    UPDATE public.apartments
    SET electric_reading = v_sub.electric_reading,
        water_reading = v_sub.water_reading,
        updated_at = now()
    WHERE id = v_sub.apartment_id;

    -- Sinh hóa đơn nếu được yêu cầu
    IF p_generate_invoice THEN
        IF p_due_date IS NULL THEN
            p_due_date := CURRENT_DATE + INTERVAL '10 days';
        END IF;

        -- Đếm xe
        SELECT 
          COUNT(*) FILTER (WHERE vehicle_type = 'motorbike'),
          COUNT(*) FILTER (WHERE vehicle_type = 'car')
        INTO v_motorbike_count, v_car_count
        FROM public.vehicles
        WHERE apartment_id = v_sub.apartment_id AND status = 'approved';

        v_parking_fee := (COALESCE(v_motorbike_count, 0) * 100000) + (COALESCE(v_car_count, 0) * 1200000);

        v_total_amount := (v_area * 16500) + (v_elec_usage * 3500) + (v_water_usage * 18000) + v_parking_fee;

        INSERT INTO public.invoices (
            apartment_id,
            period,
            due_date,
            total_amount,
            status,
            created_at,
            updated_at
        ) VALUES (
            v_sub.apartment_id,
            v_sub.period,
            p_due_date,
            v_total_amount,
            'unpaid',
            now(),
            now()
        ) RETURNING id INTO v_invoice_id;

        INSERT INTO public.invoice_items (invoice_id, fee_type, unit_price, quantity)
        VALUES (v_invoice_id, 'Phí quản lý vận hành', 16500, v_area);

        IF v_elec_usage > 0 THEN
            INSERT INTO public.invoice_items (invoice_id, fee_type, unit_price, quantity)
            VALUES (v_invoice_id, 'Tiền điện', 3500, v_elec_usage);
        END IF;

        IF v_water_usage > 0 THEN
            INSERT INTO public.invoice_items (invoice_id, fee_type, unit_price, quantity)
            VALUES (v_invoice_id, 'Tiền nước', 18000, v_water_usage);
        END IF;

        IF v_motorbike_count > 0 THEN
            INSERT INTO public.invoice_items (invoice_id, fee_type, unit_price, quantity)
            VALUES (v_invoice_id, 'Phí gửi xe máy', 100000, v_motorbike_count);
        END IF;

        IF v_car_count > 0 THEN
            INSERT INTO public.invoice_items (invoice_id, fee_type, unit_price, quantity)
            VALUES (v_invoice_id, 'Phí gửi ô tô', 1200000, v_car_count);
        END IF;
    END IF;

    -- Thông báo kết quả duyệt cho người gửi
    INSERT INTO public.notifications (
        user_id,
        apartment_id,
        title,
        body,
        type,
        payload
    ) VALUES (
        v_sub.submitted_by,
        v_sub.apartment_id,
        'Chỉ số điện nước đã được phê duyệt',
        'Khai báo chỉ số kỳ ' || v_sub.period || ' cho căn hộ ' || v_apt_code || ' đã được Ban quản lý phê duyệt.',
        'meter_reading_approved',
        jsonb_build_object('submission_id', p_submission_id, 'period', v_sub.period, 'invoice_id', v_invoice_id)
    );

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Đã phê duyệt chỉ số thành công',
        'invoice_id', v_invoice_id
    );
END;
$$;

REVOKE ALL ON FUNCTION public.approve_meter_reading(UUID, BOOLEAN, DATE) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.approve_meter_reading(UUID, BOOLEAN, DATE) TO authenticated;

CREATE OR REPLACE FUNCTION public.reject_meter_reading(
    p_submission_id UUID,
    p_reason TEXT DEFAULT 'Chỉ số không hợp lệ hoặc ảnh mờ'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_sub RECORD;
BEGIN
    IF NOT public.is_admin_or_accountant() THEN
        RAISE EXCEPTION 'Chỉ Quản trị viên hoặc Kế toán mới có quyền từ chối chỉ số đồng hồ';
    END IF;

    SELECT * INTO v_sub
    FROM public.meter_reading_submissions
    WHERE id = p_submission_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Bản ghi không tồn tại';
    END IF;

    UPDATE public.meter_reading_submissions
    SET status = 'rejected',
        reject_reason = p_reason,
        reviewed_by = auth.uid(),
        reviewed_at = now(),
        updated_at = now()
    WHERE id = p_submission_id;

    -- Thông báo từ chối
    INSERT INTO public.notifications (
        user_id,
        apartment_id,
        title,
        body,
        type,
        payload
    ) VALUES (
        v_sub.submitted_by,
        v_sub.apartment_id,
        'Chỉ số điện nước bị từ chối',
        'Khai báo kỳ ' || v_sub.period || ' bị từ chối. Lý do: ' || p_reason,
        'meter_reading_rejected',
        jsonb_build_object('submission_id', p_submission_id, 'reason', p_reason)
    );

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Đã từ chối chỉ số thành công'
    );
END;
$$;

REVOKE ALL ON FUNCTION public.reject_meter_reading(UUID, TEXT) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.reject_meter_reading(UUID, TEXT) TO authenticated;

-- ------------------------------------------------------------------------------
-- 5. RPC CHUẨN: record_manual_payment
-- Tự sinh transaction_code hợp lệ, cập nhật SUCCESS và đổi status = 'paid'
-- ------------------------------------------------------------------------------
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
    v_existing_txn RECORD;
    v_txn_code VARCHAR;
    v_res RECORD;
BEGIN
    IF NOT public.is_admin_or_accountant() THEN
        RAISE EXCEPTION 'Chỉ Quản trị viên hoặc Kế toán mới có quyền xác nhận thu tiền';
    END IF;

    SELECT * INTO v_inv
    FROM public.invoices
    WHERE id = p_invoice_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Hóa đơn không tồn tại: %', p_invoice_id;
    END IF;

    IF v_inv.status = 'paid' THEN
        RAISE EXCEPTION 'Hóa đơn này đã được xác nhận thanh toán trước đó';
    END IF;

    -- Kiểm tra giao dịch PENDING đã có từ cư dân hay chưa
    SELECT * INTO v_existing_txn
    FROM public.payment_transactions
    WHERE invoice_id = p_invoice_id AND status = 'PENDING'
    ORDER BY created_at DESC
    LIMIT 1 FOR UPDATE;

    IF FOUND THEN
        UPDATE public.payment_transactions
        SET status = 'SUCCESS',
            payment_method = COALESCE(p_payment_method, payment_method),
            confirmed_by = auth.uid(),
            confirmed_at = now()
        WHERE id = v_existing_txn.id;
        v_txn_code := v_existing_txn.transaction_code;
    ELSE
        v_txn_code := 'MAN' || to_char(now(), 'YYYYMMDDHH24MISS') || UPPER(SUBSTRING(gen_random_uuid()::text, 1, 4));

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
            confirmed_by,
            confirmed_at
        ) VALUES (
            p_invoice_id,
            v_inv.apartment_id,
            v_inv.total_amount,
            COALESCE(p_payment_method, 'CASH'),
            'SUCCESS',
            v_txn_code,
            'Thu tiền hóa đơn kỳ ' || v_inv.period,
            'INVOICE',
            auth.uid(),
            auth.uid(),
            now()
        );
    END IF;

    -- Đổi trạng thái hóa đơn sang paid
    UPDATE public.invoices
    SET status = 'paid',
        updated_at = now()
    WHERE id = p_invoice_id;

    -- Gửi thông báo đến cư dân căn hộ
    FOR v_res IN
        SELECT user_id FROM public.residents_apartments WHERE apartment_id = v_inv.apartment_id
    LOOP
        INSERT INTO public.notifications (
            user_id,
            apartment_id,
            title,
            body,
            type,
            payload
        ) VALUES (
            v_res.user_id,
            v_inv.apartment_id,
            'Hóa đơn kỳ ' || v_inv.period || ' đã được xác nhận thanh toán',
            'Ban quản lý đã xác nhận thu ' || to_char(v_inv.total_amount, 'FM999,999,999') || ' đ cho hóa đơn kỳ ' || v_inv.period || '.',
            'payment_confirmed',
            jsonb_build_object('invoice_id', p_invoice_id, 'transaction_code', v_txn_code)
        );
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'invoice_id', p_invoice_id,
        'transaction_code', v_txn_code,
        'status', 'paid',
        'message', 'Đã xác nhận thu tiền thành công'
    );
END;
$$;

REVOKE ALL ON FUNCTION public.record_manual_payment(UUID, VARCHAR, TEXT) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.record_manual_payment(UUID, VARCHAR, TEXT) TO authenticated;

-- ------------------------------------------------------------------------------
-- 6. RPC CHUẨN: validate_monthly_bulk_invoices
-- Bổ sung kiểm tra quyền is_admin_or_accountant()
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.validate_monthly_bulk_invoices(
  p_period text,
  p_mgmt_rate numeric default 16500,
  p_electric_rate numeric default 3500,
  p_water_rate numeric default 18000
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_total_scanned integer := 0;
  v_valid_count integer := 0;
  v_missing_count integer := 0;
  v_already_invoiced_count integer := 0;
  v_total_estimated_amount numeric := 0;
  
  v_issues jsonb := '[]'::jsonb;
  v_valid_items jsonb := '[]'::jsonb;
  
  v_apt record;
  v_sub_record record;
  v_prev_sub record;
  
  v_cur_elec numeric;
  v_cur_water numeric;
  v_old_elec numeric;
  v_old_water numeric;
  v_elec_usage numeric;
  v_water_usage numeric;

  v_mgmt_fee numeric;
  v_parking_fee numeric;
  v_elec_fee numeric;
  v_water_fee numeric;
  v_apt_total numeric;
  v_motorbike_count integer;
  v_car_count integer;
  v_issue_found boolean;
BEGIN
  IF NOT public.is_admin_or_accountant() THEN
    RAISE EXCEPTION 'Chỉ Quản trị viên hoặc Kế toán mới có quyền đọc trước dữ liệu tính phí toàn tòa nhà';
  END IF;

  FOR v_apt IN
    SELECT id, code, area, electric_reading, water_reading
    FROM public.apartments
    WHERE is_empty = false
    ORDER BY code ASC
  LOOP
    v_total_scanned := v_total_scanned + 1;
    v_issue_found := false;

    -- Kiểm tra hóa đơn đã tồn tại cho kỳ này
    IF EXISTS (
      SELECT 1 FROM public.invoices 
      WHERE apartment_id = v_apt.id AND period = p_period
    ) THEN
      v_already_invoiced_count := v_already_invoiced_count + 1;
      v_issues := v_issues || jsonb_build_object(
        'apartment_id', v_apt.id,
        'apartment_code', v_apt.code,
        'type', 'already_invoiced',
        'message', 'Đã tồn tại hóa đơn cho kỳ ' || p_period
      );
      CONTINUE;
    END IF;

    -- Tìm bản ghi chỉ số đã duyệt
    SELECT * INTO v_sub_record
    FROM public.meter_reading_submissions
    WHERE apartment_id = v_apt.id AND period = p_period AND status = 'approved'
    ORDER BY created_at DESC
    LIMIT 1;

    IF FOUND THEN
      v_cur_elec := v_sub_record.electric_reading;
      v_cur_water := v_sub_record.water_reading;

      SELECT * INTO v_prev_sub
      FROM public.meter_reading_submissions
      WHERE apartment_id = v_apt.id 
        AND status = 'approved'
        AND period <> p_period
        AND created_at < v_sub_record.created_at
      ORDER BY created_at DESC
      LIMIT 1;

      IF FOUND THEN
        v_old_elec := v_prev_sub.electric_reading;
        v_old_water := v_prev_sub.water_reading;
      ELSE
        IF v_apt.electric_reading IS NOT NULL AND v_apt.electric_reading < v_cur_elec THEN
          v_old_elec := v_apt.electric_reading;
        ELSE
          v_old_elec := 0;
        END IF;
        IF v_apt.water_reading IS NOT NULL AND v_apt.water_reading < v_cur_water THEN
          v_old_water := v_apt.water_reading;
        ELSE
          v_old_water := 0;
        END IF;
      END IF;

      v_elec_usage := GREATEST(0, v_cur_elec - v_old_elec);
      v_water_usage := GREATEST(0, v_cur_water - v_old_water);
    ELSE
      v_cur_elec := v_apt.electric_reading;
      v_cur_water := v_apt.water_reading;
      v_old_elec := v_apt.electric_reading;
      v_old_water := v_apt.water_reading;
      v_elec_usage := 0;
      v_water_usage := 0;
    END IF;

    -- Kiểm tra thiếu dữ liệu
    IF v_cur_elec IS NULL AND v_cur_water IS NULL THEN
      v_missing_count := v_missing_count + 1;
      v_issues := v_issues || jsonb_build_object(
        'apartment_id', v_apt.id,
        'apartment_code', v_apt.code,
        'type', 'missing_data',
        'message', 'Chưa có chỉ số điện và nước cho kỳ ' || p_period
      );
      v_issue_found := true;
    ELSIF v_cur_elec IS NULL THEN
      v_missing_count := v_missing_count + 1;
      v_issues := v_issues || jsonb_build_object(
        'apartment_id', v_apt.id,
        'apartment_code', v_apt.code,
        'type', 'missing_data',
        'message', 'Chưa có chỉ số điện cho kỳ ' || p_period
      );
      v_issue_found := true;
    ELSIF v_cur_water IS NULL THEN
      v_missing_count := v_missing_count + 1;
      v_issues := v_issues || jsonb_build_object(
        'apartment_id', v_apt.id,
        'apartment_code', v_apt.code,
        'type', 'missing_data',
        'message', 'Chưa có chỉ số nước cho kỳ ' || p_period
      );
      v_issue_found := true;
    END IF;

    IF v_issue_found THEN
      CONTINUE;
    END IF;

    IF v_elec_usage < 0 OR v_water_usage < 0 THEN
      v_issues := v_issues || jsonb_build_object(
        'apartment_id', v_apt.id,
        'apartment_code', v_apt.code,
        'type', 'invalid_reading',
        'message', 'Chỉ số tiêu thụ điện hoặc nước không hợp lệ (nhỏ hơn 0)'
      );
      CONTINUE;
    END IF;

    -- Tính các khoản phí
    v_mgmt_fee := ROUND(COALESCE(v_apt.area, 70) * p_mgmt_rate);

    SELECT 
      COUNT(*) FILTER (WHERE vehicle_type = 'motorbike'),
      COUNT(*) FILTER (WHERE vehicle_type = 'car')
    INTO v_motorbike_count, v_car_count
    FROM public.vehicles
    WHERE apartment_id = v_apt.id AND status = 'approved';

    IF (COALESCE(v_motorbike_count, 0) + COALESCE(v_car_count, 0)) = 0 THEN
      v_parking_fee := 0;
    ELSE
      v_parking_fee := (COALESCE(v_motorbike_count, 0) * 100000) + (COALESCE(v_car_count, 0) * 1200000);
    END IF;

    v_elec_fee := ROUND(v_elec_usage * p_electric_rate);
    v_water_fee := ROUND(v_water_usage * p_water_rate);
    v_apt_total := v_mgmt_fee + v_parking_fee + v_elec_fee + v_water_fee;

    v_valid_count := v_valid_count + 1;
    v_total_estimated_amount := v_total_estimated_amount + v_apt_total;

    v_valid_items := v_valid_items || jsonb_build_object(
      'apartment_id', v_apt.id,
      'apartment_code', v_apt.code,
      'area', COALESCE(v_apt.area, 70),
      'electric_reading_old', COALESCE(v_old_elec, 0),
      'electric_reading_new', COALESCE(v_cur_elec, 0),
      'electric_usage', v_elec_usage,
      'water_reading_old', COALESCE(v_old_water, 0),
      'water_reading_new', COALESCE(v_cur_water, 0),
      'water_usage', v_water_usage,
      'motorbike_count', COALESCE(v_motorbike_count, 0),
      'car_count', COALESCE(v_car_count, 0),
      'total_amount', v_apt_total
    );
  END LOOP;

  RETURN jsonb_build_object(
    'period', p_period,
    'total_scanned', v_total_scanned,
    'valid_count', v_valid_count,
    'missing_count', v_missing_count,
    'already_invoiced_count', v_already_invoiced_count,
    'total_estimated_amount', v_total_estimated_amount,
    'issues', v_issues,
    'valid_items', v_valid_items
  );
END;
$$;

REVOKE ALL ON FUNCTION public.validate_monthly_bulk_invoices(TEXT, NUMERIC, NUMERIC, NUMERIC) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.validate_monthly_bulk_invoices(TEXT, NUMERIC, NUMERIC, NUMERIC) TO authenticated;

-- ------------------------------------------------------------------------------
-- 7. RPC CHUẨN: create_invoice_with_items
-- Tạo hóa đơn đơn lẻ với status = 'unpaid'
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.create_invoice_with_items(
    p_apartment_id UUID,
    p_period VARCHAR,
    p_due_date DATE,
    p_items JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_invoice_id UUID;
    v_total NUMERIC := 0;
    v_item JSONB;
    v_fee_type VARCHAR;
    v_unit_price NUMERIC;
    v_quantity NUMERIC;
    v_apt_code VARCHAR;
    v_res RECORD;
BEGIN
    IF NOT public.is_admin_or_accountant() THEN
        RAISE EXCEPTION 'Chỉ Quản trị viên hoặc Kế toán mới có quyền lập hóa đơn';
    END IF;

    SELECT code INTO v_apt_code FROM public.apartments WHERE id = p_apartment_id;
    IF v_apt_code IS NULL THEN
        RAISE EXCEPTION 'Căn hộ không tồn tại';
    END IF;

    INSERT INTO public.invoices (
        apartment_id,
        period,
        due_date,
        total_amount,
        status,
        created_at,
        updated_at
    ) VALUES (
        p_apartment_id,
        p_period,
        p_due_date,
        0,
        'unpaid',
        now(),
        now()
    ) RETURNING id INTO v_invoice_id;

    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_fee_type := v_item->>'fee_type';
        v_unit_price := (v_item->>'unit_price')::NUMERIC;
        v_quantity := COALESCE((v_item->>'quantity')::NUMERIC, 1);

        v_total := v_total + (v_unit_price * v_quantity);

        INSERT INTO public.invoice_items (
            invoice_id,
            fee_type,
            unit_price,
            quantity
        ) VALUES (
            v_invoice_id,
            v_fee_type,
            v_unit_price,
            v_quantity
        );
    END LOOP;

    UPDATE public.invoices
    SET total_amount = v_total
    WHERE id = v_invoice_id;

    FOR v_res IN
        SELECT user_id FROM public.residents_apartments WHERE apartment_id = p_apartment_id
    LOOP
        INSERT INTO public.notifications (
            user_id,
            apartment_id,
            title,
            body,
            type,
            payload
        ) VALUES (
            v_res.user_id,
            p_apartment_id,
            'Hóa đơn dịch vụ mới kỳ ' || p_period,
            'Căn hộ ' || v_apt_code || ' có hóa đơn mới trị giá ' || to_char(v_total, 'FM999,999,999') || ' đ.',
            'invoice_created',
            jsonb_build_object('invoice_id', v_invoice_id, 'period', p_period, 'total_amount', v_total)
        );
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'invoice_id', v_invoice_id,
        'total_amount', v_total
    );
END;
$$;

REVOKE ALL ON FUNCTION public.create_invoice_with_items(UUID, VARCHAR, DATE, JSONB) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_invoice_with_items(UUID, VARCHAR, DATE, JSONB) TO authenticated;

-- ------------------------------------------------------------------------------
-- 8. DỌN DẸP TRIGGER TRÙNG LẶP & SIẾT QUYỀN
-- ------------------------------------------------------------------------------
-- Dọn dẹp trigger sự cố cũ trên issue_reports
DROP TRIGGER IF EXISTS trg_notify_on_issue_status_change ON public.issue_reports;
DROP TRIGGER IF EXISTS trg_notify_on_issue_lifecycle ON public.issue_reports;

-- Dọn dẹp trigger bảo trì thiết bị cũ trên equipment_maintenance_tasks
DROP TRIGGER IF EXISTS trg_notify_equipment_task_status ON public.equipment_maintenance_tasks;

-- Siết quyền hàm xem lịch tiện ích (kiểm tra an toàn nếu hàm có tồn tại trong CSDL)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_proc p 
        JOIN pg_namespace n ON p.pronamespace = n.oid 
        WHERE n.nspname = 'public' AND p.proname = 'get_amenity_bookings'
    ) THEN
        EXECUTE 'REVOKE ALL ON FUNCTION public.get_amenity_bookings(UUID, DATE) FROM PUBLIC, anon;';
        EXECUTE 'GRANT EXECUTE ON FUNCTION public.get_amenity_bookings(UUID, DATE) TO authenticated;';
    END IF;
END $$;

