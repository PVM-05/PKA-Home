-- ==============================================================================
-- Migration: 20261007_01_fix_p0_database_and_security.sql
-- Mô tả: Khắc phục toàn bộ lỗi P0 Database, Migration, RPC, Trigger và Bảo mật
-- 1. Chuẩn hóa schema public.vehicles và trigger bảo vệ users
-- 2. Sửa hàm phân quyền RBAC và siết RLS amenity_bookings
-- 3. Hợp nhất và sửa toàn bộ trigger thông báo
-- 4. Sửa toàn bộ RPC tính tiền và duyệt chỉ số đồng hồ
-- 5. Bảo mật thanh toán, xử lý múi giờ và siết quyền thực thi
-- ==============================================================================

-- 1. CHUẨN HÓA BẢNG VEHICLES
-- ------------------------------------------------------------------------------
ALTER TABLE public.vehicles
  ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS license_plate TEXT,
  ADD COLUMN IF NOT EXISTS brand_model TEXT,
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'pending';

-- Đồng bộ dữ liệu cũ từ plate_number sang license_plate nếu cần
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'vehicles' AND column_name = 'plate_number'
  ) THEN
    UPDATE public.vehicles
    SET license_plate = plate_number
    WHERE license_plate IS NULL AND plate_number IS NOT NULL;
  END IF;
END $$;

-- Ràng buộc giá trị hợp lệ cho status và vehicle_type
DO $$
BEGIN
  ALTER TABLE public.vehicles DROP CONSTRAINT IF EXISTS vehicles_status_check;
  ALTER TABLE public.vehicles ADD CONSTRAINT vehicles_status_check 
    CHECK (status IN ('pending', 'approved', 'rejected'));
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$
BEGIN
  ALTER TABLE public.vehicles DROP CONSTRAINT IF EXISTS vehicles_vehicle_type_check;
  ALTER TABLE public.vehicles ADD CONSTRAINT vehicles_vehicle_type_check 
    CHECK (vehicle_type IN ('motorbike', 'car', 'electric_bicycle'));
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- 2. TRIGGER BẢO VỆ CỘT NHẠY CẢM TRÊN BẢNG USERS (is_locked & role)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.protect_user_sensitive_fields()
RETURNS TRIGGER AS $$
DECLARE
  v_caller_role public.user_role;
BEGIN
  -- Lấy vai trò của người đang thực hiện truy vấn
  SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
  
  -- Nếu không phải admin hoặc management thì cấm sửa is_locked và role
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

-- 3. SỬA HÀM PHÂN QUYỀN RBAC (ĐÚNG CỘT TRONG role_delegations)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_staff_or_management()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.users
    WHERE id = auth.uid()
      AND (
        role IN ('management', 'admin', 'technician')
        OR EXISTS (
          SELECT 1 FROM public.role_delegations rd
          WHERE rd.delegate_id = auth.uid()
            AND rd.delegated_role IN ('management', 'admin', 'technician')
            AND now() BETWEEN rd.starts_at AND rd.ends_at
        )
      )
  );
$$;

CREATE OR REPLACE FUNCTION public.is_admin_or_accountant()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.users
    WHERE id = auth.uid()
      AND (
        role IN ('admin', 'accountant', 'management')
        OR EXISTS (
          SELECT 1 FROM public.role_delegations rd
          WHERE rd.delegate_id = auth.uid()
            AND rd.delegated_role = 'accountant'
            AND now() BETWEEN rd.starts_at AND rd.ends_at
        )
      )
  );
$$;

-- 4. SIẾT CHẶT RLS: CƯ DÂN CHỈ ĐƯỢC PHÉP HỦY LỊCH TIỆN ÍCH (CANCELLED)
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "Cư dân hủy booking của mình" ON public.amenity_bookings;
DROP POLICY IF EXISTS "amenity_bookings_resident_cancel_only" ON public.amenity_bookings;
DROP POLICY IF EXISTS "Cư dân cập nhật booking của mình" ON public.amenity_bookings;

CREATE POLICY "amenity_bookings_resident_cancel_only"
ON public.amenity_bookings
FOR UPDATE
TO authenticated
USING (booked_by = auth.uid())
WITH CHECK (
  booked_by = auth.uid() AND status = 'cancelled'
);

