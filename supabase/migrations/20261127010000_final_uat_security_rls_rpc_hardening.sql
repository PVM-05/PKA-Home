-- ============================================================================
-- MIGRATION: 20261127010000_final_uat_security_rls_rpc_hardening.sql
-- Mục đích: Khắc phục triệt để các lỗi P0 phát hiện trong UAT & Cross-Review
-- trước khi phát hành thương mại B2B SaaS:
--   1. Gỡ bỏ 9 legacy permissive RLS policies USING(true)/WITH CHECK(true)
--      còn tồn tại trên Production (apartments, meter_reading_submissions,
--      building_equipments, equipment_maintenance_tasks, issue_ratings) và bổ
--      sung tenant-scoped policies đầy đủ cho equipment_maintenance_tasks &
--      issue_ratings (hỗ trợ cả reporter_id lẫn user_id).
--   2. Loại bỏ toàn bộ RPC overload trùng lặp (PGRST203) và các overload
--      không kiểm tra quyền: record_maintenance_fund_transaction,
--      check_in_visitor_pass, calculate_utility_charge,
--      check_and_generate_invoice_due_reminders, simulate_unified_payment,
--      submit_apartment_link_request.
--   3. Hợp nhất record_maintenance_fund_transaction với kiểm tra thẩm quyền
--      đa tòa nhà (is_building_staff) + hỗ trợ đầy đủ cột fund_id,
--      recipient_or_payer, reference_type, receipt_url.
--   4. Gia cố update_invoice_with_items: chặn sửa hóa đơn đã thanh toán/chờ
--      xác nhận trước khi xóa items và chặn di chuyển hóa đơn trái phép sang
--      tòa nhà ngoài thẩm quyền.
--   5. Thu hồi quyền EXECUTE của anon/PUBLIC trên toàn bộ hàm nghiệp vụ nội bộ
--      (chỉ giữ anon trên 4 RPC công khai trước đăng nhập).
-- ============================================================================

-- ============================================================================
-- 1. GỠ BỎ 9 LEGACY PERMISSIVE POLICIES & BỔ SUNG TENANT-SCOPED POLICIES
-- ============================================================================

-- 1.1. public.apartments: Chặn anon đọc toàn bộ danh sách căn hộ
DROP POLICY IF EXISTS "Allow anon and authenticated to view apartments" ON public.apartments;

-- 1.2. public.meter_reading_submissions: Gỡ 3 policy public=true để kích hoạt
-- bộ policy meter_submissions_read / insert / update_admin đã chuẩn hóa
DROP POLICY IF EXISTS "Users can view meter submissions" ON public.meter_reading_submissions;
DROP POLICY IF EXISTS "Users can insert meter submissions" ON public.meter_reading_submissions;
DROP POLICY IF EXISTS "Staff can update meter submissions" ON public.meter_reading_submissions;

-- 1.3. public.building_equipments: Gỡ 2 policy true để kích hoạt
-- building_equipments_read / building_equipments_manage
DROP POLICY IF EXISTS "building_equipments_select_policy" ON public.building_equipments;
DROP POLICY IF EXISTS "building_equipments_modify_policy" ON public.building_equipments;

-- 1.4. public.equipment_maintenance_tasks: Gỡ 2 policy true & tạo policy theo building_id
DROP POLICY IF EXISTS "equipment_tasks_select_policy" ON public.equipment_maintenance_tasks;
DROP POLICY IF EXISTS "equipment_tasks_modify_policy" ON public.equipment_maintenance_tasks;
DROP POLICY IF EXISTS "equipment_tasks_read" ON public.equipment_maintenance_tasks;
DROP POLICY IF EXISTS "equipment_tasks_manage" ON public.equipment_maintenance_tasks;

CREATE POLICY "equipment_tasks_read"
ON public.equipment_maintenance_tasks
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.building_equipments be
        WHERE be.id = equipment_maintenance_tasks.equipment_id
          AND (be.building_id IS NULL OR public.can_access_building(be.building_id))
    )
);

CREATE POLICY "equipment_tasks_manage"
ON public.equipment_maintenance_tasks
FOR ALL
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.building_equipments be
        WHERE be.id = equipment_maintenance_tasks.equipment_id
          AND (
              public.is_super_admin()
              OR (
                  be.building_id IS NOT NULL
                  AND public.is_building_staff(
                      be.building_id,
                      ARRAY['admin', 'management', 'manager', 'owner', 'technician']
                  )
              )
          )
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1
        FROM public.building_equipments be
        WHERE be.id = equipment_maintenance_tasks.equipment_id
          AND (
              public.is_super_admin()
              OR (
                  be.building_id IS NOT NULL
                  AND public.is_building_staff(
                      be.building_id,
                      ARRAY['admin', 'management', 'manager', 'owner', 'technician']
                  )
              )
          )
    )
);

