-- =============================================================================
-- Migration #50: Khóa bảo mật toàn diện SECURITY DEFINER RPCs, vá lỗi cột/enum
-- runtime và chuẩn hóa Storage RLS đa tòa nhà
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- 1A. Vá schema & 5 lỗi vỡ cột / sai enum runtime trong PL/pgSQL RPCs
-- -----------------------------------------------------------------------------
ALTER TABLE public.invoice_items
    ADD COLUMN IF NOT EXISTS description TEXT;

CREATE OR REPLACE FUNCTION public.charge_issue_materials_to_invoice(
    p_issue_id uuid,
    p_invoice_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
    v_is_service BOOLEAN := COALESCE(auth.jwt() ->> 'role', '') = 'service_role';
    v_issue_apt_id UUID;
    v_issue_bld_id UUID;
    v_inv_apt_id UUID;
    v_inv_bld_id UUID;
    v_item RECORD;
    v_line_total NUMERIC(15, 2);
    v_total_charged NUMERIC(15, 2) := 0;
    v_lines_count INT := 0;
BEGIN
    SELECT ir.apartment_id, a.building_id
    INTO v_issue_apt_id, v_issue_bld_id
    FROM public.issue_reports ir
    JOIN public.apartments a ON a.id = ir.apartment_id
    WHERE ir.id = p_issue_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Không tìm thấy sự cố kỹ thuật yêu cầu.' USING ERRCODE = '22023';
    END IF;

    SELECT i.apartment_id, a.building_id
    INTO v_inv_apt_id, v_inv_bld_id
    FROM public.invoices i
    JOIN public.apartments a ON a.id = i.apartment_id
    WHERE i.id = p_invoice_id
    FOR UPDATE OF i;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Không tìm thấy hóa đơn mục tiêu.' USING ERRCODE = '22023';
    END IF;

    IF v_issue_bld_id IS DISTINCT FROM v_inv_bld_id THEN
        RAISE EXCEPTION 'Sự cố và hóa đơn không thuộc cùng một tòa nhà.' USING ERRCODE = '22023';
    END IF;

    IF NOT (
        v_is_service
        OR public.is_building_staff(
            v_inv_bld_id,
            ARRAY['admin', 'management', 'manager', 'owner', 'accountant']
        )
    ) THEN
        RAISE EXCEPTION 'Truy cập bị từ chối: Chỉ Ban Quản Lý hoặc Kế toán tòa nhà mới có quyền kết chuyển vật tư vào hóa đơn.'
            USING ERRCODE = '42501';
    END IF;

    FOR v_item IN
        SELECT im.id, im.quantity, im.unit_price, im.total_amount, mm.name AS material_name
        FROM public.issue_materials im
        JOIN public.maintenance_materials mm ON mm.id = im.material_id
        WHERE im.issue_report_id = p_issue_id
          AND im.is_chargeable = true
    LOOP
        v_line_total := ROUND(COALESCE(v_item.unit_price, 0) * COALESCE(v_item.quantity, 0), 2);

        INSERT INTO public.invoice_items (
            invoice_id,
            fee_type,
            unit_price,
            quantity,
            description
        ) VALUES (
            p_invoice_id,
            'maintenance',
            v_item.unit_price,
            v_item.quantity,
            'Vật tư sửa chữa sự cố: ' || v_item.material_name
        );

        v_total_charged := v_total_charged + v_line_total;
        v_lines_count := v_lines_count + 1;
    END LOOP;

    UPDATE public.invoices
    SET total_amount = total_amount + v_total_charged,
        updated_at = NOW()
    WHERE id = p_invoice_id;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Đã kết chuyển vật tư vào hóa đơn thành công',
        'lines_added', v_lines_count,
        'total_charged', v_total_charged
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.reject_meter_reading(
    p_submission_id uuid,
    p_reason text DEFAULT 'Chỉ số không hợp lý hoặc hình ảnh mờ'::text
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
BEGIN
    IF NOT v_is_service AND v_user_id IS NULL THEN
        RAISE EXCEPTION 'Yêu cầu đăng nhập để từ chối chỉ số công tơ.' USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_sub
    FROM public.meter_reading_submissions
    WHERE id = p_submission_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Không tìm thấy bản ghi chỉ số công tơ.';
    END IF;

    SELECT building_id INTO v_building_id
    FROM public.apartments
    WHERE id = v_sub.apartment_id;

    IF NOT (
        v_is_service
        OR public.is_building_staff(
            v_building_id,
            ARRAY['admin', 'management', 'manager', 'owner', 'accountant', 'technician', 'staff']
        )
    ) THEN
        RAISE EXCEPTION 'Truy cập bị từ chối: Bạn không có quyền từ chối chỉ số của tòa nhà này.'
            USING ERRCODE = '42501';
    END IF;

    UPDATE public.meter_reading_submissions
    SET status = 'rejected'::public.meter_submission_status,
        reject_reason = COALESCE(NULLIF(TRIM(p_reason), ''), 'Chỉ số không hợp lý hoặc hình ảnh mờ'),
        reviewed_by = v_user_id,
        reviewed_at = now(),
        updated_at = now()
    WHERE id = p_submission_id;

    RETURN jsonb_build_object('success', true, 'message', 'Đã từ chối chỉ số công tơ.');
END;
$function$;

CREATE OR REPLACE FUNCTION public.onboard_building_commercial_config(
    p_building_id uuid,
    p_bank_bin character varying,
    p_bank_name text,
    p_bank_account_number text,
    p_bank_account_name text,
    p_initial_maintenance_balance numeric DEFAULT 0.00
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
    v_is_service BOOLEAN := COALESCE(auth.jwt() ->> 'role', '') = 'service_role';
    v_user_id UUID := auth.uid();
    v_fund_id UUID;
    v_now TIMESTAMPTZ := now();
    v_payload JSONB;
BEGIN
    IF NOT v_is_service AND v_user_id IS NULL THEN
        RAISE EXCEPTION 'Yêu cầu đăng nhập để cấu hình thông tin tòa nhà.' USING ERRCODE = '42501';
    END IF;

    IF NOT (
        v_is_service
        OR public.is_building_staff(p_building_id, ARRAY['admin', 'management', 'manager', 'owner'])
        OR public.has_building_role(p_building_id, ARRAY['admin', 'manager', 'head_of_management'])
    ) THEN
        RAISE EXCEPTION 'Bạn không có quyền quản trị để cấu hình thông tin thương mại tòa nhà này.'
            USING ERRCODE = '42501';
    END IF;

    UPDATE public.buildings
    SET bank_bin = p_bank_bin,
        bank_name = p_bank_name,
        bank_account_number = p_bank_account_number,
        bank_account_name = p_bank_account_name,
        updated_at = v_now
    WHERE id = p_building_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Không tìm thấy tòa nhà có ID: %', p_building_id;
    END IF;

    SELECT id INTO v_fund_id
    FROM public.maintenance_funds
    WHERE building_id = p_building_id;

    IF v_fund_id IS NULL THEN
        INSERT INTO public.maintenance_funds (
            building_id,
            total_balance,
            bank_name,
            bank_account_number,
            created_at,
            updated_at
        ) VALUES (
            p_building_id,
            COALESCE(p_initial_maintenance_balance, 0.00),
            p_bank_name,
            p_bank_account_number,
            v_now,
            v_now
        ) RETURNING id INTO v_fund_id;
    ELSE
        UPDATE public.maintenance_funds
        SET bank_name = p_bank_name,
            bank_account_number = p_bank_account_number,
            updated_at = v_now
        WHERE id = v_fund_id;
    END IF;

    v_payload := jsonb_build_object(
        'building_id', p_building_id,
        'bank_bin', p_bank_bin,
        'bank_name', p_bank_name,
        'bank_account_number', p_bank_account_number,
        'bank_account_name', p_bank_account_name,
        'initial_maintenance_balance', p_initial_maintenance_balance,
        'onboarded_at', v_now
    );

    INSERT INTO public.audit_logs (
        building_id,
        target_table,
        target_id,
        entity_name,
        entity_id,
        action,
        actor_id,
        new_values,
        details,
        created_at
    ) VALUES (
        p_building_id,
        'buildings',
        p_building_id,
        'buildings',
        p_building_id,
        'ONBOARD_COMMERCIAL_CONFIG',
        v_user_id,
        v_payload,
        'Cấu hình thông tin ngân hàng và quỹ bảo trì tòa nhà',
        v_now
    );

    RETURN jsonb_build_object(
        'success', true,
        'building_id', p_building_id,
        'message', 'Cấu hình thông tin ngân hàng và quỹ bảo trì tòa nhà thành công.'
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.check_in_amenity_ticket(p_qr_ticket_token uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
    v_is_service BOOLEAN := COALESCE(auth.jwt() ->> 'role', '') = 'service_role';
    v_staff_id UUID := auth.uid();
    v_booking RECORD;
    v_amenity RECORD;
    v_apartment RECORD;
    v_user RECORD;
BEGIN
    IF NOT v_is_service AND v_staff_id IS NULL THEN
        RAISE EXCEPTION 'Yêu cầu đăng nhập nhân sự vận hành để check-in vé tiện ích.'
            USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_booking
    FROM public.amenity_bookings
    WHERE qr_ticket_token = p_qr_ticket_token
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Mã vé không tồn tại trên hệ thống.');
    END IF;

    SELECT name, building_id INTO v_amenity
    FROM public.building_amenities
    WHERE id = v_booking.amenity_id;

    IF NOT (v_is_service OR public.is_building_staff(v_amenity.building_id)) THEN
        RAISE EXCEPTION 'Truy cập bị từ chối: Chỉ nhân sự của tòa nhà mới có quyền check-in vé tiện ích.'
            USING ERRCODE = '42501';
    END IF;

    IF v_booking.status = 'cancelled' THEN
        RETURN jsonb_build_object('success', false, 'message', 'Vé này đã bị hủy.');
    END IF;

    IF v_booking.status = 'checked_in' THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Vé đã được check-in vào lúc ' || COALESCE(to_char(v_booking.checked_in_at, 'HH24:MI dd/MM/YYYY'), 'trước đó')
        );
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

    UPDATE public.amenity_bookings
    SET status = 'checked_in'::public.amenity_booking_status,
        checked_in_at = now(),
        checked_in_by = v_staff_id,
        updated_at = now()
    WHERE id = v_booking.id;

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
$function$;

CREATE OR REPLACE FUNCTION public.create_payment_intent(
    p_reference_id uuid,
    p_payment_type text DEFAULT 'INVOICE'::text,
    p_payment_method text DEFAULT 'VIETQR'::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
    v_is_service BOOLEAN := COALESCE(auth.jwt() ->> 'role', '') = 'service_role';
    v_user_id UUID := auth.uid();
    v_invoice RECORD;
    v_booking RECORD;
    v_tx_id UUID;
    v_now TIMESTAMPTZ := now();
    v_reference_code TEXT;
    v_amount NUMERIC(15,2);
    v_effective_type TEXT;
    v_is_paid BOOLEAN := FALSE;
BEGIN
    IF NOT v_is_service AND v_user_id IS NULL THEN
        RAISE EXCEPTION 'Yêu cầu đăng nhập để thực hiện thanh toán.' USING ERRCODE = '42501';
    END IF;

    v_effective_type := UPPER(COALESCE(p_payment_type, 'INVOICE'));

    IF v_effective_type = 'INVOICE' THEN
        SELECT * INTO v_invoice
        FROM public.invoices
        WHERE id = p_reference_id
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Không tìm thấy hóa đơn yêu cầu thanh toán.';
        END IF;

        IF NOT (v_is_service OR public.can_access_apartment(v_invoice.apartment_id)) THEN
            RAISE EXCEPTION 'Truy cập bị từ chối: Bạn không có quyền khởi tạo thanh toán cho hóa đơn này.'
                USING ERRCODE = '42501';
        END IF;

        IF v_invoice.status = 'paid' THEN
            RETURN jsonb_build_object(
                'success', false,
                'status', 'ALREADY_PAID',
                'is_pending', false,
                'message', 'Hóa đơn này đã được thanh toán trước đó.'
            );
        END IF;

        v_amount := v_invoice.total_amount;
        v_reference_code := COALESCE(
            v_invoice.payment_code,
            v_invoice.lookup_code,
            'INV-' || to_char(v_now, 'YYYYMMDD') || '-' || upper(substring(p_reference_id::text, 1, 6))
        );

        INSERT INTO public.payment_transactions (
            reference_id,
            invoice_id,
            user_id,
            apartment_id,
            payment_type,
            payment_method,
            amount,
            status,
            idempotency_key,
            created_at,
            updated_at
        ) VALUES (
            p_reference_id,
            p_reference_id,
            COALESCE(v_user_id, p_reference_id),
            v_invoice.apartment_id,
            'INVOICE',
            UPPER(p_payment_method),
            v_amount,
            'PENDING',
            gen_random_uuid()::text,
            v_now,
            v_now
        ) RETURNING id INTO v_tx_id;

        RETURN jsonb_build_object(
            'success', true,
            'status', 'PENDING',
            'is_pending', true,
            'transaction_id', v_tx_id,
            'reference_code', v_reference_code,
            'amount', v_amount,
            'message', 'Đã khởi tạo giao dịch chờ thanh toán. Vui lòng chuyển khoản đúng nội dung.'
        );

    ELSIF v_effective_type IN ('AMENITY', 'SERVICE') THEN
        SELECT * INTO v_booking
        FROM public.amenity_bookings
        WHERE id = p_reference_id
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Không tìm thấy lịch đặt tiện ích yêu cầu thanh toán.';
        END IF;

        IF NOT (
            v_is_service
            OR v_booking.booked_by = v_user_id
            OR public.can_access_apartment(v_booking.apartment_id)
        ) THEN
            RAISE EXCEPTION 'Truy cập bị từ chối: Bạn không có quyền khởi tạo thanh toán cho lịch đặt tiện ích này.'
                USING ERRCODE = '42501';
        END IF;

        SELECT EXISTS (
            SELECT 1 FROM public.payment_transactions pt
            WHERE (pt.reference_id = p_reference_id OR pt.booking_id = p_reference_id)
              AND pt.status = 'SUCCESS'
        ) INTO v_is_paid;

        IF v_booking.status IN ('confirmed', 'checked_in', 'completed') AND v_is_paid THEN
            RETURN jsonb_build_object(
                'success', false,
                'status', 'ALREADY_PAID',
                'is_pending', false,
                'message', 'Lịch đặt tiện ích này đã được thanh toán và xác nhận.'
            );
        END IF;

        v_amount := COALESCE(v_booking.fee_amount, 0) + COALESCE(v_booking.deposit_amount, 0);
        v_reference_code := 'AMN-' || to_char(v_now, 'YYYYMMDD') || '-' || upper(substring(p_reference_id::text, 1, 6));

        INSERT INTO public.payment_transactions (
            reference_id,
            booking_id,
            user_id,
            apartment_id,
            payment_type,
            payment_method,
            amount,
            status,
            idempotency_key,
            created_at,
            updated_at
        ) VALUES (
            p_reference_id,
            p_reference_id,
            COALESCE(v_user_id, v_booking.booked_by),
            v_booking.apartment_id,
            'SERVICE',
            UPPER(p_payment_method),
            v_amount,
            'PENDING',
            gen_random_uuid()::text,
            v_now,
            v_now
        ) RETURNING id INTO v_tx_id;

        RETURN jsonb_build_object(
            'success', true,
            'status', 'PENDING',
            'is_pending', true,
            'transaction_id', v_tx_id,
            'reference_code', v_reference_code,
            'amount', v_amount,
            'message', 'Đã khởi tạo giao dịch đặt tiện ích chờ thanh toán.'
        );
    ELSE
        RAISE EXCEPTION 'Loại giao dịch thanh toán không được hỗ trợ: %', p_payment_type;
    END IF;
END;
$function$;

-- -----------------------------------------------------------------------------
-- 1B. Khóa quyền đa cơ sở (is_building_staff / can_access_apartment / can_access_building)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.close_accounting_period(
    p_building_id uuid,
    p_period character varying,
    p_closed_by uuid DEFAULT NULL::uuid,
    p_notes text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
    v_is_service BOOLEAN := COALESCE(auth.jwt() ->> 'role', '') = 'service_role';
    v_effective_closed_by UUID;
    v_period_id UUID;
    v_status TEXT;
BEGIN
    IF NOT (
        v_is_service
        OR public.is_building_staff(
            p_building_id,
            ARRAY['admin', 'management', 'manager', 'owner', 'accountant']
        )
    ) THEN
        RAISE EXCEPTION 'Truy cập bị từ chối: Chỉ Ban Quản Lý hoặc Kế toán tòa nhà mới có quyền khóa sổ kỳ kế toán.'
            USING ERRCODE = '42501';
    END IF;

    v_effective_closed_by := CASE
        WHEN v_is_service THEN COALESCE(p_closed_by, auth.uid())
        ELSE auth.uid()
    END;

    SELECT id, status INTO v_period_id, v_status
    FROM public.accounting_periods
    WHERE building_id = p_building_id AND period = p_period
    FOR UPDATE;

    IF v_period_id IS NOT NULL THEN
        IF v_status = 'CLOSED' THEN
            RETURN jsonb_build_object('success', false, 'error', 'Kỳ kế toán ' || p_period || ' đã được khóa sổ trước đó.');
        END IF;

        UPDATE public.accounting_periods
        SET status = 'CLOSED',
            closed_at = now(),
            closed_by = v_effective_closed_by,
            notes = COALESCE(p_notes, notes),
            updated_at = now()
        WHERE id = v_period_id;
    ELSE
        INSERT INTO public.accounting_periods (
            building_id,
            period,
            status,
            opened_at,
            closed_at,
            closed_by,
            notes,
            created_at,
            updated_at
        ) VALUES (
            p_building_id,
            p_period,
            'CLOSED',
            now(),
            now(),
            v_effective_closed_by,
            p_notes,
            now(),
            now()
        )
        RETURNING id INTO v_period_id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'period_id', v_period_id,
        'period', p_period,
        'status', 'CLOSED'
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
        WHEN v_is_service THEN COALESCE(p_created_by, auth.uid())
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

CREATE OR REPLACE FUNCTION public.issue_credit_note(
    p_building_id uuid,
    p_apartment_id uuid,
    p_invoice_id uuid DEFAULT NULL::uuid,
    p_note_type character varying DEFAULT 'CREDIT'::character varying,
    p_amount numeric DEFAULT 0.00,
    p_reason text DEFAULT ''::text,
    p_approved_by uuid DEFAULT NULL::uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
    v_is_service BOOLEAN := COALESCE(auth.jwt() ->> 'role', '') = 'service_role';
    v_effective_approver UUID;
    v_apt_building_id UUID;
    v_credit_note_id UUID;
    v_credit_note_code TEXT;
    v_seq INT;
    v_period TEXT;
    v_ledger_result JSONB;
    v_entry_type TEXT;
BEGIN
    SELECT building_id INTO v_apt_building_id
    FROM public.apartments
    WHERE id = p_apartment_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Không tìm thấy căn hộ mục tiêu.' USING ERRCODE = '22023';
    END IF;

    IF v_apt_building_id IS DISTINCT FROM p_building_id THEN
        RAISE EXCEPTION 'Căn hộ không thuộc tòa nhà được chỉ định.' USING ERRCODE = '22023';
    END IF;

    IF NOT (
        v_is_service
        OR public.is_building_staff(
            p_building_id,
            ARRAY['admin', 'management', 'manager', 'owner', 'accountant']
        )
    ) THEN
        RAISE EXCEPTION 'Truy cập bị từ chối: Chỉ Ban Quản Lý hoặc Kế toán tòa nhà mới có quyền phát hành phiếu điều chỉnh công nợ.'
            USING ERRCODE = '42501';
    END IF;

    IF p_amount <= 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Số tiền điều chỉnh phải lớn hơn 0');
    END IF;

    v_effective_approver := CASE
        WHEN v_is_service THEN COALESCE(p_approved_by, auth.uid())
        ELSE auth.uid()
    END;

    v_period := TO_CHAR(now(), 'YYYY-MM');

    SELECT COALESCE(MAX(SUBSTRING(credit_note_code FROM 11)::INT), 0) + 1 INTO v_seq
    FROM public.credit_notes
    WHERE credit_note_code LIKE 'CN-' || REPLACE(v_period, '-', '') || '-%';

    v_credit_note_code := 'CN-' || REPLACE(v_period, '-', '') || '-' || LPAD(v_seq::TEXT, 5, '0');

    INSERT INTO public.credit_notes (
        credit_note_code,
        building_id,
        apartment_id,
        invoice_id,
        note_type,
        amount,
        reason,
        status,
        approved_by,
        approved_at,
        created_at
    ) VALUES (
        v_credit_note_code,
        p_building_id,
        p_apartment_id,
        p_invoice_id,
        p_note_type,
        p_amount,
        p_reason,
        'APPROVED',
        v_effective_approver,
        now(),
        now()
    )
    RETURNING id INTO v_credit_note_id;

    IF p_note_type = 'CREDIT' THEN
        v_entry_type := 'CREDIT_NOTE';
    ELSE
        v_entry_type := 'DEBIT_NOTE';
    END IF;

    v_ledger_result := public.record_apartment_ledger_entry(
        p_building_id := p_building_id,
        p_apartment_id := p_apartment_id,
        p_entry_type := v_entry_type,
        p_amount := p_amount,
        p_period := v_period,
        p_reference_type := 'CREDIT_NOTE',
        p_reference_id := v_credit_note_id,
        p_description := 'Phiếu điều chỉnh ' || v_credit_note_code || ': ' || COALESCE(p_reason, ''),
        p_created_by := v_effective_approver
    );

    RETURN jsonb_build_object(
        'success', true,
        'credit_note_id', v_credit_note_id,
        'credit_note_code', v_credit_note_code,
        'balance_after', v_ledger_result->>'balance_after'
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.generate_receipt_number(p_invoice_id uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
    v_is_service BOOLEAN := COALESCE(auth.jwt() ->> 'role', '') = 'service_role';
    v_inv RECORD;
    v_building_id UUID;
    v_is_staff BOOLEAN := FALSE;
    v_seq INT;
    v_period TEXT;
    v_receipt_number TEXT;
    v_lookup_code TEXT;
BEGIN
    SELECT i.*, a.building_id INTO v_inv
    FROM public.invoices i
    JOIN public.apartments a ON a.id = i.apartment_id
    WHERE i.id = p_invoice_id
    FOR UPDATE OF i;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Không tìm thấy hóa đơn yêu cầu cấp số biên lai.' USING ERRCODE = '22023';
    END IF;

    v_building_id := v_inv.building_id;
    v_is_staff := public.is_building_staff(
        v_building_id,
        ARRAY['admin', 'management', 'manager', 'owner', 'accountant']
    );

    IF NOT (
        v_is_service
        OR v_is_staff
        OR (v_inv.status = 'paid' AND public.can_access_apartment(v_inv.apartment_id))
    ) THEN
        RAISE EXCEPTION 'Truy cập bị từ chối: Bạn không có quyền cấp hoặc xem số biên lai cho hóa đơn này.'
            USING ERRCODE = '42501';
    END IF;

    IF v_inv.receipt_number IS NOT NULL THEN
        RETURN v_inv.receipt_number;
    END IF;

    SELECT to_char(CURRENT_DATE, 'YYYYMM') INTO v_period;

    SELECT COALESCE(COUNT(*), 0) + 1 INTO v_seq
    FROM public.invoices
    WHERE receipt_number LIKE 'PT-' || v_period || '-%';

    v_receipt_number := 'PT-' || v_period || '-' || LPAD(v_seq::text, 5, '0');
    v_lookup_code := UPPER(SUBSTRING(MD5(p_invoice_id::text || clock_timestamp()::text) FROM 1 FOR 8));

    UPDATE public.invoices
    SET receipt_number = v_receipt_number,
        einvoice_lookup_code = COALESCE(einvoice_lookup_code, v_lookup_code),
        paid_amount = CASE
            WHEN v_inv.status = 'paid' OR v_is_service OR v_is_staff
                THEN COALESCE(paid_amount, v_inv.total_amount, 0)
            ELSE paid_amount
        END
    WHERE id = p_invoice_id AND receipt_number IS NULL;

    RETURN v_receipt_number;
END;
$function$;

CREATE OR REPLACE FUNCTION public.confirm_payment(p_invoice_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
    v_is_service BOOLEAN := COALESCE(auth.jwt() ->> 'role', '') = 'service_role';
    v_user_id UUID := auth.uid();
    v_invoice RECORD;
    v_building_id UUID;
    v_tx_code TEXT;
    v_now TIMESTAMPTZ := now();
    v_tx_id UUID;
BEGIN
    IF NOT v_is_service AND v_user_id IS NULL THEN
        RAISE EXCEPTION 'Yêu cầu đăng nhập để xác nhận thanh toán.' USING ERRCODE = '42501';
    END IF;

    SELECT i.*, a.building_id INTO v_invoice
    FROM public.invoices i
    JOIN public.apartments a ON a.id = i.apartment_id
    WHERE i.id = p_invoice_id
    FOR UPDATE OF i;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Không tìm thấy hóa đơn.';
    END IF;

    v_building_id := v_invoice.building_id;
    IF NOT (
        v_is_service
        OR public.is_building_staff(
            v_building_id,
            ARRAY['admin', 'management', 'manager', 'owner', 'accountant']
        )
    ) THEN
        RAISE EXCEPTION 'Truy cập bị từ chối: Chỉ Ban Quản Lý hoặc Kế toán tòa nhà mới có quyền xác nhận thanh toán.'
            USING ERRCODE = '42501';
    END IF;

    IF v_invoice.status = 'paid' THEN
        RETURN jsonb_build_object('success', false, 'message', 'Hóa đơn này đã được xác nhận thanh toán trước đó.');
    END IF;

    v_tx_code := 'MAN-' || to_char(v_now, 'YYYYMMDD') || '-' || upper(substring(gen_random_uuid()::text, 1, 6));

    UPDATE public.invoices
    SET status = 'paid',
        paid_at = v_now,
        paid_amount = COALESCE(paid_amount, v_invoice.total_amount),
        payment_method = COALESCE(payment_method, 'cash'),
        updated_at = v_now
    WHERE id = p_invoice_id;

    INSERT INTO public.payment_transactions (
        reference_id, invoice_id, user_id, apartment_id, payment_type,
        payment_method, amount, status, receipt_number, created_at, updated_at
    ) VALUES (
        p_invoice_id, p_invoice_id, COALESCE(v_user_id, p_invoice_id), v_invoice.apartment_id, 'INVOICE',
        COALESCE(v_invoice.payment_method, 'cash'), v_invoice.total_amount, 'SUCCESS',
        v_tx_code, v_now, v_now
    ) RETURNING id INTO v_tx_id;

    RETURN jsonb_build_object(
        'success', true,
        'transaction_id', v_tx_id,
        'receipt_number', v_tx_code,
        'message', 'Đã xác nhận gạch nợ hóa đơn thành công.'
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.record_manual_payment(
    p_invoice_id uuid,
    p_payment_method character varying DEFAULT 'CASH'::character varying,
    p_notes text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
    v_is_service BOOLEAN := COALESCE(auth.jwt() ->> 'role', '') = 'service_role';
    v_user_id UUID := auth.uid();
    v_inv RECORD;
    v_building_id UUID;
    v_existing_txn RECORD;
    v_txn_code VARCHAR;
    v_res RECORD;
BEGIN
    IF NOT v_is_service AND v_user_id IS NULL THEN
        RAISE EXCEPTION 'Yêu cầu đăng nhập để xác nhận thu tiền.' USING ERRCODE = '42501';
    END IF;

    SELECT i.*, a.building_id INTO v_inv
    FROM public.invoices i
    JOIN public.apartments a ON a.id = i.apartment_id
    WHERE i.id = p_invoice_id
    FOR UPDATE OF i;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Hóa đơn không tồn tại: %', p_invoice_id;
    END IF;

    v_building_id := v_inv.building_id;
    IF NOT (
        v_is_service
        OR public.is_building_staff(
            v_building_id,
            ARRAY['admin', 'management', 'manager', 'owner', 'accountant']
        )
    ) THEN
        RAISE EXCEPTION 'Truy cập bị từ chối: Chỉ Ban Quản Lý hoặc Kế toán tòa nhà mới có quyền xác nhận thu tiền.'
            USING ERRCODE = '42501';
    END IF;

    IF v_inv.status = 'paid' THEN
        RAISE EXCEPTION 'Hóa đơn này đã được xác nhận thanh toán trước đó';
    END IF;

    SELECT * INTO v_existing_txn
    FROM public.payment_transactions
    WHERE invoice_id = p_invoice_id AND status = 'PENDING'
    ORDER BY created_at DESC
    LIMIT 1 FOR UPDATE;

    IF FOUND THEN
        UPDATE public.payment_transactions
        SET status = 'SUCCESS',
            payment_method = COALESCE(p_payment_method, payment_method),
            confirmed_by = v_user_id,
            confirmed_at = now(),
            updated_at = now()
        WHERE id = v_existing_txn.id;
        v_txn_code := COALESCE(v_existing_txn.transaction_code, 'MAN' || to_char(now(), 'YYYYMMDDHH24MISS'));
    ELSE
        v_txn_code := 'MAN' || to_char(now(), 'YYYYMMDDHH24MISS') || UPPER(SUBSTRING(gen_random_uuid()::text, 1, 4));

        INSERT INTO public.payment_transactions (
            reference_id,
            invoice_id,
            apartment_id,
            amount,
            payment_method,
            status,
            transaction_code,
            title,
            type,
            payment_type,
            user_id,
            confirmed_by,
            confirmed_at
        ) VALUES (
            p_invoice_id,
            p_invoice_id,
            v_inv.apartment_id,
            v_inv.total_amount,
            COALESCE(p_payment_method, 'CASH'),
            'SUCCESS',
            v_txn_code,
            'Thu tiền hóa đơn kỳ ' || v_inv.period,
            'INVOICE',
            'INVOICE',
            COALESCE(v_user_id, p_invoice_id),
            v_user_id,
            now()
        );
    END IF;

    UPDATE public.invoices
    SET status = 'paid',
        paid_at = COALESCE(paid_at, now()),
        paid_amount = COALESCE(paid_amount, v_inv.total_amount),
        payment_method = COALESCE(p_payment_method, payment_method, 'CASH'),
        updated_at = now()
    WHERE id = p_invoice_id;

    FOR v_res IN
        SELECT user_id FROM public.residents_apartments
        WHERE apartment_id = v_inv.apartment_id
          AND COALESCE(status, 'active') = 'active'
    LOOP
        INSERT INTO public.notifications (
            building_id,
            user_id,
            apartment_id,
            title,
            body,
            type,
            payload
        ) VALUES (
            v_building_id,
            v_res.user_id,
            v_inv.apartment_id,
            'Hóa đơn kỳ ' || v_inv.period || ' đã được xác nhận thanh toán',
            'Ban quản lý đã xác nhận thu ' || to_char(v_inv.total_amount, 'FM999,999,999') || ' đ cho hóa đơn kỳ ' || v_inv.period || '.',
            'payment_confirmed',
            jsonb_build_object('invoice_id', p_invoice_id, 'transaction_code', v_txn_code)
        );
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'invoice_id', p_invoice_id,
        'transaction_code', v_txn_code,
        'status', 'paid',
        'message', 'Đã xác nhận thu tiền thành công'
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.inspect_and_settle_amenity_deposit(
    p_booking_id uuid,
    p_inspection_result text,
    p_forfeited_amount numeric DEFAULT 0.0,
    p_notes text DEFAULT NULL::text,
    p_image_urls jsonb DEFAULT '[]'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
    v_is_service BOOLEAN := COALESCE(auth.jwt() ->> 'role', '') = 'service_role';
    v_staff_id UUID := auth.uid();
    v_booking RECORD;
    v_building_id UUID;
    v_deposit NUMERIC(12,2);
    v_forfeited NUMERIC(12,2) := 0.0;
    v_refund NUMERIC(12,2) := 0.0;
    v_deposit_status TEXT;
BEGIN
    IF NOT v_is_service AND v_staff_id IS NULL THEN
        RAISE EXCEPTION 'Yêu cầu đăng nhập nhân sự vận hành để nghiệm thu tiện ích.'
            USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_booking
    FROM public.amenity_bookings
    WHERE id = p_booking_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Lượt đặt tiện ích không tồn tại.');
    END IF;

    SELECT building_id INTO v_building_id
    FROM public.building_amenities
    WHERE id = v_booking.amenity_id;

    IF NOT (v_is_service OR public.is_building_staff(v_building_id)) THEN
        RAISE EXCEPTION 'Truy cập bị từ chối: Bạn không có quyền nghiệm thu tiện ích của tòa nhà này.'
            USING ERRCODE = '42501';
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
        inspected_by = v_staff_id,
        inspected_at = now(),
        inspection_notes = p_notes,
        inspection_image_urls = p_image_urls,
        deposit_status = v_deposit_status,
        forfeited_amount = v_forfeited,
        refund_amount = v_refund,
        status = CASE WHEN status = 'checked_in' THEN 'completed'::public.amenity_booking_status ELSE status END,
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
$function$;

CREATE OR REPLACE FUNCTION public.check_in_amenity_booking(p_booking_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
    v_is_service BOOLEAN := COALESCE(auth.jwt() ->> 'role', '') = 'service_role';
    v_staff_id UUID := auth.uid();
    v_booking RECORD;
    v_building_id UUID;
BEGIN
    IF NOT v_is_service AND v_staff_id IS NULL THEN
        RAISE EXCEPTION 'Yêu cầu đăng nhập nhân sự tòa nhà.' USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_booking
    FROM public.amenity_bookings
    WHERE id = p_booking_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Lượt đặt tiện ích không tồn tại: %', p_booking_id;
    END IF;

    SELECT building_id INTO v_building_id
    FROM public.building_amenities
    WHERE id = v_booking.amenity_id;

    IF NOT (v_is_service OR public.is_building_staff(v_building_id)) THEN
        RAISE EXCEPTION 'Chỉ nhân sự Ban Quản Lý tòa nhà này mới có quyền xác nhận check-in tiện ích.'
            USING ERRCODE = '42501';
    END IF;

    IF v_booking.status = 'completed' THEN
        RETURN jsonb_build_object('success', false, 'message', 'Lượt đặt này đã được check-in trước đó');
    END IF;

    UPDATE public.amenity_bookings
    SET checked_in_at = NOW(),
        checked_in_by = COALESCE(checked_in_by, v_staff_id),
        status = 'completed'::public.amenity_booking_status,
        updated_at = NOW()
    WHERE id = p_booking_id;

    RETURN jsonb_build_object('success', true, 'message', 'Xác nhận check-in thành công', 'booking_id', p_booking_id);
END;
$function$;

CREATE OR REPLACE FUNCTION public.record_issue_materials_usage(
    p_issue_id uuid,
    p_materials jsonb,
    p_staff_id uuid DEFAULT NULL::uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
    v_is_service BOOLEAN := COALESCE(auth.jwt() ->> 'role', '') = 'service_role';
    v_building_id UUID;
    v_item JSONB;
    v_material_id UUID;
    v_qty INT;
    v_is_chargeable BOOLEAN;
    v_note TEXT;
    v_current_stock INT;
    v_unit_price NUMERIC(12, 2);
    v_total_amount NUMERIC(12, 2);
    v_total_items INT := 0;
BEGIN
    SELECT a.building_id INTO v_building_id
    FROM public.issue_reports ir
    JOIN public.apartments a ON a.id = ir.apartment_id
    WHERE ir.id = p_issue_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Không tìm thấy sự cố kỹ thuật yêu cầu.' USING ERRCODE = '22023';
    END IF;

    IF NOT (
        v_is_service
        OR public.is_building_staff(
            v_building_id,
            ARRAY['admin', 'management', 'manager', 'owner', 'technician', 'staff']
        )
    ) THEN
        RAISE EXCEPTION 'Truy cập bị từ chối: Chỉ nhân sự kỹ thuật hoặc BQL tòa nhà mới có quyền xuất kho vật tư.'
            USING ERRCODE = '42501';
    END IF;

    FOR v_item IN SELECT * FROM jsonb_array_elements(p_materials)
    LOOP
        v_material_id := (v_item->>'material_id')::UUID;
        v_qty := COALESCE((v_item->>'quantity')::INT, 1);
        IF v_qty <= 0 THEN
            RAISE EXCEPTION 'Số lượng vật tư xuất kho phải lớn hơn 0.' USING ERRCODE = '22023';
        END IF;
        v_is_chargeable := COALESCE((v_item->>'is_chargeable')::BOOLEAN, false);
        v_note := v_item->>'note';

        SELECT stock_quantity, unit_price INTO v_current_stock, v_unit_price
        FROM public.maintenance_materials
        WHERE id = v_material_id
          AND (building_id IS NULL OR building_id = v_building_id)
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Vật tư với ID % không tồn tại trong kho của tòa nhà', v_material_id;
        END IF;

        IF v_current_stock < v_qty THEN
            RAISE EXCEPTION 'Không đủ tồn kho cho vật tư % (Hiện còn: %, Yêu cầu: %)', v_material_id, v_current_stock, v_qty;
        END IF;

        v_total_amount := v_unit_price * v_qty;

        UPDATE public.maintenance_materials
        SET stock_quantity = stock_quantity - v_qty,
            updated_at = NOW()
        WHERE id = v_material_id;

        INSERT INTO public.issue_materials (
            issue_report_id,
            material_id,
            quantity,
            unit_price,
            total_amount,
            is_chargeable,
            note
        ) VALUES (
            p_issue_id,
            v_material_id,
            v_qty,
            v_unit_price,
            v_total_amount,
            v_is_chargeable,
            v_note
        );

        v_total_items := v_total_items + 1;
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Đã xuất kho và ghi nhận vật tư thành công',
        'items_recorded', v_total_items
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.checkout_visitor_ticket(
    p_ticket_id uuid,
    p_payment_method character varying DEFAULT 'vietqr'::character varying
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
    v_is_service BOOLEAN := COALESCE(auth.jwt() ->> 'role', '') = 'service_role';
    v_building_id UUID;
    v_calc JSONB;
    v_fee NUMERIC;
    v_hours NUMERIC;
    v_now TIMESTAMPTZ := now();
BEGIN
    SELECT building_id INTO v_building_id
    FROM public.visitor_parking_tickets
    WHERE id = p_ticket_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Không tìm thấy vé gửi xe khách.');
    END IF;

    IF NOT (
        v_is_service
        OR (v_building_id IS NOT NULL AND public.is_building_staff(v_building_id))
        OR public.is_super_admin()
    ) THEN
        RAISE EXCEPTION 'Truy cập bị từ chối: Chỉ nhân sự bảo vệ/BQL tòa nhà mới có quyền check-out vé gửi xe.'
            USING ERRCODE = '42501';
    END IF;

    v_calc := public.calculate_visitor_parking_fee(p_ticket_id, v_now);
    IF (v_calc->>'success')::BOOLEAN IS NOT TRUE THEN
        RETURN v_calc;
    END IF;

    v_fee := (v_calc->>'fee_amount')::NUMERIC;
    v_hours := (v_calc->>'total_hours')::NUMERIC;

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
$function$;

CREATE OR REPLACE FUNCTION public.broadcast_announcement(p_announcement_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
    v_is_service BOOLEAN := COALESCE(auth.jwt() ->> 'role', '') = 'service_role';
    v_ann RECORD;
    v_target_user RECORD;
    v_count INT := 0;
    v_clean_target_val TEXT;
    v_building_id UUID;
BEGIN
    SELECT * INTO v_ann
    FROM public.announcements
    WHERE id = p_announcement_id;

    IF v_ann IS NULL THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'message', 'Không tìm thấy thông báo tương ứng.'
        );
    END IF;

    v_building_id := v_ann.building_id;

    IF NOT (
        v_is_service
        OR public.is_super_admin()
        OR (
            v_building_id IS NOT NULL
            AND public.is_building_staff(
                v_building_id,
                ARRAY['admin', 'management', 'manager', 'owner', 'staff', 'receptionist']
            )
        )
    ) THEN
        RAISE EXCEPTION 'Truy cập bị từ chối: Bạn không có quyền phát sóng thông báo cho tòa nhà này.'
            USING ERRCODE = '42501';
    END IF;

    v_clean_target_val := UPPER(TRIM(COALESCE(v_ann.target_value, v_ann.target_apartment, '')));

    FOR v_target_user IN
        SELECT DISTINCT
            u.id AS user_id,
            apt.id AS apartment_id,
            apt.building_id
        FROM public.users u
        JOIN public.residents_apartments ra ON u.id = ra.user_id
        JOIN public.apartments apt ON ra.apartment_id = apt.id
        WHERE u.is_active = TRUE
          AND COALESCE(ra.status, 'active') = 'active'
          AND (v_building_id IS NULL OR apt.building_id = v_building_id)
          AND (
              v_ann.target_type = 'all'
              OR (
                  v_ann.target_type IN ('block', 'block_a', 'block_b')
                  AND (
                      (v_ann.target_type = 'block' AND UPPER(apt.block) = v_clean_target_val)
                      OR (v_ann.target_type = 'block_a' AND (UPPER(apt.block) = 'A' OR apt.code ILIKE 'A%'))
                      OR (v_ann.target_type = 'block_b' AND (UPPER(apt.block) = 'B' OR apt.code ILIKE 'B%'))
                  )
              )
              OR (
                  v_ann.target_type = 'floor'
                  AND apt.floor = CASE
                      WHEN v_clean_target_val ~ '^[0-9]+$' THEN v_clean_target_val::INT
                      ELSE -1
                  END
              )
              OR (
                  v_ann.target_type = 'apartment'
                  AND UPPER(apt.code) = v_clean_target_val
              )
          )
    LOOP
        IF NOT EXISTS (
            SELECT 1 FROM public.notifications n
            WHERE n.user_id = v_target_user.user_id
              AND (n.payload->>'announcement_id') = p_announcement_id::TEXT
        ) THEN
            INSERT INTO public.notifications (
                id,
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
                gen_random_uuid(),
                v_target_user.building_id,
                v_target_user.user_id,
                v_target_user.apartment_id,
                CASE
                    WHEN v_ann.is_urgent THEN '[KHẨN CẤP] ' || v_ann.title
                    ELSE v_ann.title
                END,
                v_ann.content,
                'announcement',
                jsonb_build_object(
                    'announcement_id', v_ann.id,
                    'category', v_ann.category,
                    'is_urgent', v_ann.is_urgent,
                    'event_start_at', v_ann.event_start_at,
                    'event_end_at', v_ann.event_end_at,
                    'hotline_contact', v_ann.hotline_contact
                ),
                FALSE,
                CURRENT_TIMESTAMP
            );

            v_count := v_count + 1;
        END IF;
    END LOOP;

    UPDATE public.announcements
    SET broadcast_count = (
        SELECT COUNT(DISTINCT user_id)
        FROM public.notifications
        WHERE (payload->>'announcement_id') = p_announcement_id::TEXT
    ),
    updated_at = CURRENT_TIMESTAMP
    WHERE id = p_announcement_id;

    RETURN jsonb_build_object(
        'success', TRUE,
        'broadcast_count', v_count,
        'message', 'Đã phát sóng thông báo thành công tới ' || v_count || ' cư dân.'
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.mark_announcement_read(
    p_announcement_id uuid,
    p_user_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
    v_is_service BOOLEAN := COALESCE(auth.jwt() ->> 'role', '') = 'service_role';
    v_uid UUID := auth.uid();
    v_target_user_id UUID;
    v_updated_rows INT := 0;
BEGIN
    IF p_announcement_id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Thiếu mã thông báo bắt buộc.');
    END IF;

    IF NOT v_is_service THEN
        IF v_uid IS NULL THEN
            RAISE EXCEPTION 'Yêu cầu đăng nhập để đánh dấu đã đọc thông báo.' USING ERRCODE = '42501';
        END IF;
        IF p_user_id IS NOT NULL AND p_user_id <> v_uid THEN
            RAISE EXCEPTION 'Truy cập bị từ chối: Không thể cập nhật trạng thái đọc của người dùng khác.'
                USING ERRCODE = '42501';
        END IF;
        v_target_user_id := v_uid;
    ELSE
        IF p_user_id IS NULL THEN
            RETURN jsonb_build_object('success', FALSE, 'message', 'Thiếu tham số p_user_id.');
        END IF;
        v_target_user_id := p_user_id;
    END IF;

    UPDATE public.notifications
    SET is_read = TRUE
    WHERE user_id = v_target_user_id
      AND (payload->>'announcement_id') = p_announcement_id::TEXT
      AND is_read = FALSE;

    GET DIAGNOSTICS v_updated_rows = ROW_COUNT;

    UPDATE public.announcements
    SET read_count = (
        SELECT COUNT(DISTINCT user_id)
        FROM public.notifications
        WHERE (payload->>'announcement_id') = p_announcement_id::TEXT
          AND is_read = TRUE
    ),
    updated_at = CURRENT_TIMESTAMP
    WHERE id = p_announcement_id;

    RETURN jsonb_build_object(
        'success', TRUE,
        'updated_count', v_updated_rows
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.triage_and_auto_assign_issue(
    p_issue_id uuid,
    p_auto_assign boolean DEFAULT true
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
    v_is_service BOOLEAN := COALESCE(auth.jwt() ->> 'role', '') = 'service_role';
    v_issue RECORD;
    v_building_id UUID;
    v_best_staff RECORD;
BEGIN
    SELECT * INTO v_issue
    FROM public.issue_reports
    WHERE id = p_issue_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Không tìm thấy sự cố kỹ thuật yêu cầu.'
        );
    END IF;

    SELECT building_id INTO v_building_id
    FROM public.apartments
    WHERE id = v_issue.apartment_id;

    IF NOT (v_is_service OR public.can_access_apartment(v_issue.apartment_id)) THEN
        RAISE EXCEPTION 'Truy cập bị từ chối: Bạn không có quyền điều phối sự cố này.'
            USING ERRCODE = '42501';
    END IF;

    IF v_issue.assigned_staff_id IS NULL AND p_auto_assign THEN
        SELECT
            u.id,
            u.full_name,
            COUNT(i.id) FILTER (WHERE i.status::text IN ('reported', 'assigned', 'in_progress')) AS active_workload
        INTO v_best_staff
        FROM public.users u
        LEFT JOIN public.issue_reports i ON i.assigned_staff_id = u.id
        WHERE u.is_active = TRUE
          AND COALESCE(u.is_locked, FALSE) = FALSE
          AND (
              EXISTS (
                  SELECT 1 FROM public.building_memberships bm
                  WHERE bm.building_id = v_building_id
                    AND bm.user_id = u.id
                    AND bm.is_active = TRUE
                    AND (bm.expires_at IS NULL OR bm.expires_at > now())
                    AND COALESCE(bm.role::text, bm.building_role::text) IN ('technician', 'staff', 'manager', 'management')
              )
              OR EXISTS (
                  SELECT 1 FROM public.building_staff bs
                  WHERE bs.building_id = v_building_id
                    AND bs.user_id = u.id
              )
          )
        GROUP BY u.id, u.full_name, u.created_at
        ORDER BY active_workload ASC, u.created_at ASC
        LIMIT 1;

        IF v_best_staff.id IS NOT NULL THEN
            UPDATE public.issue_reports
            SET assigned_staff_id = v_best_staff.id,
                status = 'in_progress'::public.issue_status,
                auto_assigned = true,
                updated_at = now()
            WHERE id = p_issue_id;

            RETURN jsonb_build_object(
                'success', true,
                'issue_id', p_issue_id,
                'auto_assigned', true,
                'assigned_staff_id', v_best_staff.id,
                'assigned_staff_name', v_best_staff.full_name,
                'workload', v_best_staff.active_workload,
                'category', v_issue.category,
                'priority', v_issue.priority,
                'is_hazardous', v_issue.is_hazardous,
                'message', format('Đã tự động phân công sự cố cho kỹ thuật viên %s.', v_best_staff.full_name)
            );
        END IF;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'issue_id', p_issue_id,
        'auto_assigned', false,
        'assigned_staff_id', v_issue.assigned_staff_id,
        'category', v_issue.category,
        'priority', v_issue.priority,
        'is_hazardous', v_issue.is_hazardous,
        'message', 'Thông tin sự cố đã được phân loại thành công.'
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.approve_link_request(p_request_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
    v_is_service BOOLEAN := COALESCE(auth.jwt() ->> 'role', '') = 'service_role';
    v_user_id UUID;
    v_apartment_id UUID;
    v_building_id UUID;
    v_status VARCHAR(20);
    v_requested_role public.relation_type;
BEGIN
    SELECT alr.user_id, alr.apartment_id, alr.status, alr.requested_relation_role, a.building_id
    INTO v_user_id, v_apartment_id, v_status, v_requested_role, v_building_id
    FROM public.apartment_link_requests alr
    JOIN public.apartments a ON a.id = alr.apartment_id
    WHERE alr.id = p_request_id
    FOR UPDATE OF alr;

    IF v_status IS NULL THEN
        RAISE EXCEPTION 'Không tìm thấy yêu cầu liên kết.';
    END IF;

    IF NOT (
        v_is_service
        OR public.is_building_staff(
            v_building_id,
            ARRAY['admin', 'management', 'manager', 'owner', 'staff', 'receptionist']
        )
    ) THEN
        RAISE EXCEPTION 'Chỉ Ban Quản Lý hoặc Quản trị viên tòa nhà này mới có quyền duyệt yêu cầu liên kết căn hộ.'
            USING ERRCODE = '42501';
    END IF;

    IF v_status != 'pending' THEN
        RAISE EXCEPTION 'Yêu cầu này đã được xử lý.';
    END IF;

    UPDATE public.apartment_link_requests
    SET status = 'approved', updated_at = NOW()
    WHERE id = p_request_id;

    INSERT INTO public.residents_apartments (user_id, apartment_id, relation_role, status)
    VALUES (v_user_id, v_apartment_id, v_requested_role, 'active')
    ON CONFLICT (user_id, apartment_id) DO UPDATE
    SET relation_role = EXCLUDED.relation_role,
        status = 'active',
        updated_at = NOW();

    UPDATE public.apartments
    SET is_empty = false, updated_at = NOW()
    WHERE id = v_apartment_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.batch_record_meter_readings(
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
    v_user_id UUID := auth.uid();
    v_item JSONB;
    v_apt_id UUID;
    v_building_id UUID;
    v_elec NUMERIC(10, 2);
    v_water NUMERIC(10, 2);
    v_elec_img TEXT;
    v_water_img TEXT;
    v_prev_elec NUMERIC(10, 2);
    v_prev_water NUMERIC(10, 2);
    v_inserted_count INT := 0;
BEGIN
    IF NOT v_is_service AND v_user_id IS NULL THEN
        RAISE EXCEPTION 'Yêu cầu đăng nhập để chốt chỉ số công tơ hàng loạt.' USING ERRCODE = '42501';
    END IF;

    FOR v_item IN SELECT * FROM jsonb_array_elements(p_readings)
    LOOP
        v_apt_id := (v_item->>'apartment_id')::UUID;
        v_elec := (v_item->>'electric_reading')::NUMERIC;
        v_water := (v_item->>'water_reading')::NUMERIC;
        v_elec_img := v_item->>'electric_image_url';
        v_water_img := v_item->>'water_image_url';

        SELECT building_id INTO v_building_id
        FROM public.apartments
        WHERE id = v_apt_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Không tìm thấy căn hộ %', v_apt_id USING ERRCODE = '22023';
        END IF;

        IF NOT (
            v_is_service
            OR public.is_building_staff(
                v_building_id,
                ARRAY['admin', 'management', 'manager', 'owner', 'accountant', 'technician', 'staff']
            )
        ) THEN
            RAISE EXCEPTION 'Truy cập bị từ chối: Bạn không có quyền chốt chỉ số cho căn hộ thuộc tòa nhà khác.'
                USING ERRCODE = '42501';
        END IF;

        SELECT electric_reading, water_reading INTO v_prev_elec, v_prev_water
        FROM public.meter_reading_submissions
        WHERE apartment_id = v_apt_id AND status = 'approved'
        ORDER BY created_at DESC
        LIMIT 1;

        INSERT INTO public.meter_reading_submissions (
            apartment_id,
            submitted_by,
            reader_id,
            period,
            electric_reading,
            water_reading,
            previous_electric_reading,
            previous_water_reading,
            electric_image_url,
            water_image_url,
            status,
            created_at,
            updated_at
        ) VALUES (
            v_apt_id,
            COALESCE(v_user_id, v_apt_id),
            v_user_id,
            p_period,
            v_elec,
            v_water,
            v_prev_elec,
            v_prev_water,
            v_elec_img,
            v_water_img,
            'pending'::public.meter_submission_status,
            now(),
            now()
        );

        v_inserted_count := v_inserted_count + 1;
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'message', format('Đã chốt thành công %s căn hộ cho kỳ %s', v_inserted_count, p_period),
        'inserted_count', v_inserted_count
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.batch_import_apartments(
    p_building_id uuid,
    p_apartments jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
    v_is_service BOOLEAN := COALESCE(auth.jwt() ->> 'role', '') = 'service_role';
    v_calling_user_id UUID := auth.uid();
    v_apt JSONB;
    v_code TEXT;
    v_area NUMERIC;
    v_is_empty BOOLEAN;
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
            AND public.is_building_staff(p_building_id, ARRAY['admin', 'management', 'manager', 'owner'])
        )
    ) THEN
        RAISE EXCEPTION 'Truy cập bị từ chối: Bạn không có quyền nhập căn hộ hàng loạt cho tòa nhà này.'
            USING ERRCODE = '42501';
    END IF;

    FOR v_apt IN SELECT * FROM jsonb_array_elements(p_apartments)
    LOOP
        v_code := UPPER(TRIM(v_apt->>'code'));
        v_area := COALESCE((v_apt->>'area')::numeric, 50.0);
        v_is_empty := COALESCE((v_apt->>'is_empty')::boolean, TRUE);

        IF v_code IS NOT NULL AND v_code != '' THEN
            INSERT INTO public.apartments (building_id, code, area, is_empty, created_at, updated_at)
            VALUES (p_building_id, v_code, v_area, v_is_empty, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
            ON CONFLICT (building_id, code) DO UPDATE
            SET area = EXCLUDED.area,
                updated_at = CURRENT_TIMESTAMP;

            v_success_count := v_success_count + 1;
            v_imported_codes := v_imported_codes || jsonb_build_array(v_code);
        END IF;
    END LOOP;

    RETURN jsonb_build_object(
        'success', TRUE,
        'success_count', v_success_count,
        'imported_codes', v_imported_codes
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
            )
            ON CONFLICT (apartment_id, period) DO UPDATE
            SET electric_reading = EXCLUDED.electric_reading,
                water_reading = EXCLUDED.water_reading,
                status = 'approved'::public.meter_submission_status,
                reviewed_by = EXCLUDED.reviewed_by,
                reviewed_at = CURRENT_TIMESTAMP,
                updated_at = CURRENT_TIMESTAMP;

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

CREATE OR REPLACE FUNCTION public.batch_import_residents(
    p_building_id uuid,
    p_residents jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
    v_is_service BOOLEAN := COALESCE(auth.jwt() ->> 'role', '') = 'service_role';
    v_calling_user_id UUID := auth.uid();
    v_res JSONB;
    v_apt_code TEXT;
    v_full_name TEXT;
    v_phone TEXT;
    v_role_raw TEXT;
    v_relation_role public.relation_type;
    v_apt_id UUID;
    v_user_id UUID;
    v_success_count INT := 0;
    v_imported_phones JSONB := '[]'::jsonb;
BEGIN
    IF p_building_id IS NULL THEN
        RAISE EXCEPTION 'Thiếu mã tòa nhà (p_building_id).' USING ERRCODE = '22023';
    END IF;

    IF NOT (
        v_is_service
        OR (
            v_calling_user_id IS NOT NULL
            AND public.is_building_staff(p_building_id, ARRAY['admin', 'management', 'manager', 'owner'])
        )
    ) THEN
        RAISE EXCEPTION 'Truy cập bị từ chối: Bạn không có quyền nhập cư dân hàng loạt cho tòa nhà này.'
            USING ERRCODE = '42501';
    END IF;

    FOR v_res IN SELECT * FROM jsonb_array_elements(p_residents)
    LOOP
        v_apt_code := UPPER(TRIM(v_res->>'apartment_code'));
        v_full_name := TRIM(v_res->>'full_name');
        v_phone := TRIM(v_res->>'phone');
        v_role_raw := COALESCE(NULLIF(LOWER(TRIM(v_res->>'relation_role')), ''), 'member');

        BEGIN
            v_relation_role := v_role_raw::public.relation_type;
        EXCEPTION WHEN OTHERS THEN
            v_relation_role := 'member'::public.relation_type;
        END;

        SELECT id INTO v_apt_id
        FROM public.apartments
        WHERE UPPER(code) = v_apt_code
          AND building_id = p_building_id
        LIMIT 1;

        IF v_apt_id IS NOT NULL AND v_phone IS NOT NULL AND v_phone != '' THEN
            SELECT id INTO v_user_id
            FROM public.users
            WHERE phone = v_phone
            LIMIT 1;

            IF v_user_id IS NULL THEN
                v_user_id := gen_random_uuid();
                INSERT INTO public.users (id, full_name, phone, role, created_at, updated_at)
                VALUES (v_user_id, v_full_name, v_phone, 'resident', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);
            ELSE
                UPDATE public.users
                SET full_name = COALESCE(NULLIF(v_full_name, ''), full_name),
                    updated_at = CURRENT_TIMESTAMP
                WHERE id = v_user_id;
            END IF;

            IF v_relation_role = 'owner'::public.relation_type THEN
                UPDATE public.residents_apartments
                SET status = 'terminated',
                    end_date = CURRENT_TIMESTAMP,
                    updated_at = CURRENT_TIMESTAMP
                WHERE apartment_id = v_apt_id
                  AND relation_role = 'owner'::public.relation_type
                  AND COALESCE(status, 'active') = 'active'
                  AND user_id != v_user_id;
            END IF;

            INSERT INTO public.residents_apartments (
                user_id, apartment_id, relation_role, status, start_date, created_at, updated_at
            )
            VALUES (
                v_user_id, v_apt_id, v_relation_role, 'active', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
            )
            ON CONFLICT (user_id, apartment_id) DO UPDATE
            SET relation_role = EXCLUDED.relation_role,
                status = 'active',
                end_date = NULL,
                updated_at = CURRENT_TIMESTAMP;

            UPDATE public.apartments
            SET is_empty = FALSE,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = v_apt_id;

            v_success_count := v_success_count + 1;
            v_imported_phones := v_imported_phones || jsonb_build_array(v_phone);
        END IF;
    END LOOP;

    RETURN jsonb_build_object(
        'success', TRUE,
        'success_count', v_success_count,
        'imported_phones', v_imported_phones
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.import_residents_batch(p_residents jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
    v_is_service BOOLEAN := COALESCE(auth.jwt() ->> 'role', '') = 'service_role';
    v_calling_user_id UUID := auth.uid();
    v_res JSONB;
    v_apt_code TEXT;
    v_full_name TEXT;
    v_phone TEXT;
    v_role_raw TEXT;
    v_relation_role public.relation_type;
    v_apt_id UUID;
    v_apt_building_id UUID;
    v_user_id UUID;
    v_success_count INT := 0;
BEGIN
    IF NOT (
        v_is_service
        OR public.is_super_admin()
        OR (
            v_calling_user_id IS NOT NULL
            AND EXISTS (SELECT 1 FROM public.get_user_accessible_buildings(v_calling_user_id))
        )
    ) THEN
        RAISE EXCEPTION 'Truy cập bị từ chối: Chỉ Ban Quản Lý hoặc Admin mới có quyền nhập cư dân hàng loạt.'
            USING ERRCODE = '42501';
    END IF;

    FOR v_res IN SELECT * FROM jsonb_array_elements(p_residents)
    LOOP
        v_apt_code := UPPER(TRIM(v_res->>'apartment_code'));
        v_full_name := TRIM(v_res->>'full_name');
        v_phone := TRIM(v_res->>'phone');
        v_role_raw := COALESCE(NULLIF(LOWER(TRIM(v_res->>'relation_role')), ''), 'member');

        BEGIN
            v_relation_role := v_role_raw::public.relation_type;
        EXCEPTION WHEN OTHERS THEN
            v_relation_role := 'member'::public.relation_type;
        END;

        IF v_apt_code IS NOT NULL AND v_apt_code != '' AND v_phone IS NOT NULL AND v_phone != '' THEN
            SELECT id, building_id INTO v_apt_id, v_apt_building_id
            FROM public.apartments
            WHERE UPPER(code) = v_apt_code
              AND (
                  v_is_service
                  OR public.is_building_staff(building_id, ARRAY['admin', 'management', 'manager', 'owner'])
              )
            LIMIT 1;

            IF v_apt_id IS NOT NULL THEN
                SELECT id INTO v_user_id FROM public.users WHERE phone = v_phone LIMIT 1;

                IF v_user_id IS NULL THEN
                    v_user_id := gen_random_uuid();
                    INSERT INTO public.users (id, full_name, phone, role, is_active, created_at, updated_at)
                    VALUES (v_user_id, v_full_name, v_phone, 'resident', FALSE, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);
                END IF;

                INSERT INTO public.residents_apartments (apartment_id, user_id, relation_role, status, created_at, updated_at)
                VALUES (v_apt_id, v_user_id, v_relation_role, 'active', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                ON CONFLICT (apartment_id, user_id) DO UPDATE
                SET relation_role = EXCLUDED.relation_role,
                    status = 'active',
                    updated_at = CURRENT_TIMESTAMP;

                UPDATE public.apartments SET is_empty = FALSE, updated_at = CURRENT_TIMESTAMP WHERE id = v_apt_id;
                v_success_count := v_success_count + 1;
            END IF;
        END IF;
    END LOOP;

    RETURN jsonb_build_object(
        'success', TRUE,
        'imported_count', v_success_count,
        'message', 'Đã nhập thành công ' || v_success_count || ' hồ sơ cư dân.'
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_building_activation_list(p_building_id uuid)
RETURNS TABLE(
    activation_id uuid,
    user_id uuid,
    full_name character varying,
    phone character varying,
    apartment_code character varying,
    relation_role text,
    activation_code character varying,
    status character varying,
    expires_at timestamp with time zone,
    created_at timestamp with time zone,
    code_attempts integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
    v_is_service BOOLEAN := COALESCE(auth.jwt() ->> 'role', '') = 'service_role';
    v_caller_id UUID := auth.uid();
BEGIN
    IF p_building_id IS NOT NULL THEN
        IF NOT (
            v_is_service
            OR public.is_building_staff(
                p_building_id,
                ARRAY['admin', 'management', 'manager', 'owner', 'staff', 'receptionist']
            )
        ) THEN
            RAISE EXCEPTION 'Truy cập bị từ chối: Bạn không có quyền tra cứu danh sách kích hoạt của tòa nhà này.'
                USING ERRCODE = '42501';
        END IF;
    ELSE
        IF NOT (
            v_is_service
            OR public.is_super_admin()
            OR (
                v_caller_id IS NOT NULL
                AND EXISTS (SELECT 1 FROM public.get_user_accessible_buildings(v_caller_id))
            )
        ) THEN
            RAISE EXCEPTION 'Truy cập bị từ chối: Chỉ Ban Quản Lý mới có quyền tra cứu danh sách kích hoạt.'
                USING ERRCODE = '42501';
        END IF;
    END IF;

    RETURN QUERY
    SELECT
        act.id AS activation_id,
        u.id AS user_id,
        u.full_name,
        u.phone,
        a.code AS apartment_code,
        ra.relation_role::TEXT,
        act.activation_code,
        act.status,
        act.expires_at,
        act.created_at,
        act.code_attempts
    FROM public.resident_activations act
    JOIN public.users u ON u.id = act.user_id
    JOIN public.apartments a ON a.id = act.apartment_id
    LEFT JOIN public.residents_apartments ra ON ra.user_id = u.id AND ra.apartment_id = a.id
    WHERE (p_building_id IS NOT NULL AND a.building_id = p_building_id)
       OR (
           p_building_id IS NULL
           AND (
               v_is_service
               OR public.is_super_admin()
               OR a.building_id IN (SELECT public.get_user_accessible_buildings(v_caller_id))
           )
       )
    ORDER BY act.created_at DESC;
END;
$function$;

CREATE OR REPLACE FUNCTION public.regenerate_resident_activation(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_catalog'
AS $function$
DECLARE
    v_is_service BOOLEAN := COALESCE(auth.jwt() ->> 'role', '') = 'service_role';
    v_caller_id UUID := auth.uid();
    v_user RECORD;
    v_apartment_id UUID;
    v_apt_code VARCHAR;
    v_building_id UUID;
    v_code VARCHAR(32);
    v_hash VARCHAR(64);
BEGIN
    SELECT * INTO v_user FROM public.users WHERE id = p_user_id;
    IF v_user IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Không tìm thấy hồ sơ cư dân.');
    END IF;

    SELECT ra.apartment_id, a.code, a.building_id
    INTO v_apartment_id, v_apt_code, v_building_id
    FROM public.residents_apartments ra
    JOIN public.apartments a ON a.id = ra.apartment_id
    WHERE ra.user_id = p_user_id AND COALESCE(ra.status, 'active') = 'active'
    LIMIT 1;

    IF v_apartment_id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Cư dân chưa được gắn vào bất kỳ căn hộ nào.');
    END IF;

    IF NOT (
        v_is_service
        OR public.is_building_staff(
            v_building_id,
            ARRAY['admin', 'management', 'manager', 'owner', 'staff', 'receptionist']
        )
    ) THEN
        RAISE EXCEPTION 'Truy cập bị từ chối: Chỉ Ban Quản Lý tòa nhà này mới có quyền cấp lại mã kích hoạt.'
            USING ERRCODE = '42501';
    END IF;

    IF v_user.is_active = TRUE THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Cư dân này đã kích hoạt tài khoản thành công, không thể cấp lại mã.');
    END IF;

    UPDATE public.resident_activations
    SET status = 'revoked', updated_at = CURRENT_TIMESTAMP
    WHERE user_id = p_user_id AND status IN ('pending', 'otp_sent');

    v_code := 'ACT-' || LPAD((FLOOR(RANDOM() * 900000) + 100000)::TEXT, 6, '0');
    v_hash := encode(digest(v_code, 'sha256'), 'hex');

    INSERT INTO public.resident_activations (
        user_id,
        apartment_id,
        phone,
        activation_code,
        activation_code_hash,
        code_attempts,
        invited_by,
        status,
        expires_at
    ) VALUES (
        p_user_id,
        v_apartment_id,
        v_user.phone,
        v_code,
        v_hash,
        0,
        v_caller_id,
        'pending',
        CURRENT_TIMESTAMP + INTERVAL '30 days'
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Đã cấp lại mã kích hoạt thành công.',
        'activation_code', v_code,
        'phone', v_user.phone,
        'apartment_code', v_apt_code
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.revoke_resident_activation(p_activation_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
    v_is_service BOOLEAN := COALESCE(auth.jwt() ->> 'role', '') = 'service_role';
    v_caller_id UUID := auth.uid();
    v_act RECORD;
    v_building_id UUID;
BEGIN
    SELECT act.*, a.building_id INTO v_act
    FROM public.resident_activations act
    JOIN public.apartments a ON a.id = act.apartment_id
    WHERE act.id = p_activation_id;

    IF v_act IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Không tìm thấy bản ghi kích hoạt.');
    END IF;

    v_building_id := v_act.building_id;

    IF NOT (
        v_is_service
        OR public.is_building_staff(
            v_building_id,
            ARRAY['admin', 'management', 'manager', 'owner', 'staff', 'receptionist']
        )
    ) THEN
        RAISE EXCEPTION 'Truy cập bị từ chối: Chỉ Ban Quản Lý tòa nhà này mới có quyền thu hồi mã kích hoạt.'
            USING ERRCODE = '42501';
    END IF;

    UPDATE public.resident_activations
    SET status = 'revoked',
        revoked_at = CURRENT_TIMESTAMP,
        revoked_by = v_caller_id,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_activation_id;

    RETURN jsonb_build_object('success', TRUE, 'message', 'Đã thu hồi mã kích hoạt thành công.');
END;
$function$;

CREATE OR REPLACE FUNCTION public.create_apartment_invitation(
    p_apartment_id uuid,
    p_target_role character varying DEFAULT 'member'::character varying,
    p_expires_hours integer DEFAULT 48,
    p_max_uses integer DEFAULT 1
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
    v_is_service BOOLEAN := COALESCE(auth.jwt() ->> 'role', '') = 'service_role';
    v_caller_id UUID := auth.uid();
    v_is_authorized BOOLEAN := FALSE;
    v_code VARCHAR(16);
    v_expires_at TIMESTAMPTZ;
    v_invitation_id UUID;
    v_apt_code VARCHAR(50);
    v_building_id UUID;
BEGIN
    SELECT code, building_id INTO v_apt_code, v_building_id
    FROM public.apartments
    WHERE id = p_apartment_id;

    IF v_apt_code IS NULL THEN
        RAISE EXCEPTION 'Không tìm thấy căn hộ yêu cầu.';
    END IF;

    v_is_authorized := v_is_service
        OR public.is_building_staff(v_building_id, ARRAY['admin', 'management', 'manager', 'owner'])
        OR EXISTS (
            SELECT 1 FROM public.residents_apartments
            WHERE apartment_id = p_apartment_id
              AND user_id = v_caller_id
              AND relation_role = 'owner'::public.relation_type
              AND COALESCE(status, 'active') = 'active'
        );

    IF NOT v_is_authorized THEN
        RAISE EXCEPTION 'Bạn không có quyền tạo mã mời cho căn hộ này.' USING ERRCODE = '42501';
    END IF;

    v_code := UPPER(CONCAT('VVN', SUBSTRING(REPLACE(gen_random_uuid()::TEXT, '-', '') FROM 1 FOR 5)));
    v_expires_at := now() + (COALESCE(p_expires_hours, 48) || ' hours')::INTERVAL;

    INSERT INTO public.apartment_invitations (
        apartment_id,
        created_by,
        invite_code,
        target_role,
        max_uses,
        expires_at,
        status
    ) VALUES (
        p_apartment_id,
        v_caller_id,
        v_code,
        p_target_role::public.apartment_relation_role,
        COALESCE(p_max_uses, 1),
        v_expires_at,
        'active'
    ) RETURNING id INTO v_invitation_id;

    RETURN jsonb_build_object(
        'success', TRUE,
        'invitation_id', v_invitation_id,
        'invite_code', v_code,
        'apartment_id', p_apartment_id,
        'apartment_code', v_apt_code,
        'target_role', p_target_role,
        'expires_at', v_expires_at
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.terminate_resident_stay(
    p_user_id uuid,
    p_apartment_id uuid,
    p_termination_date date DEFAULT CURRENT_DATE,
    p_note text DEFAULT ''::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
    v_is_service BOOLEAN := COALESCE(auth.jwt() ->> 'role', '') = 'service_role';
    v_caller_id UUID := auth.uid();
    v_building_id UUID;
    v_is_authorized BOOLEAN := FALSE;
    v_remaining_active INT;
BEGIN
    SELECT building_id INTO v_building_id
    FROM public.apartments
    WHERE id = p_apartment_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Không tìm thấy căn hộ yêu cầu.' USING ERRCODE = '22023';
    END IF;

    v_is_authorized := v_is_service
        OR public.is_building_staff(v_building_id, ARRAY['admin', 'management', 'manager', 'owner'])
        OR EXISTS (
            SELECT 1 FROM public.residents_apartments
            WHERE apartment_id = p_apartment_id
              AND user_id = v_caller_id
              AND relation_role = 'owner'::public.relation_type
              AND COALESCE(status, 'active') = 'active'
        );

    IF NOT v_is_authorized THEN
        RAISE EXCEPTION 'Bạn không có quyền kết thúc lưu trú cho căn hộ này.' USING ERRCODE = '42501';
    END IF;

    UPDATE public.residents_apartments
    SET status = 'terminated',
        end_date = COALESCE(p_termination_date, CURRENT_DATE),
        note = CASE
            WHEN p_note IS NOT NULL AND TRIM(p_note) != '' THEN COALESCE(note || E'\n', '') || TRIM(p_note)
            ELSE note
        END,
        updated_at = now()
    WHERE user_id = p_user_id AND apartment_id = p_apartment_id;

    SELECT COUNT(*) INTO v_remaining_active
    FROM public.residents_apartments
    WHERE apartment_id = p_apartment_id AND COALESCE(status, 'active') = 'active';

    IF v_remaining_active = 0 THEN
        UPDATE public.apartments SET is_empty = TRUE, updated_at = now() WHERE id = p_apartment_id;
    END IF;

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Đã kết thúc lưu trú thành công và lưu vết lịch sử đầy đủ.',
        'user_id', p_user_id,
        'apartment_id', p_apartment_id,
        'remaining_active_residents', v_remaining_active
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.calculate_apartment_debt_risk(
    p_building_id uuid,
    p_apartment_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
    v_is_service BOOLEAN := COALESCE(auth.jwt() ->> 'role', '') = 'service_role';
    v_apt_building_id UUID;
    v_unpaid_amount NUMERIC(15, 2) := 0;
    v_overdue_days INTEGER := 0;
    v_monthly_fee_avg NUMERIC(15, 2) := 0;
    v_late_payment_count INTEGER := 0;
    v_score_overdue NUMERIC := 0;
    v_score_ratio NUMERIC := 0;
    v_score_history NUMERIC := 0;
    v_total_score INTEGER := 0;
    v_risk_level VARCHAR(20) := 'low';
    v_recommended_tier VARCHAR(20) := 'tier_1';
    v_debt_ratio NUMERIC := 0;
    v_factors JSONB := '[]'::jsonb;
    v_result JSONB;
BEGIN
    SELECT building_id INTO v_apt_building_id
    FROM public.apartments
    WHERE id = p_apartment_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Không tìm thấy căn hộ yêu cầu.' USING ERRCODE = '22023';
    END IF;

    IF v_apt_building_id IS DISTINCT FROM p_building_id THEN
        RAISE EXCEPTION 'Căn hộ không thuộc tòa nhà được chỉ định.' USING ERRCODE = '22023';
    END IF;

    IF NOT (
        v_is_service
        OR public.is_building_staff(
            p_building_id,
            ARRAY['admin', 'management', 'manager', 'owner', 'accountant']
        )
    ) THEN
        RAISE EXCEPTION 'Truy cập bị từ chối: Chỉ Ban Quản Lý hoặc Kế toán tòa nhà mới có quyền tính toán rủi ro nợ xấu.'
            USING ERRCODE = '42501';
    END IF;

    SELECT
        COALESCE(SUM(total_amount), 0),
        COALESCE(MAX(GREATEST(0, (CURRENT_DATE - due_date::date))), 0)
    INTO v_unpaid_amount, v_overdue_days
    FROM public.invoices
    WHERE apartment_id = p_apartment_id
      AND status IN ('unpaid', 'overdue');

    SELECT COALESCE(AVG(total_amount), 0)
    INTO v_monthly_fee_avg
    FROM (
        SELECT total_amount FROM public.invoices
        WHERE apartment_id = p_apartment_id
          AND status != 'cancelled'
        ORDER BY created_at DESC
        LIMIT 6
    ) sub;

    IF v_monthly_fee_avg <= 0 THEN
        v_monthly_fee_avg := 1500000;
    END IF;

    SELECT COUNT(*)
    INTO v_late_payment_count
    FROM public.invoices
    WHERE apartment_id = p_apartment_id
      AND status = 'paid'
      AND updated_at::date > due_date::date;

    IF v_overdue_days = 0 THEN
        v_score_overdue := 0;
    ELSIF v_overdue_days <= 15 THEN
        v_score_overdue := LEAST(40, v_overdue_days * 2.6);
    ELSIF v_overdue_days <= 30 THEN
        v_score_overdue := LEAST(70, 40 + (v_overdue_days - 15) * 2.0);
    ELSE
        v_score_overdue := LEAST(100, 70 + (v_overdue_days - 30) * 1.5);
    END IF;

    v_debt_ratio := v_unpaid_amount / v_monthly_fee_avg;
    IF v_debt_ratio <= 0 THEN
        v_score_ratio := 0;
    ELSIF v_debt_ratio <= 1.0 THEN
        v_score_ratio := LEAST(40, v_debt_ratio * 40);
    ELSIF v_debt_ratio <= 2.0 THEN
        v_score_ratio := LEAST(70, 40 + (v_debt_ratio - 1.0) * 30);
    ELSE
        v_score_ratio := LEAST(100, 70 + (v_debt_ratio - 2.0) * 30);
    END IF;

    IF v_late_payment_count = 0 THEN
        v_score_history := 0;
    ELSIF v_late_payment_count = 1 THEN
        v_score_history := 25;
    ELSIF v_late_payment_count = 2 THEN
        v_score_history := 50;
    ELSIF v_late_payment_count = 3 THEN
        v_score_history := 75;
    ELSE
        v_score_history := 100;
    END IF;

    v_total_score := LEAST(100, GREATEST(0, ROUND(0.40 * v_score_overdue + 0.35 * v_score_ratio + 0.25 * v_score_history)));

    IF v_total_score >= 70 THEN
        v_risk_level := 'high';
        v_recommended_tier := 'tier_3';
    ELSIF v_total_score >= 40 THEN
        v_risk_level := 'medium';
        v_recommended_tier := 'tier_2';
    ELSE
        v_risk_level := 'low';
        v_recommended_tier := 'tier_1';
    END IF;

    IF v_overdue_days > 45 THEN
        v_recommended_tier := 'tier_3';
    END IF;

    IF v_overdue_days > 0 THEN
        v_factors := v_factors || jsonb_build_object(
            'factor', 'overdue_duration',
            'label', 'Quá hạn ' || v_overdue_days || ' ngày',
            'severity', CASE WHEN v_overdue_days > 30 THEN 'high' WHEN v_overdue_days > 15 THEN 'medium' ELSE 'low' END
        );
    END IF;

    IF v_debt_ratio >= 1.5 THEN
        v_factors := v_factors || jsonb_build_object(
            'factor', 'debt_ratio',
            'label', 'Nợ vượt ' || ROUND(v_debt_ratio, 1) || ' lần phí định kỳ',
            'severity', CASE WHEN v_debt_ratio >= 2.0 THEN 'high' ELSE 'medium' END
        );
    END IF;

    IF v_late_payment_count >= 2 THEN
        v_factors := v_factors || jsonb_build_object(
            'factor', 'late_history',
            'label', 'Từng nộp muộn ' || v_late_payment_count || ' kỳ trong quá khứ',
            'severity', CASE WHEN v_late_payment_count >= 3 THEN 'high' ELSE 'medium' END
        );
    END IF;

    INSERT INTO public.debt_risk_scores (
        apartment_id,
        building_id,
        risk_score,
        risk_level,
        overdue_days,
        unpaid_amount,
        monthly_fee_avg,
        late_payment_count,
        recommended_tier,
        risk_factors,
        assessed_at,
        updated_at
    )
    VALUES (
        p_apartment_id,
        p_building_id,
        v_total_score,
        v_risk_level,
        v_overdue_days,
        v_unpaid_amount,
        v_monthly_fee_avg,
        v_late_payment_count,
        v_recommended_tier,
        v_factors,
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
    )
    ON CONFLICT (apartment_id) DO UPDATE SET
        building_id = EXCLUDED.building_id,
        risk_score = EXCLUDED.risk_score,
        risk_level = EXCLUDED.risk_level,
        overdue_days = EXCLUDED.overdue_days,
        unpaid_amount = EXCLUDED.unpaid_amount,
        monthly_fee_avg = EXCLUDED.monthly_fee_avg,
        late_payment_count = EXCLUDED.late_payment_count,
        recommended_tier = EXCLUDED.recommended_tier,
        risk_factors = EXCLUDED.risk_factors,
        assessed_at = CURRENT_TIMESTAMP,
        updated_at = CURRENT_TIMESTAMP;

    v_result := jsonb_build_object(
        'apartment_id', p_apartment_id,
        'building_id', p_building_id,
        'risk_score', v_total_score,
        'risk_level', v_risk_level,
        'overdue_days', v_overdue_days,
        'unpaid_amount', v_unpaid_amount,
        'monthly_fee_avg', v_monthly_fee_avg,
        'late_payment_count', v_late_payment_count,
        'recommended_tier', v_recommended_tier,
        'risk_factors', v_factors
    );

    RETURN v_result;
END;
$function$;

CREATE OR REPLACE FUNCTION public.execute_dunning_action(
    p_building_id uuid,
    p_apartment_id uuid,
    p_tier character varying,
    p_title text,
    p_content text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
    v_is_service BOOLEAN := COALESCE(auth.jwt() ->> 'role', '') = 'service_role';
    v_calling_user_id UUID := auth.uid();
    v_apt_building_id UUID;
    v_action_id UUID;
    v_resident_id UUID;
BEGIN
    SELECT building_id INTO v_apt_building_id
    FROM public.apartments
    WHERE id = p_apartment_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Không tìm thấy căn hộ yêu cầu.' USING ERRCODE = '22023';
    END IF;

    IF v_apt_building_id IS DISTINCT FROM p_building_id THEN
        RAISE EXCEPTION 'Căn hộ không thuộc tòa nhà được chỉ định.' USING ERRCODE = '22023';
    END IF;

    IF NOT (
        v_is_service
        OR public.is_building_staff(
            p_building_id,
            ARRAY['admin', 'management', 'manager', 'owner', 'accountant']
        )
    ) THEN
        RAISE EXCEPTION 'Truy cập bị từ chối: Bạn không có quyền thực thi đôn đốc công nợ cho tòa nhà này.'
            USING ERRCODE = '42501';
    END IF;

    IF p_tier NOT IN ('tier_1', 'tier_2', 'tier_3') THEN
        RAISE EXCEPTION 'Cấp độ đôn đốc không hợp lệ: %', p_tier;
    END IF;

    INSERT INTO public.dunning_actions (
        apartment_id,
        building_id,
        tier,
        action_type,
        action_title,
        action_content,
        status,
        performed_by
    )
    VALUES (
        p_apartment_id,
        p_building_id,
        p_tier,
        'notification',
        p_title,
        p_content,
        'sent',
        v_calling_user_id
    )
    RETURNING id INTO v_action_id;

    FOR v_resident_id IN
        SELECT user_id FROM public.residents_apartments
        WHERE apartment_id = p_apartment_id
          AND COALESCE(status, 'active') = 'active'
    LOOP
        INSERT INTO public.notifications (
            building_id,
            apartment_id,
            user_id,
            title,
            body,
            type,
            is_read,
            created_at
        )
        VALUES (
            p_building_id,
            p_apartment_id,
            v_resident_id,
            p_title,
            p_content,
            'payment_reminder',
            FALSE,
            CURRENT_TIMESTAMP
        );
    END LOOP;

    RETURN jsonb_build_object(
        'success', TRUE,
        'action_id', v_action_id,
        'apartment_id', p_apartment_id,
        'tier', p_tier,
        'status', 'sent',
        'created_at', CURRENT_TIMESTAMP
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_building_debt_radar(p_building_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
    v_is_service BOOLEAN := COALESCE(auth.jwt() ->> 'role', '') = 'service_role';
    v_apartments JSONB;
    v_kpi JSONB;
BEGIN
    IF NOT (
        v_is_service
        OR public.is_building_staff(
            p_building_id,
            ARRAY['admin', 'management', 'manager', 'owner', 'accountant']
        )
    ) THEN
        RAISE EXCEPTION 'Truy cập bị từ chối: Chỉ Ban Quản Lý hoặc Kế toán tòa nhà mới có quyền xem radar rủi ro nợ xấu.'
            USING ERRCODE = '42501';
    END IF;

    PERFORM public.calculate_apartment_debt_risk(a.building_id, a.id)
    FROM public.apartments a
    WHERE a.building_id = p_building_id
      AND EXISTS (
          SELECT 1 FROM public.invoices i
          WHERE i.apartment_id = a.id
            AND i.status IN ('unpaid', 'overdue')
      )
      AND NOT EXISTS (
          SELECT 1 FROM public.debt_risk_scores drs
          WHERE drs.apartment_id = a.id
            AND drs.assessed_at > (CURRENT_TIMESTAMP - INTERVAL '1 hour')
      );

    SELECT COALESCE(jsonb_agg(item ORDER BY (item->>'risk_score')::int DESC), '[]'::jsonb)
    INTO v_apartments
    FROM (
        SELECT jsonb_build_object(
            'apartment_id', a.id,
            'apartment_code', a.code,
            'building_id', a.building_id,
            'owner_name', COALESCE(u.full_name, 'Chưa đăng ký'),
            'owner_phone', COALESCE(u.phone, ''),
            'risk_score', COALESCE(drs.risk_score, 0),
            'risk_level', COALESCE(drs.risk_level, 'low'),
            'overdue_days', COALESCE(drs.overdue_days, 0),
            'unpaid_amount', COALESCE(drs.unpaid_amount, 0),
            'monthly_fee_avg', COALESCE(drs.monthly_fee_avg, 0),
            'late_payment_count', COALESCE(drs.late_payment_count, 0),
            'recommended_tier', COALESCE(drs.recommended_tier, 'tier_1'),
            'risk_factors', COALESCE(drs.risk_factors, '[]'::jsonb),
            'last_dunning_tier', (
                SELECT tier FROM public.dunning_actions da
                WHERE da.apartment_id = a.id
                ORDER BY created_at DESC
                LIMIT 1
            ),
            'last_dunning_at', (
                SELECT created_at FROM public.dunning_actions da
                WHERE da.apartment_id = a.id
                ORDER BY created_at DESC
                LIMIT 1
            ),
            'dunning_count', (
                SELECT COUNT(*) FROM public.dunning_actions da
                WHERE da.apartment_id = a.id
            )
        ) AS item
        FROM public.apartments a
        LEFT JOIN public.debt_risk_scores drs ON drs.apartment_id = a.id
        LEFT JOIN public.residents_apartments ra
            ON ra.apartment_id = a.id
           AND ra.relation_role = 'owner'::public.relation_type
           AND COALESCE(ra.status, 'active') = 'active'
        LEFT JOIN public.users u ON ra.user_id = u.id
        WHERE a.building_id = p_building_id
          AND (COALESCE(drs.unpaid_amount, 0) > 0 OR COALESCE(drs.risk_score, 0) > 0)
    ) sub;

    SELECT jsonb_build_object(
        'total_at_risk_apartments', COUNT(*),
        'high_risk_count', COUNT(CASE WHEN drs.risk_level = 'high' THEN 1 END),
        'medium_risk_count', COUNT(CASE WHEN drs.risk_level = 'medium' THEN 1 END),
        'low_risk_count', COUNT(CASE WHEN drs.risk_level = 'low' THEN 1 END),
        'total_overdue_debt', COALESCE(SUM(drs.unpaid_amount), 0),
        'high_risk_debt', COALESCE(SUM(CASE WHEN drs.risk_level = 'high' THEN drs.unpaid_amount ELSE 0 END), 0)
    )
    INTO v_kpi
    FROM public.debt_risk_scores drs
    WHERE drs.building_id = p_building_id
      AND drs.unpaid_amount > 0;

    RETURN jsonb_build_object(
        'building_id', p_building_id,
        'kpi', COALESCE(v_kpi, '{}'::jsonb),
        'apartments', v_apartments
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_apartment_contracts(p_apartment_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
    v_is_service BOOLEAN := COALESCE(auth.jwt() ->> 'role', '') = 'service_role';
    v_results JSONB;
BEGIN
    IF NOT (v_is_service OR public.can_access_apartment(p_apartment_id)) THEN
        RAISE EXCEPTION 'Truy cập bị từ chối: Bạn không có quyền xem thông tin hợp đồng căn hộ này.'
            USING ERRCODE = '42501';
    END IF;

    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', ra.id,
                'user_id', ra.user_id,
                'apartment_id', ra.apartment_id,
                'full_name', u.full_name,
                'phone', u.phone,
                'relation_role', ra.relation_role,
                'status', ra.status,
                'start_date', ra.start_date,
                'end_date', ra.end_date,
                'deposit_amount', ra.deposit_amount,
                'contract_number', ra.contract_number,
                'note', ra.note,
                'created_at', ra.created_at
            ) ORDER BY ra.status ASC, ra.start_date DESC
        ),
        '[]'::JSONB
    ) INTO v_results
    FROM public.residents_apartments ra
    JOIN public.users u ON u.id = ra.user_id
    WHERE ra.apartment_id = p_apartment_id;

    RETURN v_results;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_apartment_ledger_balance(p_apartment_id uuid)
RETURNS numeric
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
    v_is_service BOOLEAN := COALESCE(auth.jwt() ->> 'role', '') = 'service_role';
    v_balance NUMERIC(15,2);
BEGIN
    IF NOT (v_is_service OR public.can_access_apartment(p_apartment_id)) THEN
        RAISE EXCEPTION 'Truy cập bị từ chối: Bạn không có quyền xem số dư sổ cái của căn hộ này.'
            USING ERRCODE = '42501';
    END IF;

    SELECT balance_after INTO v_balance
    FROM public.apartment_ledger_entries
    WHERE apartment_id = p_apartment_id
    ORDER BY created_at DESC, id DESC
    LIMIT 1;

    RETURN COALESCE(v_balance, 0.00);
END;
$function$;

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
    IF NOT (v_is_service OR public.can_access_apartment(p_apartment_id)) THEN
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

CREATE OR REPLACE FUNCTION public.get_organization_subscription_status(p_building_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
    v_is_service BOOLEAN := COALESCE(auth.jwt() ->> 'role', '') = 'service_role';
    v_uid UUID := auth.uid();
    v_org_id UUID;
    v_sub RECORD;
    v_used_apartments INT := 0;
    v_max_apartments INT := 100;
    v_used_buildings INT := 0;
    v_max_buildings INT := 1;
    v_used_staff INT := 0;
    v_max_staff INT := 2;
    v_days_remaining INT := 0;
    v_apt_percent NUMERIC(5, 2) := 0;
BEGIN
    IF NOT v_is_service AND v_uid IS NULL THEN
        RAISE EXCEPTION 'Yêu cầu đăng nhập để xem thông tin gói dịch vụ.' USING ERRCODE = '42501';
    END IF;

    IF p_building_id IS NOT NULL THEN
        IF NOT (v_is_service OR public.can_access_building(p_building_id)) THEN
            RAISE EXCEPTION 'Truy cập bị từ chối: Bạn không có quyền truy cập gói dịch vụ của tòa nhà này.'
                USING ERRCODE = '42501';
        END IF;

        SELECT b.organization_id INTO v_org_id
        FROM public.buildings b
        WHERE b.id = p_building_id;
    END IF;

    IF v_org_id IS NULL AND v_uid IS NOT NULL THEN
        SELECT org_id INTO v_org_id
        FROM public.get_user_accessible_organizations(v_uid) AS org_id
        LIMIT 1;
    END IF;

    IF v_org_id IS NOT NULL THEN
        SELECT
            sub.*,
            p.code AS plan_code,
            p.name AS plan_name,
            p.description AS plan_description,
            p.max_apartments AS plan_max_apartments,
            p.max_buildings AS plan_max_buildings,
            p.max_staff AS plan_max_staff,
            p.price_monthly,
            p.price_yearly,
            p.features
        INTO v_sub
        FROM public.organization_subscriptions sub
        JOIN public.subscription_plans p ON sub.plan_id = p.id
        WHERE sub.organization_id = v_org_id;
    END IF;

    IF v_sub.id IS NULL THEN
        SELECT
            gen_random_uuid() AS id,
            v_org_id AS organization_id,
            p.id AS plan_id,
            'active' AS status,
            now() AS start_date,
            now() + INTERVAL '1 year' AS expires_at,
            'monthly' AS billing_cycle,
            true AS auto_renew,
            NULL::INT AS custom_max_apartments,
            NULL::INT AS custom_max_buildings,
            NULL::INT AS custom_max_staff,
            p.code AS plan_code,
            p.name AS plan_name,
            p.description AS plan_description,
            p.max_apartments AS plan_max_apartments,
            p.max_buildings AS plan_max_buildings,
            p.max_staff AS plan_max_staff,
            p.price_monthly,
            p.price_yearly,
            p.features
        INTO v_sub
        FROM public.subscription_plans p
        WHERE p.code = 'pro'
        LIMIT 1;
    END IF;

    v_max_apartments := COALESCE(v_sub.custom_max_apartments, v_sub.plan_max_apartments, 500);
    v_max_buildings := COALESCE(v_sub.custom_max_buildings, v_sub.plan_max_buildings, 5);
    v_max_staff := COALESCE(v_sub.custom_max_staff, v_sub.plan_max_staff, 10);

    IF v_org_id IS NOT NULL THEN
        SELECT count(a.id) INTO v_used_apartments
        FROM public.apartments a
        JOIN public.buildings b ON a.building_id = b.id
        WHERE b.organization_id = v_org_id;

        SELECT count(id) INTO v_used_buildings
        FROM public.buildings
        WHERE organization_id = v_org_id;

        SELECT COUNT(DISTINCT s.user_id) INTO v_used_staff
        FROM (
            SELECT bs.user_id
            FROM public.building_staff bs
            JOIN public.buildings b ON bs.building_id = b.id
            WHERE b.organization_id = v_org_id
            UNION
            SELECT bm.user_id
            FROM public.building_memberships bm
            JOIN public.buildings b ON bm.building_id = b.id
            WHERE b.organization_id = v_org_id
              AND bm.is_active = true
              AND (bm.expires_at IS NULL OR bm.expires_at > now())
              AND COALESCE(bm.role::text, bm.building_role::text, '') <> 'resident'
        ) s;
    ELSIF v_is_service OR public.is_super_admin() THEN
        SELECT count(*) INTO v_used_apartments FROM public.apartments;
        SELECT count(*) INTO v_used_buildings FROM public.buildings;
        SELECT COUNT(DISTINCT s.user_id) INTO v_used_staff
        FROM (
            SELECT user_id FROM public.building_staff
            UNION
            SELECT user_id FROM public.building_memberships
            WHERE is_active = true
              AND COALESCE(role::text, building_role::text, '') <> 'resident'
        ) s;
    ELSE
        v_used_apartments := 0;
        v_used_buildings := 0;
        v_used_staff := 0;
    END IF;

    IF v_sub.expires_at IS NOT NULL THEN
        v_days_remaining := GREATEST(0, EXTRACT(DAY FROM (v_sub.expires_at - now()))::INT);
    ELSE
        v_days_remaining := 365;
    END IF;

    IF v_max_apartments > 0 THEN
        v_apt_percent := ROUND((v_used_apartments::NUMERIC / v_max_apartments::NUMERIC) * 100, 1);
    ELSE
        v_apt_percent := 0;
    END IF;

    RETURN jsonb_build_object(
        'organization_id', v_org_id,
        'subscription_id', v_sub.id,
        'plan_code', COALESCE(v_sub.plan_code, 'pro'),
        'plan_name', COALESCE(v_sub.plan_name, 'Gói Nâng Cao'),
        'plan_description', v_sub.plan_description,
        'status', COALESCE(v_sub.status, 'active'),
        'start_date', v_sub.start_date,
        'expires_at', v_sub.expires_at,
        'days_remaining', v_days_remaining,
        'is_expiring_soon', (v_days_remaining <= 15),
        'billing_cycle', COALESCE(v_sub.billing_cycle, 'monthly'),
        'auto_renew', COALESCE(v_sub.auto_renew, true),
        'price_monthly', v_sub.price_monthly,
        'price_yearly', v_sub.price_yearly,
        'features', COALESCE(v_sub.features, '{}'::jsonb),
        'usage', jsonb_build_object(
            'used_apartments', v_used_apartments,
            'max_apartments', v_max_apartments,
            'apartment_usage_percent', v_apt_percent,
            'is_near_limit', (v_apt_percent >= 80.0 AND v_max_apartments > 0),
            'is_at_limit', (v_used_apartments >= v_max_apartments AND v_max_apartments > 0),
            'used_buildings', v_used_buildings,
            'max_buildings', v_max_buildings,
            'used_staff', v_used_staff,
            'max_staff', v_max_staff
        )
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_front_desk_stats(
    p_building_id uuid DEFAULT NULL::uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
    v_is_service BOOLEAN := COALESCE(auth.jwt() ->> 'role', '') = 'service_role';
    v_uid UUID := auth.uid();
    v_today_start TIMESTAMPTZ := date_trunc('day', timezone('Asia/Ho_Chi_Minh', now()));
    v_today_end TIMESTAMPTZ := v_today_start + interval '1 day';
    v_three_days_ago TIMESTAMPTZ := timezone('utc'::text, now()) - interval '3 days';
    v_expected_visitors INT := 0;
    v_in_building_visitors INT := 0;
    v_pending_parcels INT := 0;
    v_overdue_parcels INT := 0;
BEGIN
    IF NOT v_is_service AND v_uid IS NULL THEN
        RAISE EXCEPTION 'Yêu cầu đăng nhập nhân sự lễ tân/BQL.' USING ERRCODE = '42501';
    END IF;

    IF p_building_id IS NOT NULL THEN
        IF NOT (v_is_service OR public.is_building_staff(p_building_id)) THEN
            RAISE EXCEPTION 'Truy cập bị từ chối: Bạn không có quyền xem thống kê quầy lễ tân của tòa nhà này.'
                USING ERRCODE = '42501';
        END IF;
    ELSIF NOT (
        v_is_service
        OR public.is_super_admin()
        OR EXISTS (SELECT 1 FROM public.get_user_accessible_buildings(v_uid))
    ) THEN
        RAISE EXCEPTION 'Truy cập bị từ chối: Bạn không có quyền xem thống kê quầy lễ tân.'
            USING ERRCODE = '42501';
    END IF;

    SELECT COUNT(*) INTO v_expected_visitors
    FROM public.visitor_access_passes vp
    JOIN public.apartments apt ON vp.apartment_id = apt.id
    WHERE (
        (p_building_id IS NOT NULL AND apt.building_id = p_building_id)
        OR (
            p_building_id IS NULL
            AND (
                v_is_service
                OR public.is_super_admin()
                OR apt.building_id IN (SELECT public.get_user_accessible_buildings(v_uid))
            )
        )
    )
      AND vp.expected_arrival >= v_today_start
      AND vp.expected_arrival < v_today_end
      AND vp.status != 'cancelled';

    SELECT COUNT(*) INTO v_in_building_visitors
    FROM public.visitor_access_passes vp
    JOIN public.apartments apt ON vp.apartment_id = apt.id
    WHERE (
        (p_building_id IS NOT NULL AND apt.building_id = p_building_id)
        OR (
            p_building_id IS NULL
            AND (
                v_is_service
                OR public.is_super_admin()
                OR apt.building_id IN (SELECT public.get_user_accessible_buildings(v_uid))
            )
        )
    )
      AND vp.status = 'checked_in';

    SELECT COUNT(*) INTO v_pending_parcels
    FROM public.parcels p
    JOIN public.apartments apt ON p.apartment_id = apt.id
    WHERE (
        (p_building_id IS NOT NULL AND apt.building_id = p_building_id)
        OR (
            p_building_id IS NULL
            AND (
                v_is_service
                OR public.is_super_admin()
                OR apt.building_id IN (SELECT public.get_user_accessible_buildings(v_uid))
            )
        )
    )
      AND p.status = 'arrived';

    SELECT COUNT(*) INTO v_overdue_parcels
    FROM public.parcels p
    JOIN public.apartments apt ON p.apartment_id = apt.id
    WHERE (
        (p_building_id IS NOT NULL AND apt.building_id = p_building_id)
        OR (
            p_building_id IS NULL
            AND (
                v_is_service
                OR public.is_super_admin()
                OR apt.building_id IN (SELECT public.get_user_accessible_buildings(v_uid))
            )
        )
    )
      AND p.status = 'arrived'
      AND p.arrived_at < v_three_days_ago;

    RETURN jsonb_build_object(
        'expected_visitors_today', v_expected_visitors,
        'visitors_in_building', v_in_building_visitors,
        'pending_parcels', v_pending_parcels,
        'overdue_parcels', v_overdue_parcels
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_issue_sla_stats(
    p_building_id uuid DEFAULT NULL::uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
    v_is_service BOOLEAN := COALESCE(auth.jwt() ->> 'role', '') = 'service_role';
    v_uid UUID := auth.uid();
    v_total INT := 0;
    v_on_time INT := 0;
    v_warning INT := 0;
    v_breached INT := 0;
    v_compliance_rate NUMERIC(5, 2) := 100.00;
BEGIN
    IF NOT v_is_service AND v_uid IS NULL THEN
        RAISE EXCEPTION 'Yêu cầu đăng nhập nhân sự để xem thống kê SLA sự cố.' USING ERRCODE = '42501';
    END IF;

    IF p_building_id IS NOT NULL THEN
        IF NOT (v_is_service OR public.is_building_staff(p_building_id)) THEN
            RAISE EXCEPTION 'Truy cập bị từ chối: Bạn không có quyền xem thống kê SLA của tòa nhà này.'
                USING ERRCODE = '42501';
        END IF;
    ELSIF NOT (
        v_is_service
        OR public.is_super_admin()
        OR EXISTS (SELECT 1 FROM public.get_user_accessible_buildings(v_uid))
    ) THEN
        RAISE EXCEPTION 'Truy cập bị từ chối: Bạn không có quyền xem thống kê SLA sự cố.'
            USING ERRCODE = '42501';
    END IF;

    SELECT
        COUNT(*),
        COUNT(*) FILTER (WHERE ir.sla_status = 'on_time'),
        COUNT(*) FILTER (WHERE ir.sla_status = 'warning'),
        COUNT(*) FILTER (WHERE ir.sla_status = 'breached')
    INTO v_total, v_on_time, v_warning, v_breached
    FROM public.issue_reports ir
    JOIN public.apartments apt ON apt.id = ir.apartment_id
    WHERE (
        (p_building_id IS NOT NULL AND apt.building_id = p_building_id)
        OR (
            p_building_id IS NULL
            AND (
                v_is_service
                OR public.is_super_admin()
                OR apt.building_id IN (SELECT public.get_user_accessible_buildings(v_uid))
            )
        )
    );

    IF v_total > 0 THEN
        v_compliance_rate := ROUND(((v_on_time + v_warning)::NUMERIC / v_total::NUMERIC) * 100.0, 2);
    END IF;

    RETURN jsonb_build_object(
        'total_issues', v_total,
        'on_time_count', v_on_time,
        'warning_count', v_warning,
        'breached_count', v_breached,
        'compliance_rate', v_compliance_rate
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_parking_capacity_stats(
    p_building_id uuid DEFAULT NULL::uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
    v_is_service BOOLEAN := COALESCE(auth.jwt() ->> 'role', '') = 'service_role';
    v_uid UUID := auth.uid();
    v_car_total INT := 0;
    v_car_occupied INT := 0;
    v_car_available INT := 0;
    v_moto_total INT := 0;
    v_moto_occupied INT := 0;
    v_moto_available INT := 0;
    v_visitor_count INT := 0;
BEGIN
    IF NOT v_is_service AND v_uid IS NULL THEN
        RAISE EXCEPTION 'Yêu cầu đăng nhập nhân sự để xem thống kê bãi đỗ xe.' USING ERRCODE = '42501';
    END IF;

    IF p_building_id IS NOT NULL THEN
        IF NOT (v_is_service OR public.is_building_staff(p_building_id)) THEN
            RAISE EXCEPTION 'Truy cập bị từ chối: Bạn không có quyền xem công suất bãi đỗ xe của tòa nhà này.'
                USING ERRCODE = '42501';
        END IF;
    ELSIF NOT (
        v_is_service
        OR public.is_super_admin()
        OR EXISTS (SELECT 1 FROM public.get_user_accessible_buildings(v_uid))
    ) THEN
        RAISE EXCEPTION 'Truy cập bị từ chối: Bạn không có quyền xem thống kê công suất bãi đỗ xe.'
            USING ERRCODE = '42501';
    END IF;

    SELECT
        COUNT(*),
        COUNT(*) FILTER (WHERE status = 'occupied'),
        COUNT(*) FILTER (WHERE status = 'available')
    INTO v_car_total, v_car_occupied, v_car_available
    FROM public.parking_slots
    WHERE slot_type = 'car'
      AND (
          (p_building_id IS NOT NULL AND building_id = p_building_id)
          OR (
              p_building_id IS NULL
              AND (
                  v_is_service
                  OR public.is_super_admin()
                  OR building_id IN (SELECT public.get_user_accessible_buildings(v_uid))
              )
          )
      );

    SELECT
        COUNT(*),
        COUNT(*) FILTER (WHERE status = 'occupied'),
        COUNT(*) FILTER (WHERE status = 'available')
    INTO v_moto_total, v_moto_occupied, v_moto_available
    FROM public.parking_slots
    WHERE slot_type = 'motorcycle'
      AND (
          (p_building_id IS NOT NULL AND building_id = p_building_id)
          OR (
              p_building_id IS NULL
              AND (
                  v_is_service
                  OR public.is_super_admin()
                  OR building_id IN (SELECT public.get_user_accessible_buildings(v_uid))
              )
          )
      );

    SELECT COUNT(*)
    INTO v_visitor_count
    FROM public.visitor_parking_tickets
    WHERE status = 'in_parking'
      AND (
          (p_building_id IS NOT NULL AND building_id = p_building_id)
          OR (
              p_building_id IS NULL
              AND (
                  v_is_service
                  OR public.is_super_admin()
                  OR building_id IN (SELECT public.get_user_accessible_buildings(v_uid))
              )
          )
      );

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
$function$;

CREATE OR REPLACE FUNCTION public.get_upcoming_maintenance_equipments(
    p_days_ahead integer DEFAULT 7
)
RETURNS SETOF public.building_equipments
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
    v_is_service BOOLEAN := COALESCE(auth.jwt() ->> 'role', '') = 'service_role';
    v_uid UUID := auth.uid();
BEGIN
    IF NOT v_is_service AND v_uid IS NULL THEN
        RAISE EXCEPTION 'Yêu cầu đăng nhập nhân sự vận hành.' USING ERRCODE = '42501';
    END IF;

    IF NOT (
        v_is_service
        OR public.is_super_admin()
        OR EXISTS (SELECT 1 FROM public.get_user_accessible_buildings(v_uid))
    ) THEN
        RAISE EXCEPTION 'Truy cập bị từ chối: Chỉ nhân sự tòa nhà mới có quyền xem thiết bị sắp bảo trì.'
            USING ERRCODE = '42501';
    END IF;

    RETURN QUERY
    SELECT be.*
    FROM public.building_equipments be
    WHERE be.next_maintenance_date IS NOT NULL
      AND be.next_maintenance_date <= (now() + (COALESCE(p_days_ahead, 7) || ' days')::interval)
      AND be.status != 'inactive'
      AND (
          v_is_service
          OR public.is_super_admin()
          OR public.is_building_staff(be.building_id)
      )
    ORDER BY be.next_maintenance_date ASC;
END;
$function$;

-- -----------------------------------------------------------------------------
-- 1C. Khóa Storage RLS đa tòa nhà trên storage.objects
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Management toàn quyền storage" ON storage.objects;

DROP POLICY IF EXISTS "vehicle_docs_insert_scoped" ON storage.objects;
CREATE POLICY "vehicle_docs_insert_scoped"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
    (bucket_id = 'vehicle-docs'::text)
    AND (
        (owner = auth.uid())
        OR public.is_super_admin()
        OR (
            ((storage.foldername(name))[1] ~ '^[0-9a-fA-F-]{36}$'::text)
            AND public.can_access_apartment(((storage.foldername(name))[1])::uuid)
        )
    )
);

DROP POLICY IF EXISTS "handover_docs_delete_scoped" ON storage.objects;
CREATE POLICY "handover_docs_delete_scoped"
ON storage.objects
FOR DELETE
TO authenticated
USING (
    (bucket_id = 'handover-docs'::text)
    AND (
        (owner = auth.uid())
        OR public.is_super_admin()
        OR EXISTS (
            SELECT 1
            FROM public.apartment_handovers h
            WHERE (
                h.staff_signature_url = objects.name
                OR h.resident_signature_url = objects.name
                OR objects.name LIKE ('photos/' || h.id::text || '/%')
                OR objects.name LIKE ('signatures/' || h.id::text || '_%')
            )
              AND public.is_building_staff(
                  h.building_id,
                  ARRAY['admin', 'management', 'manager', 'owner']
              )
        )
    )
);

DROP POLICY IF EXISTS "issue_images_staff_scoped" ON storage.objects;
CREATE POLICY "issue_images_staff_scoped"
ON storage.objects
FOR ALL
TO authenticated
USING (
    (bucket_id = 'issue-images'::text)
    AND (
        public.is_super_admin()
        OR EXISTS (
            SELECT 1
            FROM public.issue_reports ir
            JOIN public.apartments a ON a.id = ir.apartment_id
            WHERE ir.id::text = (storage.foldername(objects.name))[1]
              AND public.is_building_staff(
                  a.building_id,
                  ARRAY['admin', 'management', 'manager', 'owner', 'technician', 'staff']
              )
        )
    )
)
WITH CHECK (
    (bucket_id = 'issue-images'::text)
    AND (
        public.is_super_admin()
        OR (storage.foldername(name))[1] = auth.uid()::text
        OR EXISTS (
            SELECT 1
            FROM public.issue_reports ir
            JOIN public.apartments a ON a.id = ir.apartment_id
            WHERE ir.id::text = (storage.foldername(objects.name))[1]
              AND public.is_building_staff(
                  a.building_id,
                  ARRAY['admin', 'management', 'manager', 'owner', 'technician', 'staff']
              )
        )
    )
);

DROP POLICY IF EXISTS "meter_readings_staff_scoped" ON storage.objects;
CREATE POLICY "meter_readings_staff_scoped"
ON storage.objects
FOR ALL
TO authenticated
USING (
    (bucket_id = 'meter-readings'::text)
    AND (
        (owner = auth.uid())
        OR public.is_super_admin()
        OR (
            ((storage.foldername(name))[1] ~ '^[0-9a-fA-F-]{36}$'::text)
            AND public.can_access_apartment(((storage.foldername(name))[1])::uuid)
        )
    )
)
WITH CHECK (
    (bucket_id = 'meter-readings'::text)
    AND (
        (owner = auth.uid())
        OR public.is_super_admin()
        OR (
            ((storage.foldername(name))[1] ~ '^[0-9a-fA-F-]{36}$'::text)
            AND public.can_access_apartment(((storage.foldername(name))[1])::uuid)
        )
    )
);

COMMIT;
