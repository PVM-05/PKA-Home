-- ==============================================================================
-- Migration: 20261108020000_amenity_lifecycle_and_deposit.sql
-- Module: Tiện Ích Nội Khu & Vòng Đời Nghiệm Thu Hoàn Cọc (Commercial PropTech SaaS)
-- ==============================================================================

-- 1. Mở rộng cấu hình tiện ích tòa nhà
ALTER TABLE public.building_amenities
    ADD COLUMN IF NOT EXISTS max_advance_days INT NOT NULL DEFAULT 7,
    ADD COLUMN IF NOT EXISTS max_slots_per_week INT NOT NULL DEFAULT 3,
    ADD COLUMN IF NOT EXISTS rules_and_regulations TEXT;

-- 2. Mở rộng thông tin vé check-in và nghiệm thu hoàn cọc cho lượt đặt
ALTER TABLE public.amenity_bookings
    ADD COLUMN IF NOT EXISTS qr_ticket_token UUID DEFAULT gen_random_uuid(),
    ADD COLUMN IF NOT EXISTS checked_in_by UUID REFERENCES public.users(id),
    ADD COLUMN IF NOT EXISTS inspected_by UUID REFERENCES public.users(id),
    ADD COLUMN IF NOT EXISTS inspected_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS inspection_result TEXT DEFAULT 'pending', -- 'pending', 'passed', 'violated'
    ADD COLUMN IF NOT EXISTS forfeited_amount NUMERIC(12,2) DEFAULT 0.0,
    ADD COLUMN IF NOT EXISTS refund_amount NUMERIC(12,2) DEFAULT 0.0,
    ADD COLUMN IF NOT EXISTS inspection_notes TEXT,
    ADD COLUMN IF NOT EXISTS inspection_image_urls JSONB DEFAULT '[]'::jsonb;

-- Chỉ mục tối ưu tra cứu vé điện tử QR tại cổng
CREATE UNIQUE INDEX IF NOT EXISTS idx_amenity_bookings_qr_ticket_token 
    ON public.amenity_bookings (qr_ticket_token) 
    WHERE qr_ticket_token IS NOT NULL;

