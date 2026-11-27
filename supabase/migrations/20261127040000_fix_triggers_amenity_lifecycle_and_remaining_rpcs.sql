-- ============================================================================
-- Migration 51: Fix Broken Triggers, Amenity Lifecycle, Bulk Invoice Engine & Remaining Global RBAC RPCs
-- Date: 2026-11-27
-- Purpose:
--   1. Fix runtime column/enum/ON CONFLICT crashes in triggers and operational RPCs:
--      - Add missing `apartment_link_requests.rejection_reason` column (42703 fix).
--      - Fix `book_amenity_slot` inserting nonexistent `payment_status` column (42703 fix),
--        add `can_access_apartment` & building match guard.
--      - Fix `check_amenity_booking_resident_update` invalid `'pending'` enum literal (22P02 fix),
--        support reschedule/waitlist bypass, and replace global `is_staff_or_management()`.
--      - Fix `handle_amenity_booking_cancellation` invalid `'per_slot'` enum literal (22P02 fix),
--        enable waitlist promotion bypass, fix exclusive slot loop, use `'VIETQR'` & populate building/apartment_id.
--      - Fix `reschedule_amenity_booking` setting `pka.in_reschedule = 'true'` and building RBAC.
--      - Fix `generate_valid_bulk_invoices` invalid `ON CONFLICT (apartment_id, period)` (42P10 fix),
--        standardize `fee_type` keys (`management`, `electricity`, `water`, `parking_motorbike`, `parking_car`),
--        remove duplicate notification loop (handled by `trg_notify_on_new_invoice`).
--      - Fix `create_invoice_with_items` calculating `total_amount` before inserting into `invoices`
--        so `trg_notify_on_new_invoice` notifies exact total amount instead of 0 đ.
--      - Fix `fn_notify_on_new_invoice` filtering active `residents_apartments`.
--      - Fix `batch_import_meter_readings` invalid `ON CONFLICT (apartment_id, period)` (42P10 fix).
--      - Fix `fn_notify_on_issue_status_change` invalid `'rejected'` enum check (`NEW.status::text = 'rejected'`).
--      - Fix `check_vehicle_limits` handling `'motorcycle'` and excluding `'cancelled'`.
--      - Fix `fn_generate_visitor_pass_code` branding prefix from `'PKAPASS:'` to `'VIVONAPASS:'`.
--      - Allow `pg_trigger_depth() > 0` in `detect_meter_reading_anomaly` and `record_apartment_ledger_entry`.
--   2. Replace ALL remaining `is_staff_or_management()` checks in operational RPCs with
--      building-scoped `is_building_staff(...)` / `can_access_apartment(...)`:
--      - `cancel_amenity_booking`, `cancel_apartment_link_request`, `cancel_pending_meter_reading`,
--        `update_pending_meter_reading`, `cancel_pending_vehicle`, `update_pending_vehicle`,
--        `get_co_residents`, `record_manual_amenity_payment`, `approve_meter_reading`,
--        `send_invoice_dunning_notifications`, `validate_monthly_bulk_invoices`.
--   3. Scope 4 previously unguarded read/calculator RPCs:
--      - `get_poll_results`, `get_amenity_slot_availability`,
--        `calculate_late_payment_penalty`, `calculate_visitor_parking_fee`.
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- 1. Schema fixes
-- ----------------------------------------------------------------------------
ALTER TABLE public.apartment_link_requests
    ADD COLUMN IF NOT EXISTS rejection_reason TEXT;

-- ----------------------------------------------------------------------------
-- 2. Trigger functions: fixes for crashes, enum casts, branding & search_path
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_notify_on_link_request_status()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
    v_apt RECORD;
    v_title TEXT;
    v_body TEXT;
BEGIN
    IF OLD.status IS DISTINCT FROM NEW.status AND NEW.status IN ('approved', 'rejected') THEN
        SELECT code, building_id INTO v_apt
        FROM public.apartments
        WHERE id = NEW.apartment_id;

        IF NEW.status = 'approved' THEN
            v_title := 'Yêu cầu liên kết căn hộ đã được phê duyệt';
            v_body := 'Yêu cầu liên kết với căn hộ/phòng ' || COALESCE(v_apt.code, '') || ' của bạn đã được Ban Quản Lý phê duyệt thành công.';
        ELSE
            v_title := 'Yêu cầu liên kết căn hộ không được duyệt';
            v_body := 'Yêu cầu liên kết với căn hộ/phòng ' || COALESCE(v_apt.code, '') || ' đã bị từ chối' ||
                      CASE WHEN NEW.rejection_reason IS NOT NULL AND NEW.rejection_reason != ''
                           THEN ': ' || NEW.rejection_reason
                           ELSE '.'
                      END;
        END IF;

        INSERT INTO public.notifications (
            building_id,
            user_id,
            apartment_id,
            title,
            body,
            type,
            payload,
            is_read,
            created_at
        ) VALUES (
            v_apt.building_id,
            NEW.user_id,
            NEW.apartment_id,
            v_title,
            v_body,
            'link_request',
            jsonb_build_object(
                'request_id', NEW.id,
                'apartment_id', NEW.apartment_id,
                'status', NEW.status,
                'rejection_reason', NEW.rejection_reason
            ),
            false,
            now()
        );
    END IF;

    RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.fn_notify_on_issue_status_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
    v_apt RECORD;
    v_title TEXT;
    v_body TEXT;
    v_desc_snippet TEXT;
BEGIN
    SELECT code, building_id INTO v_apt
    FROM public.apartments
    WHERE id = NEW.apartment_id;

    v_desc_snippet := substring(COALESCE(NEW.description, 'Sự cố') from 1 for 35);
    IF length(COALESCE(NEW.description, '')) > 35 THEN
        v_desc_snippet := v_desc_snippet || '...';
    END IF;

    IF OLD.status IS DISTINCT FROM NEW.status THEN
        IF NEW.status::text = 'in_progress' THEN
            v_title := 'Phản ánh sự cố đang được xử lý';
            v_body := 'Phản ánh "' || v_desc_snippet || '" đã được Ban Quản Lý tiếp nhận và đang tiến hành xử lý.';
        ELSIF NEW.status::text = 'resolved' THEN
            v_title := 'Phản ánh sự cố đã hoàn tất';
            v_body := 'Phản ánh "' || v_desc_snippet || '" đã được khắc phục hoàn tất. Vui lòng kiểm tra và đánh giá dịch vụ.';
        ELSIF NEW.status::text = 'rejected' THEN
            v_title := 'Thông báo về phản ánh sự cố';
            v_body := 'Phản ánh "' || v_desc_snippet || '" đã được Ban Quản Lý phản hồi/từ chối tiếp nhận.';
        ELSE
            v_title := 'Cập nhật tiến độ phản ánh sự cố';
            v_body := 'Phản ánh "' || v_desc_snippet || '" đã được cập nhật trạng thái mới: ' || NEW.status::text;
        END IF;

        IF NEW.reporter_id IS NOT NULL THEN
            INSERT INTO public.notifications (
                building_id,
                user_id,
                apartment_id,
                title,
                body,
                type,
                payload,
                is_read,
                created_at
            ) VALUES (
                v_apt.building_id,
                NEW.reporter_id,
                NEW.apartment_id,
                v_title,
                v_body,
                'issue_update',
                jsonb_build_object(
                    'issue_id', NEW.id,
                    'status', NEW.status::text,
                    'apartment_id', NEW.apartment_id
                ),
                false,
                now()
            );
        END IF;
    END IF;

    IF NEW.assigned_staff_id IS NOT NULL AND (OLD.assigned_staff_id IS DISTINCT FROM NEW.assigned_staff_id) THEN
        INSERT INTO public.notifications (
            building_id,
            user_id,
            apartment_id,
            title,
            body,
            type,
            payload,
            is_read,
            created_at
        ) VALUES (
            v_apt.building_id,
            NEW.assigned_staff_id,
            NEW.apartment_id,
            'Phân công nhiệm vụ xử lý sự cố',
            'Bạn vừa được phân công xử lý sự cố "' || v_desc_snippet || '" tại phòng ' || COALESCE(v_apt.code, '') || '.',
            'issue_update',
            jsonb_build_object(
                'issue_id', NEW.id,
                'status', NEW.status::text,
                'role', 'technician'
            ),
            false,
            now()
        );
    END IF;

    RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.fn_notify_on_new_invoice()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
    v_apt RECORD;
    v_res RECORD;
BEGIN
    SELECT code, building_id INTO v_apt
    FROM public.apartments
    WHERE id = NEW.apartment_id;

    FOR v_res IN
        SELECT DISTINCT user_id
        FROM public.residents_apartments
        WHERE apartment_id = NEW.apartment_id
          AND COALESCE(status, 'active') = 'active'
    LOOP
        INSERT INTO public.notifications (
            building_id,
            user_id,
            apartment_id,
            title,
            body,
            type,
            payload,
            is_read,
            created_at
        ) VALUES (
            v_apt.building_id,
            v_res.user_id,
            NEW.apartment_id,
            'Thông báo phát hành hóa đơn mới',
            'Hóa đơn kỳ ' || NEW.period || ' cho phòng ' || COALESCE(v_apt.code, '') || ' với số tiền ' || to_char(NEW.total_amount, 'FM999,999,999,999') || ' đ đã được phát hành. Hạn thanh toán: ' || to_char(NEW.due_date, 'DD/MM/YYYY') || '.',
            'new_invoice',
            jsonb_build_object(
                'invoice_id', NEW.id,
                'period', NEW.period,
                'amount', NEW.total_amount,
                'due_date', NEW.due_date
            ),
            false,
            now()
        );
    END LOOP;

    RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.check_vehicle_limits()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
    v_motorbike_count INT;
BEGIN
    IF NEW.vehicle_type IN ('motorbike', 'motorcycle')
       AND NEW.status NOT IN ('rejected', 'cancelled') THEN
        SELECT COUNT(*)
        INTO v_motorbike_count
        FROM public.vehicles
        WHERE apartment_id = NEW.apartment_id
          AND vehicle_type IN ('motorbike', 'motorcycle')
          AND status NOT IN ('rejected', 'cancelled')
          AND id != COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000'::uuid);

        IF v_motorbike_count >= 2 THEN
            RAISE EXCEPTION 'Mỗi căn hộ chỉ được đăng ký tối đa 2 xe máy.';
        END IF;
    END IF;

    RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.fn_generate_visitor_pass_code()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_catalog'
AS $function$
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
        NEW.qr_payload := 'VIVONAPASS:' || NEW.pass_code || ':' || SUBSTRING(gen_random_uuid()::TEXT FROM 1 FOR 8);
    END IF;

    NEW.updated_at := timezone('utc'::text, now());
    RETURN NEW;
END;
$function$;

