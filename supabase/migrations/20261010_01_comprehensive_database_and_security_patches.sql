-- ==============================================================================
-- Migration: 20261010_01_comprehensive_database_and_security_patches.sql
-- Mô tả: Bản vá toàn diện lỗi CSDL, RPC, Trigger và Phân quyền
-- 1. Sửa record_manual_payment: tự sinh transaction_code (thỏa mãn NOT NULL UNIQUE)
-- 2. Sửa trigger check_amenity_booking_resident_update: hỗ trợ thanh toán & waitlist
-- 3. Sửa validate_monthly_bulk_invoices: tính đúng hiệu số điện nước, 0 xe = 0đ, chuẩn giá 16.500đ/m²
-- 4. Sửa classify_issue_priority: thêm word boundary \y tránh xếp nhầm priority
-- 5. Xóa bỏ hoàn toàn hàm simulate_invoice_payment cũ với đúng signature
-- ==============================================================================

-- 1. SỬA RPC THU TIỀN MẶT BQL (record_manual_payment)
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

    -- Khóa hàng chống race-condition / bấm đúp
    SELECT * INTO v_inv FROM public.invoices WHERE id = p_invoice_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Hóa đơn không tồn tại: %', p_invoice_id;
    END IF;

    IF v_inv.status = 'paid' THEN
        RAISE EXCEPTION 'Hóa đơn đã được thanh toán trước đó';
    END IF;

    -- Cập nhật trạng thái hóa đơn
    UPDATE public.invoices
    SET 
        status = 'paid',
        payment_method = p_payment_method,
        paid_at = NOW(),
        updated_at = NOW()
    WHERE id = p_invoice_id;

    -- Tự sinh mã giao dịch duy nhất
    v_txn_code := 'MANUAL-' || to_char(NOW(), 'YYYYMMDDHH24MISS') || '-' || upper(substr(gen_random_uuid()::text, 1, 8));

    -- Tạo giao dịch thanh toán thành công
    INSERT INTO public.payment_transactions (
        transaction_code,
        invoice_id,
        apartment_id,
        amount,
        payment_method,
        status,
        title
    ) VALUES (
        v_txn_code,
        p_invoice_id,
        v_inv.apartment_id,
        v_inv.total_amount,
        p_payment_method,
        'SUCCESS',
        COALESCE(p_notes, 'Thanh toán hóa đơn kỳ ' || v_inv.period)
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

REVOKE ALL ON FUNCTION public.record_manual_payment FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.record_manual_payment TO authenticated;

-- 2. SỬA TRIGGER check_amenity_booking_resident_update
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.check_amenity_booking_resident_update()
RETURNS TRIGGER AS $$
BEGIN
  IF NOT public.is_staff_or_management() THEN
    -- Cho phép cư dân:
    -- - Hủy lịch (cancelled)
    -- - Chuyển sang confirmed qua RPC thanh toán (từ pending, pending_payment, waitlist)
    -- - Đôn waitlist tự động (chuyển sang pending_payment)
    IF NOT (
      NEW.status = 'cancelled' OR
      (NEW.status = 'confirmed' AND OLD.status IN ('pending', 'pending_payment', 'waitlist')) OR
      (NEW.status = 'pending_payment' AND OLD.status = 'waitlist')
    ) THEN
      RAISE EXCEPTION 'Cư dân chỉ được phép hủy lịch tiện ích hoặc thanh toán xác nhận đặt chỗ';
    END IF;

    -- Bảo vệ toàn vẹn các cột nhạy cảm khác không cho phép sửa đổi thủ công
    IF NEW.amenity_id IS DISTINCT FROM OLD.amenity_id OR
       NEW.booking_date IS DISTINCT FROM OLD.booking_date OR
       NEW.time_slot IS DISTINCT FROM OLD.time_slot OR
       NEW.fee_amount IS DISTINCT FROM OLD.fee_amount OR
       NEW.booked_by IS DISTINCT FROM OLD.booked_by OR
       NEW.apartment_id IS DISTINCT FROM OLD.apartment_id THEN
      RAISE EXCEPTION 'Không được phép thay đổi thông tin đặt chỗ';
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

-- 3. SỬA RPC validate_monthly_bulk_invoices (TÍNH ĐÚNG LƯỢNG TIÊU THỤ & PHÍ XE)
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
  -- Quét tất cả căn hộ đang có người ở (is_empty = false)
  FOR v_apt IN
    SELECT id, code, area, electric_reading, water_reading
    FROM public.apartments
    WHERE is_empty = false
    ORDER BY code ASC
  LOOP
    v_total_scanned := v_total_scanned + 1;
    v_issue_found := false;

    -- Kiểm tra căn hộ đã có invoice kỳ này chưa
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

    -- Ưu tiên lấy chỉ số từ meter_reading_submissions đã duyệt (approved) cho kỳ này
    SELECT * INTO v_sub_record
    FROM public.meter_reading_submissions
    WHERE apartment_id = v_apt.id AND period = p_period AND status = 'approved'
    ORDER BY created_at DESC
    LIMIT 1;

    v_old_elec := COALESCE(v_apt.electric_reading, 0);
    v_old_water := COALESCE(v_apt.water_reading, 0);

    IF FOUND THEN
      v_has_approved_sub := true;
      v_cur_elec := v_sub_record.electric_reading;
      v_cur_water := v_sub_record.water_reading;
      -- Lượng tiêu thụ là hiệu số giữa chỉ số mới nộp và chỉ số cũ
      v_elec_usage := GREATEST(0, v_cur_elec - v_old_elec);
      v_water_usage := GREATEST(0, v_cur_water - v_old_water);
    ELSE
      v_has_approved_sub := false;
      v_cur_elec := v_apt.electric_reading;
      v_cur_water := v_apt.water_reading;
      -- Nếu không có lượt nộp chỉ số mới, lượng tiêu thụ trong kỳ coi như bằng 0
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

    -- Kiểm tra chỉ số bất thường
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

    -- Hợp lệ: Tính toán biểu phí
    v_mgmt_fee := ROUND(COALESCE(v_apt.area, 70) * p_mgmt_rate);

    -- Tính phí gửi xe theo số xe approved (Nếu 0 xe thì phí = 0đ)
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
      'total_amount', v_apt_total
    );
  END LOOP;

  RETURN jsonb_build_object(
    'period', p_period,
    'total_apartments_scanned', v_total_scanned,
    'valid_count', v_valid_count,
    'missing_data_count', v_missing_count,
    'invalid_count', v_invalid_count,
    'already_invoiced_count', v_already_invoiced_count,
    'total_estimated_amount', v_total_estimated_amount,
    'valid_invoices', v_valid_items,
    'issues', v_issues
  );
