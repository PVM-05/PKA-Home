-- ==============================================================================
-- Migration: 20261011_06_fix_security_meters_vehicles_and_storage.sql
-- Mô tả: Khắc phục các lỗi P0, P1, P2 ngoài thanh toán
-- 1. P0: Chống leo thang đặc quyền khi đăng ký - ép cứng role = 'resident' trong handle_new_user()
-- 2. P1: Sửa RPC approve_meter_reading - dùng status = 'unpaid' chuẩn enum thay vì 'pending'
-- 3. P1: Sửa tính tiêu thụ điện nước trong validate_monthly_bulk_invoices & generate_valid_bulk_invoices
--        Tách rõ số cũ, số mới, tiêu thụ = mới - cũ (1650 - 1500 = 150), dùng status = 'unpaid'
-- 4. P1: Siết RLS storage.objects cho bucket issue-images: bắt buộc authenticated và kiểm tra quyền
-- 5. P2: Khóa căn hộ FOR UPDATE trong check_vehicle_limits() chống race condition đăng ký xe máy
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. P0: HÀM TẠO USER MỚI (handle_new_user) - PHỚT LỜ METADATA ROLE TỪ CLIENT
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_user() 
RETURNS trigger 
LANGUAGE plpgsql 
SECURITY DEFINER 
SET search_path = public, pg_catalog
AS $$
BEGIN
  -- Bảo vệ tuyệt đối: Bất kể client truyền metadata role gì (kể cả admin, management, accountant),
  -- mọi tài khoản tự đăng ký đều chỉ được khởi tạo với vai trò 'resident'.
  -- Việc nâng quyền bắt buộc phải do Quản trị viên thực hiện qua API quản trị nội bộ.
  INSERT INTO public.users (id, full_name, role)
  VALUES (
    new.id, 
    coalesce(new.raw_user_meta_data->>'full_name', 'Người dùng mới'), 
    'resident'::public.user_role
  )
  ON CONFLICT (id) DO UPDATE
  SET full_name = EXCLUDED.full_name;
  
  RETURN new;
END;
$$;


-- ------------------------------------------------------------------------------
-- 2. P1: SỬA RPC DUYỆT CHỈ SỐ ĐỒNG HỒ (approve_meter_reading)
-- Sửa status từ 'pending' thành 'unpaid' (chuẩn enum invoice_status)
-- ------------------------------------------------------------------------------
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
    WHERE id = v_sub.apartment_id FOR UPDATE;

    IF v_sub.electric_reading < v_old_elec THEN
        RAISE EXCEPTION 'Chỉ số điện mới (%) không được nhỏ hơn chỉ số cũ (%) của căn hộ', v_sub.electric_reading, v_old_elec;
    END IF;

    IF v_sub.water_reading < v_old_water THEN
        RAISE EXCEPTION 'Chỉ số nước mới (%) không được nhỏ hơn chỉ số cũ (%) của căn hộ', v_sub.water_reading, v_old_water;
    END IF;

    v_elec_diff := v_sub.electric_reading - v_old_elec;
    v_water_diff := v_sub.water_reading - v_old_water;
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
        -- ĐÚNG CHUẨN: Dùng status = 'unpaid' theo enum invoice_status thay vì 'pending'
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
            'unpaid',
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
            VALUES (v_invoice_id, 'Tiền điện sinh hoạt', 3500, v_elec_diff);
        END IF;

        IF v_water_diff > 0 THEN
            INSERT INTO public.invoice_items (invoice_id, fee_type, unit_price, quantity)
            VALUES (v_invoice_id, 'Tiền nước sinh hoạt', 18000, v_water_diff);
        END IF;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Duyệt chỉ số thành công và đã khởi tạo hóa đơn (nếu chưa có)',
        'submission_id', p_submission_id,
        'invoice_id', v_invoice_id,
        'elec_diff', v_elec_diff,
        'water_diff', v_water_diff,
        'total_amount', v_total_amount
    );
END;
$$;