-- ----------------------------------------------------------------------------
-- 3. Amenity booking lifecycle & RBAC fixes
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.check_amenity_booking_resident_update()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
  v_building_id UUID;
BEGIN
  IF current_setting('pka.in_reschedule', true) = 'true'
     OR current_setting('vivona.in_waitlist_promotion', true) = 'true'
     OR pg_trigger_depth() > 1
     OR COALESCE(auth.jwt() ->> 'role', '') = 'service_role' THEN
    RETURN NEW;
  END IF;

  SELECT building_id INTO v_building_id
  FROM public.building_amenities
  WHERE id = NEW.amenity_id;

  IF v_building_id IS NULL OR NOT public.is_building_staff(
      v_building_id,
      ARRAY['admin', 'management', 'manager', 'owner', 'staff']
  ) THEN
    IF NOT (
      NEW.status = 'cancelled' OR
      (NEW.status = 'confirmed' AND OLD.status IN ('pending_payment', 'waitlist')) OR
      (NEW.status = 'pending_payment' AND OLD.status = 'waitlist')
    ) THEN
      RAISE EXCEPTION 'Cư dân chỉ được phép hủy lịch hoặc hoàn tất thanh toán đặt chỗ tiện ích';
    END IF;

    IF NEW.amenity_id IS DISTINCT FROM OLD.amenity_id OR
       NEW.booking_date IS DISTINCT FROM OLD.booking_date OR
       NEW.time_slot IS DISTINCT FROM OLD.time_slot OR
       NEW.fee_amount IS DISTINCT FROM OLD.fee_amount OR
       NEW.booked_by IS DISTINCT FROM OLD.booked_by OR
       NEW.apartment_id IS DISTINCT FROM OLD.apartment_id THEN
      RAISE EXCEPTION 'Không được phép thay đổi thông tin cốt lõi của lượt đặt chỗ';
    END IF;
  END IF;

  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.handle_amenity_booking_cancellation()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
    v_amenity RECORD;
    v_waitlist_rec RECORD;
    v_available_capacity INT;
    v_current_confirmed_count INT;
    v_promoted_fee NUMERIC := 0;
    v_promoted_deposit NUMERIC := 0;
    v_existing_tx_id UUID;
