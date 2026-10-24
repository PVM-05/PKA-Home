-- ==============================================================================
-- Migration: 20261024_04_pending_requests_correction_and_reschedule.sql
-- Mục tiêu: Cung cấp cơ chế sửa sai và hủy an toàn cho cư dân đối với 4 nhóm 
-- nghiệp vụ đang chờ duyệt (Pending), chống Deadlock, Race Condition, bảo toàn
-- tính toàn vẹn tài chính và kiểm toán.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. NÂNG CẤP RÀNG BUỘC CHECK CONSTRAINTS VÀ LƯỢC ĐỒ (SCHEMA HARDENING)
-- ------------------------------------------------------------------------------

-- 1.1 Mở rộng trạng thái bảng public.vehicles hỗ trợ 'cancelled'
ALTER TABLE public.vehicles DROP CONSTRAINT IF EXISTS vehicles_status_check;
ALTER TABLE public.vehicles ADD CONSTRAINT vehicles_status_check 
  CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled'));

-- 1.2 Mở rộng trạng thái bảng public.meter_reading_submissions hỗ trợ 'cancelled'
ALTER TABLE public.meter_reading_submissions DROP CONSTRAINT IF EXISTS meter_reading_submissions_status_check;
ALTER TABLE public.meter_reading_submissions ADD CONSTRAINT meter_reading_submissions_status_check 
  CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled'));

-- 1.3 Chuyển đổi cột status của public.apartment_link_requests sang VARCHAR(20) an toàn
-- Xóa default cũ ràng buộc enum link_request_status
ALTER TABLE public.apartment_link_requests 
  ALTER COLUMN status DROP DEFAULT;

-- Chuyển kiểu dữ liệu sang VARCHAR(20)
ALTER TABLE public.apartment_link_requests 
  ALTER COLUMN status TYPE VARCHAR(20) USING status::text;

-- Gán default mới
ALTER TABLE public.apartment_link_requests 
  ALTER COLUMN status SET DEFAULT 'pending';

-- Áp dụng check constraint mới
ALTER TABLE public.apartment_link_requests DROP CONSTRAINT IF EXISTS apartment_link_requests_status_check;
ALTER TABLE public.apartment_link_requests ADD CONSTRAINT apartment_link_requests_status_check 
  CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled'));

-- Xóa constraint UNIQUE cũ không điều kiện (nếu có)
ALTER TABLE public.apartment_link_requests DROP CONSTRAINT IF EXISTS apartment_link_requests_user_id_apartment_id_key;

-- Cập nhật RLS Policy "Resident tạo yêu cầu" tránh ép kiểu enum cũ
DROP POLICY IF EXISTS "Resident tạo yêu cầu" ON public.apartment_link_requests;
CREATE POLICY "Resident tạo yêu cầu" 
ON public.apartment_link_requests FOR INSERT 
WITH CHECK (user_id = auth.uid() AND status = 'pending');

-- Cập nhật RPC approve_link_request để biến v_status dùng VARCHAR(20) thay vì enum cũ
CREATE OR REPLACE FUNCTION public.approve_link_request(p_request_id UUID)
RETURNS void AS $$
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
  SET status = 'approved',
      updated_at = now()
  WHERE id = p_request_id;

  INSERT INTO public.residents_apartments (user_id, apartment_id, relation_role)
  VALUES (v_user_id, v_apartment_id, v_requested_role)
  ON CONFLICT (user_id, apartment_id) DO NOTHING;

  UPDATE public.apartments
  SET is_empty = false
  WHERE id = v_apartment_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_catalog;

-- 1.4 Dọn dẹp bản ghi trùng lặp lịch sử trước khi tạo Partial Unique Index
-- Ưu tiên giữ lại bản ghi 'approved', nếu cùng trạng thái thì lấy bản ghi mới nhất (created_at DESC).
-- Các bản ghi trùng còn lại được chuyển sang 'cancelled'.
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

-- Thiết lập Partial Unique Index
CREATE UNIQUE INDEX IF NOT EXISTS uq_link_requests_active 
ON public.apartment_link_requests(user_id, apartment_id) 
WHERE status IN ('pending', 'approved');


-- ------------------------------------------------------------------------------
-- 2. RPC PHÂN HỆ PHƯƠNG TIỆN (VEHICLES)
-- ------------------------------------------------------------------------------

