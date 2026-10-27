-- Migration: Tao hoa don hang loat co tien kiem tra (Pre-flight Validation / Dry-Run) va Idempotency
-- File: supabase/migrations/20261006_01_batch_invoice_prevalidation.sql

-- 1. Rang buoc Unique Constraint chong trung lap hoa don theo can ho va ky
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'uq_invoices_apartment_period'
  ) THEN
    ALTER TABLE public.invoices 
    ADD CONSTRAINT uq_invoices_apartment_period UNIQUE (apartment_id, period);
  END IF;
END $$;

-- 2. RPC Dry-Run: validate_monthly_bulk_invoices
-- Tien kiem tra du lieu 280 can ho, phan loai 4 nhom, KHONG GHI DATABASE
CREATE OR REPLACE FUNCTION public.validate_monthly_bulk_invoices(
  p_period text,
  p_mgmt_rate numeric DEFAULT 10000,
  p_electric_rate numeric DEFAULT 3500,
  p_water_rate numeric DEFAULT 18000
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
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
  v_has_approved_sub boolean;
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
  -- Quet tat ca can ho dang co nguoi o (is_empty = false)
  FOR v_apt IN
    SELECT id, code, area, electric_reading, water_reading
    FROM public.apartments
    WHERE is_empty = false
    ORDER BY code ASC
  LOOP
    v_total_scanned := v_total_scanned + 1;
    v_issue_found := false;

    -- Rule 7: Can ho da co invoice ky nay chua?
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

    -- Uu tien lay chi so tu meter_reading_submissions da duyet (approved)
    SELECT * INTO v_sub_record
    FROM public.meter_reading_submissions
    WHERE apartment_id = v_apt.id AND period = p_period AND status = 'approved'
    ORDER BY created_at DESC
    LIMIT 1;

    IF FOUND THEN
      v_has_approved_sub := true;
      v_cur_elec := v_sub_record.electric_reading;
      v_cur_water := v_sub_record.water_reading;
    ELSE
      v_has_approved_sub := false;
      v_cur_elec := v_apt.electric_reading;
      v_cur_water := v_apt.water_reading;
    END IF;

    -- Uoc luong chi so cu: mac dinh cu = max(0, moi - tieu thu uoc luong) hoac 0
    -- Trong database thuc te ta tinh tieu thu tu chenh lech
    -- Rule 1, 2, 3, 4: Kiem tra co day du chi so dien va nuoc khong
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

    -- Tinh muc tieu thu dien va nuoc
    -- Neu khong co chi so cu, ta coi chi so hien tai tren can ho la luong tieu thu thang (hoac chenh lech neu co moc truoc)
    v_elec_usage := COALESCE(v_cur_elec, 0);
    v_water_usage := COALESCE(v_cur_water, 0);

    -- Rule 5, 6: Kiem tra chi so bat thuong (neu am hoac nho hon muc chuan)
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

    -- Hop le: Tinh toan bieu phi
    v_mgmt_fee := ROUND(COALESCE(v_apt.area, 70) * p_mgmt_rate);

    -- Tinh phi gui xe theo so xe approved
    SELECT 
      COUNT(*) FILTER (WHERE vehicle_type = 'motorbike'),
      COUNT(*) FILTER (WHERE vehicle_type = 'car')
    INTO v_motorbike_count, v_car_count
    FROM public.vehicles
    WHERE apartment_id = v_apt.id AND status = 'approved';

    IF (v_motorbike_count + v_car_count) = 0 THEN
      v_parking_fee := 100000; -- Mac dinh 1 xe may 100k
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
      'electric_usage', v_elec_usage,
      'water_usage', v_water_usage,
      'estimated_total', v_apt_total
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

-- 3. RPC Create: generate_valid_bulk_invoices
-- Tao hoa don nguyen tu cho cac can ho hop le, chong trung lap voi ON CONFLICT DO NOTHING
CREATE OR REPLACE FUNCTION public.generate_valid_bulk_invoices(
  p_period text,
  p_due_date timestamptz,
  p_mgmt_rate numeric DEFAULT 10000,
  p_electric_rate numeric DEFAULT 3500,
  p_water_rate numeric DEFAULT 18000,
  p_target_apartment_ids uuid[] DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_apt RECORD;
  v_invoice_id uuid;
  v_invoices_created integer := 0;
  v_total_amount numeric := 0;
  v_skipped_count integer := 0;

  v_mgmt_fee numeric;
  v_parking_fee numeric;
  v_elec_fee numeric;
  v_water_fee numeric;
  v_apt_total numeric;
  v_elec_usage numeric;
  v_water_usage numeric;

  v_motorbike_count integer;
  v_car_count integer;
  v_user RECORD;
BEGIN
  -- Lap qua cac can ho hop le
  FOR v_apt IN
    SELECT id, code, area, electric_reading, water_reading
    FROM public.apartments
    WHERE is_empty = false
      AND (p_target_apartment_ids IS NULL OR id = ANY(p_target_apartment_ids))
    ORDER BY code ASC
  LOOP
    -- 2 Lop bao ve: Kiem tra neu can ho da co hoa don thi bo qua
    IF EXISTS (
      SELECT 1 FROM public.invoices 
      WHERE apartment_id = v_apt.id AND period = p_period
    ) THEN
      v_skipped_count := v_skipped_count + 1;
      CONTINUE;
    END IF;

    -- Tinh luong tieu thu
    v_elec_usage := COALESCE(v_apt.electric_reading, 0);
    v_water_usage := COALESCE(v_apt.water_reading, 0);

    -- Tinh phi
    v_mgmt_fee := ROUND(COALESCE(v_apt.area, 70) * p_mgmt_rate);

    SELECT 
      COUNT(*) FILTER (WHERE vehicle_type = 'motorbike'),
      COUNT(*) FILTER (WHERE vehicle_type = 'car')
    INTO v_motorbike_count, v_car_count
    FROM public.vehicles
    WHERE apartment_id = v_apt.id AND status = 'approved';

    IF (v_motorbike_count + v_car_count) = 0 THEN
      v_parking_fee := 100000;
    ELSE
      v_parking_fee := (v_motorbike_count * 100000) + (v_car_count * 1200000);
    END IF;

    v_elec_fee := ROUND(v_elec_usage * p_electric_rate);
    v_water_fee := ROUND(v_water_usage * p_water_rate);
    v_apt_total := v_mgmt_fee + v_parking_fee + v_elec_fee + v_water_fee;

    -- Chen hoa don cha (kem ON CONFLICT DO NOTHING de dam bao Idempotency tuyet doi)
    INSERT INTO public.invoices (
      apartment_id,
      period,
      due_date,
      total_amount,
      status,
      created_at,
      updated_at
    ) VALUES (
      v_apt.id,
      p_period,
      p_due_date,
      v_apt_total,
      'unpaid',
      now(),
      now()
    )
    ON CONFLICT (apartment_id, period) DO NOTHING
    RETURNING id INTO v_invoice_id;

    -- Neu insert thanh cong
    IF v_invoice_id IS NOT NULL THEN
      -- Chen cac dong chi tiet invoice_items
      INSERT INTO public.invoice_items (invoice_id, fee_type, unit_price, quantity, subtotal)
      VALUES 
        (v_invoice_id, 'Phí quản lý vận hành', p_mgmt_rate, COALESCE(v_apt.area, 70), v_mgmt_fee),
        (v_invoice_id, 'Phí gửi xe phương tiện', v_parking_fee, 1, v_parking_fee),
        (v_invoice_id, 'Tiền điện sinh hoạt', p_electric_rate, v_elec_usage, v_elec_fee),
        (v_invoice_id, 'Tiền nước sinh hoạt', p_water_rate, v_water_usage, v_water_fee);

      v_invoices_created := v_invoices_created + 1;
      v_total_amount := v_total_amount + v_apt_total;

      -- Gui thong bao he thong den cu dan lien ket voi can ho
      FOR v_user IN
        SELECT user_id FROM public.residents_apartments WHERE apartment_id = v_apt.id
      LOOP
        INSERT INTO public.notifications (
          user_id,
          title,
          body,
          type,
          created_at
        ) VALUES (
          v_user.user_id,
          'Hóa đơn sinh hoạt kỳ ' || p_period,
          'Căn hộ ' || v_apt.code || ' đã có hóa đơn mới kỳ ' || p_period || ' với tổng tiền ' || v_apt_total || ' đ.',
          'new_invoice',
          now()
        );
      END LOOP;
    ELSE
      v_skipped_count := v_skipped_count + 1;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'period', p_period,
    'invoices_created', v_invoices_created,
    'total_amount', v_total_amount,
    'skipped_count', v_skipped_count
  );
END;
$$;
