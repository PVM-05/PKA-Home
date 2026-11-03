-- Migration: 20261103_01_visitor_and_parcel_hub.sql
-- Mô tả: An ninh kiểm soát khách ra vào bằng mã QR (Visitor Pre-registration) và Trung tâm quản lý giao nhận bưu kiện lễ tân (Parcel Hub)

-- 1. BẢNG VÉ KHÁCH RA VÀO (visitor_access_passes)
CREATE TABLE IF NOT EXISTS public.visitor_access_passes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pass_code TEXT NOT NULL UNIQUE,
    apartment_id UUID NOT NULL REFERENCES public.apartments(id) ON DELETE CASCADE,
    host_user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    visitor_name TEXT NOT NULL,
    visitor_phone TEXT,
    license_plate TEXT,
    vehicle_type TEXT NOT NULL DEFAULT 'none', -- none, motorcycle, car
    visitor_count INTEGER NOT NULL DEFAULT 1,
    expected_arrival TIMESTAMPTZ NOT NULL,
    expected_departure TIMESTAMPTZ,
    purpose TEXT NOT NULL DEFAULT 'visit', -- visit, delivery, repair, other
    qr_payload TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending', -- pending, checked_in, checked_out, cancelled, expired
    check_in_at TIMESTAMPTZ,
    check_in_guard_id UUID REFERENCES public.users(id),
    check_out_at TIMESTAMPTZ,
    check_out_guard_id UUID REFERENCES public.users(id),
    note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_visitor_passes_apartment ON public.visitor_access_passes(apartment_id);
CREATE INDEX IF NOT EXISTS idx_visitor_passes_status ON public.visitor_access_passes(status);
CREATE INDEX IF NOT EXISTS idx_visitor_passes_arrival ON public.visitor_access_passes(expected_arrival);

