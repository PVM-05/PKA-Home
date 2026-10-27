-- ==============================================================================
-- Migration: 20261025_03_audit_remediation_and_amenity_system.sql
-- Mô tả: Khắc phục 21 điểm rà soát hệ thống (P0-P3), siết chặt quyền hạn,
--        chuẩn hóa RPC thanh toán, bổ sung RPC hủy lịch tiện ích, ẩn danh PII,
--        và cấu hình sức chứa thực tế cho các tiện ích tòa nhà.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. [P0/P2] VÁ LỖ HỔNG LEO THANG ĐẶC QUYỀN (handle_new_user)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_user() 
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.users (id, full_name, email, role, is_active, is_locked)
  VALUES (
    new.id, 
    coalesce(new.raw_user_meta_data->>'full_name', 'Người dùng mới'),
    lower(trim(new.email)),
    'resident'::public.user_role, -- Ép cứng resident, chống leo thang đặc quyền từ metadata
    true,
    false
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    full_name = EXCLUDED.full_name;
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_catalog;

-- ------------------------------------------------------------------------------
-- 2. [P2] SIẾT CHẶT PHÂN QUYỀN TRONG admin_create_user VÀ admin_update_user_profile
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_create_user(
    p_email VARCHAR,
    p_password VARCHAR,
    p_full_name VARCHAR,
    p_phone VARCHAR DEFAULT NULL,
    p_role VARCHAR DEFAULT 'resident',
    p_apartment_id UUID DEFAULT NULL,
    p_relation_role VARCHAR DEFAULT 'owner'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_catalog
AS $$
DECLARE
    v_new_user_id UUID := gen_random_uuid();
    v_pwd TEXT;
    v_role public.user_role;
BEGIN
    -- Chỉ Admin hoặc Staff mới có quyền tạo người dùng
    IF NOT (public.is_admin() OR public.is_staff()) THEN
        RAISE EXCEPTION 'Bạn không có quyền quản trị để tạo tài khoản mới';
    END IF;

    p_email := LOWER(TRIM(p_email));
    IF p_email IS NULL OR p_email = '' THEN
        RAISE EXCEPTION 'Email không được để trống';
    END IF;

    -- Chỉ Quản trị viên cấp cao (admin) mới được tạo tài khoản có quyền staff hoặc admin
    IF p_role <> 'resident' AND NOT public.is_admin() THEN
        RAISE EXCEPTION 'Chỉ Quản trị viên cấp cao mới có quyền tạo tài khoản Nhân viên hoặc Quản trị';
    END IF;

    IF EXISTS (SELECT 1 FROM auth.users WHERE email = p_email) THEN
        RAISE EXCEPTION 'Email % đã tồn tại trong hệ thống', p_email;
    END IF;

    v_pwd := COALESCE(NULLIF(TRIM(p_password), ''), 'PkaHome@2026');
    v_role := p_role::public.user_role;

    -- Tạo bản ghi trong auth.users
    INSERT INTO auth.users (
        id, instance_id, email, encrypted_password, email_confirmed_at,
        raw_app_meta_data, raw_user_meta_data, created_at, updated_at, role, aud
    ) VALUES (
        v_new_user_id,
        '00000000-0000-0000-0000-000000000000',
        p_email,
        crypt(v_pwd, gen_salt('bf')),
        NOW(),
        jsonb_build_object('provider', 'email', 'providers', array['email']),
        jsonb_build_object('full_name', TRIM(p_full_name), 'role', v_role::text),
        NOW(),
        NOW(),
        'authenticated',
        'authenticated'
    );

    -- Tạo bản ghi auth.identities
    INSERT INTO auth.identities (
        id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at
    ) VALUES (
        v_new_user_id,
        v_new_user_id,
        jsonb_build_object('sub', v_new_user_id::text, 'email', p_email),
        'email',
        NOW(),
        NOW(),
        NOW()
    );

    -- Tạo hoặc cập nhật public.users
    INSERT INTO public.users (
        id, full_name, email, phone, role, is_active, is_locked, created_at, updated_at
    ) VALUES (
        v_new_user_id,
        TRIM(p_full_name),
        p_email,
        NULLIF(TRIM(p_phone), ''),
        v_role,
        true,
        false,
        NOW(),
        NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        email = EXCLUDED.email,
        phone = EXCLUDED.phone,
        role = EXCLUDED.role,
        updated_at = NOW();

    -- Gán căn hộ nếu có
    IF p_apartment_id IS NOT NULL THEN
        INSERT INTO public.residents_apartments (
            user_id, apartment_id, relation_role, created_at
        ) VALUES (
            v_new_user_id, p_apartment_id, COALESCE(p_relation_role, 'owner'), NOW()
        )
        ON CONFLICT DO NOTHING;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'user_id', v_new_user_id,
        'email', p_email,
        'role', v_role::text,
        'message', 'Tạo tài khoản người dùng thành công'
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_update_user_profile(
    p_target_user_id UUID,
    p_full_name VARCHAR,
    p_phone VARCHAR DEFAULT NULL,
    p_role VARCHAR DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_catalog
AS $$
DECLARE
    v_old_role public.user_role;
    v_new_role public.user_role;
BEGIN
    IF NOT (public.is_admin() OR public.is_staff()) THEN
        RAISE EXCEPTION 'Bạn không có quyền quản trị để chỉnh sửa hồ sơ người dùng';
    END IF;

    SELECT role INTO v_old_role FROM public.users WHERE id = p_target_user_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Không tìm thấy người dùng với ID: %', p_target_user_id;
    END IF;

    IF p_role IS NOT NULL THEN
        v_new_role := p_role::public.user_role;
        -- Chỉ Quản trị viên cấp cao mới có quyền thay đổi vai trò người dùng
        IF v_new_role <> v_old_role AND NOT public.is_admin() THEN
            RAISE EXCEPTION 'Chỉ Quản trị viên cấp cao mới có quyền thay đổi vai trò người dùng';
        END IF;
    ELSE
        v_new_role := v_old_role;
    END IF;

    UPDATE public.users
    SET full_name = COALESCE(NULLIF(TRIM(p_full_name), ''), full_name),
        phone = NULLIF(TRIM(p_phone), ''),
        role = v_new_role,
        updated_at = NOW()
    WHERE id = p_target_user_id;

    UPDATE auth.users
    SET raw_user_meta_data = raw_user_meta_data || jsonb_build_object('full_name', TRIM(p_full_name), 'role', v_new_role::text),
        updated_at = NOW()
    WHERE id = p_target_user_id;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Cập nhật thông tin hồ sơ thành công'
    );
END;
$$;

-- ------------------------------------------------------------------------------
-- 3. [P0] CHUẨN HÓA CHỮ KÝ simulate_unified_payment (MỤC #4)
-- ------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.simulate_unified_payment(text, uuid, text, text, text, text);
DROP FUNCTION IF EXISTS public.simulate_unified_payment(text, uuid, text, text, text);
DROP FUNCTION IF EXISTS public.simulate_unified_payment(text, uuid, text);
DROP FUNCTION IF EXISTS public.simulate_unified_payment(varchar, uuid, varchar, varchar, text);
DROP FUNCTION IF EXISTS public.simulate_unified_payment(varchar, uuid, varchar);

CREATE OR REPLACE FUNCTION public.simulate_unified_payment(
    p_payment_type text DEFAULT 'INVOICE'::text,
    p_reference_id uuid DEFAULT NULL::uuid,
    p_payment_method text DEFAULT 'DEMO'::text,
    p_outcome text DEFAULT 'SUCCESS'::text,
    p_failure_reason text DEFAULT NULL::text,
    p_type text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_user_id uuid;
    v_booking record;
    v_invoice record;
    v_target_apartment uuid;
    v_tx_id uuid;
    v_now timestamptz := now();
    v_tx_code text;
    v_effective_type text;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Chưa đăng nhập';
    END IF;

    v_effective_type := UPPER(COALESCE(p_type, p_payment_type, 'INVOICE'));

    IF v_effective_type = 'INVOICE' THEN
        SELECT * INTO v_invoice
        FROM public.invoices
        WHERE id = p_reference_id
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Không tìm thấy hóa đơn';
        END IF;

        IF v_invoice.status = 'paid' THEN
            RETURN jsonb_build_object('success', false, 'message', 'Hóa đơn này đã được thanh toán trước đó.');
        END IF;

        IF v_invoice.status = 'pending_confirmation' THEN
            RETURN jsonb_build_object('success', true, 'message', 'Yêu cầu thanh toán đang chờ Ban quản lý xác nhận.');
        END IF;

        UPDATE public.invoices
        SET status = 'pending_confirmation', updated_at = v_now
        WHERE id = p_reference_id;

        v_tx_code := 'INV' || to_char(v_now, 'YYYYMMDDHH24MISS') || UPPER(SUBSTRING(gen_random_uuid()::text, 1, 4));

        INSERT INTO public.payment_transactions (
            invoice_id, user_id, apartment_id, amount, payment_method, status,
            transaction_code, type, title, created_at, updated_at
        ) VALUES (
            p_reference_id, v_user_id, v_invoice.apartment_id, v_invoice.total_amount,
            p_payment_method, 'PENDING', v_tx_code, 'INVOICE',
            'Thanh toán hóa đơn kỳ ' || v_invoice.period, v_now, v_now
        ) RETURNING id INTO v_tx_id;

        RETURN jsonb_build_object(
            'success', true,
            'transaction_id', v_tx_id,
            'transaction_code', v_tx_code,
            'status', 'PENDING',
            'message', 'Đã gửi thông báo thanh toán, vui lòng chờ Ban quản lý xác nhận'
        );

    ELSIF v_effective_type = 'SERVICE' THEN
        SELECT * INTO v_booking
        FROM public.amenity_bookings
        WHERE id = p_reference_id
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Không tìm thấy lịch đặt chỗ dịch vụ';
        END IF;

        IF v_booking.status = 'confirmed' THEN
            RETURN jsonb_build_object('success', true, 'message', 'Lịch đặt chỗ đã được xác nhận.');
        END IF;

        IF v_booking.status = 'cancelled' THEN
            RAISE EXCEPTION 'Lịch đặt chỗ này đã bị hủy, không thể thanh toán.';
        END IF;

        UPDATE public.amenity_bookings
        SET status = 'confirmed', updated_at = v_now
        WHERE id = p_reference_id;

        v_tx_code := 'SVC' || to_char(v_now, 'YYYYMMDDHH24MISS') || UPPER(SUBSTRING(gen_random_uuid()::text, 1, 4));

        INSERT INTO public.payment_transactions (
            booking_id, user_id, apartment_id, amount, payment_method, status,
            transaction_code, type, title, created_at, updated_at
        ) VALUES (
            p_reference_id, v_user_id, v_booking.apartment_id,
            (COALESCE(v_booking.fee_amount, 0) + COALESCE(v_booking.deposit_amount, 0)),
            p_payment_method, 'SUCCESS', v_tx_code, 'SERVICE',
            'Thanh toán dịch vụ tiện ích', v_now, v_now
        ) RETURNING id INTO v_tx_id;

        RETURN jsonb_build_object(
            'success', true,
            'transaction_id', v_tx_id,
            'transaction_code', v_tx_code,
            'status', 'SUCCESS',
            'message', 'Thanh toán dịch vụ thành công'
        );
    ELSE
        RAISE EXCEPTION 'Loại thanh toán không hợp lệ: %', v_effective_type;
    END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.simulate_unified_payment(text, uuid, text, text, text, text) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.simulate_unified_payment(text, uuid, text, text, text, text) TO authenticated;

-- ------------------------------------------------------------------------------
-- 4. [P0/P1] RPC HỦY LỊCH TIỆN ÍCH NGUYÊN TỬ (cancel_amenity_booking)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.cancel_amenity_booking(p_booking_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_user_id UUID;
    v_booking RECORD;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Bạn chưa đăng nhập vào hệ thống';
    END IF;

    SELECT * INTO v_booking
    FROM public.amenity_bookings
    WHERE id = p_booking_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Không tìm thấy lượt đặt chỗ với mã ID đã cho';
    END IF;

    -- Kiểm tra quyền: Người đặt hoặc Ban quản lý
    IF v_booking.booked_by <> v_user_id AND NOT public.is_staff_or_management() THEN
        RAISE EXCEPTION 'Bạn không có quyền hủy lượt đặt chỗ của người khác';
    END IF;

    IF v_booking.status = 'cancelled' THEN
        RETURN jsonb_build_object(
            'success', true,
            'message', 'Lịch đặt chỗ này đã được hủy trước đó',
            'booking_id', p_booking_id
        );
    END IF;

    -- Hủy giao dịch thanh toán tạm liên quan nếu có
    UPDATE public.payment_transactions
    SET status = 'CANCELLED', updated_at = NOW()
    WHERE booking_id = p_booking_id AND status = 'PENDING';

    -- Đánh dấu trạng thái hủy (Trigger sau đó sẽ tự động đôn Waitlist nếu có)
    UPDATE public.amenity_bookings
    SET status = 'cancelled', updated_at = NOW()
    WHERE id = p_booking_id;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Đã hủy lịch đặt tiện ích thành công',
        'booking_id', p_booking_id
    );
END;
$$;

REVOKE ALL ON FUNCTION public.cancel_amenity_booking(UUID) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.cancel_amenity_booking(UUID) TO authenticated;

-- ------------------------------------------------------------------------------
-- 5. [P0] SỬA LỖI UUID VÀ TIMESTAMPTZ TRONG reschedule_amenity_booking (MỤC #5)
-- ------------------------------------------------------------------------------
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
    v_is_same_slot BOOLEAN;
    v_final_guests INT;
    v_current_slot_capacity INT;
    v_new_fee NUMERIC;
    v_old_slot_avail INT;
    v_old_slot_used_guests INT;
    v_old_slot_used_count INT;
    v_next_waitlist RECORD;
    v_promoted_fee NUMERIC;
    v_promoted_deposit NUMERIC;
    v_waitlist_promoted BOOLEAN := false;
    v_existing_tx_id UUID;
    v_day_start TIMESTAMPTZ;
    v_day_end TIMESTAMPTZ;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Chưa đăng nhập vào hệ thống.';
    END IF;

    SELECT * INTO v_booking
    FROM public.amenity_bookings
    WHERE id = p_booking_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Không tìm thấy lượt đặt tiện ích này.';
    END IF;

    IF v_booking.booked_by <> v_user_id AND NOT public.is_staff_or_management() THEN
        RAISE EXCEPTION 'Bạn không có quyền đổi lịch của người khác.';
    END IF;

    IF v_booking.status = 'cancelled' THEN
        RAISE EXCEPTION 'Lịch đặt đã bị hủy, không thể đổi lịch.';
    END IF;

    IF v_booking.status = 'completed' THEN
        RAISE EXCEPTION 'Lịch đặt đã hoàn thành sử dụng, không thể đổi lịch.';
    END IF;

    IF p_new_date < CURRENT_DATE THEN
        RAISE EXCEPTION 'Không thể đổi lịch sang ngày trong quá khứ.';
    END IF;

    SELECT * INTO v_amenity
    FROM public.building_amenities
    WHERE id = v_booking.amenity_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Không tìm thấy thông tin tiện ích tòa nhà.';
    END IF;

    -- Kiểm tra bảo trì bằng start_time/end_time chuẩn TIMESTAMPTZ
    v_day_start := p_new_date::timestamp at time zone 'Asia/Ho_Chi_Minh';
    v_day_end := (p_new_date + 1)::timestamp at time zone 'Asia/Ho_Chi_Minh' - interval '1 second';

    IF EXISTS (
        SELECT 1 FROM public.amenity_maintenance_windows
        WHERE amenity_id = v_booking.amenity_id
          AND start_time <= v_day_end
          AND end_time >= v_day_start
    ) THEN
        RAISE EXCEPTION 'Tiện ích đang trong thời gian bảo trì vào ngày đã chọn.';
    END IF;

    -- Khóa Advisory chống Deadlock
    v_h_old := hashtext(v_booking.amenity_id::text || '_' || v_booking.booking_date::text || '_' || v_booking.time_slot);
    v_h_new := hashtext(v_booking.amenity_id::text || '_' || p_new_date::text || '_' || p_new_time_slot);
    v_lock1 := LEAST(v_h_old, v_h_new);
    v_lock2 := GREATEST(v_h_old, v_h_new);

    PERFORM pg_advisory_xact_lock(v_lock1);
    IF v_lock1 <> v_lock2 THEN
        PERFORM pg_advisory_xact_lock(v_lock2);
    END IF;

    v_is_same_slot := (v_booking.booking_date = p_new_date AND v_booking.time_slot = p_new_time_slot);

    -- Xác định số khách
    IF v_booking.status = 'confirmed' THEN
        v_final_guests := v_booking.guests_count;
    ELSE
        v_final_guests := COALESCE(p_new_guests_count, v_booking.guests_count, 1);
        IF v_final_guests < 1 THEN v_final_guests := 1; END IF;
        IF v_final_guests > v_amenity.max_capacity THEN
            RAISE EXCEPTION 'Số lượng người (% người) vượt quá sức chứa tối đa của tiện ích (% người)', 
                v_final_guests, v_amenity.max_capacity;
        END IF;
    END IF;

    -- Kiểm tra sức chứa tại slot mới
    IF v_amenity.booking_type = 'exclusive' THEN
        SELECT COUNT(*) INTO v_current_slot_capacity
        FROM public.amenity_bookings
        WHERE amenity_id = v_booking.amenity_id
          AND booking_date = p_new_date
          AND time_slot = p_new_time_slot
          AND status IN ('confirmed', 'pending_payment', 'completed')
          AND id <> p_booking_id;

        IF v_current_slot_capacity > 0 THEN
            RAISE EXCEPTION 'Khung giờ mới đã có người đặt trước (Độc quyền).';
        END IF;
    ELSE
        SELECT COALESCE(SUM(guests_count), 0) INTO v_current_slot_capacity
        FROM public.amenity_bookings
        WHERE amenity_id = v_booking.amenity_id
          AND booking_date = p_new_date
          AND time_slot = p_new_time_slot
          AND status IN ('confirmed', 'pending_payment', 'completed')
          AND id <> p_booking_id;

        IF (v_current_slot_capacity + v_final_guests) > v_amenity.max_capacity THEN
            RAISE EXCEPTION 'Khung giờ mới không đủ chỗ cho % khách (chỉ còn trống % chỗ).',
                v_final_guests, (v_amenity.max_capacity - v_current_slot_capacity);
        END IF;
    END IF;

    IF v_booking.status = 'waitlist' THEN
        IF COALESCE(v_amenity.fee_amount, 0) > 0 OR COALESCE(v_amenity.deposit_amount, 0) > 0 THEN
            v_booking.status := 'pending_payment';
        ELSE
            v_booking.status := 'confirmed';
        END IF;
    ELSIF v_booking.status = 'pending_payment' AND v_amenity.booking_type = 'shared' THEN
        v_new_fee := COALESCE(v_amenity.fee_amount, 0) * v_final_guests;
        UPDATE public.amenity_bookings
        SET fee_amount = v_new_fee
        WHERE id = p_booking_id;

        -- Sửa lỗi so sánh UUID với text
        UPDATE public.payment_transactions
        SET amount = (v_new_fee + COALESCE(v_booking.deposit_amount, 0)),
            updated_at = NOW()
        WHERE booking_id = p_booking_id
          AND status = 'PENDING';
    END IF;

    UPDATE public.amenity_bookings
    SET booking_date = p_new_date,
        time_slot = p_new_time_slot,
        guests_count = v_final_guests,
        notes = COALESCE(p_new_notes, notes),
        status = v_booking.status,
        updated_at = NOW()
    WHERE id = p_booking_id;

    -- Đôn Waitlist cho slot cũ
    IF NOT v_is_same_slot THEN
        SELECT COALESCE(SUM(guests_count), 0), COUNT(*) 
        INTO v_old_slot_used_guests, v_old_slot_used_count
        FROM public.amenity_bookings
        WHERE amenity_id = v_booking.amenity_id
          AND booking_date = v_booking.booking_date
          AND time_slot = v_booking.time_slot
          AND status IN ('confirmed', 'pending_payment');

        v_old_slot_avail := v_amenity.max_capacity - v_old_slot_used_guests;

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
            IF (v_amenity.booking_type = 'exclusive' AND v_old_slot_used_count = 0)
               OR (v_amenity.booking_type = 'shared' AND v_next_waitlist.guests_count <= v_old_slot_avail) THEN
                
                v_promoted_fee := COALESCE(v_amenity.fee_amount, 0) * v_next_waitlist.guests_count;
                v_promoted_deposit := COALESCE(v_amenity.deposit_amount, 0);

                IF (v_promoted_fee + v_promoted_deposit) > 0 THEN
                    UPDATE public.amenity_bookings
                    SET status = 'pending_payment',
                        fee_amount = v_promoted_fee,
                        deposit_amount = v_promoted_deposit,
                        deposit_status = CASE WHEN v_promoted_deposit > 0 THEN 'pending' ELSE 'none' END,
                        updated_at = NOW()
                    WHERE id = v_next_waitlist.id;

                    SELECT id INTO v_existing_tx_id
                    FROM public.payment_transactions
                    WHERE booking_id = v_next_waitlist.id AND status = 'PENDING'
                    LIMIT 1;

                    IF v_existing_tx_id IS NOT NULL THEN
                        UPDATE public.payment_transactions
                        SET amount = (v_promoted_fee + v_promoted_deposit),
                            updated_at = NOW()
                        WHERE id = v_existing_tx_id;
                    ELSE
                        INSERT INTO public.payment_transactions (
                            booking_id, user_id, apartment_id, amount,
                            payment_method, status, transaction_code, type, title,
                            created_at, updated_at
                        ) VALUES (
                            v_next_waitlist.id, v_next_waitlist.booked_by, v_next_waitlist.apartment_id,
                            (v_promoted_fee + v_promoted_deposit), 'DEMO', 'PENDING',
                            'SVC' || to_char(now(), 'YYYYMMDDHH24MISS') || UPPER(SUBSTRING(gen_random_uuid()::text, 1, 4)),
                            'SERVICE', v_amenity.name || ' (' || v_booking.time_slot || ')',
                            NOW(), NOW()
                        );
                    END IF;
                ELSE
                    UPDATE public.amenity_bookings
                    SET status = 'confirmed', updated_at = NOW()
                    WHERE id = v_next_waitlist.id;
                END IF;

                v_waitlist_promoted := true;
            END IF;
        END IF;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'action', CASE 
            WHEN v_booking.status = 'confirmed' THEN 'rescheduled_confirmed'
            ELSE 'rescheduled_pending_payment'
        END,
        'status', v_booking.status,
        'waitlist_promoted', v_waitlist_promoted,
        'message', 'Đổi lịch đặt tiện ích thành công',
        'booking_id', p_booking_id,
        'new_date', p_new_date,
        'new_time_slot', p_new_time_slot
    );
END;
$$;

-- ------------------------------------------------------------------------------
-- 6. [P1] RPC ẨN DANH LỊCH TIỆN ÍCH (get_amenity_slot_availability) (MỤC #19)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_amenity_slot_availability(
    p_amenity_id UUID,
    p_date DATE
)
RETURNS TABLE (
    time_slot VARCHAR,
    status VARCHAR,
    guests_count INT,
    is_my_booking BOOLEAN
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
    SELECT 
        b.time_slot,
        b.status,
        b.guests_count,
        (b.booked_by = auth.uid()) AS is_my_booking
    FROM public.amenity_bookings b
    WHERE b.amenity_id = p_amenity_id
      AND b.booking_date = p_date
      AND b.status IN ('confirmed', 'waitlist', 'pending_payment');
$$;

REVOKE ALL ON FUNCTION public.get_amenity_slot_availability(UUID, DATE) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_amenity_slot_availability(UUID, DATE) TO authenticated;

-- ------------------------------------------------------------------------------
-- 7. [P1] ĐỒNG BỘ KEY JSON HÓA ĐƠN HÀNG LOẠT (MỤC #8, #9)
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
  v_total_scanned integer := 0;
  v_valid_count integer := 0;
  v_missing_count integer := 0;
  v_already_invoiced_count integer := 0;
  v_total_estimated_amount numeric := 0;
  
  v_issues jsonb := '[]'::jsonb;
  v_valid_items jsonb := '[]'::jsonb;
  
  v_apt record;
  v_sub_record record;
  v_prev_sub record;
  
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
  IF NOT public.is_admin_or_accountant() THEN
    RAISE EXCEPTION 'Chỉ Quản trị viên hoặc Kế toán mới có quyền đọc trước dữ liệu tính phí toàn tòa nhà';
  END IF;

  FOR v_apt IN
    SELECT id, code, area, electric_reading, water_reading
    FROM public.apartments
    WHERE is_empty = false
    ORDER BY code ASC
  LOOP
    v_total_scanned := v_total_scanned + 1;
    v_issue_found := false;

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

    SELECT * INTO v_sub_record
    FROM public.meter_reading_submissions
    WHERE apartment_id = v_apt.id AND period = p_period AND status = 'approved'
    ORDER BY created_at DESC
    LIMIT 1;

    IF FOUND THEN
      v_cur_elec := v_sub_record.electric_reading;
      v_cur_water := v_sub_record.water_reading;

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
        v_old_elec := COALESCE(v_apt.electric_reading, 0);
        v_old_water := COALESCE(v_apt.water_reading, 0);
      END IF;

      v_elec_usage := GREATEST(0, v_cur_elec - v_old_elec);
      v_water_usage := GREATEST(0, v_cur_water - v_old_water);
    ELSE
      v_cur_elec := v_apt.electric_reading;
      v_cur_water := v_apt.water_reading;
      v_old_elec := v_apt.electric_reading;
      v_old_water := v_apt.water_reading;
      v_elec_usage := 0;
      v_water_usage := 0;
    END IF;

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

    IF v_elec_usage < 0 OR v_water_usage < 0 THEN
      v_issues := v_issues || jsonb_build_object(
        'apartment_id', v_apt.id,
        'apartment_code', v_apt.code,
        'type', 'invalid_reading',
        'message', 'Chỉ số tiêu thụ điện hoặc nước không hợp lệ'
      );
      CONTINUE;
    END IF;

    v_mgmt_fee := ROUND(COALESCE(v_apt.area, 70) * p_mgmt_rate);

    SELECT 
      COUNT(*) FILTER (WHERE vehicle_type = 'motorbike'),
      COUNT(*) FILTER (WHERE vehicle_type = 'car')
    INTO v_motorbike_count, v_car_count
    FROM public.vehicles
    WHERE apartment_id = v_apt.id AND status = 'approved';

    v_parking_fee := (COALESCE(v_motorbike_count, 0) * 100000) + (COALESCE(v_car_count, 0) * 1200000);
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
      'total_amount', v_apt_total,
      'estimated_total', v_apt_total -- Đồng bộ với BulkInvoiceValidationModel Dart
    );
  END LOOP;

  RETURN jsonb_build_object(
    'period', p_period,
    'total_scanned', v_total_scanned,
    'valid_count', v_valid_count,
    'missing_count', v_missing_count,
    'already_invoiced_count', v_already_invoiced_count,
    'total_estimated_amount', v_total_estimated_amount,
    'issues', v_issues,
    'valid_items', v_valid_items
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.generate_valid_bulk_invoices(
    p_period text, 
    p_due_date date, 
    p_mgmt_rate numeric DEFAULT 16500, 
    p_electric_rate numeric DEFAULT 3500, 
    p_water_rate numeric DEFAULT 18000, 
    p_target_apartment_ids uuid[] DEFAULT NULL::uuid[]
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
  v_created_count integer := 0;
  v_skipped_count integer := 0;
  v_elec_qty numeric;
  v_water_qty numeric;
  v_parking_fee numeric;
  v_total_amount numeric;
  v_total_generated numeric := 0;
  v_res record;
BEGIN
  IF NOT public.is_admin_or_accountant() THEN
    RAISE EXCEPTION 'Chỉ Quản trị viên hoặc Kế toán mới có quyền lập hóa đơn hàng loạt';
  END IF;

  v_validation := public.validate_monthly_bulk_invoices(
    p_period, p_mgmt_rate, p_electric_rate, p_water_rate
  );

  FOR v_inv_record IN
    SELECT 
      (item->>'apartment_id')::uuid as apartment_id,
      item->>'apartment_code' as apartment_code,
      (item->>'area')::numeric as area,
      (item->>'electric_usage')::numeric as electric_usage,
      (item->>'water_usage')::numeric as water_usage,
      (item->>'motorbike_count')::integer as motorbike_count,
      (item->>'car_count')::integer as car_count,
      (item->>'total_amount')::numeric as total_amount
    FROM jsonb_array_elements(v_validation->'valid_items') as item
    WHERE p_target_apartment_ids IS NULL 
       OR (item->>'apartment_id')::uuid = ANY(p_target_apartment_ids)
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

      INSERT INTO public.invoices (
        apartment_id, period, due_date, total_amount, status, created_at, updated_at
      ) VALUES (
        v_inv_record.apartment_id, p_period, p_due_date, v_total_amount, 'unpaid', now(), now()
      ) RETURNING id INTO v_new_invoice_id;

      INSERT INTO public.invoice_items (invoice_id, fee_type, unit_price, quantity)
      VALUES (v_new_invoice_id, 'Phí quản lý vận hành', p_mgmt_rate, COALESCE(v_inv_record.area, 70));

      IF v_elec_qty > 0 THEN
        INSERT INTO public.invoice_items (invoice_id, fee_type, unit_price, quantity)
        VALUES (v_new_invoice_id, 'Tiền điện', p_electric_rate, v_elec_qty);
      END IF;

      IF v_water_qty > 0 THEN
        INSERT INTO public.invoice_items (invoice_id, fee_type, unit_price, quantity)
        VALUES (v_new_invoice_id, 'Tiền nước', p_water_rate, v_water_qty);
      END IF;

      IF COALESCE(v_inv_record.motorbike_count, 0) > 0 THEN
        INSERT INTO public.invoice_items (invoice_id, fee_type, unit_price, quantity)
        VALUES (v_new_invoice_id, 'Phí gửi xe máy', 100000, v_inv_record.motorbike_count);
      END IF;

      IF COALESCE(v_inv_record.car_count, 0) > 0 THEN
        INSERT INTO public.invoice_items (invoice_id, fee_type, unit_price, quantity)
        VALUES (v_new_invoice_id, 'Phí gửi ô tô', 1200000, v_inv_record.car_count);
      END IF;

      FOR v_res IN
        SELECT user_id FROM public.residents_apartments WHERE apartment_id = v_inv_record.apartment_id
      LOOP
        INSERT INTO public.notifications (
          user_id, apartment_id, title, body, type, payload
        ) VALUES (
          v_res.user_id, v_inv_record.apartment_id,
          'Hóa đơn dịch vụ mới kỳ ' || p_period,
          'Căn hộ ' || v_inv_record.apartment_code || ' có hóa đơn mới trị giá ' || to_char(v_total_amount, 'FM999,999,999') || ' đ. Hạn nộp: ' || to_char(p_due_date, 'DD/MM/YYYY'),
          'invoice_created',
          jsonb_build_object('invoice_id', v_new_invoice_id, 'period', p_period, 'total_amount', v_total_amount)
        );
      END LOOP;

      v_created_count := v_created_count + 1;
      v_total_generated := v_total_generated + v_total_amount;
      v_results := v_results || jsonb_build_object(
        'apartment_id', v_inv_record.apartment_id,
        'apartment_code', v_inv_record.apartment_code,
        'invoice_id', v_new_invoice_id,
        'total_amount', v_total_amount
      );
    ELSE
      v_skipped_count := v_skipped_count + 1;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'period', p_period,
    'due_date', p_due_date,
    'created_count', v_created_count,
    'invoices_created', v_created_count, -- Đồng bộ với BulkInvoiceDialog
    'skipped_count', v_skipped_count,
    'total_amount', v_total_generated,
    'invoices', v_results
  );
END;
$$;

-- ------------------------------------------------------------------------------
-- 8. [P1] KHỞI TẠO SỨC CHỨA VÀ HÌNH THỨC SỬ DỤNG CHO TIỆN ÍCH TÒA NHÀ
-- ------------------------------------------------------------------------------
UPDATE public.building_amenities
SET booking_type = 'shared', max_capacity = 30
WHERE name LIKE '%Hồ bơi%' OR name LIKE '%bể bơi%';

UPDATE public.building_amenities
SET booking_type = 'shared', max_capacity = 20
WHERE name LIKE '%Gym%' OR name LIKE '%Yoga%';

UPDATE public.building_amenities
SET booking_type = 'shared', max_capacity = 4
WHERE name LIKE '%Tennis%';

UPDATE public.building_amenities
SET booking_type = 'shared', max_capacity = 15
WHERE name LIKE '%BBQ%' OR name LIKE '%nướng%';

UPDATE public.building_amenities
SET booking_type = 'shared', max_capacity = 50
WHERE name LIKE '%sinh hoạt cộng đồng%';

-- Đảm bảo không còn tiện ích nào có max_capacity < 1
UPDATE public.building_amenities
SET max_capacity = 10
WHERE max_capacity <= 1 AND booking_type = 'shared';

-- ------------------------------------------------------------------------------
-- 9. [P2] BẢO MẬT STORAGE BUCKET issue-images (MỤC #21)
-- ------------------------------------------------------------------------------
UPDATE storage.buckets 
SET public = false 
WHERE id = 'issue-images';
