-- ==============================================================================
-- Migration: 20261125010000_fix_p0_functional_rpc_rls_and_schema_sync.sql
-- Mô tả:
--   1. Đồng bộ idempotent các cột schema giữa baseline và CSDL Production (phục vụ triển khai khách hàng B2B mới)
--   2. Khắc phục lỗi 428C9 (INSERT trực tiếp vào cột GENERATED ALWAYS invoice_items.subtotal)
--      trên create_invoice_with_items, update_invoice_with_items, generate_valid_bulk_invoices, approve_meter_reading
--   3. Khắc phục lỗi PGRST203 (trùng lặp hàm overload) trên submit_poll_vote, get_financial_aging_report,
--      record_manual_amenity_payment
--   4. Bổ sung RPC send_invoice_dunning_notifications cho Trạm Kế Toán & cập nhật RLS notifications
--   5. Cập nhật RLS handover_items cho phép Kỹ thuật viên (technician) và nhân viên tòa nhà lưu biên bản kiểm kê
-- ==============================================================================

-- ==============================================================================
-- PHẦN 1: ĐỒNG BỘ SCHEMA IDEMPOTENT CHO TRIỂN KHAI MỚI (MULTI-TENANT B2B ONBOARDING)
-- ==============================================================================

ALTER TYPE public.amenity_booking_status ADD VALUE IF NOT EXISTS 'checked_in';
ALTER TYPE public.amenity_booking_status ADD VALUE IF NOT EXISTS 'no_show';

ALTER TABLE public.apartments
    ADD COLUMN IF NOT EXISTS building_code VARCHAR(20),
    ADD COLUMN IF NOT EXISTS floor_number INT,
    ADD COLUMN IF NOT EXISTS electric_reading NUMERIC(10,2) DEFAULT 0.0,
    ADD COLUMN IF NOT EXISTS water_reading NUMERIC(10,2) DEFAULT 0.0;

ALTER TABLE public.building_amenities
    ADD COLUMN IF NOT EXISTS open_hours VARCHAR(50) DEFAULT '06:00 - 22:00',
    ADD COLUMN IF NOT EXISTS display_order INT DEFAULT 0,
    ADD COLUMN IF NOT EXISTS requires_deposit BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS max_advance_days INT NOT NULL DEFAULT 14,
    ADD COLUMN IF NOT EXISTS max_slots_per_week INT NOT NULL DEFAULT 5,
    ADD COLUMN IF NOT EXISTS rules_and_regulations TEXT;

ALTER TABLE public.building_rules
    ADD COLUMN IF NOT EXISTS display_order INT DEFAULT 0;

ALTER TABLE public.emergency_contacts
    ADD COLUMN IF NOT EXISTS contact_type VARCHAR(50) DEFAULT 'security';

ALTER TABLE public.announcements
    ADD COLUMN IF NOT EXISTS target_apartment VARCHAR(50);

ALTER TABLE public.issue_images
    ADD COLUMN IF NOT EXISTS image_role VARCHAR(30) NOT NULL DEFAULT 'report';

ALTER TABLE public.issue_ratings
    ADD COLUMN IF NOT EXISTS reporter_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    ADD COLUMN IF NOT EXISTS speed_rating INT DEFAULT 5,
    ADD COLUMN IF NOT EXISTS attitude_rating INT DEFAULT 5,
    ADD COLUMN IF NOT EXISTS quality_rating INT DEFAULT 5;

ALTER TABLE public.meter_reading_submissions
    ADD COLUMN IF NOT EXISTS reviewed_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS reject_reason TEXT;

ALTER TABLE public.amenity_bookings
    ADD COLUMN IF NOT EXISTS checked_in_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS checked_in_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS deposit_notes TEXT,
    ADD COLUMN IF NOT EXISTS qr_ticket_token UUID DEFAULT gen_random_uuid(),
    ADD COLUMN IF NOT EXISTS inspected_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS inspected_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS inspection_result TEXT,
    ADD COLUMN IF NOT EXISTS forfeited_amount NUMERIC(12,2),
    ADD COLUMN IF NOT EXISTS refund_amount NUMERIC(12,2),
    ADD COLUMN IF NOT EXISTS inspection_notes TEXT,
    ADD COLUMN IF NOT EXISTS inspection_image_urls JSONB DEFAULT '[]'::jsonb;