BEGIN
    IF OLD.status <> 'cancelled' AND NEW.status = 'cancelled' THEN
        SELECT * INTO v_amenity FROM public.building_amenities WHERE id = NEW.amenity_id;
        IF NOT FOUND THEN RETURN NEW; END IF;

        IF v_amenity.booking_type = 'exclusive' THEN
            SELECT COUNT(*) INTO v_current_confirmed_count
            FROM public.amenity_bookings
            WHERE amenity_id = NEW.amenity_id
              AND booking_date = NEW.booking_date
              AND time_slot = NEW.time_slot
              AND status IN ('confirmed', 'pending_payment');

            IF v_current_confirmed_count > 0 THEN
                RETURN NEW;
            END IF;
            v_available_capacity := COALESCE(v_amenity.max_capacity, 1);
        ELSE
            SELECT COALESCE(SUM(guests_count), 0) INTO v_current_confirmed_count
            FROM public.amenity_bookings
            WHERE amenity_id = NEW.amenity_id
              AND booking_date = NEW.booking_date
              AND time_slot = NEW.time_slot
              AND status IN ('confirmed', 'pending_payment');

            v_available_capacity := COALESCE(v_amenity.max_capacity, 1) - v_current_confirmed_count;
        END IF;

        IF v_available_capacity <= 0 THEN
            RETURN NEW;
        END IF;

        PERFORM set_config('vivona.in_waitlist_promotion', 'true', true);

        FOR v_waitlist_rec IN
            SELECT id, booked_by, guests_count, apartment_id
            FROM public.amenity_bookings
            WHERE amenity_id = NEW.amenity_id
              AND booking_date = NEW.booking_date
              AND time_slot = NEW.time_slot
              AND status = 'waitlist'
              AND (v_amenity.booking_type = 'exclusive' OR guests_count <= v_available_capacity)
            ORDER BY created_at ASC
            FOR UPDATE SKIP LOCKED
        LOOP
            v_promoted_fee := CASE
                WHEN v_amenity.booking_type = 'shared' THEN COALESCE(v_amenity.fee_amount, 0) * v_waitlist_rec.guests_count
                ELSE COALESCE(v_amenity.fee_amount, 0)
            END;
            v_promoted_deposit := COALESCE(v_amenity.deposit_amount, 0);

            IF (v_promoted_fee + v_promoted_deposit) > 0 THEN
                UPDATE public.amenity_bookings
                SET status = 'pending_payment',
                    fee_amount = v_promoted_fee,
                    deposit_amount = v_promoted_deposit,
                    deposit_status = CASE WHEN v_promoted_deposit > 0 THEN 'pending' ELSE 'none' END,
                    updated_at = NOW()
                WHERE id = v_waitlist_rec.id;

                SELECT id INTO v_existing_tx_id
                FROM public.payment_transactions
                WHERE booking_id = v_waitlist_rec.id AND status = 'PENDING'
                LIMIT 1;

                IF v_existing_tx_id IS NOT NULL THEN
                    UPDATE public.payment_transactions
                    SET amount = (v_promoted_fee + v_promoted_deposit),
                        updated_at = NOW()
                    WHERE id = v_existing_tx_id;
                ELSE
                    INSERT INTO public.payment_transactions (
                        booking_id,
                        user_id,
                        apartment_id,
                        amount,
                        payment_method,
                        status,
                        transaction_code,
                        type,
                        title,
                        created_at,
                        updated_at
                    ) VALUES (
                        v_waitlist_rec.id,
                        v_waitlist_rec.booked_by,
                        v_waitlist_rec.apartment_id,
                        (v_promoted_fee + v_promoted_deposit),
                        'VIETQR',
                        'PENDING',
                        'SVC' || to_char(now(), 'YYYYMMDDHH24MISS') || UPPER(SUBSTRING(gen_random_uuid()::text, 1, 4)),
                        'SERVICE',
                        v_amenity.name || ' (' || NEW.time_slot || ')',
                        NOW(),
                        NOW()
                    );
                END IF;
            ELSE
                UPDATE public.amenity_bookings
                SET status = 'confirmed',
                    fee_amount = 0,
                    deposit_amount = 0,
                    deposit_status = 'none',
                    updated_at = NOW()
                WHERE id = v_waitlist_rec.id;
            END IF;

            INSERT INTO public.notifications (building_id, apartment_id, user_id, title, body, type, payload)
            VALUES (
                v_amenity.building_id,
                v_waitlist_rec.apartment_id,
                v_waitlist_rec.booked_by,
                'Đã có chỗ trống tiện ích ' || v_amenity.name,
                'Lượt đặt chỗ ngày ' || to_char(NEW.booking_date, 'DD/MM/YYYY') || ' khung giờ ' || NEW.time_slot || ' của bạn đã được chuyển từ danh sách chờ.',
                'amenity_promoted',
                jsonb_build_object('booking_id', v_waitlist_rec.id, 'amenity_id', NEW.amenity_id)
            );

            IF v_amenity.booking_type = 'exclusive' THEN
                EXIT;
            END IF;

            v_available_capacity := v_available_capacity - v_waitlist_rec.guests_count;
            IF v_available_capacity <= 0 THEN
                EXIT;
            END IF;
        END LOOP;

        PERFORM set_config('vivona.in_waitlist_promotion', 'false', true);
    END IF;
    RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.book_amenity_slot(
    p_amenity_id uuid,
    p_booking_date date,
    p_time_slot character varying,
    p_guests_count integer DEFAULT 1,
    p_apartment_id uuid DEFAULT NULL::uuid,
    p_allow_waitlist boolean DEFAULT true,
    p_notes text DEFAULT NULL::text
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
    v_user_id UUID;
    v_amenity RECORD;
    v_target_apartment UUID;
    v_apt_building_id UUID;
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
        RAISE EXCEPTION 'Chưa đăng nhập vào hệ thống.' USING ERRCODE = '42501';
    END IF;

    IF p_booking_date < CURRENT_DATE THEN
        RAISE EXCEPTION 'Không thể đặt lịch ngày trong quá khứ.';
    END IF;

    SELECT * INTO v_amenity
    FROM public.building_amenities
    WHERE id = p_amenity_id;

    IF NOT FOUND OR NOT v_amenity.is_active THEN
        RAISE EXCEPTION 'Tiện ích không tồn tại hoặc đang tạm ngưng phục vụ.';
    END IF;

    v_target_apartment := p_apartment_id;
    IF v_target_apartment IS NULL THEN
        SELECT ra.apartment_id INTO v_target_apartment
        FROM public.residents_apartments ra
        JOIN public.apartments a ON a.id = ra.apartment_id
        WHERE ra.user_id = v_user_id
          AND COALESCE(ra.status, 'active') = 'active'
          AND (v_amenity.building_id IS NULL OR a.building_id = v_amenity.building_id)
        ORDER BY ra.created_at ASC
        LIMIT 1;
    END IF;

    IF v_target_apartment IS NULL THEN
        RAISE EXCEPTION 'Người dùng chưa được liên kết với căn hộ phù hợp tại tòa nhà này.';
    END IF;

    IF NOT public.can_access_apartment(v_target_apartment) THEN
        RAISE EXCEPTION 'Truy cập bị từ chối: Bạn không có quyền đặt tiện ích cho căn hộ này.' USING ERRCODE = '42501';
    END IF;

    SELECT building_id INTO v_apt_building_id
    FROM public.apartments
    WHERE id = v_target_apartment;

    IF v_amenity.building_id IS NOT NULL AND v_apt_building_id IS DISTINCT FROM v_amenity.building_id THEN
        RAISE EXCEPTION 'Căn hộ được chọn không thuộc tòa nhà của tiện ích này.' USING ERRCODE = '22023';
    END IF;

    IF p_booking_date > (CURRENT_DATE + v_amenity.max_advance_days) THEN
        RAISE EXCEPTION 'Chỉ có thể đặt trước tối đa % ngày.', v_amenity.max_advance_days;
    END IF;

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

    v_lock_id := hashtext(p_amenity_id::text || '_' || p_booking_date::text || '_' || p_time_slot);
    PERFORM pg_advisory_xact_lock(v_lock_id);

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
        qr_ticket_token, notes, created_at, updated_at
    ) VALUES (
        p_amenity_id, v_target_apartment, v_user_id, p_booking_date, p_time_slot,
        p_guests_count, v_status, v_fee, v_deposit,
        CASE WHEN v_deposit > 0 THEN 'pending' ELSE 'none' END,
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
$function$;

CREATE OR REPLACE FUNCTION public.reschedule_amenity_booking(
    p_booking_id uuid,
    p_new_date date,
    p_new_time_slot character varying,
    p_new_guests_count integer DEFAULT NULL::integer,
    p_new_notes text DEFAULT NULL::text
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
    v_user_id UUID;
    v_booking RECORD;
    v_amenity RECORD;
    v_day_start TIMESTAMPTZ;
    v_day_end TIMESTAMPTZ;
    v_final_guests INT;
    v_current_slot_capacity INT;
    v_lock_id BIGINT;
    v_new_fee NUMERIC(12,2);
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Chưa đăng nhập vào hệ thống.' USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_booking
    FROM public.amenity_bookings
    WHERE id = p_booking_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Không tìm thấy lượt đặt tiện ích này.';
    END IF;

    SELECT * INTO v_amenity
    FROM public.building_amenities
    WHERE id = v_booking.amenity_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Không tìm thấy tiện ích tương ứng.';
    END IF;

    IF v_booking.booked_by <> v_user_id AND NOT (
        v_amenity.building_id IS NOT NULL
        AND public.is_building_staff(v_amenity.building_id, ARRAY['admin', 'management', 'manager', 'owner', 'staff'])
    ) THEN
        RAISE EXCEPTION 'Bạn không có quyền đổi lịch của người khác.' USING ERRCODE = '42501';
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

    v_lock_id := hashtext(v_booking.amenity_id::text || '_' || p_new_date::text || '_' || p_new_time_slot);
    PERFORM pg_advisory_xact_lock(v_lock_id);

    v_final_guests := COALESCE(p_new_guests_count, v_booking.guests_count, 1);
    IF v_final_guests < 1 THEN v_final_guests := 1; END IF;
    IF v_final_guests > v_amenity.max_capacity THEN
        RAISE EXCEPTION 'Số khách vượt quá sức chứa tối đa của tiện ích (% người)', v_amenity.max_capacity;
    END IF;

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

    v_new_fee := CASE
        WHEN v_amenity.booking_type = 'shared' THEN COALESCE(v_amenity.fee_amount, 0) * v_final_guests
        ELSE COALESCE(v_amenity.fee_amount, 0)
    END;

    PERFORM set_config('pka.in_reschedule', 'true', true);

    UPDATE public.amenity_bookings
    SET booking_date = p_new_date,
        time_slot = p_new_time_slot,
        guests_count = v_final_guests,
        fee_amount = v_new_fee,
        notes = COALESCE(p_new_notes, notes),
        updated_at = now()
    WHERE id = p_booking_id;

    PERFORM set_config('pka.in_reschedule', 'false', true);

    UPDATE public.payment_transactions
    SET amount = (v_new_fee + COALESCE(v_booking.deposit_amount, 0)),
        updated_at = now()
    WHERE booking_id = p_booking_id
      AND status = 'PENDING';

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Đổi lịch tiện ích thành công.',
        'booking_id', p_booking_id
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.cancel_amenity_booking(p_booking_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
    v_user_id UUID;
    v_booking RECORD;
    v_lock_id BIGINT;
    v_amenity RECORD;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Chưa đăng nhập.' USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_booking
    FROM public.amenity_bookings
    WHERE id = p_booking_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Không tìm thấy lịch đặt.';
    END IF;

    SELECT * INTO v_amenity
    FROM public.building_amenities
    WHERE id = v_booking.amenity_id;

    IF v_booking.booked_by <> v_user_id AND NOT (
        v_amenity.building_id IS NOT NULL
        AND public.is_building_staff(v_amenity.building_id, ARRAY['admin', 'management', 'manager', 'owner', 'staff'])
    ) THEN
        RAISE EXCEPTION 'Không có quyền hủy lịch này.' USING ERRCODE = '42501';
    END IF;

    IF v_booking.status = 'cancelled' THEN
        RETURN jsonb_build_object('success', false, 'message', 'Lịch này đã được hủy trước đó.');
    END IF;

    v_lock_id := hashtext(v_booking.amenity_id::text || '_' || v_booking.booking_date::text || '_' || v_booking.time_slot);
    PERFORM pg_advisory_xact_lock(v_lock_id);

    -- Trigger handle_amenity_booking_cancellation AFTER UPDATE tự động đôn danh sách chờ (Waitlist FIFO)
    UPDATE public.amenity_bookings
    SET status = 'cancelled', updated_at = now()
    WHERE id = p_booking_id;

    RETURN jsonb_build_object('success', true, 'message', 'Đã hủy lịch đặt thành công.');
END;
$function$;

-- ----------------------------------------------------------------------------
-- 4. Bulk invoice engine, invoice creation & meter batch import fixes
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.create_invoice_with_items(
    p_apartment_id uuid,
    p_period character varying,
    p_due_date date,
    p_items jsonb
)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
    v_building_id UUID;
    v_invoice_id UUID;
    v_item JSONB;
    v_unit_price NUMERIC(15,2);
    v_quantity NUMERIC(12,2);
    v_subtotal NUMERIC(15,2);
    v_total_amount NUMERIC(15,2) := 0;
BEGIN
    SELECT building_id INTO v_building_id FROM public.apartments WHERE id = p_apartment_id;
    IF v_building_id IS NULL THEN
        RAISE EXCEPTION 'Không tìm thấy căn hộ hợp lệ.' USING ERRCODE = '22023';
    END IF;

    IF NOT (
        COALESCE(auth.jwt() ->> 'role', '') = 'service_role'
        OR public.is_building_staff(v_building_id, ARRAY['admin', 'management', 'manager', 'owner', 'accountant'])
    ) THEN
        RAISE EXCEPTION 'Truy cập bị từ chối: Chỉ Ban Quản Lý hoặc Kế toán tòa nhà mới có quyền lập hóa đơn.'
            USING ERRCODE = '42501';
    END IF;

    -- Tính tổng tiền trước khi INSERT invoices để trigger trg_notify_on_new_invoice gửi đúng số tiền
    IF p_items IS NOT NULL AND jsonb_typeof(p_items) = 'array' AND jsonb_array_length(p_items) > 0 THEN
        FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
        LOOP
            v_unit_price := COALESCE((v_item->>'unit_price')::NUMERIC, 0);
            v_quantity := COALESCE((v_item->>'quantity')::NUMERIC, 1);
            IF v_unit_price < 0 OR v_quantity < 0 THEN
                RAISE EXCEPTION 'Đơn giá và số lượng hạng mục hóa đơn không được mang giá trị âm.'
                    USING ERRCODE = '22023';
            END IF;
            v_subtotal := ROUND(v_unit_price * v_quantity, 2);
            v_total_amount := v_total_amount + v_subtotal;
        END LOOP;
    END IF;

    INSERT INTO public.invoices (apartment_id, period, due_date, total_amount, status)
    VALUES (p_apartment_id, p_period, p_due_date, v_total_amount, 'unpaid'::public.invoice_status)
    RETURNING id INTO v_invoice_id;

    IF p_items IS NOT NULL AND jsonb_typeof(p_items) = 'array' AND jsonb_array_length(p_items) > 0 THEN
        FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
        LOOP
            v_unit_price := COALESCE((v_item->>'unit_price')::NUMERIC, 0);
            v_quantity := COALESCE((v_item->>'quantity')::NUMERIC, 1);

            INSERT INTO public.invoice_items (
                invoice_id, fee_type, unit_price, quantity
            ) VALUES (
                v_invoice_id,
                v_item->>'fee_type',
                v_unit_price,
                v_quantity
            );
        END LOOP;
    END IF;

    RETURN v_invoice_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.generate_valid_bulk_invoices(
    p_period text,
    p_due_date timestamp with time zone,
    p_target_apartment_ids uuid[] DEFAULT NULL::uuid[],
    p_mgmt_rate numeric DEFAULT 10000,
    p_electric_rate numeric DEFAULT 3500,
    p_water_rate numeric DEFAULT 18000
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
  v_is_service BOOLEAN := COALESCE(auth.jwt() ->> 'role', '') = 'service_role';
  v_apt RECORD;
  v_sub_record RECORD;
  v_invoice_id uuid;
  v_invoices_created integer := 0;
  v_skipped_count integer := 0;
  v_total_amount numeric := 0;
  v_elec_consumed numeric;
  v_water_consumed numeric;
  v_mgmt_fee numeric;
  v_parking_fee numeric;
  v_elec_fee numeric;
  v_water_fee numeric;
  v_apt_total numeric;
  v_motorbike_count integer;
  v_car_count integer;
BEGIN
  IF NOT (
    v_is_service
    OR EXISTS (
      SELECT 1 FROM public.user_buildings ub
      WHERE ub.user_id = auth.uid()
        AND LOWER(ub.role) = ANY(ARRAY['admin', 'management', 'manager', 'owner', 'accountant'])
    )
  ) THEN
    RAISE EXCEPTION 'Chỉ Ban Quản Lý mới có quyền phát hành hóa đơn hàng loạt' USING ERRCODE = '42501';
  END IF;

  FOR v_apt IN
    SELECT id, code, area, building_id
    FROM public.apartments
    WHERE is_empty = false
      AND (v_is_service OR building_id IN (SELECT public.get_user_accessible_buildings(auth.uid())))
      AND (p_target_apartment_ids IS NULL OR id = ANY(p_target_apartment_ids))
    ORDER BY code ASC
  LOOP
    IF NOT (
      v_is_service
      OR public.is_building_staff(v_apt.building_id, ARRAY['admin', 'management', 'manager', 'owner', 'accountant'])
    ) THEN
      v_skipped_count := v_skipped_count + 1;
      CONTINUE;
    END IF;

    IF EXISTS (
      SELECT 1 FROM public.invoices
      WHERE apartment_id = v_apt.id AND period = p_period AND status != 'cancelled'
    ) THEN
      v_skipped_count := v_skipped_count + 1;
      CONTINUE;
    END IF;

    SELECT electric_consumed, water_consumed INTO v_sub_record
    FROM public.meter_reading_submissions
    WHERE apartment_id = v_apt.id AND period = p_period AND status = 'approved'
    ORDER BY created_at DESC
    LIMIT 1;

    v_elec_consumed := CASE WHEN FOUND THEN GREATEST(0, COALESCE(v_sub_record.electric_consumed, 0)) ELSE 0 END;
    v_water_consumed := CASE WHEN FOUND THEN GREATEST(0, COALESCE(v_sub_record.water_consumed, 0)) ELSE 0 END;

    v_mgmt_fee := ROUND(COALESCE(v_apt.area, 70) * p_mgmt_rate);

    SELECT
      COUNT(*) FILTER (WHERE vehicle_type IN ('motorbike', 'motorcycle')),
      COUNT(*) FILTER (WHERE vehicle_type = 'car')
    INTO v_motorbike_count, v_car_count
    FROM public.vehicles
    WHERE apartment_id = v_apt.id AND status = 'approved';

    v_parking_fee := (v_motorbike_count * 100000) + (v_car_count * 1200000);
    v_elec_fee := ROUND(v_elec_consumed * p_electric_rate);
    v_water_fee := ROUND(v_water_consumed * p_water_rate);
    v_apt_total := v_mgmt_fee + v_parking_fee + v_elec_fee + v_water_fee;

    -- Trigger trg_notify_on_new_invoice tự động gửi thông báo hóa đơn mới cho cư dân
    INSERT INTO public.invoices (
      apartment_id, period, due_date, total_amount, status, created_at, updated_at
    ) VALUES (
      v_apt.id, p_period, p_due_date::date, v_apt_total, 'unpaid'::public.invoice_status, now(), now()
    )
    RETURNING id INTO v_invoice_id;

    INSERT INTO public.invoice_items (invoice_id, fee_type, unit_price, quantity)
    VALUES
      (v_invoice_id, 'management', p_mgmt_rate, COALESCE(v_apt.area, 70)),
      (v_invoice_id, 'electricity', p_electric_rate, v_elec_consumed),
      (v_invoice_id, 'water', p_water_rate, v_water_consumed);

    IF v_motorbike_count > 0 THEN
      INSERT INTO public.invoice_items (invoice_id, fee_type, unit_price, quantity)
      VALUES (v_invoice_id, 'parking_motorbike', 100000, v_motorbike_count);
    END IF;

    IF v_car_count > 0 THEN
      INSERT INTO public.invoice_items (invoice_id, fee_type, unit_price, quantity)
      VALUES (v_invoice_id, 'parking_car', 1200000, v_car_count);
    END IF;

    v_invoices_created := v_invoices_created + 1;
    v_total_amount := v_total_amount + v_apt_total;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'period', p_period,
    'invoices_created', v_invoices_created,
    'skipped_count', v_skipped_count,
    'total_amount', v_total_amount,
    'message', 'Đã phát hành ' || v_invoices_created || ' hóa đơn thành công'
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.validate_monthly_bulk_invoices(
    p_period text,
    p_mgmt_rate numeric DEFAULT 10000,
    p_electric_rate numeric DEFAULT 3500,
    p_water_rate numeric DEFAULT 18000
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
  v_is_service BOOLEAN := COALESCE(auth.jwt() ->> 'role', '') = 'service_role';
  v_apt RECORD;
  v_total_scanned integer := 0;
  v_valid_count integer := 0;
  v_already_invoiced_count integer := 0;
  v_total_estimated_amount numeric := 0;
  v_valid_items jsonb := '[]'::jsonb;
  v_issues jsonb := '[]'::jsonb;
  v_sub_record RECORD;
  v_elec_consumed numeric;
  v_water_consumed numeric;
  v_mgmt_fee numeric;
  v_parking_fee numeric;
  v_elec_fee numeric;
  v_water_fee numeric;
  v_apt_total numeric;
  v_motorbike_count integer;
  v_car_count integer;
BEGIN
  IF NOT (
    v_is_service
    OR EXISTS (
      SELECT 1 FROM public.user_buildings ub
      WHERE ub.user_id = auth.uid()
        AND LOWER(ub.role) = ANY(ARRAY['admin', 'management', 'manager', 'owner', 'accountant'])
    )
  ) THEN
    RAISE EXCEPTION 'Chỉ Ban Quản Lý mới có quyền tiền kiểm tra hóa đơn hàng loạt' USING ERRCODE = '42501';
  END IF;

  FOR v_apt IN
    SELECT id, code, area, building_id
    FROM public.apartments
    WHERE is_empty = false
      AND (v_is_service OR building_id IN (SELECT public.get_user_accessible_buildings(auth.uid())))
    ORDER BY code ASC
  LOOP
    IF NOT (
      v_is_service
      OR public.is_building_staff(v_apt.building_id, ARRAY['admin', 'management', 'manager', 'owner', 'accountant'])
    ) THEN
      CONTINUE;
    END IF;

    v_total_scanned := v_total_scanned + 1;

    IF EXISTS (
      SELECT 1 FROM public.invoices
      WHERE apartment_id = v_apt.id AND period = p_period AND status != 'cancelled'
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

    SELECT electric_consumed, water_consumed INTO v_sub_record
    FROM public.meter_reading_submissions
    WHERE apartment_id = v_apt.id AND period = p_period AND status = 'approved'
    ORDER BY created_at DESC
    LIMIT 1;

    IF FOUND THEN
      v_elec_consumed := GREATEST(0, COALESCE(v_sub_record.electric_consumed, 0));
      v_water_consumed := GREATEST(0, COALESCE(v_sub_record.water_consumed, 0));
    ELSE
      v_elec_consumed := 0;
      v_water_consumed := 0;
    END IF;

    v_mgmt_fee := ROUND(COALESCE(v_apt.area, 70) * p_mgmt_rate);

    SELECT
      COUNT(*) FILTER (WHERE vehicle_type IN ('motorbike', 'motorcycle')),
      COUNT(*) FILTER (WHERE vehicle_type = 'car')
    INTO v_motorbike_count, v_car_count
    FROM public.vehicles
    WHERE apartment_id = v_apt.id AND status = 'approved';

    v_parking_fee := (v_motorbike_count * 100000) + (v_car_count * 1200000);
    v_elec_fee := ROUND(v_elec_consumed * p_electric_rate);
    v_water_fee := ROUND(v_water_consumed * p_water_rate);
    v_apt_total := v_mgmt_fee + v_parking_fee + v_elec_fee + v_water_fee;

    v_valid_count := v_valid_count + 1;
    v_total_estimated_amount := v_total_estimated_amount + v_apt_total;
    v_valid_items := v_valid_items || jsonb_build_object(
      'apartment_id', v_apt.id,
      'apartment_code', v_apt.code,
      'total_amount', v_apt_total
    );
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'period', p_period,
    'total_scanned', v_total_scanned,
    'valid_count', v_valid_count,
    'already_invoiced_count', v_already_invoiced_count,
    'total_estimated_amount', v_total_estimated_amount,
    'valid_items', v_valid_items,
    'issues', v_issues
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.batch_import_meter_readings(
    p_building_id uuid,
    p_period text,
    p_readings jsonb
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
    v_is_service BOOLEAN := COALESCE(auth.jwt() ->> 'role', '') = 'service_role';
    v_calling_user_id UUID := auth.uid();
    v_item JSONB;
    v_apt_code TEXT;
    v_elec NUMERIC;
    v_water NUMERIC;
    v_apt_id UUID;
    v_existing_id UUID;
    v_success_count INT := 0;
    v_imported_codes JSONB := '[]'::jsonb;
BEGIN
    IF p_building_id IS NULL THEN
        RAISE EXCEPTION 'Thiếu mã tòa nhà (p_building_id).' USING ERRCODE = '22023';
    END IF;

    IF NOT (
        v_is_service
        OR (
            v_calling_user_id IS NOT NULL
            AND public.is_building_staff(
                p_building_id,
                ARRAY['admin', 'management', 'manager', 'owner', 'accountant', 'technician', 'staff']
            )
        )
    ) THEN
        RAISE EXCEPTION 'Truy cập bị từ chối: Bạn không có quyền nhập chỉ số điện nước hàng loạt cho tòa nhà này.'
            USING ERRCODE = '42501';
    END IF;

    FOR v_item IN SELECT * FROM jsonb_array_elements(p_readings)
    LOOP
        v_apt_code := UPPER(TRIM(v_item->>'apartment_code'));
        v_elec := COALESCE((v_item->>'electric_reading')::numeric, 0.0);
        v_water := COALESCE((v_item->>'water_reading')::numeric, 0.0);

        SELECT id INTO v_apt_id
        FROM public.apartments
        WHERE UPPER(code) = v_apt_code
          AND building_id = p_building_id
        LIMIT 1;

        IF v_apt_id IS NOT NULL THEN
            SELECT id INTO v_existing_id
            FROM public.meter_reading_submissions
            WHERE apartment_id = v_apt_id
              AND period = p_period
              AND status <> 'cancelled'
            ORDER BY created_at DESC
            LIMIT 1
            FOR UPDATE;

            IF v_existing_id IS NOT NULL THEN
                UPDATE public.meter_reading_submissions
                SET electric_reading = v_elec,
                    water_reading = v_water,
                    status = 'approved'::public.meter_submission_status,
                    reviewed_by = v_calling_user_id,
                    reviewed_at = CURRENT_TIMESTAMP,
                    updated_at = CURRENT_TIMESTAMP
                WHERE id = v_existing_id;
            ELSE
                INSERT INTO public.meter_reading_submissions (
                    apartment_id,
                    period,
                    electric_reading,
                    water_reading,
                    status,
                    submitted_by,
                    reviewed_by,
                    reviewed_at,
                    created_at,
                    updated_at
                )
                VALUES (
                    v_apt_id,
                    p_period,
                    v_elec,
                    v_water,
                    'approved'::public.meter_submission_status,
                    COALESCE(v_calling_user_id, v_apt_id),
                    v_calling_user_id,
                    CURRENT_TIMESTAMP,
                    CURRENT_TIMESTAMP,
                    CURRENT_TIMESTAMP
                );
            END IF;

            v_success_count := v_success_count + 1;
            v_imported_codes := v_imported_codes || jsonb_build_array(v_apt_code);
        END IF;
    END LOOP;

    RETURN jsonb_build_object(
        'success', TRUE,
        'success_count', v_success_count,
        'imported_codes', v_imported_codes
    );
END;
$function$;

-- ----------------------------------------------------------------------------
-- 5. Allow internal triggers to call anomaly detector & ledger poster safely
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.detect_meter_reading_anomaly(
    p_apartment_id uuid,
    p_electric_reading numeric,
    p_water_reading numeric,
    p_period character varying DEFAULT NULL::character varying
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
    v_is_service BOOLEAN := COALESCE(auth.jwt() ->> 'role', '') = 'service_role';
    v_prev_sub RECORD;
    v_avg_elec NUMERIC := NULL;
    v_avg_water NUMERIC := NULL;
    v_is_anomaly BOOLEAN := false;
    v_severity VARCHAR(20) := 'normal';
    v_reasons TEXT[] := ARRAY[]::TEXT[];
    v_elec_delta NUMERIC := 0.0;
    v_water_delta NUMERIC := 0.0;
    v_elec_pct NUMERIC := NULL;
    v_water_pct NUMERIC := NULL;
BEGIN
    IF NOT (v_is_service OR pg_trigger_depth() > 0 OR public.can_access_apartment(p_apartment_id)) THEN
        RAISE EXCEPTION 'Truy cập bị từ chối: Bạn không có quyền kiểm tra bất thường chỉ số của căn hộ này.'
            USING ERRCODE = '42501';
    END IF;

    SELECT electric_reading, water_reading INTO v_prev_sub
    FROM public.meter_reading_submissions
    WHERE apartment_id = p_apartment_id
      AND status = 'approved'
      AND (p_period IS NULL OR period < p_period)
    ORDER BY created_at DESC
    LIMIT 1;

    WITH recent_readings AS (
        SELECT
            electric_reading - LAG(electric_reading) OVER (ORDER BY created_at) AS e_diff,
            water_reading - LAG(water_reading) OVER (ORDER BY created_at) AS w_diff
        FROM public.meter_reading_submissions
        WHERE apartment_id = p_apartment_id
          AND status = 'approved'
          AND (p_period IS NULL OR period < p_period)
        ORDER BY created_at DESC
        LIMIT 4
    )
    SELECT
        ROUND(AVG(e_diff)::numeric, 1),
        ROUND(AVG(w_diff)::numeric, 1)
    INTO v_avg_elec, v_avg_water
    FROM recent_readings
    WHERE e_diff IS NOT NULL AND w_diff IS NOT NULL AND e_diff >= 0 AND w_diff >= 0;

    IF v_prev_sub.electric_reading IS NOT NULL THEN
        v_elec_delta := p_electric_reading - v_prev_sub.electric_reading;

        IF v_elec_delta < 0 THEN
            v_is_anomaly := true;
            v_severity := 'danger';
            v_reasons := array_append(v_reasons, format('Chỉ số điện mới (%s kWh) nhỏ hơn chỉ số kỳ trước (%s kWh).', p_electric_reading, v_prev_sub.electric_reading));
        ELSIF v_avg_elec IS NOT NULL AND v_avg_elec > 0 THEN
            v_elec_pct := ROUND(((v_elec_delta - v_avg_elec) / v_avg_elec * 100)::numeric, 1);
            IF v_elec_delta >= v_avg_elec * 2.5 AND (v_elec_delta - v_avg_elec) >= 40 THEN
                v_is_anomaly := true;
                v_severity := 'danger';
                v_reasons := array_append(v_reasons, format('Tiêu thụ điện tăng đột biến %s%% (%s kWh so với trung bình %s kWh).', v_elec_pct, v_elec_delta, v_avg_elec));
            ELSIF v_elec_delta >= v_avg_elec * 1.5 AND (v_elec_delta - v_avg_elec) >= 20 THEN
                v_is_anomaly := true;
                IF v_severity <> 'danger' THEN v_severity := 'warning'; END IF;
                v_reasons := array_append(v_reasons, format('Tiêu thụ điện tăng cao %s%% so với mức trung bình (%s kWh).', v_elec_pct, v_avg_elec));
            END IF;
        END IF;
    END IF;

    IF v_prev_sub.water_reading IS NOT NULL THEN
        v_water_delta := p_water_reading - v_prev_sub.water_reading;

        IF v_water_delta < 0 THEN
            v_is_anomaly := true;
            v_severity := 'danger';
            v_reasons := array_append(v_reasons, format('Chỉ số nước mới (%s m³) nhỏ hơn chỉ số kỳ trước (%s m³).', p_water_reading, v_prev_sub.water_reading));
        ELSIF v_avg_water IS NOT NULL AND v_avg_water > 0 THEN
            v_water_pct := ROUND(((v_water_delta - v_avg_water) / v_avg_water * 100)::numeric, 1);
            IF v_water_delta >= v_avg_water * 2.5 AND (v_water_delta - v_avg_water) >= 5 THEN
                v_is_anomaly := true;
                v_severity := 'danger';
                v_reasons := array_append(v_reasons, format('Tiêu thụ nước tăng đột biến %s%% (%s m³ so với trung bình %s m³ - Nghi ngờ rò rỉ).', v_water_pct, v_water_delta, v_avg_water));
            ELSIF v_water_delta >= v_avg_water * 1.5 AND (v_water_delta - v_avg_water) >= 3 THEN
                v_is_anomaly := true;
                IF v_severity <> 'danger' THEN v_severity := 'warning'; END IF;
                v_reasons := array_append(v_reasons, format('Tiêu thụ nước tăng cao %s%% so với mức trung bình (%s m³).', v_water_pct, v_avg_water));
            END IF;
        END IF;
    END IF;

    RETURN jsonb_build_object(
        'is_anomaly', v_is_anomaly,
        'anomaly_severity', v_severity,
        'anomaly_reason', array_to_string(v_reasons, ' | '),
        'previous_electric_reading', v_prev_sub.electric_reading,
        'previous_water_reading', v_prev_sub.water_reading,
        'avg_electric_usage', v_avg_elec,
        'avg_water_usage', v_avg_water,
        'electric_delta', v_elec_delta,
        'water_delta', v_water_delta,
        'electric_percent_change', v_elec_pct,
        'water_percent_change', v_water_pct
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.record_apartment_ledger_entry(
    p_building_id uuid,
    p_apartment_id uuid,
    p_entry_type character varying,
    p_amount numeric,
    p_period character varying,
    p_reference_type character varying,
    p_reference_id uuid DEFAULT NULL::uuid,
    p_description text DEFAULT ''::text,
    p_created_by uuid DEFAULT NULL::uuid
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
    v_is_service BOOLEAN := COALESCE(auth.jwt() ->> 'role', '') = 'service_role';
    v_effective_creator UUID;
    v_apt_building_id UUID;
    v_current_balance NUMERIC(15,2) := 0.00;
    v_new_balance NUMERIC(15,2);
    v_entry_code TEXT;
    v_seq INT;
    v_entry_id UUID;
BEGIN
    SELECT building_id INTO v_apt_building_id
    FROM public.apartments
    WHERE id = p_apartment_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Không tìm thấy căn hộ mục tiêu.' USING ERRCODE = '22023';
    END IF;

    IF v_apt_building_id IS DISTINCT FROM p_building_id THEN
        RAISE EXCEPTION 'Căn hộ không thuộc tòa nhà được chỉ định.' USING ERRCODE = '22023';
    END IF;

    IF NOT (
        v_is_service
        OR pg_trigger_depth() > 0
        OR public.is_building_staff(
            p_building_id,
            ARRAY['admin', 'management', 'manager', 'owner', 'accountant']
        )
    ) THEN
        RAISE EXCEPTION 'Truy cập bị từ chối: Chỉ Ban Quản Lý hoặc Kế toán tòa nhà mới có quyền ghi bút toán sổ cái.'
            USING ERRCODE = '42501';
    END IF;

    IF p_amount <= 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Số tiền bút toán phải lớn hơn 0');
    END IF;

    v_effective_creator := CASE
        WHEN v_is_service OR pg_trigger_depth() > 0 THEN COALESCE(p_created_by, auth.uid())
        ELSE auth.uid()
    END;

    SELECT balance_after INTO v_current_balance
    FROM public.apartment_ledger_entries
    WHERE apartment_id = p_apartment_id
    ORDER BY created_at DESC, id DESC
    LIMIT 1;

    IF v_current_balance IS NULL THEN
        v_current_balance := 0.00;
    END IF;

    IF p_entry_type IN ('DEBIT', 'DEBIT_NOTE', 'REFUND') THEN
        v_new_balance := v_current_balance + p_amount;
    ELSIF p_entry_type IN ('CREDIT', 'CREDIT_NOTE') THEN
        v_new_balance := v_current_balance - p_amount;
    ELSE
        RETURN jsonb_build_object('success', false, 'error', 'Loại bút toán không hợp lệ: ' || p_entry_type);
    END IF;

    SELECT COALESCE(MAX(SUBSTRING(entry_code FROM 11)::INT), 0) + 1 INTO v_seq
    FROM public.apartment_ledger_entries
    WHERE entry_code LIKE 'LE-' || REPLACE(p_period, '-', '') || '-%';

    v_entry_code := 'LE-' || REPLACE(p_period, '-', '') || '-' || LPAD(v_seq::TEXT, 5, '0');

    INSERT INTO public.apartment_ledger_entries (
        building_id,
        apartment_id,
        entry_code,
        entry_type,
        amount,
        balance_after,
        period,
        reference_type,
        reference_id,
        description,
        created_by,
        created_at
    ) VALUES (
        p_building_id,
        p_apartment_id,
        v_entry_code,
        p_entry_type,
        p_amount,
        v_new_balance,
        p_period,
        p_reference_type,
        p_reference_id,
        p_description,
        v_effective_creator,
        now()
    )
    RETURNING id INTO v_entry_id;

    RETURN jsonb_build_object(
        'success', true,
        'entry_id', v_entry_id,
        'entry_code', v_entry_code,
        'balance_after', v_new_balance
    );
END;
$function$;

-- ----------------------------------------------------------------------------
-- 6. Replace all remaining `is_staff_or_management()` checks with building RBAC
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.cancel_apartment_link_request(p_request_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
    v_user_id UUID := auth.uid();
    v_req RECORD;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Bạn chưa đăng nhập vào hệ thống' USING ERRCODE = '42501';
    END IF;

    SELECT r.id, r.user_id, r.status, a.building_id
    INTO v_req
    FROM public.apartment_link_requests r
    JOIN public.apartments a ON a.id = r.apartment_id
    WHERE r.id = p_request_id
    FOR UPDATE OF r;

    IF NOT FOUND OR v_req.status <> 'pending' THEN
        RAISE EXCEPTION 'Không tìm thấy yêu cầu liên kết đang chờ duyệt để hủy.';
    END IF;

    IF v_req.user_id <> v_user_id AND NOT (
        v_req.building_id IS NOT NULL
        AND public.is_building_staff(v_req.building_id, ARRAY['admin', 'management', 'manager', 'owner', 'staff'])
    ) THEN
        RAISE EXCEPTION 'Bạn không có quyền hủy yêu cầu liên kết này.' USING ERRCODE = '42501';
    END IF;

    UPDATE public.apartment_link_requests
    SET status = 'cancelled', updated_at = NOW()
    WHERE id = p_request_id;

    RETURN jsonb_build_object('success', true, 'message', 'Đã hủy yêu cầu liên kết căn hộ thành công', 'request_id', p_request_id);
END;
$function$;

CREATE OR REPLACE FUNCTION public.cancel_pending_meter_reading(p_submission_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
    v_user_id UUID := auth.uid();
    v_sub RECORD;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Bạn chưa đăng nhập vào hệ thống' USING ERRCODE = '42501';
    END IF;

    SELECT m.id, m.submitted_by, m.status, a.building_id
    INTO v_sub
    FROM public.meter_reading_submissions m
    JOIN public.apartments a ON a.id = m.apartment_id
    WHERE m.id = p_submission_id
    FOR UPDATE OF m;

    IF NOT FOUND OR v_sub.status <> 'pending' THEN
        RAISE EXCEPTION 'Không tìm thấy phiếu chỉ số đang chờ duyệt để hủy.';
    END IF;

    IF v_sub.submitted_by <> v_user_id AND NOT (
        v_sub.building_id IS NOT NULL
        AND public.is_building_staff(v_sub.building_id, ARRAY['admin', 'management', 'manager', 'owner', 'technician', 'staff'])
    ) THEN
        RAISE EXCEPTION 'Bạn không có quyền hủy phiếu chỉ số này.' USING ERRCODE = '42501';
    END IF;

    UPDATE public.meter_reading_submissions
    SET status = 'cancelled', updated_at = NOW()
    WHERE id = p_submission_id;

    RETURN jsonb_build_object('success', true, 'message', 'Đã hủy phiếu khai báo chỉ số thành công', 'submission_id', p_submission_id);
END;
$function$;

CREATE OR REPLACE FUNCTION public.update_pending_meter_reading(
    p_submission_id uuid,
    p_electric_reading numeric,
    p_water_reading numeric,
    p_electric_image_url text DEFAULT NULL::text,
    p_water_image_url text DEFAULT NULL::text,
    p_clear_electric_image boolean DEFAULT false,
    p_clear_water_image boolean DEFAULT false
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
    v_user_id UUID := auth.uid();
    v_sub RECORD;
    v_building_id UUID;
    v_new_elec_img TEXT;
    v_new_water_img TEXT;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Bạn chưa đăng nhập vào hệ thống' USING ERRCODE = '42501';
    END IF;

    IF p_electric_reading < 0 OR p_water_reading < 0 THEN
        RAISE EXCEPTION 'Chỉ số điện và nước không được mang giá trị âm.';
    END IF;

    SELECT * INTO v_sub
    FROM public.meter_reading_submissions
    WHERE id = p_submission_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Phiếu khai báo chỉ số không tồn tại';
    END IF;

    IF v_sub.status != 'pending' THEN
        RAISE EXCEPTION 'Chỉ có thể chỉnh sửa phiếu chỉ số đang ở trạng thái chờ duyệt (pending).';
    END IF;

    SELECT building_id INTO v_building_id
    FROM public.apartments
    WHERE id = v_sub.apartment_id;

    IF v_sub.submitted_by != v_user_id AND NOT (
        v_building_id IS NOT NULL
        AND public.is_building_staff(v_building_id, ARRAY['admin', 'management', 'manager', 'owner', 'technician', 'staff'])
    ) THEN
        RAISE EXCEPTION 'Bạn không có quyền chỉnh sửa phiếu chỉ số này.' USING ERRCODE = '42501';
    END IF;

    IF p_clear_electric_image THEN
        v_new_elec_img := NULL;
    ELSIF p_electric_image_url IS NOT NULL THEN
        v_new_elec_img := p_electric_image_url;
    ELSE
        v_new_elec_img := v_sub.electric_image_url;
    END IF;

    IF p_clear_water_image THEN
        v_new_water_img := NULL;
    ELSIF p_water_image_url IS NOT NULL THEN
        v_new_water_img := p_water_image_url;
    ELSE
        v_new_water_img := v_sub.water_image_url;
    END IF;

    UPDATE public.meter_reading_submissions
    SET electric_reading = p_electric_reading,
        water_reading = p_water_reading,
        electric_image_url = v_new_elec_img,
        water_image_url = v_new_water_img,
        updated_at = NOW()
    WHERE id = p_submission_id AND status = 'pending';

    RETURN jsonb_build_object('success', true, 'message', 'Đã cập nhật chỉ số điện nước thành công', 'submission_id', p_submission_id);
END;
$function$;

CREATE OR REPLACE FUNCTION public.cancel_pending_vehicle(p_vehicle_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
    v_user_id UUID := auth.uid();
    v_vehicle RECORD;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Bạn chưa đăng nhập vào hệ thống' USING ERRCODE = '42501';
    END IF;

    SELECT v.id, v.user_id, v.status, a.building_id
    INTO v_vehicle
    FROM public.vehicles v
    JOIN public.apartments a ON a.id = v.apartment_id
    WHERE v.id = p_vehicle_id
    FOR UPDATE OF v;

    IF NOT FOUND OR v_vehicle.status <> 'pending' THEN
        RAISE EXCEPTION 'Không tìm thấy phương tiện đang chờ duyệt để hủy.';
    END IF;

    IF v_vehicle.user_id <> v_user_id AND NOT (
        v_vehicle.building_id IS NOT NULL
        AND public.is_building_staff(v_vehicle.building_id, ARRAY['admin', 'management', 'manager', 'owner', 'staff'])
    ) THEN
        RAISE EXCEPTION 'Bạn không có quyền hủy bản ghi này.' USING ERRCODE = '42501';
    END IF;

    UPDATE public.vehicles
    SET status = 'cancelled', updated_at = NOW()
    WHERE id = p_vehicle_id;

    RETURN jsonb_build_object('success', true, 'message', 'Đã hủy đăng ký phương tiện thành công', 'vehicle_id', p_vehicle_id);
END;
$function$;

CREATE OR REPLACE FUNCTION public.update_pending_vehicle(
    p_vehicle_id uuid,
    p_license_plate character varying,
    p_vehicle_type character varying,
    p_brand_model character varying DEFAULT NULL::character varying
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
    v_user_id UUID := auth.uid();
    v_vehicle RECORD;
    v_building_id UUID;
    v_clean_plate VARCHAR;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Bạn chưa đăng nhập vào hệ thống' USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_vehicle
    FROM public.vehicles
    WHERE id = p_vehicle_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Phương tiện không tồn tại';
    END IF;

    IF v_vehicle.status != 'pending' THEN
        RAISE EXCEPTION 'Chỉ có thể chỉnh sửa phương tiện đang ở trạng thái chờ duyệt (pending).';
    END IF;

    SELECT building_id INTO v_building_id
    FROM public.apartments
    WHERE id = v_vehicle.apartment_id;

    IF v_vehicle.user_id != v_user_id AND NOT (
        v_building_id IS NOT NULL
        AND public.is_building_staff(v_building_id, ARRAY['admin', 'management', 'manager', 'owner', 'staff'])
    ) THEN
        RAISE EXCEPTION 'Bạn không có quyền chỉnh sửa thông tin phương tiện này.' USING ERRCODE = '42501';
    END IF;

    v_clean_plate := UPPER(TRIM(p_license_plate));
    IF v_clean_plate IS NULL OR v_clean_plate = '' THEN
        RAISE EXCEPTION 'Biển số xe không được để trống.';
    END IF;

    UPDATE public.vehicles
    SET license_plate = v_clean_plate,
        vehicle_type = p_vehicle_type,
        brand_model = p_brand_model,
        updated_at = NOW()
    WHERE id = p_vehicle_id AND status = 'pending';

    RETURN jsonb_build_object('success', true, 'message', 'Đã cập nhật thông tin phương tiện thành công', 'vehicle_id', p_vehicle_id);
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_co_residents(p_apartment_id uuid)
 RETURNS TABLE(user_id uuid, full_name text, phone text, relation_role text)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
  SELECT u.id, u.full_name, u.phone, ra.relation_role::TEXT
  FROM public.residents_apartments ra
  JOIN public.users u ON u.id = ra.user_id
  WHERE ra.apartment_id = p_apartment_id
    AND COALESCE(ra.status, 'active') = 'active'
    AND (
      COALESCE(auth.jwt() ->> 'role', '') = 'service_role'
      OR public.can_access_apartment(p_apartment_id)
    );
$function$;

CREATE OR REPLACE FUNCTION public.record_manual_amenity_payment(
    p_booking_id uuid,
    p_payment_method text DEFAULT 'CASH'::text,
    p_notes text DEFAULT NULL::text,
    p_amount numeric DEFAULT NULL::numeric
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
    v_booking RECORD;
    v_txn_id UUID;
    v_txn_code VARCHAR(100);
    v_existing_success_txn RECORD;
    v_pending_txn RECORD;
    v_staff_id UUID := auth.uid();
    v_total_fee NUMERIC(12,2) := 0;
BEGIN
    IF v_staff_id IS NULL THEN
        RAISE EXCEPTION 'Bạn không có quyền xác nhận thu phí dịch vụ tiện ích' USING ERRCODE = '42501';
    END IF;

    SELECT b.*, a.name AS amenity_name, a.fee_amount AS a_fee, a.deposit_amount AS a_deposit,
           a.requires_deposit AS a_req_deposit, a.building_id AS a_building_id
    INTO v_booking
    FROM public.amenity_bookings b
    JOIN public.building_amenities a ON b.amenity_id = a.id
    WHERE b.id = p_booking_id
    FOR UPDATE OF b;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Lịch đặt tiện ích không tồn tại: %', p_booking_id;
    END IF;

    IF v_booking.a_building_id IS NULL OR NOT public.is_building_staff(
        v_booking.a_building_id,
        ARRAY['admin', 'management', 'manager', 'owner', 'accountant', 'staff']
    ) THEN
        RAISE EXCEPTION 'Bạn không thuộc quyền quản lý tòa nhà của tiện ích này.' USING ERRCODE = '42501';
    END IF;

    IF v_booking.status = 'cancelled' THEN
        RAISE EXCEPTION 'Lịch đặt này đã bị hủy, không thể xác nhận thu tiền';
    END IF;

    SELECT * INTO v_existing_success_txn
    FROM public.payment_transactions
    WHERE booking_id = p_booking_id AND status = 'SUCCESS'
    ORDER BY created_at DESC
    LIMIT 1
    FOR UPDATE;

    IF FOUND THEN
        RETURN jsonb_build_object(
            'success', true,
            'message', 'Lịch đặt tiện ích này đã được xác nhận thanh toán trước đó',
            'already_paid', true,
            'booking_id', p_booking_id,
            'transaction_id', v_existing_success_txn.id,
            'transaction_code', COALESCE(v_existing_success_txn.transaction_code, v_existing_success_txn.receipt_number)
        );
    END IF;

    v_total_fee := COALESCE(p_amount, COALESCE(v_booking.fee_amount, 0) + COALESCE(v_booking.deposit_amount, 0));
    IF v_total_fee <= 0 THEN
        v_total_fee := (COALESCE(v_booking.a_fee, 0) * GREATEST(COALESCE(v_booking.guests_count, 1), 1))
            + (CASE WHEN COALESCE(v_booking.a_req_deposit, false) THEN COALESCE(v_booking.a_deposit, 0) ELSE 0 END);
    END IF;

    SELECT * INTO v_pending_txn
    FROM public.payment_transactions
    WHERE booking_id = p_booking_id AND status = 'PENDING'
    ORDER BY created_at DESC
    LIMIT 1
    FOR UPDATE;

    IF FOUND THEN
        v_txn_code := COALESCE(v_pending_txn.transaction_code, v_pending_txn.receipt_number, 'MANUAL-SRV-' || to_char(NOW(), 'YYYYMMDDHH24MISS'));
        v_txn_id := v_pending_txn.id;

        UPDATE public.payment_transactions
        SET status = 'SUCCESS',
            payment_method = COALESCE(p_payment_method, v_pending_txn.payment_method),
            amount = v_total_fee,
            confirmed_by = v_staff_id,
            confirmed_at = NOW(),
            failure_reason = NULL,
            updated_at = NOW()
        WHERE id = v_txn_id;
    ELSE
        v_txn_code := 'MANUAL-SRV-' || to_char(NOW(), 'YYYYMMDDHH24MISS') || '-' || upper(substr(gen_random_uuid()::text, 1, 8));

        INSERT INTO public.payment_transactions (
            reference_id, transaction_code, receipt_number, booking_id, user_id, apartment_id,
            amount, payment_method, payment_type, type, status, title,
            confirmed_by, confirmed_at, created_at, updated_at
        ) VALUES (
            p_booking_id, v_txn_code, v_txn_code, p_booking_id, COALESCE(v_booking.booked_by, v_staff_id), v_booking.apartment_id,
            v_total_fee, p_payment_method, 'AMENITY', 'SERVICE', 'SUCCESS',
            COALESCE(p_notes, 'Thanh toán trực tiếp dịch vụ ' || v_booking.amenity_name),
            v_staff_id, NOW(), NOW(), NOW()
        ) RETURNING id INTO v_txn_id;
    END IF;

    UPDATE public.amenity_bookings
    SET status = 'confirmed',
        deposit_status = CASE
            WHEN COALESCE(deposit_amount, 0) > 0 OR COALESCE(v_booking.a_deposit, 0) > 0 THEN 'received'
            ELSE deposit_status
        END,
        deposit_notes = COALESCE(p_notes, deposit_notes),
        updated_at = NOW()
    WHERE id = p_booking_id;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Xác nhận thu phí dịch vụ tiện ích thành công',
        'already_paid', false,
        'booking_id', p_booking_id,
        'transaction_id', v_txn_id,
        'transaction_code', v_txn_code
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.approve_meter_reading(
    p_submission_id uuid,
    p_generate_invoice boolean DEFAULT true,
    p_due_date date DEFAULT NULL::date
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
    v_is_service BOOLEAN := COALESCE(auth.jwt() ->> 'role', '') = 'service_role';
    v_user_id UUID := auth.uid();
    v_sub RECORD;
    v_building_id UUID;
    v_prev RECORD;
    v_prev_electric NUMERIC(10, 2) := 0;
    v_prev_water NUMERIC(10, 2) := 0;
    v_electric_consumed NUMERIC(10, 2) := 0;
    v_water_consumed NUMERIC(10, 2) := 0;
    v_elec_charge JSONB;
    v_water_charge JSONB;
    v_elec_total NUMERIC(12, 2) := 0;
    v_water_total NUMERIC(12, 2) := 0;
    v_utility_total NUMERIC(12, 2) := 0;
    v_invoice_id UUID;
    v_existing_inv RECORD;
    v_due_date DATE;
BEGIN
    IF NOT v_is_service AND v_user_id IS NULL THEN
        RAISE EXCEPTION 'Chỉ nhân viên hoặc Ban Quản Lý mới có quyền duyệt chỉ số công tơ.' USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_sub
    FROM public.meter_reading_submissions
    WHERE id = p_submission_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Không tìm thấy bản ghi chỉ số công tơ.';
    END IF;

    SELECT building_id INTO v_building_id FROM public.apartments WHERE id = v_sub.apartment_id;
    IF NOT v_is_service AND (
        v_building_id IS NULL
        OR NOT public.is_building_staff(v_building_id, ARRAY['admin', 'management', 'manager', 'owner', 'accountant', 'technician', 'staff'])
    ) THEN
        RAISE EXCEPTION 'Bạn không thuộc quyền quản lý của tòa nhà này.' USING ERRCODE = '42501';
    END IF;

    IF v_sub.status = 'approved' THEN
        RETURN jsonb_build_object('success', false, 'message', 'Chỉ số này đã được duyệt trước đó.');
    END IF;

    IF v_sub.previous_electric_reading IS NOT NULL THEN
        v_prev_electric := v_sub.previous_electric_reading;
        v_prev_water := COALESCE(v_sub.previous_water_reading, 0);
    ELSE
        SELECT electric_reading, water_reading INTO v_prev
        FROM public.meter_reading_submissions
        WHERE apartment_id = v_sub.apartment_id
          AND status = 'approved'
          AND id <> p_submission_id
        ORDER BY created_at DESC
        LIMIT 1;

        IF FOUND THEN
            v_prev_electric := COALESCE(v_prev.electric_reading, 0);
            v_prev_water := COALESCE(v_prev.water_reading, 0);
        END IF;
    END IF;

    v_electric_consumed := GREATEST(0, v_sub.electric_reading - v_prev_electric);
    v_water_consumed := GREATEST(0, v_sub.water_reading - v_prev_water);

    IF p_generate_invoice THEN
        v_elec_charge := public.calculate_utility_charge('electricity', v_electric_consumed, v_building_id);
        v_water_charge := public.calculate_utility_charge('water', v_water_consumed, v_building_id);

        v_elec_total := COALESCE((v_elec_charge->>'total_amount')::NUMERIC, 0);
        v_water_total := COALESCE((v_water_charge->>'total_amount')::NUMERIC, 0);
        v_utility_total := v_elec_total + v_water_total;
        v_due_date := COALESCE(p_due_date, CURRENT_DATE + 10);

        SELECT id, total_amount INTO v_existing_inv
        FROM public.invoices
        WHERE apartment_id = v_sub.apartment_id
          AND period = v_sub.period
          AND status IN ('pending', 'unpaid', 'overdue')
        ORDER BY created_at DESC
        LIMIT 1
        FOR UPDATE;

        IF FOUND THEN
            v_invoice_id := v_existing_inv.id;
            UPDATE public.invoices
            SET total_amount = total_amount + v_utility_total,
                updated_at = now()
            WHERE id = v_invoice_id;
        ELSE
            INSERT INTO public.invoices (
                apartment_id, period, due_date, total_amount, status, created_at, updated_at
            ) VALUES (
                v_sub.apartment_id, v_sub.period, v_due_date, v_utility_total, 'unpaid'::public.invoice_status, now(), now()
            ) RETURNING id INTO v_invoice_id;
        END IF;

        IF v_electric_consumed > 0 OR v_elec_total > 0 THEN
            INSERT INTO public.invoice_items (invoice_id, fee_type, unit_price, quantity)
            VALUES (
                v_invoice_id,
                'electricity',
                CASE WHEN v_electric_consumed > 0 THEN ROUND(v_elec_total / v_electric_consumed, 2) ELSE v_elec_total END,
                CASE WHEN v_electric_consumed > 0 THEN v_electric_consumed ELSE 1 END
            );
        END IF;

        IF v_water_consumed > 0 OR v_water_total > 0 THEN
            INSERT INTO public.invoice_items (invoice_id, fee_type, unit_price, quantity)
            VALUES (
                v_invoice_id,
                'water',
                CASE WHEN v_water_consumed > 0 THEN ROUND(v_water_total / v_water_consumed, 2) ELSE v_water_total END,
                CASE WHEN v_water_consumed > 0 THEN v_water_consumed ELSE 1 END
            );
        END IF;
    END IF;

    UPDATE public.meter_reading_submissions
    SET status = 'approved',
        reviewed_by = v_user_id,
        reviewed_at = now(),
        previous_electric_reading = v_prev_electric,
        previous_water_reading = v_prev_water,
        invoice_id = COALESCE(v_invoice_id, invoice_id),
        updated_at = now()
    WHERE id = p_submission_id;

    UPDATE public.apartments
    SET electric_reading = v_sub.electric_reading,
        water_reading = v_sub.water_reading,
        updated_at = now()
    WHERE id = v_sub.apartment_id;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Đã phê duyệt chỉ số công tơ và đồng bộ hóa đơn thành công.',
        'submission_id', p_submission_id,
        'invoice_id', v_invoice_id,
        'electric_consumed', v_electric_consumed,
        'water_consumed', v_water_consumed,
        'utility_total', v_utility_total
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.send_invoice_dunning_notifications(p_invoice_ids uuid[])
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
    v_is_service BOOLEAN := COALESCE(auth.jwt() ->> 'role', '') = 'service_role';
    v_inv RECORD;
    v_res RECORD;
    v_sent_count INT := 0;
    v_apt_count INT := 0;
    v_has_resident BOOLEAN;
BEGIN
    IF p_invoice_ids IS NULL OR array_length(p_invoice_ids, 1) IS NULL THEN
        RETURN jsonb_build_object('success', true, 'notifications_sent', 0, 'apartments_notified', 0);
    END IF;

    IF NOT (
        v_is_service
        OR EXISTS (
            SELECT 1 FROM public.user_buildings ub
            WHERE ub.user_id = auth.uid()
              AND LOWER(ub.role) = ANY(ARRAY['admin', 'management', 'manager', 'owner', 'accountant'])
        )
    ) THEN
        RAISE EXCEPTION 'Chỉ Ban Quản Lý hoặc Kế toán mới có quyền gửi thông báo nhắc nợ.' USING ERRCODE = '42501';
    END IF;

    FOR v_inv IN
        SELECT i.id, i.apartment_id, i.period, i.total_amount, a.code AS apt_code, a.building_id
        FROM public.invoices i
        JOIN public.apartments a ON a.id = i.apartment_id
        WHERE i.id = ANY(p_invoice_ids)
          AND i.status NOT IN ('paid', 'cancelled')
    LOOP
        IF NOT v_is_service AND (
            v_inv.building_id IS NULL
            OR NOT public.is_building_staff(v_inv.building_id, ARRAY['admin', 'management', 'manager', 'owner', 'accountant'])
        ) THEN
            CONTINUE;
        END IF;

        v_has_resident := FALSE;
        FOR v_res IN
            SELECT DISTINCT user_id
            FROM public.residents_apartments
            WHERE apartment_id = v_inv.apartment_id
              AND COALESCE(status, 'active') = 'active'
        LOOP
            INSERT INTO public.notifications (
                building_id,
                apartment_id,
                user_id,
                title,
                body,
                type,
                payload,
                is_read,
                created_at
            ) VALUES (
                v_inv.building_id,
                v_inv.apartment_id,
                v_res.user_id,
                'Nhắc nợ hóa đơn kỳ ' || v_inv.period,
                'Hóa đơn căn hộ ' || v_inv.apt_code || ' kỳ ' || v_inv.period || ' số tiền ' || to_char(v_inv.total_amount, 'FM999,999,999,999') || ' đ đã đến hạn thanh toán. Kính đề nghị Quý cư dân thanh toán sớm.',
                'invoice_reminder',
                jsonb_build_object(
                    'invoice_id', v_inv.id,
                    'period', v_inv.period,
                    'amount', v_inv.total_amount
                ),
                false,
                now()
            );
            v_sent_count := v_sent_count + 1;
            v_has_resident := TRUE;
        END LOOP;

        IF v_has_resident THEN
            v_apt_count := v_apt_count + 1;
        END IF;
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'notifications_sent', v_sent_count,
        'apartments_notified', v_apt_count
    );
END;
$function$;

-- ----------------------------------------------------------------------------
-- 7. Scope the 4 previously unguarded read & calculator RPCs
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_poll_results(p_poll_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
    v_is_service BOOLEAN := COALESCE(auth.jwt() ->> 'role', '') = 'service_role';
    v_poll RECORD;
    v_total_apartments INT;
    v_total_area NUMERIC(12,2);
    v_voted_apartments INT;
    v_voted_area NUMERIC(12,2);
    v_participation_rate NUMERIC(5,2);
    v_options_result JSONB;
    v_is_quorum_met BOOLEAN;
BEGIN
    SELECT * INTO v_poll FROM public.polls WHERE id = p_poll_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Cuộc biểu quyết không tồn tại');
    END IF;

    IF NOT (
        v_is_service
        OR (
            v_poll.building_id IS NOT NULL
            AND v_poll.building_id IN (SELECT public.get_user_accessible_buildings(auth.uid()))
        )
    ) THEN
        RAISE EXCEPTION 'Truy cập bị từ chối: Bạn không có quyền xem kết quả biểu quyết này.' USING ERRCODE = '42501';
    END IF;

    IF v_poll.building_id IS NOT NULL THEN
        SELECT COUNT(*), COALESCE(SUM(area), 0.0)
        INTO v_total_apartments, v_total_area
        FROM public.apartments
        WHERE building_id = v_poll.building_id;
    ELSE
        SELECT COUNT(*), COALESCE(SUM(area), 0.0)
        INTO v_total_apartments, v_total_area
        FROM public.apartments;
    END IF;

    IF v_total_apartments = 0 THEN v_total_apartments := 1; END IF;
    IF v_total_area = 0 THEN v_total_area := 1.0; END IF;

    SELECT COUNT(*), COALESCE(SUM(vote_weight), 0.0)
    INTO v_voted_apartments, v_voted_area
    FROM public.poll_votes
    WHERE poll_id = p_poll_id;

    IF v_poll.vote_weight_type = 'by_area' THEN
        v_participation_rate := ROUND((v_voted_area / v_total_area) * 100, 2);
    ELSE
        v_participation_rate := ROUND((v_voted_apartments::NUMERIC / v_total_apartments::NUMERIC) * 100, 2);
    END IF;

    v_is_quorum_met := v_participation_rate >= COALESCE(v_poll.min_participation_rate, 50.0);

    SELECT jsonb_agg(
        jsonb_build_object(
            'option_id', opt.id,
            'option_text', opt.option_text,
            'vote_count', COALESCE(counts.cnt, 0),
            'vote_weight_sum', COALESCE(counts.weight_sum, 0.0),
            'percent_of_votes', CASE
                WHEN v_voted_apartments > 0 THEN
                    CASE
                        WHEN v_poll.vote_weight_type = 'by_area' THEN ROUND((COALESCE(counts.weight_sum, 0.0) / v_voted_area) * 100, 2)
                        ELSE ROUND((COALESCE(counts.cnt, 0)::NUMERIC / v_voted_apartments::NUMERIC) * 100, 2)
                    END
                ELSE 0.0
            END
        ) ORDER BY opt.option_order ASC
    ) INTO v_options_result
    FROM public.poll_options opt
    LEFT JOIN (
        SELECT unnest(selected_option_ids) AS opt_id,
               COUNT(*) AS cnt,
               SUM(vote_weight) AS weight_sum
        FROM public.poll_votes
        WHERE poll_id = p_poll_id
        GROUP BY opt_id
    ) counts ON opt.id = counts.opt_id
    WHERE opt.poll_id = p_poll_id;

    RETURN jsonb_build_object(
        'success', true,
        'poll_id', v_poll.id,
        'poll_code', v_poll.poll_code,
        'title', v_poll.title,
        'status', v_poll.status,
        'vote_weight_type', v_poll.vote_weight_type,
        'total_apartments', v_total_apartments,
        'voted_apartments', v_voted_apartments,
        'total_area', v_total_area,
        'voted_area', v_voted_area,
        'participation_rate', v_participation_rate,
        'is_quorum_met', v_is_quorum_met,
        'options', COALESCE(v_options_result, '[]'::JSONB)
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_amenity_slot_availability(p_amenity_id uuid, p_date date)
 RETURNS TABLE(time_slot character varying, status character varying, guests_count integer, is_my_booking boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
    v_is_service BOOLEAN := COALESCE(auth.jwt() ->> 'role', '') = 'service_role';
    v_building_id UUID;
BEGIN
    SELECT building_id INTO v_building_id
    FROM public.building_amenities
    WHERE id = p_amenity_id;

    IF NOT (
        v_is_service
        OR (
            v_building_id IS NOT NULL
            AND v_building_id IN (SELECT public.get_user_accessible_buildings(auth.uid()))
        )
    ) THEN
        RAISE EXCEPTION 'Truy cập bị từ chối: Bạn không có quyền xem lịch trống tiện ích của tòa nhà này.' USING ERRCODE = '42501';
    END IF;

    RETURN QUERY
    SELECT
        b.time_slot,
        b.status::character varying,
        b.guests_count,
        (b.booked_by = auth.uid()) AS is_my_booking
    FROM public.amenity_bookings b
    WHERE b.amenity_id = p_amenity_id
      AND b.booking_date = p_date
      AND b.status IN ('confirmed', 'waitlist', 'pending_payment', 'completed');
END;
$function$;

CREATE OR REPLACE FUNCTION public.calculate_late_payment_penalty(
    p_invoice_id uuid,
    p_as_of_date date DEFAULT CURRENT_DATE
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
    v_is_service BOOLEAN := COALESCE(auth.jwt() ->> 'role', '') = 'service_role';
    v_invoice RECORD;
    v_policy RECORD;
    v_grace_days INT := 3;
    v_penalty_rate NUMERIC := 0.0005;
    v_diff INT;
    v_days_overdue INT := 0;
    v_in_grace BOOLEAN := false;
    v_penalty_amount NUMERIC := 0;
    v_check_date DATE;
BEGIN
    v_check_date := COALESCE(p_as_of_date, CURRENT_DATE);

    SELECT i.*, a.building_id
    INTO v_invoice
    FROM public.invoices i
    JOIN public.apartments a ON a.id = i.apartment_id
    WHERE i.id = p_invoice_id;

    IF v_invoice.id IS NULL THEN
        RAISE EXCEPTION 'Không tìm thấy hóa đơn với mã %', p_invoice_id;
    END IF;

    IF NOT (v_is_service OR public.can_access_apartment(v_invoice.apartment_id)) THEN
        RAISE EXCEPTION 'Truy cập bị từ chối: Bạn không có quyền tính lãi phạt cho hóa đơn này.' USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_policy
    FROM public.fee_tier_policies
    WHERE policy_type = 'LATE_PAYMENT_PENALTY'
      AND is_active = true
      AND (
          (v_invoice.building_id IS NOT NULL AND building_id = v_invoice.building_id)
          OR building_id IS NULL
      )
    ORDER BY (CASE WHEN building_id IS NOT NULL THEN 0 ELSE 1 END), effective_from DESC
    LIMIT 1;

    IF v_policy.id IS NOT NULL THEN
        v_grace_days := COALESCE((v_policy.tiers->>'grace_period_days')::INT, 3);
        v_penalty_rate := COALESCE((v_policy.tiers->>'penalty_rate_per_day')::NUMERIC, 0.0005);
    END IF;

    IF v_invoice.status = 'paid' THEN
        RETURN jsonb_build_object(
            'invoice_id', p_invoice_id,
            'due_date', v_invoice.due_date,
            'as_of_date', v_check_date,
            'days_overdue', 0,
            'in_grace_period', false,
            'penalty_rate_per_day', v_penalty_rate,
            'penalty_amount', 0,
            'total_amount', v_invoice.total_amount
        );
    END IF;

    v_diff := (v_check_date - v_invoice.due_date);

    IF v_diff <= 0 THEN
        v_days_overdue := 0;
        v_in_grace := false;
        v_penalty_amount := 0;
    ELSIF v_diff <= v_grace_days THEN
        v_days_overdue := v_diff;
        v_in_grace := true;
        v_penalty_amount := 0;
    ELSE
        v_days_overdue := v_diff;
        v_in_grace := false;
        v_penalty_amount := ROUND(v_invoice.total_amount * v_penalty_rate * v_diff);
    END IF;

    RETURN jsonb_build_object(
        'invoice_id', p_invoice_id,
        'due_date', v_invoice.due_date,
        'as_of_date', v_check_date,
        'days_overdue', v_days_overdue,
        'in_grace_period', v_in_grace,
        'penalty_rate_per_day', v_penalty_rate,
        'penalty_amount', v_penalty_amount,
        'total_amount', v_invoice.total_amount
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.calculate_visitor_parking_fee(
    p_ticket_id uuid,
    p_check_out_at timestamp with time zone DEFAULT now()
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
    v_is_service BOOLEAN := COALESCE(auth.jwt() ->> 'role', '') = 'service_role';
    v_ticket RECORD;
    v_diff_minutes INT;
    v_hours NUMERIC;
    v_total_fee NUMERIC := 0;
    v_is_overnight BOOLEAN := false;
BEGIN
    SELECT * INTO v_ticket
    FROM public.visitor_parking_tickets
    WHERE id = p_ticket_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Không tìm thấy vé xe');
    END IF;

    IF NOT (
        v_is_service
        OR (
            v_ticket.building_id IS NOT NULL
            AND public.is_building_staff(
                v_ticket.building_id,
                ARRAY['admin', 'management', 'manager', 'owner', 'staff', 'security', 'receptionist', 'accountant']
            )
        )
    ) THEN
        RAISE EXCEPTION 'Truy cập bị từ chối: Bạn không có quyền tính phí vé xe khách này.' USING ERRCODE = '42501';
    END IF;

    v_diff_minutes := EXTRACT(EPOCH FROM (p_check_out_at - v_ticket.check_in_at)) / 60;
    IF v_diff_minutes < 0 THEN v_diff_minutes := 0; END IF;

    v_hours := CEIL(v_diff_minutes::NUMERIC / 60.0);
    IF v_hours < 1 THEN v_hours := 1; END IF;

    IF v_ticket.vehicle_type = 'car' THEN
        IF v_hours <= 2 THEN
            v_total_fee := 25000;
        ELSE
            v_total_fee := 25000 + ((v_hours - 2) * 15000);
        END IF;

        IF v_hours >= 12 THEN
            v_total_fee := v_total_fee + 50000;
            v_is_overnight := true;
        END IF;
    ELSE
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
$function$;

COMMIT;