-- 1.5. public.issue_ratings: Gỡ 2 policy public=true & đồng bộ kiểm tra cả reporter_id và user_id
DROP POLICY IF EXISTS "issue_ratings_select_policy" ON public.issue_ratings;
DROP POLICY IF EXISTS "issue_ratings_insert_policy" ON public.issue_ratings;
DROP POLICY IF EXISTS "issue_ratings_read" ON public.issue_ratings;
DROP POLICY IF EXISTS "issue_ratings_insert" ON public.issue_ratings;
DROP POLICY IF EXISTS "issue_ratings_update" ON public.issue_ratings;

CREATE POLICY "issue_ratings_read"
ON public.issue_ratings
FOR SELECT
TO authenticated
USING (
    reporter_id = auth.uid()
    OR user_id = auth.uid()
    OR EXISTS (
        SELECT 1
        FROM public.issue_reports ir
        WHERE ir.id = issue_ratings.issue_report_id
          AND public.can_access_apartment(ir.apartment_id)
    )
);

CREATE POLICY "issue_ratings_insert"
ON public.issue_ratings
FOR INSERT
TO authenticated
WITH CHECK (
    (reporter_id = auth.uid() OR user_id = auth.uid())
    AND EXISTS (
        SELECT 1
        FROM public.issue_reports ir
        WHERE ir.id = issue_ratings.issue_report_id
          AND (
              ir.reporter_id = auth.uid()
              OR public.can_access_apartment(ir.apartment_id)
          )
    )
);

CREATE POLICY "issue_ratings_update"
ON public.issue_ratings
FOR UPDATE
TO authenticated
USING (reporter_id = auth.uid() OR user_id = auth.uid())
WITH CHECK (reporter_id = auth.uid() OR user_id = auth.uid());

-- ============================================================================
-- 2. HỢP NHẤT & BẢO MẬT QUỸ BẢO TRÌ (record_maintenance_fund_transaction)
-- ============================================================================

ALTER TABLE public.maintenance_fund_transactions
    ADD COLUMN IF NOT EXISTS receipt_url TEXT;

CREATE SEQUENCE IF NOT EXISTS public.maintenance_fund_pt_seq START 1;
CREATE SEQUENCE IF NOT EXISTS public.maintenance_fund_pc_seq START 1;

-- Gỡ bỏ cả 2 overload cũ (overload 9 tham số không auth & overload 8 tham số thiếu cột)
DROP FUNCTION IF EXISTS public.record_maintenance_fund_transaction(
    UUID, VARCHAR, VARCHAR, NUMERIC, TEXT, TEXT, VARCHAR, UUID, UUID
);
DROP FUNCTION IF EXISTS public.record_maintenance_fund_transaction(
    UUID, TEXT, NUMERIC, TEXT, TEXT, TEXT, UUID, UUID
);

