-- ==============================================================================
-- PKA-HOME: QUẢN LÝ Ô ĐỖ HẦM, SỨC CHỨA BÃI XE & VÉ XE VÃNG LAI (D2)
-- Migration 20261102_01_parking_slots_and_visitor_tickets.sql
-- ==============================================================================

-- 1. BẢNG Ô ĐỖ XE TẦNG HẦM (PARKING SLOTS)
CREATE TABLE IF NOT EXISTS public.parking_slots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    building_id UUID REFERENCES public.buildings(id) ON DELETE CASCADE,
    zone VARCHAR(20) NOT NULL DEFAULT 'B1', -- 'B1', 'B2', 'B3'
    slot_number VARCHAR(30) NOT NULL,       -- 'P-B1-01', 'M-B1-01'
    slot_type VARCHAR(20) NOT NULL DEFAULT 'car', -- 'car', 'motorcycle'
    status VARCHAR(20) NOT NULL DEFAULT 'available', -- 'available', 'occupied', 'reserved', 'maintenance'
    assigned_vehicle_id UUID REFERENCES public.vehicles(id) ON DELETE SET NULL,
    assigned_apartment_id UUID REFERENCES public.apartments(id) ON DELETE SET NULL,
    note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(building_id, zone, slot_number)
);

CREATE INDEX IF NOT EXISTS idx_parking_slots_building ON public.parking_slots(building_id);
CREATE INDEX IF NOT EXISTS idx_parking_slots_status ON public.parking_slots(status);
CREATE INDEX IF NOT EXISTS idx_parking_slots_type ON public.parking_slots(slot_type);

-- 2. BẢNG VÉ XE VÃNG LAI / KHÁCH THĂM (VISITOR PARKING TICKETS)
CREATE TABLE IF NOT EXISTS public.visitor_parking_tickets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    building_id UUID REFERENCES public.buildings(id) ON DELETE CASCADE,
    ticket_code VARCHAR(30) NOT NULL UNIQUE,
    license_plate VARCHAR(20) NOT NULL,
    vehicle_type VARCHAR(20) NOT NULL DEFAULT 'motorcycle', -- 'car', 'motorcycle'
    check_in_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    check_out_at TIMESTAMPTZ,
    status VARCHAR(20) NOT NULL DEFAULT 'in_parking', -- 'in_parking', 'completed', 'cancelled'
    hourly_rate NUMERIC NOT NULL DEFAULT 5000,
    total_hours NUMERIC,
    fee_amount NUMERIC NOT NULL DEFAULT 0,
    payment_status VARCHAR(20) NOT NULL DEFAULT 'unpaid', -- 'unpaid', 'paid'
    payment_method VARCHAR(20), -- 'vietqr', 'cash'
    qr_payload TEXT NOT NULL,
    note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_visitor_tickets_status ON public.visitor_parking_tickets(status);
CREATE INDEX IF NOT EXISTS idx_visitor_tickets_plate ON public.visitor_parking_tickets(license_plate);

-- 3. BỔ SUNG TRƯỜNG VÀO VEHICLES
ALTER TABLE public.vehicles
ADD COLUMN IF NOT EXISTS parking_slot_id UUID REFERENCES public.parking_slots(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS parking_slot_number VARCHAR(30);

-- 4. BẬT RLS CHO CÁC BẢNG MỚI
ALTER TABLE public.parking_slots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.visitor_parking_tickets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "parking_slots_read" ON public.parking_slots;
CREATE POLICY "parking_slots_read" ON public.parking_slots
    FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "parking_slots_manage_admin" ON public.parking_slots;
CREATE POLICY "parking_slots_manage_admin" ON public.parking_slots
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.users
            WHERE id = auth.uid() AND role IN ('admin', 'management', 'technician')
        )
    );

DROP POLICY IF EXISTS "visitor_tickets_read" ON public.visitor_parking_tickets;
CREATE POLICY "visitor_tickets_read" ON public.visitor_parking_tickets
    FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "visitor_tickets_manage_admin" ON public.visitor_parking_tickets;
CREATE POLICY "visitor_tickets_manage_admin" ON public.visitor_parking_tickets
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.users
            WHERE id = auth.uid() AND role IN ('admin', 'management', 'technician')
        )
    );