-- 2.1 Hủy đăng ký phương tiện đang chờ duyệt (Quyền sở hữu nghiêm ngặt)
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

    -- Kiểm tra trạng thái pending và quyền: chỉ chính người tạo hoặc BQL
    UPDATE public.vehicles
    SET status = 'cancelled',
        updated_at = NOW()
    WHERE id = p_vehicle_id 
      AND status = 'pending'
      AND (
          user_id = v_user_id 
          OR registered_by = v_user_id 
          OR public.is_staff()
      );

    GET DIAGNOSTICS v_updated_count = ROW_COUNT;

    IF v_updated_count = 0 THEN
        RAISE EXCEPTION 'Không tìm thấy phương tiện đang chờ duyệt hoặc bạn không có quyền hủy bản ghi này.';
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Đã hủy đăng ký phương tiện thành công',
        'vehicle_id', p_vehicle_id
    );
END;
$$;

-- 2.2 Chỉnh sửa thông tin phương tiện đang chờ duyệt
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

    -- Kiểm tra bản ghi xe
    SELECT * INTO v_vehicle
    FROM public.vehicles
    WHERE id = p_vehicle_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Phương tiện không tồn tại';
    END IF;

    IF v_vehicle.status != 'pending' THEN
        RAISE EXCEPTION 'Chỉ có thể chỉnh sửa phương tiện đang ở trạng thái chờ duyệt (pending).';
    END IF;

    -- Kiểm tra quyền: chỉ người tạo xe hoặc BQL (không cho phép cư dân cùng căn hộ thao tác chéo)
    IF v_vehicle.user_id != v_user_id 
       AND v_vehicle.registered_by != v_user_id 
       AND NOT public.is_staff() THEN
        RAISE EXCEPTION 'Bạn không có quyền chỉnh sửa thông tin phương tiện này.';
    END IF;

    v_clean_plate := UPPER(TRIM(p_license_plate));
    IF v_clean_plate IS NULL OR v_clean_plate = '' THEN
        RAISE EXCEPTION 'Biển số xe không được để trống.';
    END IF;

    -- Khóa advisory chống Race Condition kiểm tra hạn mức xe theo căn hộ
    PERFORM pg_advisory_xact_lock(hashtext('vehicle_limit_' || v_vehicle.apartment_id::text));

    -- Nếu đổi sang xe máy, kiểm tra hạn mức 2 xe máy đang hoạt động (pending hoặc approved)
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

    -- Cập nhật đồng bộ cả license_plate và plate_number để không bị lệch dữ liệu
    UPDATE public.vehicles
    SET license_plate = v_clean_plate,
        plate_number = v_clean_plate,
        vehicle_type = p_vehicle_type,
        brand_model = TRIM(p_brand_model),
        updated_at = NOW()
    WHERE id = p_vehicle_id AND status = 'pending';

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Cập nhật thông tin phương tiện thành công',
        'vehicle_id', p_vehicle_id
    );
END;
$$;

-- 2.3 Củng cố Trigger kiểm tra hạn mức 2 xe máy cấp CSDL
CREATE OR REPLACE FUNCTION public.check_vehicle_limits()
RETURNS TRIGGER 
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    current_motorbike_count INT;
BEGIN
    -- Chỉ kiểm tra khi là xe máy và bản ghi ở trạng thái hoạt động (pending hoặc approved)
    IF NEW.vehicle_type = 'motorbike' AND NEW.status IN ('pending', 'approved') THEN
        IF NEW.apartment_id IS NULL THEN
            RAISE EXCEPTION 'Căn hộ không hợp lệ (apartment_id không được để trống).';
        END IF;

        -- Khóa dòng căn hộ để tuần tự hóa chống Race Condition đăng ký đồng thời
        PERFORM 1 FROM public.apartments WHERE id = NEW.apartment_id FOR UPDATE;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Không tìm thấy căn hộ tương ứng trong hệ thống.';
        END IF;

        -- Đếm số xe máy active của căn hộ, loại trừ chính bản ghi đang cập nhật
        SELECT count(*) INTO current_motorbike_count
        FROM public.vehicles
        WHERE apartment_id = NEW.apartment_id 
          AND vehicle_type = 'motorbike'
          AND status IN ('pending', 'approved')
          AND id != COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000'::uuid);

        IF current_motorbike_count >= 2 THEN
            RAISE EXCEPTION 'Mỗi căn hộ chỉ được đăng ký tối đa 2 xe máy theo quy định của tòa nhà.';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.check_vehicle_limits() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.check_vehicle_limits() TO authenticated, service_role;