END;
$$;

REVOKE ALL ON FUNCTION public.validate_monthly_bulk_invoices FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.validate_monthly_bulk_invoices TO authenticated;

-- 4. SỬA REGEX PHÂN LOẠI MỨC ĐỘ SỰ CỐ (classify_issue_priority)
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

  -- Trường hợp bóng đèn bị cháy -> Xếp vào mức LOW
  IF v_desc ~* '(bóng đèn|bong den|đèn|den).*(cháy|chay)' OR v_desc ~* '(cháy|chay).*(bóng|bong|đèn|den)' THEN
    NEW.priority := 'low'::public.issue_priority;
    RETURN NEW;
  END IF;

  -- 1.1 Khẩn cấp (High): Hỏa hoạn, rò rỉ gas, chập điện, kẹt thang máy (Thêm \y cho các từ ngắn)
  IF v_desc ~* '(hỏa hoạn|hoa hoan|cháy nhà|chay nha|bốc cháy|boc chay|đám cháy|dam chay|báo cháy|bao chay|khói độc|khoi doc|chập điện|chap dien|rò rỉ gas|ro ri gas|khí gas|khi gas|kẹt thang máy|ket thang may|\ysập\y|\ysap\y|\ynổ\y|\yno\y)' THEN
    NEW.priority := 'high'::public.issue_priority;

  -- 1.2 Thấp (Low): Bóng đèn, mạng wifi, rác, vệ sinh, tiếng ồn, cây cảnh
  ELSIF v_desc ~* '(bóng đèn|bong den|mạng|mang|wifi|vệ sinh|ve sinh|ồn ào|on ao|rác|rac|cây cảnh|cay canh|sơn tường|son tuong|thẩm mỹ|tham my)' THEN
    NEW.priority := 'low'::public.issue_priority;

  -- 1.3 Trung bình (Medium)
  ELSIF v_desc ~* '(rò nước|ro nuoc|rỉ nước|ri nuoc|ngập|ngap|khẩn cấp|khan cap|hỏng khóa|hong khoa|mất điện|mat dien|mất nước|mat nuoc)' THEN
    NEW.priority := 'medium'::public.issue_priority;

  ELSE
    NEW.priority := 'medium'::public.issue_priority;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 5. XÓA BỎ HOÀN TOÀN HÀM simulate_invoice_payment CŨ
-- ------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.simulate_invoice_payment(UUID, VARCHAR);
DROP FUNCTION IF EXISTS public.simulate_invoice_payment(UUID);