CREATE OR REPLACE FUNCTION public.record_maintenance_fund_transaction(
    p_building_id UUID,
    p_transaction_type TEXT,
    p_amount NUMERIC,
    p_category TEXT,
    p_description TEXT,
    p_receipt_url TEXT DEFAULT NULL,
    p_reference_id UUID DEFAULT NULL,
    p_created_by UUID DEFAULT NULL,
    p_recipient_or_payer TEXT DEFAULT 'Ban Quản Lý',
    p_reference_type VARCHAR DEFAULT 'MANUAL'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_is_service BOOLEAN := COALESCE(auth.jwt() ->> 'role', '') = 'service_role';
    v_user_id UUID;
    v_tx_type TEXT;
    v_fund_id UUID;
    v_current_balance NUMERIC(15,2);
    v_new_balance NUMERIC(15,2);
    v_period TEXT;
    v_prefix TEXT;
    v_seq BIGINT;
    v_voucher_number TEXT;
    v_tx_id UUID;
    v_recipient TEXT;
BEGIN
    v_user_id := CASE WHEN v_is_service THEN COALESCE(p_created_by, auth.uid()) ELSE auth.uid() END;
    IF NOT v_is_service THEN
        IF v_user_id IS NULL THEN
            RAISE EXCEPTION 'Yêu cầu đăng nhập để thực hiện ghi sổ quỹ bảo trì.'
                USING ERRCODE = '42501';
        END IF;

        IF NOT public.is_building_staff(
            p_building_id,
            ARRAY['admin', 'management', 'manager', 'owner', 'accountant', 'head_of_management']
        ) THEN
            RAISE EXCEPTION 'Bạn không có quyền kế toán hoặc quản trị để ghi sổ quỹ bảo trì tại tòa nhà này.'
                USING ERRCODE = '42501';
        END IF;
    END IF;

    IF p_amount IS NULL OR p_amount <= 0 THEN
        RAISE EXCEPTION 'Số tiền giao dịch phải lớn hơn 0.'
            USING ERRCODE = '22023';
    END IF;

    v_tx_type := UPPER(TRIM(COALESCE(p_transaction_type, '')));
    IF v_tx_type = 'THU' THEN
        v_tx_type := 'INCOME';
    ELSIF v_tx_type = 'CHI' THEN
        v_tx_type := 'EXPENSE';
    END IF;

    IF v_tx_type NOT IN ('INCOME', 'EXPENSE') THEN
        RAISE EXCEPTION 'Loại giao dịch không hợp lệ: %', p_transaction_type
            USING ERRCODE = '22023';
    END IF;

    SELECT id, total_balance INTO v_fund_id, v_current_balance
    FROM public.maintenance_funds
    WHERE building_id = p_building_id
    LIMIT 1
    FOR UPDATE;

    IF v_fund_id IS NULL THEN
        INSERT INTO public.maintenance_funds (building_id, total_balance)
        VALUES (p_building_id, 0.00)
        RETURNING id, total_balance INTO v_fund_id, v_current_balance;
    END IF;

    SELECT to_char(CURRENT_DATE, 'YYYYMM') INTO v_period;

    IF v_tx_type = 'INCOME' THEN
        v_new_balance := v_current_balance + p_amount;
        v_prefix := 'PT-';
        v_seq := nextval('public.maintenance_fund_pt_seq');
    ELSE
        IF v_current_balance < p_amount THEN
            RAISE EXCEPTION 'Số dư quỹ bảo trì không đủ để chi (Số dư hiện tại: %, Cần chi: %)', v_current_balance, p_amount
                USING ERRCODE = '22023';
        END IF;
        v_new_balance := v_current_balance - p_amount;
        v_prefix := 'PC-';
        v_seq := nextval('public.maintenance_fund_pc_seq');
    END IF;

    v_voucher_number := v_prefix || v_period || '-' || LPAD(v_seq::text, 5, '0');
    v_recipient := COALESCE(NULLIF(TRIM(p_recipient_or_payer), ''), 'Ban Quản Lý');

    UPDATE public.maintenance_funds
    SET total_balance = v_new_balance,
        updated_at = now()
    WHERE id = v_fund_id;

    INSERT INTO public.maintenance_fund_transactions (
        building_id,
        fund_id,
        voucher_number,
        transaction_type,
        category,
        amount,
        balance_after,
        reference_type,
        reference_id,
        recipient_or_payer,
        description,
        receipt_url,
        created_by,
        created_at
    ) VALUES (
        p_building_id,
        v_fund_id,
        v_voucher_number,
        v_tx_type,
        p_category,
        p_amount,
        v_new_balance,
        COALESCE(NULLIF(TRIM(p_reference_type), ''), 'MANUAL'),
        p_reference_id,
        v_recipient,
        p_description,
        p_receipt_url,
        v_user_id,
        now()
    ) RETURNING id INTO v_tx_id;

    RETURN jsonb_build_object(
        'success', true,
        'transaction_id', v_tx_id,
        'voucher_number', v_voucher_number,
        'new_balance', v_new_balance,
        'message', 'Ghi sổ quỹ bảo trì thành công.'
    );
END;
$$;

REVOKE ALL ON FUNCTION public.record_maintenance_fund_transaction(
    UUID, TEXT, NUMERIC, TEXT, TEXT, TEXT, UUID, UUID, TEXT, VARCHAR
) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.record_maintenance_fund_transaction(
    UUID, TEXT, NUMERIC, TEXT, TEXT, TEXT, UUID, UUID, TEXT, VARCHAR
) TO authenticated, service_role;

-- ============================================================================
-- 3. GỠ BỎ 5 RPC OVERLOAD TRÙNG LẶP KHÁC & GIA CỐ NHẮC HẠN HÓA ĐƠN
-- ============================================================================

-- 3.1. check_in_visitor_pass: Gỡ bản cũ 2 tham số không kiểm tra quyền
DROP FUNCTION IF EXISTS public.check_in_visitor_pass(TEXT, UUID);

-- 3.2. calculate_utility_charge: Gỡ bản cũ 2 tham số fixed-rate
DROP FUNCTION IF EXISTS public.calculate_utility_charge(VARCHAR, NUMERIC);

-- 3.3. simulate_unified_payment: Gỡ bản overload 6 tham số còn mở quyền authenticated
--      và khóa chặt bản còn lại chỉ dành cho service_role
DROP FUNCTION IF EXISTS public.simulate_unified_payment(TEXT, UUID, TEXT, TEXT, TEXT, TEXT);
REVOKE ALL ON FUNCTION public.simulate_unified_payment(UUID, TEXT, TEXT, TEXT, TEXT)
    FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.simulate_unified_payment(UUID, TEXT, TEXT, TEXT, TEXT)
    TO service_role;

-- 3.4. submit_apartment_link_request: Gỡ bản overload uuid không dùng ở client
DROP FUNCTION IF EXISTS public.submit_apartment_link_request(UUID, public.apartment_relation_role);

-- 3.5. check_and_generate_invoice_due_reminders: Gỡ bản 0 tham số & gia cố bản 1 tham số
DROP FUNCTION IF EXISTS public.check_and_generate_invoice_due_reminders();

CREATE OR REPLACE FUNCTION public.check_and_generate_invoice_due_reminders(
    p_building_id UUID DEFAULT NULL
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_is_service BOOLEAN := COALESCE(auth.jwt() ->> 'role', '') = 'service_role';
    v_inv RECORD;
    v_res RECORD;
    v_count INT := 0;
    v_reminder_type TEXT;
    v_title TEXT;
    v_body TEXT;
    v_days_diff INT;
BEGIN
    IF NOT v_is_service THEN
        IF auth.uid() IS NULL THEN
            RAISE EXCEPTION 'Yêu cầu đăng nhập nhân sự quản lý để quét nhắc hạn hóa đơn.'
                USING ERRCODE = '42501';
        END IF;
        IF p_building_id IS NOT NULL THEN
            IF NOT public.is_building_staff(
                p_building_id,
                ARRAY['admin', 'management', 'manager', 'owner', 'accountant']
            ) THEN
                RAISE EXCEPTION 'Bạn không có quyền quét nhắc hạn hóa đơn cho tòa nhà này.'
                    USING ERRCODE = '42501';
            END IF;
        ELSIF NOT (public.is_super_admin() OR public.is_management()) THEN
            RAISE EXCEPTION 'Chỉ Ban Quản Lý mới có quyền quét nhắc hạn hóa đơn.'
                USING ERRCODE = '42501';
        END IF;
    END IF;

    FOR v_inv IN
        SELECT i.id, i.apartment_id, i.period, i.due_date, i.total_amount,
               a.code AS apt_code, a.building_id
        FROM public.invoices i
        JOIN public.apartments a ON i.apartment_id = a.id
        WHERE i.status::text IN ('unpaid', 'pending', 'overdue')
          AND i.due_date::date <= (CURRENT_DATE + INTERVAL '3 days')::date
          AND i.due_date::date >= (CURRENT_DATE - INTERVAL '14 days')::date
          AND (p_building_id IS NULL OR a.building_id = p_building_id)
          AND (
              v_is_service
              OR p_building_id IS NOT NULL
              OR public.is_building_staff(
                  a.building_id,
                  ARRAY['admin', 'management', 'manager', 'owner', 'accountant']
              )
          )
    LOOP
        v_days_diff := (v_inv.due_date::date - CURRENT_DATE);

        IF v_days_diff > 0 THEN
            v_reminder_type := 'invoice_due_soon';
            v_title := 'Nhắc hạn thanh toán phí kỳ ' || v_inv.period;
            v_body := 'Hóa đơn căn hộ ' || v_inv.apt_code || ' số tiền ' ||
                      to_char(v_inv.total_amount, 'FM999,999,999,999') ||
                      ' đ sắp đến hạn (còn ' || v_days_diff || ' ngày nữa).';
        ELSIF v_days_diff = 0 THEN
            v_reminder_type := 'invoice_due_today';
            v_title := 'Hóa đơn kỳ ' || v_inv.period || ' đến hạn hôm nay';
            v_body := 'Hôm nay là hạn cuối thanh toán hóa đơn căn hộ ' || v_inv.apt_code ||
                      '. Vui lòng hoàn tất thanh toán để tránh phát sinh gián đoạn dịch vụ.';
        ELSE
            v_reminder_type := 'invoice_overdue';
            v_title := 'Cảnh báo: Hóa đơn kỳ ' || v_inv.period || ' đã quá hạn';
            v_body := 'Hóa đơn căn hộ ' || v_inv.apt_code || ' đã quá hạn ' || ABS(v_days_diff) ||
                      ' ngày. Vui lòng thanh toán ngay qua ứng dụng.';
        END IF;

        FOR v_res IN
            SELECT user_id FROM public.residents_apartments WHERE apartment_id = v_inv.apartment_id
        LOOP
            IF NOT EXISTS (
                SELECT 1 FROM public.notifications n
                WHERE n.user_id = v_res.user_id
                  AND n.type = v_reminder_type
                  AND (n.payload->>'invoice_id') = v_inv.id::text
                  AND n.created_at::date = CURRENT_DATE
            ) THEN
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
                    v_inv.building_id,
                    v_res.user_id,
                    v_inv.apartment_id,
                    v_title,
                    v_body,
                    v_reminder_type,
                    jsonb_build_object(
                        'invoice_id', v_inv.id,
                        'period', v_inv.period,
                        'amount', v_inv.total_amount
                    ),
                    false,
                    now()
                );
                v_count := v_count + 1;
            END IF;
        END LOOP;
    END LOOP;

    RETURN v_count;
END;
$$;

REVOKE ALL ON FUNCTION public.check_and_generate_invoice_due_reminders(UUID) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.check_and_generate_invoice_due_reminders(UUID) TO authenticated, service_role;

-- ============================================================================
-- 4. GIA CỐ update_invoice_with_items: CHẶN SỬA HÓA ĐƠN ĐÃ THANH TOÁN & CHÉO TÒA
-- ============================================================================

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
    v_is_service BOOLEAN := COALESCE(auth.jwt() ->> 'role', '') = 'service_role';
    v_inv RECORD;
    v_building_id UUID;
    v_target_building_id UUID;
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
        v_is_service
        OR public.is_building_staff(v_building_id, ARRAY['admin', 'management', 'manager', 'owner', 'accountant'])
    ) THEN
        RAISE EXCEPTION 'Truy cập bị từ chối: Chỉ Ban Quản Lý hoặc Kế toán tòa nhà mới có quyền cập nhật hóa đơn.'
            USING ERRCODE = '42501';
    END IF;

    IF v_inv.status::text IN ('paid', 'pending_confirmation') THEN
        RAISE EXCEPTION 'Không thể chỉnh sửa hạng mục của hóa đơn đã thanh toán hoặc đang chờ xác nhận.'
            USING ERRCODE = '22023';
    END IF;

    IF p_apartment_id IS NOT NULL AND p_apartment_id <> v_inv.apartment_id THEN
        SELECT building_id INTO v_target_building_id
        FROM public.apartments
        WHERE id = p_apartment_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Căn hộ đích không tồn tại.'
                USING ERRCODE = '22023';
        END IF;

        IF v_target_building_id IS DISTINCT FROM v_building_id AND NOT (
            v_is_service
            OR public.is_building_staff(v_target_building_id, ARRAY['admin', 'management', 'manager', 'owner', 'accountant'])
        ) THEN
            RAISE EXCEPTION 'Truy cập bị từ chối: Không được chuyển hóa đơn sang tòa nhà ngoài thẩm quyền.'
                USING ERRCODE = '42501';
        END IF;
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