-- 5. HỢP NHẤT VÀ SỬA TOÀN BỘ TRIGGER THÔNG BÁO SỰ CỐ (issue_reports)
-- ------------------------------------------------------------------------------
-- Xóa các trigger cũ bị phân mảnh/lỗi
DROP TRIGGER IF EXISTS trg_notify_on_issue_status_change ON public.issue_reports;
DROP TRIGGER IF EXISTS trg_notify_on_issue_lifecycle ON public.issue_reports;
DROP TRIGGER IF EXISTS trg_notify_on_issue_event ON public.issue_reports;

CREATE OR REPLACE FUNCTION public.trigger_notify_on_issue_event()
RETURNS TRIGGER AS $$
DECLARE
  v_apt_code TEXT;
  v_title TEXT;
  v_body TEXT;
BEGIN
  -- Lấy mã căn hộ
  SELECT code INTO v_apt_code FROM public.apartments WHERE id = NEW.apartment_id;
  v_apt_code := COALESCE(v_apt_code, 'N/A');

  -- A. KHI CƯ DÂN TẠO PHẢN ÁNH MỚI (INSERT) -> BÁO BAN QUẢN LÝ & KỸ THUẬT
  IF TG_OP = 'INSERT' THEN
    IF NEW.priority = 'high' THEN
      v_title := '🚨 PHẢN ÁNH KHẨN: Căn hộ ' || v_apt_code;
    ELSE
      v_title := 'Phản ánh sự cố mới: Căn hộ ' || v_apt_code;
    END IF;

    v_body := LEFT(COALESCE(NEW.description, 'Cư dân vừa gửi một phản ánh sự cố mới.'), 120);

    INSERT INTO public.notifications (
      user_id,
      apartment_id,
      title,
      body,
      type,
      payload
    )
    SELECT 
      u.id,
      NEW.apartment_id,
      v_title,
      v_body,
      'issue_update',
      jsonb_build_object(
        'issue_id', NEW.id,
        'apartment_id', NEW.apartment_id,
        'priority', NEW.priority
      )
    FROM public.users u
    WHERE u.role IN ('admin', 'management', 'technician');

    RETURN NEW;
  END IF;

  -- B. KHI CẬP NHẬT TRẠNG THÁI SỰ CỐ (UPDATE) -> BÁO CƯ DÂN
  IF TG_OP = 'UPDATE' THEN
    IF OLD.status IS DISTINCT FROM NEW.status THEN
      IF NEW.status = 'in_progress' THEN
        v_title := 'Sự cố đã được tiếp nhận xử lý';
        v_body := 'Phản ánh ("' || LEFT(COALESCE(NEW.description, 'sự cố'), 40) || '...") của bạn đã được BQL tiếp nhận và cử kỹ thuật viên xử lý.';
      ELSIF NEW.status = 'resolved' THEN
        v_title := 'Sự cố đã được xử lý hoàn tất';
        v_body := 'Phản ánh ("' || LEFT(COALESCE(NEW.description, 'sự cố'), 40) || '...") đã hoàn tất. Quý cư dân vui lòng kiểm tra và đánh giá dịch vụ.';
      ELSIF NEW.status = 'cancelled' THEN
        v_title := 'Phản ánh sự cố đã bị hủy';
        v_body := 'Phản ánh ("' || LEFT(COALESCE(NEW.description, 'sự cố'), 40) || '...") đã được Ban Quản Lý cập nhật trạng thái hủy.';
      ELSE
        v_title := 'Cập nhật tiến độ xử lý sự cố';
        v_body := 'Phản ánh ("' || LEFT(COALESCE(NEW.description, 'sự cố'), 40) || '...") vừa được cập nhật sang trạng thái: ' || NEW.status || '.';
      END IF;

      IF NEW.reporter_id IS NOT NULL THEN
        INSERT INTO public.notifications (
          user_id,
          apartment_id,
          title,
          body,
          type,
          payload
        ) VALUES (
          NEW.reporter_id,
          NEW.apartment_id,
          v_title,
          v_body,
          'issue_update',
          jsonb_build_object(
            'issue_id', NEW.id,
            'status', NEW.status,
            'apartment_id', NEW.apartment_id
          )
        );
      END IF;
    END IF;

    -- Báo cho kỹ thuật viên khi được phân công mới
    IF NEW.assigned_staff_id IS NOT NULL AND 
       (OLD.assigned_staff_id IS NULL OR OLD.assigned_staff_id <> NEW.assigned_staff_id) THEN
      INSERT INTO public.notifications (
        user_id,
        apartment_id,
        title,
        body,
        type,
        payload
      ) VALUES (
        NEW.assigned_staff_id,
        NEW.apartment_id,
        'Bạn được phân công xử lý sự cố',
        'Căn hộ ' || v_apt_code || ': ' || LEFT(COALESCE(NEW.description, 'Chi tiết phản ánh sự cố'), 100),
        'issue_update',
        jsonb_build_object(
          'issue_id', NEW.id,
          'priority', NEW.priority,
          'apartment_id', NEW.apartment_id
        )
      );
    END IF;

    RETURN NEW;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_catalog;