-- ------------------------------------------------------------------------------
-- 3. P1: SỬA validate_monthly_bulk_invoices (TÍNH ĐÚNG TIÊU THỤ & ĐẦU KỲ - CUỐI KỲ)
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
  v_prev_sub RECORD;
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

    -- 1. Tìm bản ghi chỉ số đã duyệt (approved) của kỳ này
    SELECT * INTO v_sub_record
    FROM public.meter_reading_submissions
    WHERE apartment_id = v_apt.id AND period = p_period AND status = 'approved'
    ORDER BY created_at DESC
    LIMIT 1;

    IF FOUND THEN
      v_cur_elec := v_sub_record.electric_reading;
      v_cur_water := v_sub_record.water_reading;

      -- Tìm chỉ số đầu kỳ từ bản ghi duyệt trước đó (kỳ trước)
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
        -- Nếu không có kỳ trước trong submissions, đối chiếu với chỉ số lưu trên căn hộ
        -- Nếu chỉ số trên căn hộ khác với số mới kỳ này, coi đó là chỉ số đầu kỳ
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

      -- CÔNG THỨC CHUẨN: Tiêu thụ = Cuối kỳ - Đầu kỳ (Ví dụ: 1650 - 1500 = 150)
      v_elec_usage := GREATEST(0, v_cur_elec - v_old_elec);
      v_water_usage := GREATEST(0, v_cur_water - v_old_water);
    ELSE
      -- Chưa có submission duyệt kỳ này, lấy số đọc hiện tại trên apartments (tiêu thụ mặc định = 0)
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

    -- Kiểm tra số âm bất thường
    IF v_elec_usage < 0 OR v_water_usage < 0 THEN
      v_invalid_count := v_invalid_count + 1;
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
    'invalid_count', v_invalid_count,
    'already_invoiced_count', v_already_invoiced_count,
    'total_estimated_amount', v_total_estimated_amount,
    'valid_items', v_valid_items,
    'issues', v_issues
  );
END;
$$;


-- ------------------------------------------------------------------------------
-- 4. P1: SỬA generate_valid_bulk_invoices
-- Đảm bảo dùng đúng lượng tiêu thụ và chèn status = 'unpaid' chuẩn enum
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
      electric_reading_old numeric,
      electric_reading_new numeric,
      electric_usage numeric,
      water_reading_old numeric,
      water_reading_new numeric,
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

      -- ĐÚNG CHUẨN: Dùng status = 'unpaid' theo enum invoice_status thay vì 'pending'
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

      -- Tiền điện nước
      IF v_elec_qty > 0 THEN
        INSERT INTO public.invoice_items (invoice_id, fee_type, unit_price, quantity)
        VALUES (v_new_invoice_id, 'Tiền điện sinh hoạt', p_electric_rate, v_elec_qty);
      END IF;

      IF v_water_qty > 0 THEN
        INSERT INTO public.invoice_items (invoice_id, fee_type, unit_price, quantity)
        VALUES (v_new_invoice_id, 'Tiền nước sinh hoạt', p_water_rate, v_water_qty);
      END IF;

      v_created_count := v_created_count + 1;
      v_results := v_results || jsonb_build_object(
        'invoice_id', v_new_invoice_id,
        'apartment_id', v_inv_record.apartment_id,
        'apartment_code', v_inv_record.apartment_code,
        'total_amount', v_total_amount,
        'status', 'unpaid'
      );
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'period', p_period,
    'invoices_created', v_created_count,
    'results', v_results
  );
END;
$$;


-- ------------------------------------------------------------------------------
-- 5. P2: KHÓA CĂN HỘ (FOR UPDATE) CHỐNG RACE CONDITION ĐĂNG KÝ XE MÁY
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.check_vehicle_limits()
RETURNS TRIGGER 
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    current_motorbike_count INT;
BEGIN
    -- Chỉ kiểm tra khi là xe máy và bản ghi mới có trạng thái đang hoạt động (pending hoặc approved)
    IF NEW.vehicle_type = 'motorbike' AND NEW.status != 'rejected' THEN
        -- Khóa dòng căn hộ để tuần tự hóa (ngăn chặn race condition khi nhiều người nộp cùng lúc)
        PERFORM 1 FROM public.apartments WHERE id = NEW.apartment_id FOR UPDATE;

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

DROP TRIGGER IF EXISTS trg_check_vehicle_limits ON public.vehicles;
CREATE TRIGGER trg_check_vehicle_limits
BEFORE INSERT OR UPDATE ON public.vehicles
FOR EACH ROW EXECUTE FUNCTION public.check_vehicle_limits();


-- ------------------------------------------------------------------------------
-- 6. P1: SIẾT CHẶT VÀ RÀ SOÁT RLS STORAGE CHO BUCKET issue-images
-- Bắt buộc auth.role() = 'authenticated' và giới hạn đúng đối tượng xem ảnh
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "Authenticated Read Access" ON storage.objects;
CREATE POLICY "Authenticated Read Access" 
ON storage.objects FOR SELECT 
USING (
  bucket_id = 'issue-images' 
  AND auth.role() = 'authenticated'
  AND (
    public.is_staff()
    OR (storage.foldername(name))[1] = auth.uid()::text
    OR EXISTS (
      SELECT 1 FROM public.issue_reports ir
      WHERE ir.id::text = (storage.foldername(name))[2]
        AND (
          ir.reporter_id = auth.uid()
          OR ir.apartment_id IN (
            SELECT apartment_id FROM public.residents_apartments WHERE user_id = auth.uid()
          )
        )
    )
  )
);
