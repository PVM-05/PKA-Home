-- ==============================================================================
-- PKA HOME ADMIN ECOSYSTEM MIGRATION
-- 1. users.is_locked
-- 2. apartments.electric_reading, water_reading
-- 3. vehicles table & RLS policies
-- 4. RPC generate_monthly_bulk_invoices
-- 5. RPC check_in_amenity_booking
-- ==============================================================================

-- 1. users.is_locked
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS is_locked boolean NOT NULL DEFAULT false;

-- 2. apartments readings
ALTER TABLE public.apartments 
ADD COLUMN IF NOT EXISTS electric_reading numeric DEFAULT 0,
ADD COLUMN IF NOT EXISTS water_reading numeric DEFAULT 0;

-- 3. vehicles table
CREATE TABLE IF NOT EXISTS public.vehicles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  apartment_id uuid NOT NULL REFERENCES public.apartments(id) ON DELETE CASCADE,
  user_id uuid REFERENCES public.users(id) ON DELETE SET NULL,
  vehicle_type text NOT NULL CHECK (vehicle_type IN ('motorbike', 'car', 'electric_bicycle')),
  license_plate text NOT NULL,
  brand_model text,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Enable RLS for vehicles
ALTER TABLE public.vehicles ENABLE ROW LEVEL SECURITY;

-- Vehicles Policies
CREATE POLICY "Residents can view vehicles of their apartment"
  ON public.vehicles FOR SELECT
  TO authenticated
  USING (
    apartment_id IN (
      SELECT apartment_id FROM public.residents_apartments
      WHERE user_id = auth.uid()
    )
    OR
    EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid() AND role IN ('admin', 'management')
    )
  );

CREATE POLICY "Residents can insert vehicles for their apartment"
  ON public.vehicles FOR INSERT
  TO authenticated
  WITH CHECK (
    apartment_id IN (
      SELECT apartment_id FROM public.residents_apartments
      WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Management can update vehicles status"
  ON public.vehicles FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid() AND role IN ('admin', 'management')
    )
  );

-- 4. RPC: generate_monthly_bulk_invoices
CREATE OR REPLACE FUNCTION public.generate_monthly_bulk_invoices(
  p_period text,
  p_due_date timestamptz,
  p_mgmt_rate numeric DEFAULT 10000,
  p_electric_rate numeric DEFAULT 3000,
  p_water_rate numeric DEFAULT 15000
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_apt RECORD;
  v_invoice_id uuid;
  v_count integer := 0;
  v_total_revenue numeric := 0;
  v_mgmt_fee numeric;
  v_parking_fee numeric;
  v_electric_fee numeric;
  v_water_fee numeric;
  v_invoice_total numeric;
  v_motorbike_count integer;
  v_car_count integer;
BEGIN
  -- Lặp qua từng căn hộ đang có người ở (is_empty = false)
  FOR v_apt IN 
    SELECT id, code, area, COALESCE(electric_reading, 50) as ele_val, COALESCE(water_reading, 10) as wat_val
    FROM public.apartments 
    WHERE is_empty = false
  LOOP
    -- Kiểm tra nếu kỳ này căn hộ đã có hóa đơn thì bỏ qua
    IF NOT EXISTS (
      SELECT 1 FROM public.invoices 
      WHERE apartment_id = v_apt.id AND period = p_period
    ) THEN
      -- Tính phí quản lý theo diện tích
      v_mgmt_fee := ROUND(COALESCE(v_apt.area, 70) * p_mgmt_rate);

      -- Đếm số xe đã duyệt của căn hộ
      SELECT 
        COUNT(*) FILTER (WHERE vehicle_type = 'motorbike'),
        COUNT(*) FILTER (WHERE vehicle_type = 'car')
      INTO v_motorbike_count, v_car_count
      FROM public.vehicles
      WHERE apartment_id = v_apt.id AND status = 'approved';

      -- Phí gửi xe: 100k/xe máy, 1.2M/ô tô (nếu không có xe nào thì mặc định 1 xe máy định mức 100k)
      IF (v_motorbike_count + v_car_count) = 0 THEN
        v_parking_fee := 100000;
      ELSE
        v_parking_fee := (v_motorbike_count * 100000) + (v_car_count * 1200000);
      END IF;

      -- Phí điện nước tiêu thụ
      v_electric_fee := ROUND(v_apt.ele_val * p_electric_rate);
      v_water_fee := ROUND(v_apt.wat_val * p_water_rate);

      v_invoice_total := v_mgmt_fee + v_parking_fee + v_electric_fee + v_water_fee;

      -- Tạo hóa đơn cha
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
        v_invoice_total,
        'unpaid',
        now(),
        now()
      ) RETURNING id INTO v_invoice_id;

      -- Tạo các khoản mục chi tiết
      INSERT INTO public.invoice_items (invoice_id, fee_type, unit_price, quantity, subtotal)
      VALUES 
        (v_invoice_id, 'Phí quản lý vận hành', p_mgmt_rate, COALESCE(v_apt.area, 70), v_mgmt_fee),
        (v_invoice_id, 'Phí gửi xe phương tiện', v_parking_fee, 1, v_parking_fee),
        (v_invoice_id, 'Tiền điện sinh hoạt', p_electric_rate, v_apt.ele_val, v_electric_fee),
        (v_invoice_id, 'Tiền nước sinh hoạt', p_water_rate, v_apt.wat_val, v_water_fee);

      v_count := v_count + 1;
      v_total_revenue := v_total_revenue + v_invoice_total;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'invoices_created', v_count,
    'total_amount', v_total_revenue,
    'period', p_period
  );
END;
$$;

-- 5. RPC: check_in_amenity_booking
CREATE OR REPLACE FUNCTION public.check_in_amenity_booking(
  p_booking_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_status text;
BEGIN
  SELECT status INTO v_status 
  FROM public.amenity_bookings 
  WHERE id = p_booking_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Không tìm thấy lượt đặt chỗ');
  END IF;

  IF v_status = 'completed' THEN
    RETURN jsonb_build_object('success', false, 'message', 'Lượt đặt này đã được check-in trước đó');
  END IF;

  UPDATE public.amenity_bookings
  SET 
    status = 'completed',
    updated_at = now()
  WHERE id = p_booking_id;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Check-in thành công',
    'booking_id', p_booking_id
  );
END;
$$;
