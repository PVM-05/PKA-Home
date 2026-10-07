-- ==============================================================================
-- Migration: 20261007_02_fix_critical_security_and_policies.sql
-- Mô tả: Khắc phục triệt để các lỗ hổng bảo mật RPC và RLS chưa có trong P0
-- 1. Siết quyền RPC hóa đơn: create_invoice_with_items & update_invoice_with_items
-- 2. Thêm RPC nguyên tử xác nhận thu tiền: record_manual_payment
-- 3. Siết RLS vehicles & meter_reading_submissions ép status='pending'
-- 4. Chặn cư dân INSERT direct amenity_bookings & trigger ép cancel-only
-- 5. Siết RLS payment_transactions sang is_admin_or_accountant()
-- 6. Bổ sung policy DELETE cho apartment_link_requests khi status='rejected'
-- 7. Xóa bỏ simulate_invoice_payment cũ
-- ==============================================================================

-- 1. SIẾT QUYỀN RPC QUẢN LÝ HÓA ĐƠN
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
BEGIN
    -- Chỉ admin, accountant hoặc management mới có quyền tạo hóa đơn
    IF NOT public.is_admin_or_accountant() THEN
        RAISE EXCEPTION 'Bạn không có quyền thực hiện thao tác này';
    END IF;

    -- 1. Tạo hóa đơn
    INSERT INTO public.invoices (apartment_id, period, due_date, status)
    VALUES (p_apartment_id, p_period, p_due_date, 'unpaid'::public.invoice_status)
    RETURNING id INTO v_invoice_id;

    -- 2. Chèn từng hạng mục chi phí (bỏ subtotal vì là cột tự sinh GENERATED)
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

    RETURN v_invoice_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.update_invoice_with_items(
    p_invoice_id UUID,
    p_period VARCHAR,
    p_due_date DATE,
    p_items JSONB,
    p_apartment_id UUID DEFAULT NULL,
    p_status VARCHAR DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_item JSONB;
BEGIN
    -- Chỉ admin, accountant hoặc management mới có quyền sửa hóa đơn
    IF NOT public.is_admin_or_accountant() THEN
        RAISE EXCEPTION 'Bạn không có quyền thực hiện thao tác này';
    END IF;

    -- 1. Cập nhật thông tin hóa đơn
    UPDATE public.invoices
    SET 
        period = p_period,
        due_date = p_due_date,
        apartment_id = COALESCE(p_apartment_id, apartment_id),
        status = CASE 
            WHEN p_status IS NOT NULL THEN p_status::public.invoice_status 
            ELSE status 
        END,
        updated_at = NOW()
    WHERE id = p_invoice_id;

    -- 2. Xóa các mục chi phí cũ
    DELETE FROM public.invoice_items WHERE invoice_id = p_invoice_id;

    -- 3. Chèn lại các mục chi phí mới (bỏ subtotal vì là cột tự sinh)
    IF p_items IS NOT NULL AND jsonb_array_length(p_items) > 0 THEN
        FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
        LOOP
            INSERT INTO public.invoice_items (
                invoice_id,
                fee_type,
                unit_price,
                quantity
            ) VALUES (
                p_invoice_id,
                v_item->>'fee_type',
                COALESCE((v_item->>'unit_price')::DECIMAL, 0),
                COALESCE((v_item->>'quantity')::DECIMAL, 1)
            );
        END LOOP;
    END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.create_invoice_with_items FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public.update_invoice_with_items FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_invoice_with_items TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_invoice_with_items TO authenticated;

-- 2. TẠO RPC NGUYÊN TỬ XÁC NHẬN THU TIỀN (record_manual_payment)
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

    -- Tạo giao dịch thanh toán thành công
    INSERT INTO public.payment_transactions (
        invoice_id,
        apartment_id,
        amount,
        payment_method,
        status,
        title
    ) VALUES (
        p_invoice_id,
        v_inv.apartment_id,
        v_inv.total_amount,
        p_payment_method,
        'SUCCESS',
        COALESCE(p_notes, 'Thanh toán hóa đơn kỳ ' || v_inv.period)
    ) RETURNING id INTO v_txn_id;

    RETURN jsonb_build_object(
        'success', true,
        'invoice_id', p_invoice_id,
        'transaction_id', v_txn_id
    );
END;
$$;

REVOKE ALL ON FUNCTION public.record_manual_payment FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.record_manual_payment TO authenticated;

-- 3. SIẾT RLS BẢNG VEHICLES: CƯ DÂN KHÔNG ĐƯỢC TỰ DUYỆT XE
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "Residents can insert vehicles for their apartment" ON public.vehicles;
CREATE POLICY "Residents can insert vehicles for their apartment"
  ON public.vehicles FOR INSERT
  TO authenticated
  WITH CHECK (
    apartment_id IN (
      SELECT apartment_id FROM public.residents_apartments
      WHERE user_id = auth.uid()
    )
    AND status = 'pending'
    AND rejection_reason IS NULL
  );

-- 4. SIẾT RLS METER_READING_SUBMISSIONS: ÉP STATUS='PENDING' & SUBMITTED_BY=AUTH.UID()
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "Residents can insert meter submissions" ON public.meter_reading_submissions;
CREATE POLICY "Residents can insert meter submissions"
  ON public.meter_reading_submissions FOR INSERT
  TO authenticated
  WITH CHECK (
    apartment_id IN (
      SELECT apartment_id FROM public.residents_apartments
      WHERE user_id = auth.uid()
    )
    AND status = 'pending'
    AND (submitted_by = auth.uid() OR submitted_by IS NULL)
  );

-- 5. SIẾT CHẶT ĐẶT LỊCH TIỆN ÍCH (AMENITY_BOOKINGS)
-- ------------------------------------------------------------------------------
-- Bỏ policy cho cư dân INSERT trực tiếp (bắt buộc gọi qua RPC book_amenity_slot)
DROP POLICY IF EXISTS "Cư dân đặt lịch tiện ích" ON public.amenity_bookings;

-- Trigger kiểm soát UPDATE: nếu không phải nhân viên/quản lý thì CHỈ được đổi status sang 'cancelled'
CREATE OR REPLACE FUNCTION public.check_amenity_booking_resident_update()
RETURNS TRIGGER AS $$
BEGIN
  IF NOT public.is_staff_or_management() THEN
    IF NEW.status <> 'cancelled' THEN
      RAISE EXCEPTION 'Cư dân chỉ được phép hủy lịch tiện ích';
    END IF;
    -- Bảo vệ toàn vẹn các cột nhạy cảm khác
    IF NEW.amenity_id IS DISTINCT FROM OLD.amenity_id OR
       NEW.booking_date IS DISTINCT FROM OLD.booking_date OR
       NEW.time_slot IS DISTINCT FROM OLD.time_slot OR
       NEW.fee_amount IS DISTINCT FROM OLD.fee_amount OR
       NEW.deposit_status IS DISTINCT FROM OLD.deposit_status OR
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

-- 6. SIẾT RLS GIAO DỊCH THANH TOÁN (PAYMENT_TRANSACTIONS) SANG IS_ADMIN_OR_ACCOUNTANT
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "BQL quản lý giao dịch thanh toán" ON public.payment_transactions;
CREATE POLICY "BQL quản lý giao dịch thanh toán" ON public.payment_transactions
  FOR ALL
  TO authenticated
  USING (public.is_admin_or_accountant());

-- 7. CHO PHÉP CƯ DÂN XÓA YÊU CẦU LIÊN KẾT CĂN HỘ BỊ TỪ CHỐI (ĐỂ NỘP LẠI)
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "Cư dân xóa yêu cầu bị từ chối" ON public.apartment_link_requests;
CREATE POLICY "Cư dân xóa yêu cầu bị từ chối"
  ON public.apartment_link_requests FOR DELETE
  TO authenticated
  USING (user_id = auth.uid() AND status = 'rejected');

-- 8. DỌN DẸP RPC MÔ PHỎNG CŨ
-- ------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.simulate_invoice_payment(UUID);