-- ==============================================================================
-- PHẦN 2: SỬA LỖI 428C9 GENERATED COLUMN TRÊN INVOICE_ITEMS & APPROVE_METER_READING
-- ==============================================================================

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

    INSERT INTO public.invoices (apartment_id, period, due_date, total_amount, status)
    VALUES (p_apartment_id, p_period, p_due_date, 0, 'unpaid'::public.invoice_status)
    RETURNING id INTO v_invoice_id;

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

            -- Không truyền cột subtotal vì là GENERATED ALWAYS AS (unit_price * quantity) STORED
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

    UPDATE public.invoices
    SET total_amount = v_total_amount, updated_at = now()
    WHERE id = v_invoice_id;

    RETURN v_invoice_id;
END;
$$;

REVOKE ALL ON FUNCTION public.create_invoice_with_items(UUID, VARCHAR, DATE, JSONB) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_invoice_with_items(UUID, VARCHAR, DATE, JSONB) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.update_invoice_with_items(
    p_invoice_id UUID,
    p_period VARCHAR,
    p_due_date DATE,
    p_items JSONB,
    p_apartment_id UUID DEFAULT NULL,
    p_status VARCHAR DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_inv RECORD;
    v_building_id UUID;
    v_item JSONB;
    v_unit_price NUMERIC(15,2);
    v_quantity NUMERIC(12,2);
    v_subtotal NUMERIC(15,2);
    v_total_amount NUMERIC(15,2) := 0;
BEGIN
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
        COALESCE(auth.jwt() ->> 'role', '') = 'service_role'
        OR public.is_building_staff(v_building_id, ARRAY['admin', 'management', 'manager', 'owner', 'accountant'])
    ) THEN
        RAISE EXCEPTION 'Truy cập bị từ chối: Chỉ Ban Quản Lý hoặc Kế toán tòa nhà mới có quyền cập nhật hóa đơn.'
            USING ERRCODE = '42501';
    END IF;

    DELETE FROM public.invoice_items WHERE invoice_id = p_invoice_id;

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

            INSERT INTO public.invoice_items (
                invoice_id, fee_type, unit_price, quantity
            ) VALUES (
                p_invoice_id,
                v_item->>'fee_type',
                v_unit_price,
                v_quantity
            );
        END LOOP;
    END IF;

    UPDATE public.invoices
    SET period = p_period,
        due_date = p_due_date,
        apartment_id = COALESCE(p_apartment_id, apartment_id),
        total_amount = v_total_amount,
        status = CASE
            WHEN p_status IS NOT NULL THEN p_status::public.invoice_status
            ELSE status
        END,
        updated_at = NOW()
    WHERE id = p_invoice_id;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Cập nhật hóa đơn và các hạng mục chi phí thành công',
        'invoice_id', p_invoice_id,
        'total_amount', v_total_amount
    );
END;
$$;