-- ============================================================================
-- 5. THU HỒI QUYỀN EXECUTE CỦA ANON/PUBLIC TRÊN TOÀN BỘ HÀM NGHIỆP VỤ NỘI BỘ
--    (CHỈ GIỮ ANON TRÊN 4 RPC CÔNG KHAI TRƯỚC ĐĂNG NHẬP)
-- ============================================================================

DO $$
DECLARE
    r RECORD;
    v_sig TEXT;
BEGIN
    FOR r IN
        SELECT p.oid,
               p.proname,
               pg_get_function_identity_arguments(p.oid) AS args,
               has_function_privilege('authenticated', p.oid, 'EXECUTE') AS auth_exec
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public'
          AND p.prokind = 'f'
          AND NOT EXISTS (
              SELECT 1 FROM pg_depend d
              WHERE d.objid = p.oid AND d.deptype = 'e'
          )
          AND p.proname NOT IN (
              'verify_activation_code',
              'verify_activation_otp',
              'complete_resident_activation',
              'verify_document_lookup'
          )
          AND has_function_privilege('anon', p.oid, 'EXECUTE')
    LOOP
        v_sig := format('public.%I(%s)', r.proname, r.args);
        EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM anon, PUBLIC;', v_sig);
        IF r.proname IN ('simulate_unified_payment', 'process_bank_payment_webhook') OR NOT r.auth_exec THEN
            EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM authenticated;', v_sig);
            EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role;', v_sig);
        ELSE
            EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated, service_role;', v_sig);
        END IF;
    END LOOP;
END $$;