-- 3. Nâng cấp RPC: book_amenity_slot (Hỗ trợ quota tuần và mã vé QR)
CREATE OR REPLACE FUNCTION public.book_amenity_slot(
    p_amenity_id UUID,
    p_booking_date DATE,
    p_time_slot VARCHAR,
    p_guests_count INT DEFAULT 1,
    p_apartment_id UUID DEFAULT NULL,
    p_allow_waitlist BOOLEAN DEFAULT true,
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_user_id UUID;
    v_amenity RECORD;
    v_target_apartment UUID;
    v_day_start TIMESTAMPTZ;
    v_day_end TIMESTAMPTZ;
    v_week_start DATE;
    v_week_end DATE;
    v_apartment_weekly_count INT := 0;
    v_current_slot_capacity INT := 0;
    v_lock_id BIGINT;
    v_booking_id UUID;
    v_ticket_token UUID := gen_random_uuid();
    v_status public.amenity_booking_status := 'confirmed';
    v_fee NUMERIC(12,2) := 0.0;
    v_deposit NUMERIC(12,2) := 0.0;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Chưa đăng nhập vào hệ thống.';
    END IF;

    IF p_booking_date < CURRENT_DATE THEN
        RAISE EXCEPTION 'Không thể đặt lịch ngày trong quá khứ.';
    END IF;

    -- Xác định căn hộ
    v_target_apartment := p_apartment_id;
    IF v_target_apartment IS NULL THEN
        SELECT apartment_id INTO v_target_apartment
        FROM public.residents_apartments
        WHERE user_id = v_user_id
        LIMIT 1;
    END IF;

    IF v_target_apartment IS NULL THEN
        RAISE EXCEPTION 'Người dùng chưa được liên kết với bất kỳ căn hộ nào.';
    END IF;

    -- Lấy thông tin tiện ích
    SELECT * INTO v_amenity
    FROM public.building_amenities
    WHERE id = p_amenity_id;

    IF NOT FOUND OR NOT v_amenity.is_active THEN
        RAISE EXCEPTION 'Tiện ích không tồn tại hoặc đang tạm ngưng phục vụ.';
    END IF;

    -- Kiểm tra đặt trước tối đa bao nhiêu ngày
    IF p_booking_date > (CURRENT_DATE + v_amenity.max_advance_days) THEN
        RAISE EXCEPTION 'Chỉ có thể đặt trước tối đa % ngày.', v_amenity.max_advance_days;
    END IF;

    -- Kiểm tra Quota tuần của căn hộ (tính từ thứ 2 đến chủ nhật)
    v_week_start := date_trunc('week', p_booking_date)::DATE;
    v_week_end := v_week_start + 6;

    SELECT COUNT(*) INTO v_apartment_weekly_count
    FROM public.amenity_bookings
    WHERE apartment_id = v_target_apartment
      AND amenity_id = p_amenity_id
      AND booking_date BETWEEN v_week_start AND v_week_end
      AND status IN ('confirmed', 'pending_payment', 'completed');

    IF v_apartment_weekly_count >= v_amenity.max_slots_per_week THEN
        RAISE EXCEPTION 'Căn hộ đã đạt giới hạn tối đa % lượt đặt tiện ích này trong tuần.', v_amenity.max_slots_per_week;
    END IF;

    -- Kiểm tra lịch bảo trì
    v_day_start := p_booking_date::timestamp at time zone 'Asia/Ho_Chi_Minh';
    v_day_end := (p_booking_date + 1)::timestamp at time zone 'Asia/Ho_Chi_Minh' - interval '1 second';

    IF EXISTS (
        SELECT 1 FROM public.amenity_maintenance_windows
        WHERE amenity_id = p_amenity_id
          AND start_time <= v_day_end
          AND end_time >= v_day_start
    ) THEN
        RAISE EXCEPTION 'Tiện ích đang trong thời gian bảo trì vào ngày này.';
    END IF;

    -- Khóa Advisory Transaction để tránh race condition
    v_lock_id := hashtext(p_amenity_id::text || '_' || p_booking_date::text || '_' || p_time_slot);
    PERFORM pg_advisory_xact_lock(v_lock_id);

    -- Đếm số chỗ đã dùng
    IF v_amenity.booking_type = 'exclusive' THEN
        SELECT COUNT(*) INTO v_current_slot_capacity
        FROM public.amenity_bookings
        WHERE amenity_id = p_amenity_id
          AND booking_date = p_booking_date
          AND time_slot = p_time_slot
          AND status IN ('confirmed', 'pending_payment', 'completed');

        IF v_current_slot_capacity > 0 THEN
            IF NOT p_allow_waitlist THEN
                RAISE EXCEPTION 'Khung giờ này đã được đặt kín.';
            END IF;
            v_status := 'waitlist';
        END IF;
    ELSE
        SELECT COALESCE(SUM(guests_count), 0) INTO v_current_slot_capacity
        FROM public.amenity_bookings
        WHERE amenity_id = p_amenity_id
          AND booking_date = p_booking_date
          AND time_slot = p_time_slot
          AND status IN ('confirmed', 'pending_payment', 'completed');

        IF (v_current_slot_capacity + p_guests_count) > v_amenity.max_capacity THEN
            IF NOT p_allow_waitlist THEN
                RAISE EXCEPTION 'Khung giờ này không đủ chỗ cho % người.', p_guests_count;
            END IF;
            v_status := 'waitlist';
        END IF;
    END IF;

    -- Tính phí & cọc
    IF v_status <> 'waitlist' THEN
        v_fee := CASE 
            WHEN v_amenity.booking_type = 'shared' THEN COALESCE(v_amenity.fee_amount, 0) * p_guests_count
            ELSE COALESCE(v_amenity.fee_amount, 0)
        END;
        v_deposit := COALESCE(v_amenity.deposit_amount, 0);

        IF (v_fee + v_deposit) > 0 THEN
            v_status := 'pending_payment';
        ELSE
            v_status := 'confirmed';
        END IF;
    END IF;

    INSERT INTO public.amenity_bookings (
        amenity_id, apartment_id, booked_by, booking_date, time_slot,
        guests_count, status, fee_amount, deposit_amount, deposit_status,
        payment_status, qr_ticket_token, notes, created_at, updated_at
    ) VALUES (
        p_amenity_id, v_target_apartment, v_user_id, p_booking_date, p_time_slot,
        p_guests_count, v_status, v_fee, v_deposit,
        CASE WHEN v_deposit > 0 THEN 'pending' ELSE 'none' END,
        CASE WHEN (v_fee + v_deposit) > 0 THEN 'unpaid' ELSE 'none' END,
        v_ticket_token, p_notes, now(), now()
    ) RETURNING id INTO v_booking_id;

    RETURN jsonb_build_object(
        'success', true,
        'booking_id', v_booking_id,
        'status', v_status,
        'fee_amount', v_fee,
        'deposit_amount', v_deposit,
        'qr_ticket_token', v_ticket_token,
        'message', CASE 
            WHEN v_status = 'waitlist' THEN 'Khung giờ đã kín chỗ, bạn đã được thêm vào danh sách chờ.'
            WHEN v_status = 'pending_payment' THEN 'Đặt chỗ thành công! Vui lòng quét VietQR thanh toán tiền phí/cọc trong 15 phút.'
            ELSE 'Đặt lịch tiện ích thành công!'
        END
    );
END;
$$;

-- 4. RPC: check_in_amenity_ticket (Bảo vệ/Lễ tân quét mã QR vé tại cổng)
CREATE OR REPLACE FUNCTION public.check_in_amenity_ticket(
    p_qr_ticket_token UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_booking RECORD;
    v_amenity RECORD;
    v_apartment RECORD;
    v_user RECORD;
BEGIN
    SELECT * INTO v_booking
    FROM public.amenity_bookings
    WHERE qr_ticket_token = p_qr_ticket_token;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Mã vé không tồn tại trên hệ thống.');
    END IF;

    IF v_booking.status = 'cancelled' THEN
        RETURN jsonb_build_object('success', false, 'message', 'Vé này đã bị hủy.');
    END IF;

    IF v_booking.status = 'checked_in' THEN
        RETURN jsonb_build_object('success', false, 'message', 'Vé đã được check-in vào lúc ' || to_char(v_booking.check_in_time, 'HH24:MI dd/MM/YYYY'));
    END IF;

    IF v_booking.status = 'completed' THEN
        RETURN jsonb_build_object('success', false, 'message', 'Ca sử dụng của vé này đã hoàn tất.');
    END IF;

    IF v_booking.booking_date <> CURRENT_DATE THEN
        RETURN jsonb_build_object(
            'success', false, 
            'message', 'Vé này có ngày sử dụng là ' || to_char(v_booking.booking_date, 'dd/MM/YYYY') || ', không thể check-in hôm nay.'
        );
    END IF;

    -- Cập nhật check-in
    UPDATE public.amenity_bookings
    SET status = 'checked_in',
        check_in_time = now(),
        checked_in_by = auth.uid(),
        updated_at = now()
    WHERE id = v_booking.id;

    SELECT name INTO v_amenity FROM public.building_amenities WHERE id = v_booking.amenity_id;
    SELECT code INTO v_apartment FROM public.apartments WHERE id = v_booking.apartment_id;
    SELECT full_name INTO v_user FROM public.users WHERE id = v_booking.booked_by;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Check-in thành công!',
        'booking_id', v_booking.id,
        'amenity_name', v_amenity.name,
        'apartment_code', v_apartment.code,
        'booker_name', v_user.full_name,
        'time_slot', v_booking.time_slot,
        'guests_count', v_booking.guests_count,
        'checked_in_at', now()
    );
END;
$$;

-- 5. RPC: inspect_and_settle_amenity_deposit (Nghiệm thu mặt bằng & Xử lý cọc)
CREATE OR REPLACE FUNCTION public.inspect_and_settle_amenity_deposit(
    p_booking_id UUID,
    p_inspection_result TEXT, -- 'passed' hoặc 'violated'
    p_forfeited_amount NUMERIC DEFAULT 0.0,
    p_notes TEXT DEFAULT NULL,
    p_image_urls JSONB DEFAULT '[]'::jsonb
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_booking RECORD;
    v_deposit NUMERIC(12,2);
    v_forfeited NUMERIC(12,2) := 0.0;
    v_refund NUMERIC(12,2) := 0.0;
    v_deposit_status TEXT;
BEGIN
    SELECT * INTO v_booking
    FROM public.amenity_bookings
    WHERE id = p_booking_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Lượt đặt tiện ích không tồn tại.');
    END IF;

    v_deposit := COALESCE(v_booking.deposit_amount, 0.0);

    IF p_inspection_result = 'passed' THEN
        v_deposit_status := 'refunded';
        v_refund := v_deposit;
        v_forfeited := 0.0;
    ELSE
        v_deposit_status := 'forfeited';
        v_forfeited := LEAST(v_deposit, GREATEST(0.0, p_forfeited_amount));
        v_refund := v_deposit - v_forfeited;
    END IF;

    UPDATE public.amenity_bookings
    SET inspection_result = p_inspection_result,
        inspected_by = auth.uid(),
        inspected_at = now(),
        inspection_notes = p_notes,
        inspection_image_urls = p_image_urls,
        deposit_status = v_deposit_status,
        forfeited_amount = v_forfeited,
        refund_amount = v_refund,
        status = CASE WHEN status = 'checked_in' THEN 'completed' ELSE status END,
        updated_at = now()
    WHERE id = p_booking_id;

    RETURN jsonb_build_object(
        'success', true,
        'message', CASE 
            WHEN p_inspection_result = 'passed' THEN 'Nghiệm thu đạt! Tiền cọc đã được xác nhận hoàn trả.'
            ELSE 'Nghiệm thu vi phạm! Đã ghi nhận khấu trừ cọc đền bù.'
        END,
        'deposit_status', v_deposit_status,
        'refund_amount', v_refund,
        'forfeited_amount', v_forfeited
    );
END;
$$;