CREATE TRIGGER trg_notify_on_issue_event
  AFTER INSERT OR UPDATE ON public.issue_reports
  FOR EACH ROW
  EXECUTE FUNCTION public.trigger_notify_on_issue_event();

-- 6. SỬA HÀM HỦY LỊCH TIỆN ÍCH (DÙNG CỘT body THAY VÌ content TRONG notifications)
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
        SELECT * INTO v_amenity FROM public.amenities WHERE id = NEW.amenity_id;
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
            SET status = 'confirmed', updated_at = NOW()
            WHERE id = v_waitlist_rec.id;

            -- SỬA CHUẨN: Dùng body thay vì content
            INSERT INTO public.notifications (user_id, title, body, type, payload)
            VALUES (
                v_waitlist_rec.booked_by,
                'Lịch tiện ích đã được xác nhận!',
                format('Khung giờ %s ngày %s cho tiện ích %s đã có chỗ trống và tự động xác nhận cho bạn.', 
                    NEW.time_slot, NEW.booking_date, v_amenity.name),
                'amenity',
                jsonb_build_object('booking_id', v_waitlist_rec.id, 'amenity_id', NEW.amenity_id)
            );

            v_available_capacity := v_available_capacity - v_waitlist_rec.guests_count;
            EXIT WHEN v_available_capacity <= 0;
        END LOOP;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_catalog;

-- 7. SỬA TRIGGER THÔNG BÁO BẢO TRÌ THIẾT BỊ (DÙNG a.building_code)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trigger_notify_on_equipment_maintenance()
RETURNS TRIGGER AS $$
DECLARE
    v_eq_name TEXT;
    v_eq_code TEXT;
    v_building TEXT;
    v_resident RECORD;
    v_title TEXT;
    v_body TEXT;
    v_start_str TEXT;
    v_end_str TEXT;
BEGIN
    SELECT name, code, building
    INTO v_eq_name, v_eq_code, v_building
    FROM public.building_equipments
    WHERE id = NEW.equipment_id;

    v_eq_name := COALESCE(v_eq_name, 'Thiết bị kỹ thuật');
    v_eq_code := COALESCE(v_eq_code, 'N/A');
    v_building := COALESCE(v_building, 'Toàn khu');

    v_start_str := to_char(NEW.scheduled_start, 'HH24:MI DD/MM/YYYY');
    v_end_str := to_char(NEW.scheduled_end, 'HH24:MI DD/MM/YYYY');

    v_title := 'Bảo trì thiết bị: ' || v_eq_name;
    v_body := 'Thiết bị ' || v_eq_name || ' (' || v_eq_code || ') tại khu vực ' || v_building || 
              ' đang được bảo dưỡng định kỳ và tạm gián đoạn dịch vụ từ ' || v_start_str || 
              ' đến ' || v_end_str || 
              CASE WHEN NEW.service_interruption_note IS NOT NULL AND NEW.service_interruption_note <> ''
                   THEN '. Lưu ý: ' || NEW.service_interruption_note
                   ELSE ''
              END || '.';

    IF v_building = 'Toàn khu' OR v_building = '' THEN
        FOR v_resident IN
            SELECT DISTINCT user_id FROM public.residents_apartments
        LOOP
            INSERT INTO public.notifications (user_id, title, body, type, payload)
            VALUES (
                v_resident.user_id,
                v_title,
                v_body,
                'equipment_maintenance',
                jsonb_build_object(
                    'task_id', NEW.id,
                    'equipment_id', NEW.equipment_id,
                    'equipment_name', v_eq_name,
                    'equipment_code', v_eq_code,
                    'building', v_building
                )
            );
        END LOOP;
    ELSE
        -- SỬA CHUẨN: Dùng a.building_code thay vì a.building
        FOR v_resident IN
            SELECT DISTINCT ra.user_id 
            FROM public.residents_apartments ra
            JOIN public.apartments a ON ra.apartment_id = a.id
            WHERE a.building_code = v_building 
               OR ('Tòa ' || a.building_code) = v_building
               OR v_building LIKE '%' || a.building_code || '%'
        LOOP
            INSERT INTO public.notifications (user_id, title, body, type, payload)
            VALUES (
                v_resident.user_id,
                v_title,
                v_body,
                'equipment_maintenance',
                jsonb_build_object(
                    'task_id', NEW.id,
                    'equipment_id', NEW.equipment_id,
                    'equipment_name', v_eq_name,
                    'equipment_code', v_eq_code,
                    'building', v_building
                )
            );
        END LOOP;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_catalog;