-- 2. BẢNG QUẢN LÝ BƯU KIỆN TẠI LỄ TÂN (parcels)
CREATE TABLE IF NOT EXISTS public.parcels (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    parcel_code TEXT NOT NULL UNIQUE,
    apartment_id UUID NOT NULL REFERENCES public.apartments(id) ON DELETE CASCADE,
    recipient_name TEXT,
    carrier TEXT NOT NULL DEFAULT 'SPX', -- SPX, GHTK, GHN, Viettel Post, J&T, NinjaVan, Grab, Khác
    tracking_number TEXT,
    description TEXT,
    shelf_location TEXT NOT NULL DEFAULT 'Kệ chung',
    image_url TEXT,
    pickup_pin TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'arrived', -- arrived, collected, returned
    arrived_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    received_staff_id UUID REFERENCES public.users(id),
    collected_at TIMESTAMPTZ,
    handover_staff_id UUID REFERENCES public.users(id),
    collected_by TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_parcels_apartment ON public.parcels(apartment_id);
CREATE INDEX IF NOT EXISTS idx_parcels_status ON public.parcels(status);
CREATE INDEX IF NOT EXISTS idx_parcels_arrived ON public.parcels(arrived_at);

-- 3. TRIGGERS SINH MÃ TỰ ĐỘNG
-- A. Trigger sinh pass_code và qr_payload cho visitor_access_passes
CREATE OR REPLACE FUNCTION public.fn_generate_visitor_pass_code()
RETURNS TRIGGER AS $$
DECLARE
    v_prefix TEXT;
    v_seq_num INT;
BEGIN
    IF NEW.pass_code IS NULL OR NEW.pass_code = '' THEN
        v_prefix := 'VP-' || to_char(COALESCE(NEW.created_at, now()), 'YYYYMM') || '-';
        SELECT COALESCE(MAX(SUBSTRING(pass_code FROM 11)::INT), 0) + 1
        INTO v_seq_num
        FROM public.visitor_access_passes
        WHERE pass_code LIKE v_prefix || '%';
        
        NEW.pass_code := v_prefix || LPAD(v_seq_num::TEXT, 5, '0');
    END IF;

    IF NEW.qr_payload IS NULL OR NEW.qr_payload = '' THEN
        NEW.qr_payload := 'PKAPASS:' || NEW.pass_code || ':' || SUBSTRING(gen_random_uuid()::TEXT FROM 1 FOR 8);
    END IF;

    NEW.updated_at := timezone('utc'::text, now());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_generate_visitor_pass_code ON public.visitor_access_passes;
CREATE TRIGGER trg_generate_visitor_pass_code
    BEFORE INSERT ON public.visitor_access_passes
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_generate_visitor_pass_code();

-- B. Trigger sinh parcel_code và pickup_pin cho parcels
CREATE OR REPLACE FUNCTION public.fn_generate_parcel_code_and_pin()
RETURNS TRIGGER AS $$
DECLARE
    v_prefix TEXT;
    v_seq_num INT;
    v_random_pin TEXT;
BEGIN
    IF NEW.parcel_code IS NULL OR NEW.parcel_code = '' THEN
        v_prefix := 'PCL-' || to_char(COALESCE(NEW.arrived_at, now()), 'YYYYMM') || '-';
        SELECT COALESCE(MAX(SUBSTRING(parcel_code FROM 12)::INT), 0) + 1
        INTO v_seq_num
        FROM public.parcels
        WHERE parcel_code LIKE v_prefix || '%';
        
        NEW.parcel_code := v_prefix || LPAD(v_seq_num::TEXT, 5, '0');
    END IF;

    IF NEW.pickup_pin IS NULL OR NEW.pickup_pin = '' THEN
        -- Sinh mã PIN ngẫu nhiên 6 chữ số từ 100000 đến 999999
        v_random_pin := floor(100000 + random() * 900000)::TEXT;
        NEW.pickup_pin := v_random_pin;
    END IF;

    NEW.updated_at := timezone('utc'::text, now());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_generate_parcel_code_and_pin ON public.parcels;
CREATE TRIGGER trg_generate_parcel_code_and_pin
    BEFORE INSERT ON public.parcels
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_generate_parcel_code_and_pin();

-- 4. BỘ RPCS NGHIỆP VỤ AN NINH & LỄ TÂN
-- A. check_in_visitor_pass
CREATE OR REPLACE FUNCTION public.check_in_visitor_pass(
    p_pass_code TEXT,
    p_guard_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_pass public.visitor_access_passes%ROWTYPE;
BEGIN
    SELECT * INTO v_pass
    FROM public.visitor_access_passes
    WHERE pass_code = UPPER(TRIM(p_pass_code))
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Không tìm thấy vé khách với mã đã quét.');
    END IF;

    IF v_pass.status = 'checked_in' THEN
        RETURN jsonb_build_object('success', false, 'message', 'Khách này đã được check-in vào tòa nhà trước đó.');
    END IF;

    IF v_pass.status = 'cancelled' THEN
        RETURN jsonb_build_object('success', false, 'message', 'Vé khách này đã bị cư dân hủy.');
    END IF;

    UPDATE public.visitor_access_passes
    SET status = 'checked_in',
        check_in_at = timezone('utc'::text, now()),
        check_in_guard_id = p_guard_id,
        updated_at = timezone('utc'::text, now())
    WHERE id = v_pass.id;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Check-in thành công. Chào mừng khách viếng thăm!',
        'pass_code', v_pass.pass_code,
        'visitor_name', v_pass.visitor_name,
        'apartment_id', v_pass.apartment_id
    );
END;
$$;

-- B. check_out_visitor_pass
CREATE OR REPLACE FUNCTION public.check_out_visitor_pass(
    p_pass_code TEXT,
    p_guard_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_pass public.visitor_access_passes%ROWTYPE;
BEGIN
    SELECT * INTO v_pass
    FROM public.visitor_access_passes
    WHERE pass_code = UPPER(TRIM(p_pass_code))
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Không tìm thấy vé khách với mã đã quét.');
    END IF;

    IF v_pass.status = 'checked_out' THEN
        RETURN jsonb_build_object('success', false, 'message', 'Khách này đã check-out rời tòa nhà rồi.');
    END IF;

    UPDATE public.visitor_access_passes
    SET status = 'checked_out',
        check_out_at = timezone('utc'::text, now()),
        check_out_guard_id = p_guard_id,
        updated_at = timezone('utc'::text, now())
    WHERE id = v_pass.id;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Check-out hoàn tất. Khách đã rời khỏi tòa nhà.',
        'pass_code', v_pass.pass_code,
        'visitor_name', v_pass.visitor_name
    );
END;
$$;

-- C. collect_parcel
CREATE OR REPLACE FUNCTION public.collect_parcel(
    p_parcel_id UUID,
    p_pickup_pin TEXT,
    p_staff_id UUID,
    p_collected_by TEXT DEFAULT 'Cư dân'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_parcel public.parcels%ROWTYPE;
BEGIN
    SELECT * INTO v_parcel
    FROM public.parcels
    WHERE id = p_parcel_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Không tìm thấy kiện hàng yêu cầu.');
    END IF;

    IF v_parcel.status = 'collected' THEN
        RETURN jsonb_build_object('success', false, 'message', 'Kiện hàng này đã được bàn giao trước đó.');
    END IF;

    -- Kiểm tra mã PIN lấy hàng
    IF TRIM(p_pickup_pin) != v_parcel.pickup_pin THEN
        RETURN jsonb_build_object('success', false, 'message', 'Mã PIN lấy hàng không chính xác!');
    END IF;

    UPDATE public.parcels
    SET status = 'collected',
        collected_at = timezone('utc'::text, now()),
        handover_staff_id = p_staff_id,
        collected_by = COALESCE(p_collected_by, 'Cư dân'),
        updated_at = timezone('utc'::text, now())
    WHERE id = v_parcel.id;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Bàn giao bưu kiện cho cư dân thành công.',
        'parcel_code', v_parcel.parcel_code,
        'tracking_number', v_parcel.tracking_number
    );
END;
$$;

-- D. get_front_desk_stats
CREATE OR REPLACE FUNCTION public.get_front_desk_stats(
    p_building_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_today_start TIMESTAMPTZ := date_trunc('day', timezone('Asia/Ho_Chi_Minh', now()));
    v_today_end TIMESTAMPTZ := v_today_start + interval '1 day';
    v_three_days_ago TIMESTAMPTZ := timezone('utc'::text, now()) - interval '3 days';
    v_expected_visitors INT := 0;
    v_in_building_visitors INT := 0;
    v_pending_parcels INT := 0;
    v_overdue_parcels INT := 0;
BEGIN
    -- Đếm khách dự kiến hôm nay
    SELECT COUNT(*) INTO v_expected_visitors
    FROM public.visitor_access_passes vp
    JOIN public.apartments apt ON vp.apartment_id = apt.id
    WHERE (p_building_id IS NULL OR apt.building_id = p_building_id)
      AND vp.expected_arrival >= v_today_start
      AND vp.expected_arrival < v_today_end
      AND vp.status != 'cancelled';

    -- Đếm khách đang trong tòa nhà
    SELECT COUNT(*) INTO v_in_building_visitors
    FROM public.visitor_access_passes vp
    JOIN public.apartments apt ON vp.apartment_id = apt.id
    WHERE (p_building_id IS NULL OR apt.building_id = p_building_id)
      AND vp.status = 'checked_in';

    -- Đếm bưu kiện chờ nhận tại kệ
    SELECT COUNT(*) INTO v_pending_parcels
    FROM public.parcels p
    JOIN public.apartments apt ON p.apartment_id = apt.id
    WHERE (p_building_id IS NULL OR apt.building_id = p_building_id)
      AND p.status = 'arrived';

    -- Đếm bưu kiện tồn đọng quá 3 ngày
    SELECT COUNT(*) INTO v_overdue_parcels
    FROM public.parcels p
    JOIN public.apartments apt ON p.apartment_id = apt.id
    WHERE (p_building_id IS NULL OR apt.building_id = p_building_id)
      AND p.status = 'arrived'
      AND p.arrived_at < v_three_days_ago;

    RETURN jsonb_build_object(
        'expected_visitors_today', v_expected_visitors,
        'visitors_in_building', v_in_building_visitors,
        'pending_parcels', v_pending_parcels,
        'overdue_parcels', v_overdue_parcels
    );
END;
$$;

-- 5. RLS POLICIES BẢO MẬT
ALTER TABLE public.visitor_access_passes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.parcels ENABLE ROW LEVEL SECURITY;

-- Policies cho visitor_access_passes:
DROP POLICY IF EXISTS "Management and guards can view and edit all visitor passes" ON public.visitor_access_passes;
CREATE POLICY "Management and guards can view and edit all visitor passes"
    ON public.visitor_access_passes
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.users
            WHERE users.id = auth.uid() AND users.role IN ('admin', 'management', 'security', 'receptionist')
        )
    );