REVOKE ALL ON FUNCTION public.update_invoice_with_items(UUID, VARCHAR, DATE, JSONB, UUID, VARCHAR) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.update_invoice_with_items(UUID, VARCHAR, DATE, JSONB, UUID, VARCHAR) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.generate_valid_bulk_invoices(
  p_period text,
  p_due_date timestamptz,
  p_target_apartment_ids uuid[] DEFAULT NULL,
  p_mgmt_rate numeric DEFAULT 10000,
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
  v_user RECORD;
BEGIN
  IF NOT public.is_staff_or_management() THEN
    RAISE EXCEPTION 'Chỉ Ban Quản Lý mới có quyền phát hành hóa đơn hàng loạt' USING ERRCODE = '42501';
  END IF;

  FOR v_apt IN
    SELECT id, code, area, building_id
    FROM public.apartments
    WHERE is_empty = false
      AND building_id IN (SELECT public.get_user_accessible_buildings(auth.uid()))
      AND (p_target_apartment_ids IS NULL OR id = ANY(p_target_apartment_ids))
    ORDER BY code ASC
  LOOP
    IF NOT public.is_building_staff(v_apt.building_id, ARRAY['admin', 'management', 'manager', 'owner', 'accountant']) THEN
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

    INSERT INTO public.invoices (
      apartment_id, period, due_date, total_amount, status, created_at, updated_at
    ) VALUES (
      v_apt.id, p_period, p_due_date::date, v_apt_total, 'unpaid'::public.invoice_status, now(), now()
    )
    ON CONFLICT (apartment_id, period) DO NOTHING
    RETURNING id INTO v_invoice_id;

    IF v_invoice_id IS NOT NULL THEN
      INSERT INTO public.invoice_items (invoice_id, fee_type, unit_price, quantity)
      VALUES
        (v_invoice_id, 'Phí quản lý vận hành', p_mgmt_rate, COALESCE(v_apt.area, 70)),
        (v_invoice_id, 'Tiền điện sinh hoạt', p_electric_rate, v_elec_consumed),
        (v_invoice_id, 'Tiền nước sinh hoạt', p_water_rate, v_water_consumed);

      IF v_parking_fee > 0 THEN
        INSERT INTO public.invoice_items (invoice_id, fee_type, unit_price, quantity)
        VALUES (v_invoice_id, 'Phí gửi xe phương tiện', v_parking_fee, 1);
      END IF;

      v_invoices_created := v_invoices_created + 1;
      v_total_amount := v_total_amount + v_apt_total;

      FOR v_user IN
        SELECT user_id FROM public.residents_apartments WHERE apartment_id = v_apt.id AND COALESCE(status, 'active') = 'active'
      LOOP
        INSERT INTO public.notifications (building_id, apartment_id, user_id, title, body, type, created_at)
        VALUES (
          v_apt.building_id,
          v_apt.id,
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
    'skipped_count', v_skipped_count,
    'total_amount', v_total_amount,
    'message', 'Đã phát hành ' || v_invoices_created || ' hóa đơn thành công'
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.approve_meter_reading(
    p_submission_id UUID,
    p_generate_invoice BOOLEAN DEFAULT true,
    p_due_date DATE DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
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
    IF v_user_id IS NULL OR NOT public.is_staff_or_management() THEN
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
    IF v_building_id IS NOT NULL AND NOT public.is_building_staff(v_building_id, ARRAY['admin', 'management', 'manager', 'owner', 'accountant', 'technician', 'staff']) THEN
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
$$;

-- ==============================================================================
-- PHẦN 3: XÓA BỎ CÁC HÀM OVERLOAD GÂY XUNG ĐỘT PGRST203 & CHUẨN HÓA HỢP ĐỒNG JSON
-- ==============================================================================

-- 3.1 Xóa bản overload cũ của submit_poll_vote (đảo vị trí p_voter_user_id và p_option_ids)
DROP FUNCTION IF EXISTS public.submit_poll_vote(UUID, UUID, UUID, UUID[]);

-- 3.2 Xóa bản overload đảo tham số của get_financial_aging_report và chuẩn hóa JSON trả về
DROP FUNCTION IF EXISTS public.get_financial_aging_report(TEXT, UUID);

CREATE OR REPLACE FUNCTION public.get_financial_aging_report(
    p_building_id UUID DEFAULT NULL,
    p_period TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_calling_user_id UUID := auth.uid();
    v_is_service BOOLEAN := (COALESCE(auth.jwt() ->> 'role', '') = 'service_role');
    v_is_authorized BOOLEAN := FALSE;
    v_result JSONB;
BEGIN
    IF NOT v_is_service THEN
        IF p_building_id IS NOT NULL THEN
            v_is_authorized := public.is_building_staff(p_building_id, ARRAY['admin', 'management', 'manager', 'owner', 'accountant']);
        ELSE
            v_is_authorized := public.is_super_admin() OR EXISTS (
                SELECT 1 FROM public.users
                WHERE id = v_calling_user_id AND role IN ('admin', 'management', 'accountant')
                  AND is_active = true AND is_locked = false
            ) OR EXISTS (
                SELECT 1 FROM public.role_delegations
                WHERE delegate_id = v_calling_user_id
                  AND is_revoked = FALSE
                  AND starts_at <= CURRENT_TIMESTAMP
                  AND ends_at >= CURRENT_TIMESTAMP
                  AND delegated_role IN ('admin', 'management', 'accountant')
            );
        END IF;

        IF NOT v_is_authorized THEN
            RAISE EXCEPTION 'Truy cập bị từ chối: Chỉ Ban Quản Lý hoặc Kế toán mới có quyền xem báo cáo tài chính.'
                USING ERRCODE = '42501';
        END IF;
    END IF;

    WITH filtered_invoices AS (
        SELECT
            i.id,
            i.apartment_id,
            i.period,
            i.total_amount,
            i.due_date,
            i.status,
            a.code AS apt_code,
            a.building_id,
            GREATEST(0, (CURRENT_DATE - i.due_date::date)) AS days_overdue
        FROM public.invoices i
        JOIN public.apartments a ON a.id = i.apartment_id
        WHERE i.status != 'cancelled'
          AND (p_period IS NULL OR i.period = p_period)
          AND (p_building_id IS NULL OR a.building_id = p_building_id)
          AND (v_is_service OR a.building_id IN (SELECT public.get_user_accessible_buildings(v_calling_user_id)))
    ),
    summary AS (
        SELECT
            COALESCE(SUM(total_amount), 0) AS total_billed,
            COALESCE(SUM(CASE WHEN status = 'paid' THEN total_amount ELSE 0 END), 0) AS actual_collected,
            COALESCE(SUM(CASE WHEN status != 'paid' THEN total_amount ELSE 0 END), 0) AS total_outstanding,
            COUNT(*) AS total_invoice_count,
            COUNT(CASE WHEN status = 'paid' THEN 1 END) AS paid_invoice_count,
            COUNT(CASE WHEN status != 'paid' THEN 1 END) AS unpaid_invoice_count,
            ROUND(COALESCE(SUM(CASE WHEN status = 'paid' THEN total_amount ELSE 0 END) * 100.0 / NULLIF(SUM(total_amount), 0), 0), 1) AS collection_rate
        FROM filtered_invoices
    ),
    buckets AS (
        SELECT
            COALESCE(SUM(CASE WHEN status != 'paid' AND days_overdue BETWEEN 0 AND 30 THEN total_amount ELSE 0 END), 0) AS amount_0_to_30,
            COUNT(CASE WHEN status != 'paid' AND days_overdue BETWEEN 0 AND 30 THEN 1 END) AS count_0_to_30,
            COALESCE(SUM(CASE WHEN status != 'paid' AND days_overdue BETWEEN 31 AND 60 THEN total_amount ELSE 0 END), 0) AS amount_31_to_60,
            COUNT(CASE WHEN status != 'paid' AND days_overdue BETWEEN 31 AND 60 THEN 1 END) AS count_31_to_60,
            COALESCE(SUM(CASE WHEN status != 'paid' AND days_overdue BETWEEN 61 AND 90 THEN total_amount ELSE 0 END), 0) AS amount_61_to_90,
            COUNT(CASE WHEN status != 'paid' AND days_overdue BETWEEN 61 AND 90 THEN 1 END) AS count_61_to_90,
            COALESCE(SUM(CASE WHEN status != 'paid' AND days_overdue > 90 THEN total_amount ELSE 0 END), 0) AS amount_over_90,
            COUNT(CASE WHEN status != 'paid' AND days_overdue > 90 THEN 1 END) AS count_over_90
        FROM filtered_invoices
    ),
    block_rates AS (
        SELECT
            COALESCE(SUBSTRING(apt_code FROM '^[A-Za-z]+'), 'Chung') AS block_name,
            COALESCE(SUBSTRING(apt_code FROM '^[A-Za-z]+'), 'Chung') AS block,
            COALESCE(SUM(total_amount), 0) AS block_billed,
            COALESCE(SUM(total_amount), 0) AS billed,
            COALESCE(SUM(CASE WHEN status = 'paid' THEN total_amount ELSE 0 END), 0) AS block_collected,
            COALESCE(SUM(CASE WHEN status = 'paid' THEN total_amount ELSE 0 END), 0) AS collected,
            COALESCE(SUM(CASE WHEN status != 'paid' THEN total_amount ELSE 0 END), 0) AS block_outstanding,
            ROUND(COALESCE(SUM(CASE WHEN status = 'paid' THEN total_amount ELSE 0 END) * 100.0 / NULLIF(SUM(total_amount), 0), 0), 1) AS collection_rate,
            ROUND(COALESCE(SUM(CASE WHEN status = 'paid' THEN total_amount ELSE 0 END) * 100.0 / NULLIF(SUM(total_amount), 0), 0), 1) AS rate
        FROM filtered_invoices
        GROUP BY 1
        ORDER BY 1
    ),
    debtors AS (
        SELECT
            fi.apartment_id,
            fi.apt_code AS apartment_code,
            COALESCE(u.full_name, 'Chưa đăng ký') AS owner_name,
            COALESCE(u.phone, '') AS owner_phone,
            COALESCE(SUM(fi.total_amount), 0) AS total_debt,
            COALESCE(SUM(fi.total_amount), 0) AS outstanding_amount,
            MAX(fi.days_overdue) AS max_days_overdue,
            COUNT(*) AS unpaid_invoices_count,
            COUNT(*) AS unpaid_invoice_count,
            MIN(fi.due_date) AS oldest_due_date,
            CASE
                WHEN MAX(fi.days_overdue) > 90 THEN 'over_90'
                WHEN MAX(fi.days_overdue) > 60 THEN '61_to_90'
                WHEN MAX(fi.days_overdue) > 30 THEN '31_to_60'
                ELSE '0_to_30'
            END AS risk_level
        FROM filtered_invoices fi
        LEFT JOIN public.residents_apartments ra ON ra.apartment_id = fi.apartment_id AND ra.relation_role = 'owner'
        LEFT JOIN public.users u ON u.id = ra.user_id
        WHERE fi.status != 'paid'
        GROUP BY fi.apartment_id, fi.apt_code, u.full_name, u.phone
        ORDER BY total_debt DESC
        LIMIT 50
    )
    SELECT jsonb_build_object(
        'generated_at', CURRENT_TIMESTAMP,
        'filter_period', p_period,
        'filter_building_id', p_building_id,
        'summary', (SELECT to_jsonb(s) FROM summary s),
        'aging_buckets', (
            SELECT jsonb_build_object(
                'amount_0_to_30', b.amount_0_to_30,
                'count_0_to_30', b.count_0_to_30,
                'amount_31_to_60', b.amount_31_to_60,
                'count_31_to_60', b.count_31_to_60,
                'amount_61_to_90', b.amount_61_to_90,
                'count_61_to_90', b.count_61_to_90,
                'amount_over_90', b.amount_over_90,
                'count_over_90', b.count_over_90,
                'bucket_0_30', jsonb_build_object('amount', b.amount_0_to_30, 'count', b.count_0_to_30),
                'bucket_31_60', jsonb_build_object('amount', b.amount_31_to_60, 'count', b.count_31_to_60),
                'bucket_61_90', jsonb_build_object('amount', b.amount_61_to_90, 'count', b.count_61_to_90),
                'bucket_over_90', jsonb_build_object('amount', b.amount_over_90, 'count', b.count_over_90)
            )
            FROM buckets b
        ),
        'collection_by_block', COALESCE((SELECT jsonb_agg(to_jsonb(br)) FROM block_rates br), '[]'::jsonb),
        'block_collection_rates', COALESCE((SELECT jsonb_agg(to_jsonb(br)) FROM block_rates br), '[]'::jsonb),
        'debtors', COALESCE((SELECT jsonb_agg(to_jsonb(d)) FROM debtors d), '[]'::jsonb),
        'top_debtors', COALESCE((SELECT jsonb_agg(to_jsonb(d)) FROM debtors d), '[]'::jsonb)
    ) INTO v_result;

    RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.get_financial_aging_report(UUID, TEXT) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_financial_aging_report(UUID, TEXT) TO authenticated, service_role;

-- 3.3 Gộp duy nhất chữ ký record_manual_amenity_payment (tương thích cả có hoặc không truyền p_amount)
DROP FUNCTION IF EXISTS public.record_manual_amenity_payment(UUID, NUMERIC, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.record_manual_amenity_payment(UUID, VARCHAR, TEXT);

CREATE OR REPLACE FUNCTION public.record_manual_amenity_payment(
    p_booking_id UUID,
    p_payment_method TEXT DEFAULT 'CASH',
    p_notes TEXT DEFAULT NULL,
    p_amount NUMERIC DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_booking RECORD;
    v_txn_id UUID;
    v_txn_code VARCHAR(100);
    v_existing_success_txn RECORD;
    v_pending_txn RECORD;
    v_staff_id UUID := auth.uid();
    v_total_fee NUMERIC(12,2) := 0;
BEGIN
    IF v_staff_id IS NULL OR NOT public.is_staff_or_management() THEN
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

    IF v_booking.a_building_id IS NOT NULL AND NOT public.is_building_staff(v_booking.a_building_id, ARRAY['admin', 'management', 'manager', 'owner', 'accountant', 'staff']) THEN
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
$$;

REVOKE ALL ON FUNCTION public.record_manual_amenity_payment(UUID, TEXT, TEXT, NUMERIC) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.record_manual_amenity_payment(UUID, TEXT, TEXT, NUMERIC) TO authenticated, service_role;

-- ==============================================================================
-- PHẦN 4: SỬA RLS NOTIFICATIONS, HANDOVER_ITEMS & THÊM RPC NHẮC NỢ TRẠM KẾ TOÁN
-- ==============================================================================

DROP POLICY IF EXISTS "notifications_manager_all" ON public.notifications;
CREATE POLICY "notifications_manager_all" ON public.notifications
    FOR ALL TO authenticated
    USING (
        public.is_super_admin()
        OR (
            building_id IS NOT NULL
            AND public.is_building_staff(building_id, ARRAY['admin', 'management', 'manager', 'owner', 'bql', 'accountant'])
        )
    )
    WITH CHECK (
        public.is_super_admin()
        OR (
            building_id IS NOT NULL
            AND public.is_building_staff(building_id, ARRAY['admin', 'management', 'manager', 'owner', 'bql', 'accountant'])
        )
    );

CREATE OR REPLACE FUNCTION public.send_invoice_dunning_notifications(
    p_invoice_ids UUID[]
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_inv RECORD;
    v_res RECORD;
    v_sent_count INT := 0;
    v_apt_count INT := 0;
    v_has_resident BOOLEAN;
BEGIN
    IF p_invoice_ids IS NULL OR array_length(p_invoice_ids, 1) IS NULL THEN
        RETURN jsonb_build_object('success', true, 'notifications_sent', 0, 'apartments_notified', 0);
    END IF;

    IF NOT public.is_staff_or_management() THEN
        RAISE EXCEPTION 'Chỉ Ban Quản Lý hoặc Kế toán mới có quyền gửi thông báo nhắc nợ.' USING ERRCODE = '42501';
    END IF;

    FOR v_inv IN
        SELECT i.id, i.apartment_id, i.period, i.total_amount, a.code AS apt_code, a.building_id
        FROM public.invoices i
        JOIN public.apartments a ON a.id = i.apartment_id
        WHERE i.id = ANY(p_invoice_ids)
          AND i.status NOT IN ('paid', 'cancelled')
    LOOP
        IF v_inv.building_id IS NOT NULL AND NOT public.is_building_staff(v_inv.building_id, ARRAY['admin', 'management', 'manager', 'owner', 'bql', 'accountant']) THEN
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
$$;

REVOKE ALL ON FUNCTION public.send_invoice_dunning_notifications(UUID[]) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.send_invoice_dunning_notifications(UUID[]) TO authenticated, service_role;

-- Cập nhật RLS handover_items cho phép Kỹ thuật viên (technician) và nhân viên tòa nhà kiểm kê tài sản
DROP POLICY IF EXISTS "handover_items_select_policy" ON public.handover_items;
CREATE POLICY "handover_items_select_policy" ON public.handover_items
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.apartment_handovers h
            WHERE h.id = handover_items.handover_id
              AND (
                  h.conducted_by = auth.uid()
                  OR h.resident_id = auth.uid()
                  OR public.is_super_admin()
                  OR (h.building_id IS NOT NULL AND public.is_building_staff(h.building_id, ARRAY['admin', 'management', 'manager', 'owner', 'bql', 'staff', 'technician']))
              )
        )
    );

DROP POLICY IF EXISTS "handover_items_modify_policy" ON public.handover_items;
CREATE POLICY "handover_items_modify_policy" ON public.handover_items
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.apartment_handovers h
            WHERE h.id = handover_items.handover_id
              AND (
                  h.conducted_by = auth.uid()
                  OR public.is_super_admin()
                  OR (h.building_id IS NOT NULL AND public.is_building_staff(h.building_id, ARRAY['admin', 'management', 'manager', 'owner', 'bql', 'staff', 'technician']))
              )
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.apartment_handovers h
            WHERE h.id = handover_items.handover_id
              AND (
                  h.conducted_by = auth.uid()
                  OR public.is_super_admin()
                  OR (h.building_id IS NOT NULL AND public.is_building_staff(h.building_id, ARRAY['admin', 'management', 'manager', 'owner', 'bql', 'staff', 'technician']))
              )
        )
    );