DROP TRIGGER IF EXISTS trg_check_vehicle_limits ON public.vehicles;
CREATE TRIGGER trg_check_vehicle_limits
BEFORE INSERT OR UPDATE ON public.vehicles
FOR EACH ROW EXECUTE FUNCTION public.check_vehicle_limits();


-- ------------------------------------------------------------------------------
-- 3. RPC PHÂN HỆ ĐẶT TIỆN ÍCH (AMENITY BOOKINGS)
-- ------------------------------------------------------------------------------

-- Đổi lịch đặt tiện ích an toàn (Chống Deadlock, Bảo toàn Tài chính & Đôn Waitlist)
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
    v_slot_start_str TEXT;
    v_slot_start_time TIME;
    v_final_guests INT;
    v_current_slot_capacity INT := 0;
    v_is_same_slot BOOLEAN := false;
    v_next_waitlist RECORD;
    v_new_fee NUMERIC;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Bạn chưa đăng nhập vào hệ thống';
    END IF;

    -- 1. Lấy thông tin booking hiện tại
    SELECT * INTO v_booking
    FROM public.amenity_bookings
    WHERE id = p_booking_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Lượt đặt tiện ích không tồn tại';
    END IF;

    -- Kiểm tra quyền
    IF v_booking.booked_by != v_user_id AND NOT public.is_staff() THEN
        RAISE EXCEPTION 'Bạn không có quyền đổi lịch cho lượt đặt tiện ích này.';
    END IF;

    IF v_booking.status NOT IN ('confirmed', 'pending_payment', 'waitlist') THEN
        RAISE EXCEPTION 'Chỉ có thể đổi lịch cho các lượt đặt đang xác nhận, chờ thanh toán hoặc trong hàng đợi.';
    END IF;

    -- 2. Lấy thông tin tiện ích
    SELECT * INTO v_amenity
    FROM public.building_amenities
    WHERE id = v_booking.amenity_id AND is_active = true;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Tiện ích không tồn tại hoặc đã ngừng hoạt động';
    END IF;

    -- 3. Kiểm tra xem slot cũ đã diễn ra hay chưa
    IF v_booking.booking_date < (v_now_vn::date) THEN
        RAISE EXCEPTION 'Lượt đặt tiện ích này đã diễn ra trong quá khứ, không thể đổi lịch.';
    ELSIF v_booking.booking_date = (v_now_vn::date) THEN
        v_slot_start_str := TRIM(SPLIT_PART(v_booking.time_slot, '-', 1));
        BEGIN
            v_slot_start_time := v_slot_start_str::time;
            IF (v_now_vn::time) >= v_slot_start_time THEN
                RAISE EXCEPTION 'Lượt đặt hiện tại (%) đã bắt đầu hoặc đã qua, không thể đổi lịch.', v_booking.time_slot;
            END IF;
        EXCEPTION 
            WHEN invalid_datetime_format THEN NULL;
        END;
    END IF;

    -- 4. Kiểm tra slot mới hợp lệ
    IF p_new_date < (v_now_vn::date) THEN
        RAISE EXCEPTION 'Không thể dời lịch sang ngày trong quá khứ.';
    ELSIF p_new_date = (v_now_vn::date) THEN
        v_slot_start_str := TRIM(SPLIT_PART(p_new_time_slot, '-', 1));
        BEGIN
            v_slot_start_time := v_slot_start_str::time;
            IF (v_now_vn::time) >= v_slot_start_time THEN
                RAISE EXCEPTION 'Khung giờ mới (%) đã bắt đầu hoặc đã qua trong hôm nay.', p_new_time_slot;
            END IF;
        EXCEPTION 
            WHEN invalid_datetime_format THEN NULL;
        END;
    END IF;

    -- Kiểm tra lịch bảo trì định kỳ tại slot mới
    IF EXISTS (
        SELECT 1 FROM public.amenity_maintenance_windows
        WHERE amenity_id = v_booking.amenity_id
          AND p_new_date BETWEEN start_date AND end_date
    ) THEN
        RAISE EXCEPTION 'Tiện ích đang trong thời gian bảo trì vào ngày đã chọn.';
    END IF;

    -- 5. Chống Deadlock: Sắp xếp khóa Advisory theo thứ tự giá trị băm
    v_h_old := hashtext(v_booking.amenity_id::text || '_' || v_booking.booking_date::text || '_' || v_booking.time_slot);
    v_h_new := hashtext(v_booking.amenity_id::text || '_' || p_new_date::text || '_' || p_new_time_slot);
    v_lock1 := LEAST(v_h_old, v_h_new);
    v_lock2 := GREATEST(v_h_old, v_h_new);

    PERFORM pg_advisory_xact_lock(v_lock1);
    IF v_lock1 <> v_lock2 THEN
        PERFORM pg_advisory_xact_lock(v_lock2);
    END IF;

    v_is_same_slot := (v_booking.booking_date = p_new_date AND v_booking.time_slot = p_new_time_slot);

    -- 6. Xác định số khách và tính toàn vẹn tài chính
    IF v_booking.status = 'confirmed' THEN
        -- Đã thanh toán: Khóa cứng số lượng khách để bảo toàn chứng từ kế toán
        v_final_guests := v_booking.guests_count;
    ELSE
        v_final_guests := COALESCE(p_new_guests_count, v_booking.guests_count, 1);
        IF v_final_guests < 1 THEN v_final_guests := 1; END IF;
        IF v_final_guests > v_amenity.max_capacity THEN
            RAISE EXCEPTION 'Số lượng người (% người) vượt quá sức chứa tối đa của tiện ích (% người)', 
                v_final_guests, v_amenity.max_capacity;
        END IF;
    END IF;

    -- 7. Kiểm tra sức chứa tại slot mới (loại trừ chính bản ghi hiện tại)
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
        -- Dạng SHARED: Kiểm tra tổng số khách
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

    -- 8. Điều chỉnh trạng thái và tiền nếu từ waitlist chuyển sang slot trống
    IF v_booking.status = 'waitlist' THEN
        IF COALESCE(v_amenity.fee_amount, 0) > 0 OR COALESCE(v_amenity.deposit_amount, 0) > 0 THEN
            v_booking.status := 'pending_payment';
        ELSE
            v_booking.status := 'confirmed';
        END IF;
    ELSIF v_booking.status = 'pending_payment' AND v_amenity.booking_type = 'shared' THEN
        -- Cập nhật lại phí theo số khách mới
        v_new_fee := COALESCE(v_amenity.fee_amount, 0) * v_final_guests;
        UPDATE public.amenity_bookings
        SET fee_amount = v_new_fee
        WHERE id = p_booking_id;

        -- Đồng bộ số tiền trong payment_transactions PENDING nếu có
        UPDATE public.payment_transactions
        SET amount = (v_new_fee + COALESCE(v_booking.deposit_amount, 0))
        WHERE (booking_id = p_booking_id OR invoice_id = p_booking_id::text)
          AND status = 'PENDING';
    END IF;

    -- 9. Thực hiện cập nhật slot mới cho booking hiện tại
    UPDATE public.amenity_bookings
    SET booking_date = p_new_date,
        time_slot = p_new_time_slot,
        guests_count = v_final_guests,
        notes = COALESCE(p_new_notes, notes),
        status = v_booking.status,
        updated_at = NOW()
    WHERE id = p_booking_id;

    -- 10. Đôn hàng đợi (Waitlist Promotion) cho slot cũ nếu slot thực sự thay đổi
    IF NOT v_is_same_slot THEN
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
            -- Nếu có phí/cọc thì đôn lên pending_payment để họ thanh toán, tuyệt đối không confirmed tự do
            IF COALESCE(v_amenity.fee_amount, 0) > 0 OR COALESCE(v_amenity.deposit_amount, 0) > 0 THEN
                UPDATE public.amenity_bookings
                SET status = 'pending_payment', updated_at = NOW()
                WHERE id = v_next_waitlist.id;
            ELSE
                UPDATE public.amenity_bookings
                SET status = 'confirmed', updated_at = NOW()
                WHERE id = v_next_waitlist.id;
            END IF;
        END IF;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Đổi lịch đặt tiện ích thành công',
        'booking_id', p_booking_id,
        'new_date', p_new_date,
        'new_time_slot', p_new_time_slot,
        'status', v_booking.status
    );