DROP POLICY IF EXISTS "Residents can view and create their own apartment visitor passes" ON public.visitor_access_passes;
CREATE POLICY "Residents can view and create their own apartment visitor passes"
    ON public.visitor_access_passes
    FOR ALL
    TO authenticated
    USING (
        host_user_id = auth.uid()
        OR EXISTS (
            SELECT 1 FROM public.residents_apartments ra
            WHERE ra.user_id = auth.uid() AND ra.apartment_id = visitor_access_passes.apartment_id
        )
    )
    WITH CHECK (
        host_user_id = auth.uid()
        OR EXISTS (
            SELECT 1 FROM public.residents_apartments ra
            WHERE ra.user_id = auth.uid() AND ra.apartment_id = visitor_access_passes.apartment_id
        )
    );

-- Policies cho parcels:
DROP POLICY IF EXISTS "Management and receptionists can manage all parcels" ON public.parcels;
CREATE POLICY "Management and receptionists can manage all parcels"
    ON public.parcels
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.users
            WHERE users.id = auth.uid() AND users.role IN ('admin', 'management', 'security', 'receptionist')
        )
    );

DROP POLICY IF EXISTS "Residents can view their own apartment parcels" ON public.parcels;
CREATE POLICY "Residents can view their own apartment parcels"
    ON public.parcels
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.residents_apartments ra
            WHERE ra.user_id = auth.uid() AND ra.apartment_id = parcels.apartment_id
        )
    );

