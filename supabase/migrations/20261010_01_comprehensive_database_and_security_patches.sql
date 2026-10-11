-- ==============================================================================
-- Migration: 20261010_01_comprehensive_database_and_security_patches.sql
-- Mô tả: Bản vá toàn diện lỗi CSDL, RPC, Trigger, RLS và Phân quyền Least Privilege
-- ==============================================================================

-- 1. BỔ SUNG CỘT CÒN THIẾU TRONG CSDL
-- ------------------------------------------------------------------------------
ALTER TABLE public.amenity_bookings ADD COLUMN IF NOT EXISTS checked_in_at TIMESTAMPTZ;
ALTER TABLE public.vehicles ADD COLUMN IF NOT EXISTS rejection_reason TEXT;

-- 2. HỦY TOÀN BỘ CÁC CHỮ KÝ OVERLOAD / HÀM CŨ ĐỂ DỌN SẠCH CSDL
-- ------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.book_amenity_slot(UUID, UUID, DATE, VARCHAR, INT, BOOLEAN);
DROP FUNCTION IF EXISTS public.book_amenity_slot(UUID, DATE, VARCHAR, INT, TEXT);

DROP FUNCTION IF EXISTS public.simulate_unified_payment(VARCHAR, UUID, VARCHAR);
DROP FUNCTION IF EXISTS public.simulate_unified_payment(TEXT, UUID, TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.simulate_unified_payment(VARCHAR, UUID, VARCHAR, VARCHAR, TEXT);

DROP FUNCTION IF EXISTS public.simulate_invoice_payment(UUID, VARCHAR);
DROP FUNCTION IF EXISTS public.simulate_invoice_payment(UUID);

DROP FUNCTION IF EXISTS public.generate_monthly_bulk_invoices(TEXT, TIMESTAMPTZ, NUMERIC, NUMERIC, NUMERIC);
DROP FUNCTION IF EXISTS public.generate_monthly_bulk_invoices(TEXT, DATE, NUMERIC, NUMERIC, NUMERIC);

DROP FUNCTION IF EXISTS public.generate_valid_bulk_invoices(TEXT, TIMESTAMPTZ, NUMERIC, NUMERIC, NUMERIC, UUID[]);
DROP FUNCTION IF EXISTS public.generate_valid_bulk_invoices(TEXT, DATE, NUMERIC, NUMERIC, NUMERIC);

DROP FUNCTION IF EXISTS public.reject_meter_reading(UUID, TEXT);
DROP FUNCTION IF EXISTS public.reject_meter_reading(UUID);

DROP FUNCTION IF EXISTS public.approve_meter_reading(UUID);
DROP FUNCTION IF EXISTS public.check_in_amenity_booking(UUID);

DROP FUNCTION IF EXISTS public.record_manual_payment(UUID, VARCHAR, TEXT);
DROP FUNCTION IF EXISTS public.record_manual_payment(UUID);

DROP FUNCTION IF EXISTS public.create_invoice_with_items(UUID, VARCHAR, DATE, JSONB);
DROP FUNCTION IF EXISTS public.update_invoice_with_items(UUID, VARCHAR, DATE, JSONB, UUID, VARCHAR);

DROP FUNCTION IF EXISTS public.validate_monthly_bulk_invoices(TEXT, NUMERIC, NUMERIC, NUMERIC);
DROP FUNCTION IF EXISTS public.validate_monthly_bulk_invoices(TEXT, DATE, NUMERIC, NUMERIC, NUMERIC);

-- 3. ĐẢM BẢO HÀM KIỂM TRA VAI TRÒ ADMIN / KẾ TOÁN TỒN TẠI
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_admin_or_accountant()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.users
    WHERE id = auth.uid() AND role IN ('admin', 'management', 'accountant')
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. BẢO VỆ CỘT NHẠY CẢM TRÊN BẢNG USERS (CHO PHÉP SEED/MIGRATION KHI auth.uid() NULL)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.protect_user_sensitive_fields()
RETURNS TRIGGER AS $$
DECLARE
  v_caller_role public.user_role;
BEGIN
  -- Khi chạy từ script bảo trì hệ thống / migration / seed data (auth.uid() IS NULL) -> Cho phép
  IF auth.uid() IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
  
  IF v_caller_role IS NULL OR v_caller_role NOT IN ('admin', 'management') THEN
    IF OLD.is_locked IS DISTINCT FROM NEW.is_locked THEN
      RAISE EXCEPTION 'Bạn không có quyền thay đổi trạng thái khóa tài khoản';
    END IF;
    IF OLD.role IS DISTINCT FROM NEW.role THEN
      RAISE EXCEPTION 'Bạn không có quyền thay đổi vai trò hệ thống';
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_catalog;

DROP TRIGGER IF EXISTS trg_protect_user_sensitive_fields ON public.users;
CREATE TRIGGER trg_protect_user_sensitive_fields
  BEFORE UPDATE ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION public.protect_user_sensitive_fields();

-- 5. SỬA RPC DUYỆT & TỪ CHỐI CHỈ SỐ ĐỒNG HỒ (approve_meter_reading & reject_meter_reading)
-- Chỉ Admin hoặc Kế toán mới có quyền duyệt/từ chối và lập hóa đơn tài chính (Least Privilege)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.reject_meter_reading(
    p_submission_id UUID,
    p_reason TEXT DEFAULT 'Chỉ số không hợp lệ hoặc ảnh mờ'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
BEGIN
    IF NOT public.is_admin_or_accountant() THEN
        RAISE EXCEPTION 'Chỉ Quản trị viên hoặc Kế toán mới có quyền từ chối chỉ số đồng hồ';
    END IF;

    UPDATE public.meter_reading_submissions
    SET status = 'rejected',
        reject_reason = p_reason,
        reviewed_by = auth.uid(),
        reviewed_at = now(),
        updated_at = now()
    WHERE id = p_submission_id AND status = 'pending';

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Bản ghi không tồn tại hoặc đã được xử lý trước đó';
    END IF;

    RETURN jsonb_build_object('success', true, 'submission_id', p_submission_id, 'status', 'rejected');
END;
$$;

CREATE OR REPLACE FUNCTION public.approve_meter_reading(
    p_submission_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_sub RECORD;
    v_area NUMERIC;
    v_old_elec NUMERIC;
    v_old_water NUMERIC;
    v_elec_diff NUMERIC;
    v_water_diff NUMERIC;
    v_mgmt_fee NUMERIC;
    v_motorbike_count INT;
    v_car_count INT;
    v_parking_fee NUMERIC;
    v_total_amount NUMERIC;
    v_invoice_id UUID;
BEGIN
    -- Chỉ Admin hoặc Kế toán có quyền duyệt và sinh hóa đơn tài chính
    IF NOT public.is_admin_or_accountant() THEN
        RAISE EXCEPTION 'Chỉ Quản trị viên hoặc Kế toán mới có quyền duyệt chỉ số và lập hóa đơn';
    END IF;

    SELECT * INTO v_sub FROM public.meter_reading_submissions WHERE id = p_submission_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Bản ghi chỉ số không tồn tại: %', p_submission_id;
    END IF;

    IF v_sub.status <> 'pending' THEN
        RAISE EXCEPTION 'Bản ghi chỉ số đã được xử lý trước đó (Trạng thái: %)', v_sub.status;
    END IF;

    SELECT area, COALESCE(electric_reading, 0), COALESCE(water_reading, 0)
    INTO v_area, v_old_elec, v_old_water
    FROM public.apartments
    WHERE id = v_sub.apartment_id;

    v_elec_diff := GREATEST(0, v_sub.electric_reading - v_old_elec);
    v_water_diff := GREATEST(0, v_sub.water_reading - v_old_water);
    v_mgmt_fee := ROUND(COALESCE(v_area, 70) * 16500);

    -- Đếm số xe approved của căn hộ (nếu 0 xe thì phí = 0đ)
    SELECT 
        COUNT(*) FILTER (WHERE vehicle_type = 'motorbike'),
        COUNT(*) FILTER (WHERE vehicle_type = 'car')
    INTO v_motorbike_count, v_car_count
    FROM public.vehicles
    WHERE apartment_id = v_sub.apartment_id AND status = 'approved';

    IF (v_motorbike_count + v_car_count) = 0 THEN
        v_parking_fee := 0;
    ELSE
        v_parking_fee := (v_motorbike_count * 100000) + (v_car_count * 1200000);
    END IF;

    v_total_amount := v_mgmt_fee + v_parking_fee + (v_elec_diff * 3500) + (v_water_diff * 18000);

    -- 1. Cập nhật chỉ số mới vào bảng apartments
    UPDATE public.apartments
    SET electric_reading = v_sub.electric_reading,
        water_reading = v_sub.water_reading,
        updated_at = now()
    WHERE id = v_sub.apartment_id;

    -- 2. Đánh dấu bản ghi nộp chỉ số là approved
    UPDATE public.meter_reading_submissions
    SET status = 'approved',
        reviewed_by = auth.uid(),
        reviewed_at = now(),
        updated_at = now()
    WHERE id = p_submission_id;

    -- 3. Tạo hóa đơn tương ứng (nếu chưa có cho kỳ này)
    IF NOT EXISTS (
        SELECT 1 FROM public.invoices WHERE apartment_id = v_sub.apartment_id AND period = v_sub.period
    ) THEN
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
            CURRENT_DATE + INTERVAL '10 days',
            v_total_amount,
            'pending',
            now(),
            now()
        ) RETURNING id INTO v_invoice_id;

        -- Hạng mục phí quản lý
        INSERT INTO public.invoice_items (invoice_id, fee_type, unit_price, quantity)
        VALUES (v_invoice_id, 'Phí quản lý vận hành', 16500, COALESCE(v_area, 70));

        -- Hạng mục gửi xe (nếu có xe)
        IF v_parking_fee > 0 THEN
            IF v_motorbike_count > 0 THEN
                INSERT INTO public.invoice_items (invoice_id, fee_type, unit_price, quantity)
                VALUES (v_invoice_id, 'Phí gửi xe máy', 100000, v_motorbike_count);
            END IF;
            IF v_car_count > 0 THEN
                INSERT INTO public.invoice_items (invoice_id, fee_type, unit_price, quantity)
                VALUES (v_invoice_id, 'Phí gửi ô tô', 1200000, v_car_count);
            END IF;
        END IF;

        -- Hạng mục điện nước
        IF v_elec_diff > 0 THEN
            INSERT INTO public.invoice_items (invoice_id, fee_type, unit_price, quantity)
            VALUES (v_invoice_id, 'Tiền điện', 3500, v_elec_diff);
        END IF;

        IF v_water_diff > 0 THEN
            INSERT INTO public.invoice_items (invoice_id, fee_type, unit_price, quantity)
            VALUES (v_invoice_id, 'Tiền nước', 18000, v_water_diff);
        END IF;
    END IF;

    RETURN jsonb_build_object('success', true, 'submission_id', p_submission_id, 'status', 'approved');
END;
$$;

-- 6. SỬA RPC CHECK-IN TIỆN ÍCH (DÙNG CỘT checked_in_at)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.check_in_amenity_booking(p_booking_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_booking RECORD;
BEGIN
  IF NOT public.is_staff() THEN
    RAISE EXCEPTION 'Chỉ nhân sự Ban Quản Lý mới có quyền xác nhận check-in tiện ích';
  END IF;

  SELECT * INTO v_booking FROM public.amenity_bookings WHERE id = p_booking_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Lượt đặt tiện ích không tồn tại: %', p_booking_id;
  END IF;

  IF v_booking.status = 'completed' THEN
    RETURN jsonb_build_object('success', false, 'message', 'Lượt đặt này đã được check-in trước đó');
  END IF;

  UPDATE public.amenity_bookings
  SET checked_in_at = now(),
      status = 'completed',
      updated_at = now()
  WHERE id = p_booking_id;

  RETURN jsonb_build_object('success', true, 'message', 'Xác nhận check-in thành công', 'booking_id', p_booking_id);
END;
$$;

-- 7. SỬA TRIGGER HỦY LỊCH TIỆN ÍCH (TRUY VẤN ĐÚNG BẢNG building_amenities)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_amenity_booking_cancellation()
RETURNS TRIGGER AS $$
DECLARE
    v_amenity RECORD;
    v_waitlist_rec RECORD;
    v_available_capacity INT;
    v_current_confirmed_count INT;
BEGIN
    IF OLD.status <> 'cancelled' AND NEW.status = 'cancelled' THEN
        -- Truy vấn đúng bảng building_amenities
        SELECT * INTO v_amenity FROM public.building_amenities WHERE id = NEW.amenity_id;
        IF NOT FOUND THEN RETURN NEW; END IF;

        IF v_amenity.booking_type = 'per_slot' THEN
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
            SELECT id, booked_by, guests_count
            FROM public.amenity_bookings
            WHERE amenity_id = NEW.amenity_id
              AND booking_date = NEW.booking_date
              AND time_slot = NEW.time_slot
              AND status = 'waitlist'
              AND guests_count <= v_available_capacity
            ORDER BY created_at ASC
            FOR UPDATE SKIP LOCKED
        LOOP
            UPDATE public.amenity_bookings
            SET status = 'pending_payment',
                updated_at = now()
            WHERE id = v_waitlist_rec.id;

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

DROP TRIGGER IF EXISTS trg_amenity_booking_cancellation ON public.amenity_bookings;
CREATE TRIGGER trg_amenity_booking_cancellation
    AFTER UPDATE OF status ON public.amenity_bookings
    FOR EACH ROW
    WHEN (OLD.status IS DISTINCT FROM NEW.status AND NEW.status = 'cancelled')
    EXECUTE FUNCTION public.handle_amenity_booking_cancellation();

-- 8. SỬA TRIGGER BẢO VỆ ĐẶT CHỖ CHO CƯ DÂN (HỖ TRỢ THANH TOÁN & ĐÔN WAITLIST)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.check_amenity_booking_resident_update()
RETURNS TRIGGER AS $$
BEGIN
  IF NOT public.is_staff_or_management() THEN
    -- Cư dân được phép:
    -- - Hủy lịch (cancelled)
    -- - Xác nhận đặt chỗ / thanh toán thành công (pending, pending_payment, waitlist -> confirmed)
    -- - Đôn waitlist (waitlist -> pending_payment)
    IF NOT (
      NEW.status = 'cancelled' OR
      (NEW.status = 'confirmed' AND OLD.status IN ('pending', 'pending_payment', 'waitlist')) OR
      (NEW.status = 'pending_payment' AND OLD.status = 'waitlist')
    ) THEN
      RAISE EXCEPTION 'Cư dân chỉ được phép hủy lịch hoặc hoàn tất thanh toán đặt chỗ tiện ích';
    END IF;

    -- Bảo vệ toàn vẹn các cột nhạy cảm khác
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

DROP TRIGGER IF EXISTS trg_check_amenity_booking_resident_update ON public.amenity_bookings;
CREATE TRIGGER trg_check_amenity_booking_resident_update
  BEFORE UPDATE ON public.amenity_bookings
  FOR EACH ROW
  EXECUTE FUNCTION public.check_amenity_booking_resident_update();

-- 9. SỬA RPC ĐẶT TIỆN ÍCH book_amenity_slot (DÙNG building_amenities VÀ MÚI GIỜ CHUẨN)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.book_amenity_slot(
    p_amenity_id UUID,
    p_booking_date DATE,
    p_time_slot VARCHAR,
    p_guests_count INT DEFAULT 1,
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_amenity RECORD;
    v_total_guests INT;
    v_booking_id UUID;
    v_status VARCHAR;
    v_today DATE;
    v_resident_apt UUID;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Yêu cầu đăng nhập để thực hiện đặt chỗ';
    END IF;

    -- Lấy căn hộ liên kết của cư dân
    SELECT apartment_id INTO v_resident_apt
    FROM public.residents_apartments
    WHERE user_id = auth.uid()
    LIMIT 1;

    -- Lấy ngày hôm nay theo múi giờ Việt Nam
    v_today := (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date;
    IF p_booking_date < v_today THEN
        RAISE EXCEPTION 'Không thể đặt lịch cho ngày trong quá khứ';
    END IF;

    -- Truy vấn đúng bảng building_amenities
    SELECT * INTO v_amenity FROM public.building_amenities WHERE id = p_amenity_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Tiện ích không tồn tại';
    END IF;

    IF NOT v_amenity.is_active THEN
        RAISE EXCEPTION 'Tiện ích này hiện đang tạm ngưng phục vụ';
    END IF;

    IF v_amenity.booking_type = 'per_slot' THEN
        SELECT COUNT(*) INTO v_total_guests
        FROM public.amenity_bookings
        WHERE amenity_id = p_amenity_id
          AND booking_date = p_booking_date
          AND time_slot = p_time_slot
          AND status IN ('confirmed', 'completed');

        IF v_total_guests > 0 THEN
            v_status := 'waitlist';
        ELSE
            v_status := CASE WHEN COALESCE(v_amenity.price_per_slot, 0) > 0 THEN 'pending_payment' ELSE 'confirmed' END;
        END IF;
    ELSE
        SELECT COALESCE(SUM(guests_count), 0) INTO v_total_guests
        FROM public.amenity_bookings
        WHERE amenity_id = p_amenity_id
          AND booking_date = p_booking_date
          AND time_slot = p_time_slot
          AND status IN ('confirmed', 'completed');

        IF (v_total_guests + p_guests_count) > v_amenity.max_capacity THEN
            v_status := 'waitlist';
        ELSE
            v_status := CASE WHEN COALESCE(v_amenity.price_per_slot, 0) > 0 THEN 'pending_payment' ELSE 'confirmed' END;
        END IF;
    END IF;

    INSERT INTO public.amenity_bookings (
        amenity_id,
        booked_by,
        apartment_id,
        booking_date,
        time_slot,
        guests_count,
        status,
        fee_amount,
        notes,
        created_at,
        updated_at
    ) VALUES (
        p_amenity_id,
        auth.uid(),
        v_resident_apt,
        p_booking_date,
        p_time_slot,
        p_guests_count,
        v_status,
        COALESCE(v_amenity.price_per_slot, 0),
        p_notes,
        now(),
        now()
    ) RETURNING id INTO v_booking_id;

    RETURN jsonb_build_object(
        'success', true,
        'booking_id', v_booking_id,
        'status', v_status,
        'is_waitlist', (v_status = 'waitlist')
    );
END;
$$;

-- 10. SỬA RPC THANH TOÁN ĐỒNG BỘ simulate_unified_payment (KHÔNG DÙNG CỘT LẠ)
-- ------------------------------------------------------------------------------
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
  v_user_role VARCHAR;
  v_apt_id UUID;
  v_amount NUMERIC(12, 2);
  v_tx_id UUID;
  v_tx_code VARCHAR;
  v_title TEXT;
  v_clean_type VARCHAR := upper(p_type);
  v_clean_outcome VARCHAR := upper(p_outcome);
  v_inv_status VARCHAR;
  v_booking_user UUID;
  v_booking_status VARCHAR;
BEGIN
  -- 1. Bắt buộc đăng nhập
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Yêu cầu đăng nhập để thực hiện thanh toán';
  END IF;

  -- 2. Kiểm tra loại thanh toán & kết quả hợp lệ
  IF v_clean_type NOT IN ('INVOICE', 'SERVICE') THEN
    RAISE EXCEPTION 'Loại thanh toán không hợp lệ (chỉ hỗ trợ INVOICE hoặc SERVICE): %', p_type;
  END IF;

  IF v_clean_outcome NOT IN ('SUCCESS', 'FAILED') THEN
    RAISE EXCEPTION 'Kết quả thanh toán không hợp lệ (chỉ hỗ trợ SUCCESS hoặc FAILED): %', p_outcome;
  END IF;

  SELECT role INTO v_user_role FROM public.users WHERE id = v_user_id;

  v_tx_code := 'SIM-' || to_char(clock_timestamp(), 'YYYYMMDDHH24MISSMS') || '-' || upper(substr(gen_random_uuid()::text, 1, 6));

  -- 3. Xử lý nhánh INVOICE
  IF v_clean_type = 'INVOICE' THEN
    SELECT apartment_id, total_amount, status INTO v_apt_id, v_amount, v_inv_status
    FROM public.invoices
    WHERE id = p_reference_id FOR UPDATE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Hóa đơn không tồn tại: %', p_reference_id;
    END IF;

    -- Kiểm tra trạng thái hóa đơn
    IF v_inv_status = 'paid' THEN
      RAISE EXCEPTION 'Hóa đơn này đã được thanh toán trước đó';
    END IF;
    IF v_inv_status = 'cancelled' THEN
      RAISE EXCEPTION 'Hóa đơn này đã bị hủy, không thể thanh toán';
    END IF;

    -- Kiểm soát phân quyền: Chỉ cư dân của căn hộ hoặc Admin/Manager mới được thanh toán
    IF COALESCE(v_user_role, 'resident') NOT IN ('admin', 'manager') THEN
      IF NOT EXISTS (
        SELECT 1 FROM public.residents_apartments 
        WHERE apartment_id = v_apt_id AND user_id = v_user_id
      ) THEN
        RAISE EXCEPTION 'Bạn không có quyền thanh toán hóa đơn của căn hộ này';
      END IF;
    END IF;

    v_title := 'Thanh toán hóa đơn tiền phòng/dịch vụ';

    IF v_clean_outcome = 'SUCCESS' THEN
      UPDATE public.invoices
      SET status = 'paid',
          payment_method = p_payment_method,
          transaction_code = v_tx_code,
          paid_at = now(),
          updated_at = now()
      WHERE id = p_reference_id;
    END IF;

    INSERT INTO public.payment_transactions (
      transaction_code,
      user_id,
      apartment_id,
      invoice_id,
      amount,
      payment_method,
      type,
      title,
      status,
      failure_reason,
      created_at
    ) VALUES (
      v_tx_code,
      v_user_id,
      v_apt_id,
      p_reference_id,
      v_amount,
      p_payment_method,
      'INVOICE',
      v_title,
      v_clean_outcome,
      CASE WHEN v_clean_outcome = 'FAILED' THEN COALESCE(p_failure_reason, 'Giao dịch mô phỏng thất bại') ELSE NULL END,
      now()
    ) RETURNING id INTO v_tx_id;

  -- 4. Xử lý nhánh SERVICE
  ELSE
    SELECT b.apartment_id, b.user_id, b.status, b.fee_amount, a.name 
    INTO v_apt_id, v_booking_user, v_booking_status, v_amount, v_title
    FROM public.amenity_bookings b
    JOIN public.building_amenities a ON a.id = b.amenity_id
    WHERE b.id = p_reference_id FOR UPDATE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Lượt đặt tiện ích không tồn tại: %', p_reference_id;
    END IF;

    -- Kiểm tra trạng thái lượt đặt
    IF v_booking_status = 'confirmed' THEN
      RAISE EXCEPTION 'Lượt đặt tiện ích này đã được xác nhận/thanh toán trước đó';
    END IF;
    IF v_booking_status IN ('cancelled', 'rejected') THEN
      RAISE EXCEPTION 'Lượt đặt tiện ích này đã bị hủy hoặc từ chối, không thể thanh toán';
    END IF;

    -- Kiểm soát quyền sở hữu: Người đặt, cư dân cùng căn hộ hoặc BQL
    IF COALESCE(v_user_role, 'resident') NOT IN ('admin', 'manager') THEN
      IF v_booking_user != v_user_id AND NOT EXISTS (
        SELECT 1 FROM public.residents_apartments
        WHERE apartment_id = v_apt_id AND user_id = v_user_id
      ) THEN
        RAISE EXCEPTION 'Bạn không có quyền thanh toán cho lượt đặt tiện ích này';
      END IF;
    END IF;

    v_title := 'Thanh toán dịch vụ ' || COALESCE(v_title, 'tiện ích');

    IF v_clean_outcome = 'SUCCESS' THEN
      UPDATE public.amenity_bookings
      SET status = 'confirmed',
          updated_at = now()
      WHERE id = p_reference_id;
    END IF;

    INSERT INTO public.payment_transactions (
      transaction_code,
      user_id,
      apartment_id,
      booking_id,
      amount,
      payment_method,
      type,
      title,
      status,
      failure_reason,
      created_at
    ) VALUES (
      v_tx_code,
      v_user_id,
      v_apt_id,
      p_reference_id,
      v_amount,
      p_payment_method,
      'SERVICE',
      v_title,
      v_clean_outcome,
      CASE WHEN v_clean_outcome = 'FAILED' THEN COALESCE(p_failure_reason, 'Giao dịch mô phỏng thất bại') ELSE NULL END,
      now()
    ) RETURNING id INTO v_tx_id;
  END IF;

  RETURN jsonb_build_object(
    'success', v_clean_outcome = 'SUCCESS',
    'transaction_id', v_tx_id,
    'transaction_code', v_tx_code,
    'status', v_clean_outcome
  );
END;
$$;

-- 11. SỬA RPC THU TIỀN MẶT BQL record_manual_payment (TỰ SINH transaction_code)
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
    v_txn_id UUID;
    v_txn_code VARCHAR(100);
BEGIN
    IF NOT public.is_admin_or_accountant() THEN
        RAISE EXCEPTION 'Bạn không có quyền xác nhận thu tiền';
    END IF;

    SELECT * INTO v_inv FROM public.invoices WHERE id = p_invoice_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Hóa đơn không tồn tại: %', p_invoice_id;
    END IF;

    IF v_inv.status = 'paid' THEN
        RAISE EXCEPTION 'Hóa đơn đã được thanh toán trước đó';
    END IF;

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
        title
    ) VALUES (
        v_txn_code,
        p_invoice_id,
        v_inv.apartment_id,
        v_inv.total_amount,
        p_payment_method,
        'INVOICE',
        'SUCCESS',
        COALESCE(p_notes, 'Thanh toán trực tiếp hóa đơn kỳ ' || v_inv.period)
    ) RETURNING id INTO v_txn_id;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Xác nhận thu tiền thành công',
        'invoice_id', p_invoice_id,
        'transaction_id', v_txn_id,
        'transaction_code', v_txn_code
    );
END;
$$;

-- 12. SỬA RPC validate_monthly_bulk_invoices (TÍNH ĐÚNG LƯỢNG TIÊU THỤ & PHÍ XE)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.validate_monthly_bulk_invoices(
  p_period text,
  p_mgmt_rate numeric DEFAULT 16500,
  p_electric_rate numeric DEFAULT 3500,
  p_water_rate numeric DEFAULT 18000
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_apt RECORD;
  v_total_scanned integer := 0;
  v_valid_count integer := 0;
  v_missing_count integer := 0;
  v_invalid_count integer := 0;
  v_already_invoiced_count integer := 0;
  v_total_estimated_amount numeric := 0;

  v_valid_items jsonb := '[]'::jsonb;
  v_issues jsonb := '[]'::jsonb;

  v_sub_record RECORD;
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
  FOR v_apt IN
    SELECT id, code, area, electric_reading, water_reading
    FROM public.apartments
    WHERE is_empty = false
    ORDER BY code ASC
  LOOP
    v_total_scanned := v_total_scanned + 1;
    v_issue_found := false;

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

    SELECT * INTO v_sub_record
    FROM public.meter_reading_submissions
    WHERE apartment_id = v_apt.id AND period = p_period AND status = 'approved'
    ORDER BY created_at DESC
    LIMIT 1;

    v_old_elec := COALESCE(v_apt.electric_reading, 0);
    v_old_water := COALESCE(v_apt.water_reading, 0);

    IF FOUND THEN
      v_cur_elec := v_sub_record.electric_reading;
      v_cur_water := v_sub_record.water_reading;
      v_elec_usage := GREATEST(0, v_cur_elec - v_old_elec);
      v_water_usage := GREATEST(0, v_cur_water - v_old_water);
    ELSE
      v_cur_elec := v_apt.electric_reading;
      v_cur_water := v_apt.water_reading;
      v_elec_usage := 0;
      v_water_usage := 0;
    END IF;

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

    v_mgmt_fee := ROUND(COALESCE(v_apt.area, 70) * p_mgmt_rate);

    SELECT 
      COUNT(*) FILTER (WHERE vehicle_type = 'motorbike'),
      COUNT(*) FILTER (WHERE vehicle_type = 'car')
    INTO v_motorbike_count, v_car_count
    FROM public.vehicles
    WHERE apartment_id = v_apt.id AND status = 'approved';

    IF (v_motorbike_count + v_car_count) = 0 THEN
      v_parking_fee := 0;
    ELSE
      v_parking_fee := (v_motorbike_count * 100000) + (v_car_count * 1200000);
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
      'electric_reading', v_cur_elec,
      'water_reading', v_cur_water,
      'electric_usage', v_elec_usage,
      'water_usage', v_water_usage,
      'management_fee', v_mgmt_fee,
      'parking_fee', v_parking_fee,
      'electric_fee', v_elec_fee,
      'water_fee', v_water_fee,
      'motorbike_count', v_motorbike_count,
      'car_count', v_car_count,
      'total_amount', v_apt_total,
      'estimated_total', v_apt_total
    );
  END LOOP;

  RETURN jsonb_build_object(
    'period', p_period,
    'total_apartments_scanned', v_total_scanned,
    'total_scanned', v_total_scanned,
    'valid_count', v_valid_count,
    'missing_data_count', v_missing_count,
    'missing_count', v_missing_count,
    'invalid_count', v_invalid_count,
    'already_invoiced_count', v_already_invoiced_count,
    'total_estimated_amount', v_total_estimated_amount,
    'valid_invoices', v_valid_items,
    'valid_items', v_valid_items,
    'issues', v_issues
  );
END;
$$;

-- 13. SỬA RPC TẠO HÓA ĐƠN HÀNG LOẠT generate_valid_bulk_invoices (BỎ CHÈN SUBTOTAL)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.generate_valid_bulk_invoices(
  p_period text,
  p_due_date date,
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
  v_validation jsonb;
  v_results jsonb := '[]'::jsonb;
  v_inv_record record;
  v_new_invoice_id uuid;
  v_total_amount numeric;
  v_created_count integer := 0;
  v_parking_fee numeric;
  v_elec_qty numeric;
  v_water_qty numeric;
BEGIN
  IF NOT public.is_admin_or_accountant() THEN
    RAISE EXCEPTION 'Chỉ Kế toán hoặc Quản trị viên mới có quyền tạo hóa đơn hàng loạt';
  END IF;

  v_validation := public.validate_monthly_bulk_invoices(
    p_period, p_mgmt_rate, p_electric_rate, p_water_rate
  );

  FOR v_inv_record IN 
    SELECT * FROM jsonb_to_recordset(v_validation->'valid_items') AS x(
      apartment_id uuid,
      apartment_code text,
      area numeric,
      electric_reading numeric,
      water_reading numeric,
      electric_usage numeric,
      water_usage numeric,
      motorbike_count integer,
      car_count integer,
      total_amount numeric
    )
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
        'pending',
        now(),
        now()
      ) RETURNING id INTO v_new_invoice_id;

      -- Phí quản lý
      INSERT INTO public.invoice_items (invoice_id, fee_type, unit_price, quantity)
      VALUES (v_new_invoice_id, 'Phí quản lý vận hành', p_mgmt_rate, COALESCE(v_inv_record.area, 70));

      -- Phí gửi xe
      IF v_parking_fee > 0 THEN
        IF COALESCE(v_inv_record.motorbike_count, 0) > 0 THEN
          INSERT INTO public.invoice_items (invoice_id, fee_type, unit_price, quantity)
          VALUES (v_new_invoice_id, 'Phí gửi xe máy', 100000, v_inv_record.motorbike_count);
        END IF;
        IF COALESCE(v_inv_record.car_count, 0) > 0 THEN
          INSERT INTO public.invoice_items (invoice_id, fee_type, unit_price, quantity)
          VALUES (v_new_invoice_id, 'Phí gửi ô tô', 1200000, v_inv_record.car_count);
        END IF;
      END IF;

      -- Điện nước
      IF v_elec_qty > 0 THEN
        INSERT INTO public.invoice_items (invoice_id, fee_type, unit_price, quantity)
        VALUES (v_new_invoice_id, 'Tiền điện', p_electric_rate, v_elec_qty);
      END IF;

      IF v_water_qty > 0 THEN
        INSERT INTO public.invoice_items (invoice_id, fee_type, unit_price, quantity)
        VALUES (v_new_invoice_id, 'Tiền nước', p_water_rate, v_water_qty);
      END IF;

      v_created_count := v_created_count + 1;
      v_results := v_results || jsonb_build_object(
        'apartment_id', v_inv_record.apartment_id,
        'apartment_code', v_inv_record.apartment_code,
        'invoice_id', v_new_invoice_id,
        'total_amount', v_total_amount
      );
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'period', p_period,
    'created_count', v_created_count,
    'total_created', v_created_count,
    'invoices', v_results
  );
END;
$$;

-- 14. KHÔI PHỤC create_invoice_with_items (TÍNH TỔNG TIỀN & GỬI THÔNG BÁO CHO CƯ DÂN)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.create_invoice_with_items(
    p_apartment_id UUID,
    p_period VARCHAR,
    p_due_date DATE,
    p_items JSONB
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_invoice_id UUID;
    v_item JSONB;
    v_total NUMERIC := 0;
    v_apt_code TEXT;
    v_resident RECORD;
BEGIN
    IF NOT public.is_admin_or_accountant() THEN
        RAISE EXCEPTION 'Chỉ Quản trị viên hoặc Kế toán mới có quyền lập hóa đơn';
    END IF;

    -- 1. Tạo hóa đơn gốc
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
        'pending',
        now(),
        now()
    ) RETURNING id INTO v_invoice_id;

    -- 2. Chèn từng hạng mục chi phí (bỏ subtotal vì là cột tự sinh)
    IF p_items IS NOT NULL AND jsonb_array_length(p_items) > 0 THEN
        FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
        LOOP
            INSERT INTO public.invoice_items (
                invoice_id,
                fee_type,
                unit_price,
                quantity
            ) VALUES (
                v_invoice_id,
                v_item->>'fee_type',
                COALESCE((v_item->>'unit_price')::DECIMAL, 0),
                COALESCE((v_item->>'quantity')::DECIMAL, 1)
            );
        END LOOP;
    END IF;

    -- 3. Cập nhật và lấy tổng tiền thực tế
    SELECT COALESCE(SUM(subtotal), 0) INTO v_total
    FROM public.invoice_items
    WHERE invoice_id = v_invoice_id;

    UPDATE public.invoices
    SET total_amount = v_total
    WHERE id = v_invoice_id;

    -- 4. Bắn thông báo thời gian thực đến cư dân của căn hộ
    SELECT code INTO v_apt_code FROM public.apartments WHERE id = p_apartment_id;

    FOR v_resident IN
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
            v_resident.user_id,
            p_apartment_id,
            'Hóa đơn mới kỳ ' || p_period,
            'Căn hộ ' || COALESCE(v_apt_code, 'N/A') || ' vừa nhận được hóa đơn kỳ ' || p_period || 
            ' với tổng tiền ' || to_char(v_total, 'FM999,999,999') || ' đ. Hạn thanh toán: ' || 
            to_char(p_due_date, 'DD/MM/YYYY') || '.',
            'new_invoice',
            jsonb_build_object(
                'invoice_id', v_invoice_id,
                'period', p_period,
                'amount', v_total
            )
        );
    END LOOP;

    RETURN v_invoice_id;
END;
$$;

-- 15. SỬA REGEX PHÂN LOẠI MỨC ĐỘ SỰ CỐ (classify_issue_priority)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.classify_issue_priority()
RETURNS TRIGGER AS $$
DECLARE
  v_desc TEXT;
BEGIN
  IF TG_OP = 'UPDATE' AND NEW.priority IS DISTINCT FROM OLD.priority THEN
    RETURN NEW;
  END IF;

  IF NEW.priority IS NOT NULL AND NEW.priority != 'medium'::public.issue_priority THEN
    RETURN NEW;
  END IF;

  v_desc := lower(coalesce(NEW.description, ''));

  IF v_desc ~* '(bóng đèn|bong den|đèn|den).*(cháy|chay)' OR v_desc ~* '(cháy|chay).*(bóng|bong|đèn|den)' THEN
    NEW.priority := 'low'::public.issue_priority;
    RETURN NEW;
  END IF;

  IF v_desc ~* '(hỏa hoạn|hoa hoan|cháy nhà|chay nha|bốc cháy|boc chay|đám cháy|dam chay|báo cháy|bao chay|khói độc|khoi doc|chập điện|chap dien|rò rỉ gas|ro ri gas|khí gas|khi gas|kẹt thang máy|ket thang may|\ysập\y|\ysap\y|\ynổ\y|\yno\y)' THEN
    NEW.priority := 'high'::public.issue_priority;
  ELSIF v_desc ~* '(bóng đèn|bong den|mạng|mang|wifi|vệ sinh|ve sinh|ồn ào|on ao|rác|rac|cây cảnh|cay canh|sơn tường|son tuong|thẩm mỹ|tham my)' THEN
    NEW.priority := 'low'::public.issue_priority;
  ELSIF v_desc ~* '(rò nước|ro nuoc|rỉ nước|ri nuoc|ngập|ngap|khẩn cấp|khan cap|hỏng khóa|hong khoa|mất điện|mat dien|mất nước|mat nuoc)' THEN
    NEW.priority := 'medium'::public.issue_priority;
  ELSE
    NEW.priority := 'medium'::public.issue_priority;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 16. SIẾT RLS INSERT BẢNG VEHICLES (CHỐNG CƯ DÂN TỰ CHÈN XE STATUS='APPROVED')
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "Cư dân đăng ký xe cho căn hộ mình" ON public.vehicles;
CREATE POLICY "Cư dân đăng ký xe cho căn hộ mình" ON public.vehicles
FOR INSERT WITH CHECK (
    (
        apartment_id IN (
            SELECT apartment_id FROM public.residents_apartments WHERE user_id = auth.uid()
        )
        AND status = 'pending'
        AND rejection_reason IS NULL
    )
    OR public.is_staff()
);

-- 17. PHÂN QUYỀN THỰC THI CHÍNH XÁC KÈM ĐẦY ĐỦ CHỮ KÝ (HARDENED EXECUTE PERMISSIONS)
-- ------------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.approve_meter_reading(UUID) FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public.reject_meter_reading(UUID, TEXT) FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public.validate_monthly_bulk_invoices(TEXT, NUMERIC, NUMERIC, NUMERIC) FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public.generate_valid_bulk_invoices(TEXT, DATE, NUMERIC, NUMERIC, NUMERIC) FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public.check_in_amenity_booking(UUID) FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public.record_manual_payment(UUID, VARCHAR, TEXT) FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public.create_invoice_with_items(UUID, VARCHAR, DATE, JSONB) FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public.simulate_unified_payment(VARCHAR, UUID, VARCHAR, VARCHAR, TEXT) FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public.book_amenity_slot(UUID, DATE, VARCHAR, INT, TEXT) FROM anon, PUBLIC;

GRANT EXECUTE ON FUNCTION public.approve_meter_reading(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.reject_meter_reading(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.validate_monthly_bulk_invoices(TEXT, NUMERIC, NUMERIC, NUMERIC) TO authenticated;
GRANT EXECUTE ON FUNCTION public.generate_valid_bulk_invoices(TEXT, DATE, NUMERIC, NUMERIC, NUMERIC) TO authenticated;
GRANT EXECUTE ON FUNCTION public.check_in_amenity_booking(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_manual_payment(UUID, VARCHAR, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_invoice_with_items(UUID, VARCHAR, DATE, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION public.simulate_unified_payment(VARCHAR, UUID, VARCHAR, VARCHAR, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.book_amenity_slot(UUID, DATE, VARCHAR, INT, TEXT) TO authenticated;