END;
$$;


-- ------------------------------------------------------------------------------
-- 4. RPC PHÂN HỆ CHỈ SỐ ĐIỆN NƯỚC (METER READINGS)
-- ------------------------------------------------------------------------------

-- 4.1 Cập nhật thông tin phiếu gửi chỉ số đang chờ duyệt
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

    -- Kiểm tra quyền sở hữu nghiêm ngặt: chỉ người gửi hoặc BQL
    IF v_sub.submitted_by != v_user_id AND NOT public.is_staff() THEN
        RAISE EXCEPTION 'Bạn không có quyền chỉnh sửa phiếu chỉ số này.';
    END IF;

    -- Xử lý ảnh công tơ rõ ràng
    IF p_clear_electric_image THEN
        v_new_elec_img := NULL;
    ELSIF p_electric_image_url IS NOT NULL THEN
        v_new_elec_img := p_electric_image_url;
    ELSE
        v_new_elec_img := v_sub.electric_image_url; -- Giữ nguyên ảnh cũ
    END IF;

    IF p_clear_water_image THEN
        v_new_water_img := NULL;
    ELSIF p_water_image_url IS NOT NULL THEN
        v_new_water_img := p_water_image_url;
    ELSE
        v_new_water_img := v_sub.water_image_url; -- Giữ nguyên ảnh cũ
    END IF;

    UPDATE public.meter_reading_submissions
    SET electric_reading = p_electric_reading,
        water_reading = p_water_reading,
        electric_image_url = v_new_elec_img,
        water_image_url = v_new_water_img,
        updated_at = NOW()
    WHERE id = p_submission_id AND status = 'pending';

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Đã cập nhật chỉ số điện nước thành công',
        'submission_id', p_submission_id
    );