-- 5. RPC: THỐNG KÊ SỨC CHỨA THỜI GIAN THỰC (GET_PARKING_CAPACITY_STATS)
CREATE OR REPLACE FUNCTION public.get_parking_capacity_stats(p_building_id UUID DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_car_total INT := 0;
    v_car_occupied INT := 0;
    v_car_available INT := 0;
    v_moto_total INT := 0;
    v_moto_occupied INT := 0;
    v_moto_available INT := 0;
    v_visitor_count INT := 0;
BEGIN
    -- Thống kê Slot Ô tô
    SELECT 
        COUNT(*),
        COUNT(*) FILTER (WHERE status = 'occupied'),
        COUNT(*) FILTER (WHERE status = 'available')
    INTO v_car_total, v_car_occupied, v_car_available
    FROM public.parking_slots
    WHERE slot_type = 'car'
      AND (p_building_id IS NULL OR building_id = p_building_id);

    -- Thống kê Slot Xe máy
    SELECT 
        COUNT(*),
        COUNT(*) FILTER (WHERE status = 'occupied'),
        COUNT(*) FILTER (WHERE status = 'available')
    INTO v_moto_total, v_moto_occupied, v_moto_available
    FROM public.parking_slots
    WHERE slot_type = 'motorcycle'
      AND (p_building_id IS NULL OR building_id = p_building_id);

    -- Đếm số xe vãng lai đang đỗ
    SELECT COUNT(*)
    INTO v_visitor_count
    FROM public.visitor_parking_tickets
    WHERE status = 'in_parking'
      AND (p_building_id IS NULL OR building_id = p_building_id);

    RETURN jsonb_build_object(
        'car_total', COALESCE(v_car_total, 0),
        'car_occupied', COALESCE(v_car_occupied, 0),
        'car_available', COALESCE(v_car_available, 0),
        'moto_total', COALESCE(v_moto_total, 0),
        'moto_occupied', COALESCE(v_moto_occupied, 0),
        'moto_available', COALESCE(v_moto_available, 0),
        'visitor_count', COALESCE(v_visitor_count, 0)
    );
END;
$$;

-- 6. RPC: TÍNH PHÍ XE VÃNG LAI THEO GIỜ (CALCULATE_VISITOR_PARKING_FEE)
CREATE OR REPLACE FUNCTION public.calculate_visitor_parking_fee(
    p_ticket_id UUID,
    p_check_out_at TIMESTAMPTZ DEFAULT now()
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_ticket RECORD;
    v_diff_minutes INT;
    v_hours NUMERIC;
    v_base_rate NUMERIC;
    v_total_fee NUMERIC := 0;
    v_is_overnight BOOLEAN := false;
BEGIN
    SELECT * INTO v_ticket 
    FROM public.visitor_parking_tickets 
    WHERE id = p_ticket_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Không tìm thấy vé xe');
    END IF;

    -- Tính số phút thực tế
    v_diff_minutes := EXTRACT(EPOCH FROM (p_check_out_at - v_ticket.check_in_at)) / 60;
    IF v_diff_minutes < 0 THEN v_diff_minutes := 0; END IF;
    
    -- Làm tròn lên theo giờ (vd: 15p tính 1h, 1h10p tính 2h)
    v_hours := CEIL(v_diff_minutes::NUMERIC / 60.0);
    IF v_hours < 1 THEN v_hours := 1; END IF;

    -- Biểu phí theo loại xe
    IF v_ticket.vehicle_type = 'car' THEN
        -- Ô tô: 2h đầu 25.000đ, mỗi giờ tiếp theo 15.000đ
        IF v_hours <= 2 THEN
            v_total_fee := 25000;
        ELSE
            v_total_fee := 25000 + ((v_hours - 2) * 15000);
        END IF;
        
        -- Phụ thu qua đêm nếu gửi > 12 tiếng hoặc vượt qua 00:00
        IF v_hours >= 12 THEN
            v_total_fee := v_total_fee + 50000;
            v_is_overnight := true;
        END IF;
    ELSE
        -- Xe máy: 2h đầu 5.000đ, mỗi giờ tiếp theo 3.000đ
        IF v_hours <= 2 THEN
            v_total_fee := 5000;
        ELSE
            v_total_fee := 5000 + ((v_hours - 2) * 3000);
        END IF;

        IF v_hours >= 12 THEN
            v_total_fee := v_total_fee + 15000;
            v_is_overnight := true;
        END IF;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'ticket_id', v_ticket.id,
        'ticket_code', v_ticket.ticket_code,
        'license_plate', v_ticket.license_plate,
        'vehicle_type', v_ticket.vehicle_type,
        'check_in_at', v_ticket.check_in_at,
        'check_out_at', p_check_out_at,
        'total_hours', v_hours,
        'fee_amount', v_total_fee,
        'is_overnight', v_is_overnight
    );
END;
$$;

-- 7. RPC: CHECK-OUT VÀ THU TIỀN VÉ XE (CHECKOUT_VISITOR_TICKET)
CREATE OR REPLACE FUNCTION public.checkout_visitor_ticket(
    p_ticket_id UUID,
    p_payment_method VARCHAR DEFAULT 'vietqr'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_calc JSONB;
    v_fee NUMERIC;
    v_hours NUMERIC;
    v_now TIMESTAMPTZ := now();
BEGIN
    -- 1. Tính toán cước
    v_calc := public.calculate_visitor_parking_fee(p_ticket_id, v_now);
    IF (v_calc->>'success')::BOOLEAN IS NOT TRUE THEN
        RETURN v_calc;
    END IF;

    v_fee := (v_calc->>'fee_amount')::NUMERIC;
    v_hours := (v_calc->>'total_hours')::NUMERIC;

    -- 2. Cập nhật trạng thái vé
    UPDATE public.visitor_parking_tickets
    SET check_out_at = v_now,
        total_hours = v_hours,
        fee_amount = v_fee,
        status = 'completed',
        payment_status = 'paid',
        payment_method = p_payment_method,
        updated_at = v_now
    WHERE id = p_ticket_id;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Đã check-out và xác nhận thu tiền thành công',
        'fee_amount', v_fee,
        'payment_method', p_payment_method,
        'check_out_at', v_now
    );
END;
$$;

-- 8. SEED MẪU CÁC Ô ĐỖ TẦNG HẦM (B1, B2)
INSERT INTO public.parking_slots (zone, slot_number, slot_type, status)
SELECT 
    'B1',
    'P-B1-' || lpad(i::text, 2, '0'),
    'car',
    CASE WHEN i <= 5 THEN 'occupied' ELSE 'available' END
FROM generate_series(1, 20) AS i
ON CONFLICT (building_id, zone, slot_number) DO NOTHING;

INSERT INTO public.parking_slots (zone, slot_number, slot_type, status)
SELECT 
    'B2',
    'M-B2-' || lpad(i::text, 2, '0'),
    'motorcycle',
    CASE WHEN i <= 10 THEN 'occupied' ELSE 'available' END
FROM generate_series(1, 30) AS i
ON CONFLICT (building_id, zone, slot_number) DO NOTHING;