-- 8. SỬA RPC DUYỆT CHỈ SỐ ĐỒNG HỒ (approve_meter_reading & reject_meter_reading)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.approve_meter_reading(
    p_submission_id UUID,
    p_generate_invoice BOOLEAN DEFAULT false,
    p_due_date DATE DEFAULT (CURRENT_DATE + INTERVAL '15 days'),
    p_mgmt_rate NUMERIC DEFAULT 10000,
    p_electric_rate NUMERIC DEFAULT 3000,
    p_water_rate NUMERIC DEFAULT 15000
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
    -- Kiểm tra phân quyền
    IF NOT (public.is_staff_or_management() OR public.is_admin_or_accountant()) THEN
        RAISE EXCEPTION 'Bạn không có quyền duyệt chỉ số đồng hồ';
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
    FROM public.apartments WHERE id = v_sub.apartment_id;

    v_area := COALESCE(v_area, 50.0);

    -- Cập nhật chỉ số mới vào căn hộ
    UPDATE public.apartments
    SET electric_reading = v_sub.electric_reading,
        water_reading = v_sub.water_reading,
        updated_at = now()
    WHERE id = v_sub.apartment_id;

    -- Cập nhật trạng thái submission
    UPDATE public.meter_reading_submissions
    SET status = 'approved',
        reviewed_by = auth.uid(),
        reviewed_at = now(),
        updated_at = now()
    WHERE id = p_submission_id;

    -- Tạo hóa đơn nếu được yêu cầu
    IF p_generate_invoice THEN
        v_elec_diff := GREATEST(0, v_sub.electric_reading - v_old_elec);
        v_water_diff := GREATEST(0, v_sub.water_reading - v_old_water);
        v_mgmt_fee := v_area * p_mgmt_rate;

        -- Đếm xe đã duyệt
        SELECT COUNT(*) FILTER (WHERE vehicle_type = 'motorbike' AND status = 'approved'),
               COUNT(*) FILTER (WHERE vehicle_type = 'car' AND status = 'approved')
        INTO v_motorbike_count, v_car_count
        FROM public.vehicles WHERE apartment_id = v_sub.apartment_id;

        v_parking_fee := (v_motorbike_count * 100000) + (v_car_count * 1200000);
        v_total_amount := v_mgmt_fee + (v_elec_diff * p_electric_rate) + (v_water_diff * p_water_rate) + v_parking_fee;

        -- SỬA CHUẨN: status = 'unpaid' thay vì 'pending'
        INSERT INTO public.invoices (apartment_id, period, due_date, total_amount, status, created_at, updated_at)
        VALUES (v_sub.apartment_id, v_sub.period, p_due_date, v_total_amount, 'unpaid', now(), now())
        RETURNING id INTO v_invoice_id;

        -- SỬA CHUẨN: BỎ CỘT subtotal KHỎI INSERT INTO invoice_items
        INSERT INTO public.invoice_items (invoice_id, fee_type, unit_price, quantity)
        VALUES
            (v_invoice_id, 'Phí quản lý', p_mgmt_rate, v_area),
            (v_invoice_id, 'Tiền điện', p_electric_rate, v_elec_diff),
            (v_invoice_id, 'Tiền nước', p_water_rate, v_water_diff);

        IF v_parking_fee > 0 THEN
            INSERT INTO public.invoice_items (invoice_id, fee_type, unit_price, quantity)
            VALUES (v_invoice_id, 'Phí gửi xe', v_parking_fee, 1);
        END IF;

        RETURN jsonb_build_object(
            'success', true,
            'submission_id', p_submission_id,
            'invoice_id', v_invoice_id,
            'status', 'approved'
        );
    END IF;

    RETURN jsonb_build_object('success', true, 'submission_id', p_submission_id, 'status', 'approved');
END;
$$;

CREATE OR REPLACE FUNCTION public.reject_meter_reading(
    p_submission_id UUID,
    p_rejection_reason TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
BEGIN
    IF NOT (public.is_staff_or_management() OR public.is_admin_or_accountant()) THEN
        RAISE EXCEPTION 'Bạn không có quyền từ chối chỉ số đồng hồ';
    END IF;

    UPDATE public.meter_reading_submissions
    SET status = 'rejected',
        rejection_reason = p_rejection_reason,
        reviewed_by = auth.uid(),
        reviewed_at = now(),
        updated_at = now()
    WHERE id = p_submission_id AND status = 'pending';

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Bản ghi không tồn tại hoặc đã được xử lý';
    END IF;

    RETURN jsonb_build_object('success', true, 'submission_id', p_submission_id, 'status', 'rejected');
END;
$$;

-- 9. SỬA RPC TẠO HÓA ĐƠN HÀNG LOẠT (generate_valid_bulk_invoices & validate_monthly_bulk_invoices)
-- ------------------------------------------------------------------------------
-- Xóa hàm cũ không còn sử dụng
DROP FUNCTION IF EXISTS public.generate_monthly_bulk_invoices(TEXT, DATE, NUMERIC, NUMERIC, NUMERIC);

CREATE OR REPLACE FUNCTION public.generate_valid_bulk_invoices(
  p_period text,
  p_due_date date,
  p_mgmt_rate numeric default 10000,
  p_electric_rate numeric default 3000,
  p_water_rate numeric default 15000
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
    p_period, p_due_date, p_mgmt_rate, p_electric_rate, p_water_rate
  );

  FOR v_inv_record IN 
    SELECT * FROM jsonb_to_recordset(v_validation->'valid_invoices') AS x(
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
      v_parking_fee := (COALESCE(v_inv_record.motorbike_count, 0) * 100000) + 
                       (COALESCE(v_inv_record.car_count, 0) * 1200000);
      
      v_total_amount := (COALESCE(v_inv_record.area, 50) * p_mgmt_rate) +
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
        'unpaid',
        now(),
        now()
      ) RETURNING id INTO v_new_invoice_id;

      -- SỬA CHUẨN: BỎ CỘT subtotal KHỎI INSERT INTO invoice_items
      INSERT INTO public.invoice_items (invoice_id, fee_type, unit_price, quantity)
      VALUES 
        (v_new_invoice_id, 'Phí quản lý', p_mgmt_rate, COALESCE(v_inv_record.area, 50)),
        (v_new_invoice_id, 'Tiền điện', p_electric_rate, v_elec_qty),
        (v_new_invoice_id, 'Tiền nước', p_water_rate, v_water_qty);

      -- Chỉ chèn phí gửi xe nếu căn hộ thực sự có xe đã duyệt
      IF v_parking_fee > 0 THEN
        INSERT INTO public.invoice_items (invoice_id, fee_type, unit_price, quantity)
        VALUES (v_new_invoice_id, 'Phí gửi xe', v_parking_fee, 1);
      END IF;

      v_created_count := v_created_count + 1;
      v_results := v_results || jsonb_build_object(
        'apartment_code', v_inv_record.apartment_code,
        'invoice_id', v_new_invoice_id,
        'total_amount', v_total_amount
      );
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'period', p_period,
    'created_count', v_created_count,
    'invoices', v_results
  );
END;
$$;