END;
$$;

-- 4.2 Hủy phiếu khai báo chỉ số đang chờ duyệt
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
    SET status = 'cancelled',
        updated_at = NOW()
    WHERE id = p_submission_id 
      AND status = 'pending'
      AND (
          submitted_by = v_user_id 
          OR public.is_staff()
      );

    GET DIAGNOSTICS v_updated_count = ROW_COUNT;

    IF v_updated_count = 0 THEN
        RAISE EXCEPTION 'Không tìm thấy phiếu chỉ số đang chờ duyệt hoặc bạn không có quyền hủy.';
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Đã hủy phiếu khai báo chỉ số thành công',
        'submission_id', p_submission_id
    );
END;
$$;


-- ------------------------------------------------------------------------------
-- 5. RPC PHÂN HỆ LIÊN KẾT CĂN HỘ (APARTMENT LINK REQUESTS)
-- ------------------------------------------------------------------------------

-- Hủy yêu cầu liên kết căn hộ đang chờ duyệt
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
    SET status = 'cancelled',
        updated_at = NOW()
    WHERE id = p_request_id 
      AND user_id = v_user_id 
      AND status = 'pending';

    GET DIAGNOSTICS v_updated_count = ROW_COUNT;

    IF v_updated_count = 0 THEN
        RAISE EXCEPTION 'Không tìm thấy yêu cầu liên kết đang chờ duyệt để hủy.';
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Đã hủy yêu cầu liên kết căn hộ thành công',
        'request_id', p_request_id
    );
END;
$$;


-- ------------------------------------------------------------------------------
-- 6. PHÂN QUYỀN THỰC THI (RBAC SECURITY GRANTS)
-- ------------------------------------------------------------------------------

REVOKE ALL ON FUNCTION public.cancel_pending_vehicle(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cancel_pending_vehicle(UUID) TO authenticated;

REVOKE ALL ON FUNCTION public.update_pending_vehicle(UUID, VARCHAR, VARCHAR, VARCHAR) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_pending_vehicle(UUID, VARCHAR, VARCHAR, VARCHAR) TO authenticated;

REVOKE ALL ON FUNCTION public.reschedule_amenity_booking(UUID, DATE, VARCHAR, INT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.reschedule_amenity_booking(UUID, DATE, VARCHAR, INT, TEXT) TO authenticated;

REVOKE ALL ON FUNCTION public.update_pending_meter_reading(UUID, NUMERIC, NUMERIC, TEXT, TEXT, BOOLEAN, BOOLEAN) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_pending_meter_reading(UUID, NUMERIC, NUMERIC, TEXT, TEXT, BOOLEAN, BOOLEAN) TO authenticated;

REVOKE ALL ON FUNCTION public.cancel_pending_meter_reading(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cancel_pending_meter_reading(UUID) TO authenticated;

REVOKE ALL ON FUNCTION public.cancel_apartment_link_request(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cancel_apartment_link_request(UUID) TO authenticated;
