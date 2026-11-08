-- ============================================================================
-- MIGRATION: 20261108_03_utility_billing_engine.sql
-- Phân Hệ Chốt Chỉ Số Điện - Nước & Tự Động Lập Hóa Đơn Kỳ B2B SaaS
-- ============================================================================

-- 1. BẢNG CẤU HÌNH BIỂU GIÁ TIỆN ÍCH TÒA NHÀ (building_utility_rates)
CREATE TABLE IF NOT EXISTS public.building_utility_rates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    utility_type VARCHAR(20) NOT NULL CHECK (utility_type IN ('electricity', 'water')),
    pricing_model VARCHAR(20) NOT NULL DEFAULT 'fixed' CHECK (pricing_model IN ('fixed', 'tiered_evn', 'tiered_water')),
    base_unit_price NUMERIC(12, 2) NOT NULL DEFAULT 3500.00,
    vat_percentage NUMERIC(5, 2) NOT NULL DEFAULT 8.00,
    environment_fee_percentage NUMERIC(5, 2) NOT NULL DEFAULT 0.00,
    tiers JSONB DEFAULT '[]'::jsonb,
    effective_from DATE NOT NULL DEFAULT CURRENT_DATE,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- RLS cho building_utility_rates
ALTER TABLE public.building_utility_rates ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "utility_rates_read" ON public.building_utility_rates;
CREATE POLICY "utility_rates_read" ON public.building_utility_rates
    FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "utility_rates_manage" ON public.building_utility_rates;
CREATE POLICY "utility_rates_manage" ON public.building_utility_rates
    FOR ALL TO authenticated USING (public.is_staff_or_management());

-- Seed biểu giá tiêu chuẩn ban đầu nếu chưa có
INSERT INTO public.building_utility_rates (utility_type, pricing_model, base_unit_price, vat_percentage, environment_fee_percentage, is_active)
SELECT 'electricity', 'fixed', 3500.00, 8.00, 0.00, true
WHERE NOT EXISTS (SELECT 1 FROM public.building_utility_rates WHERE utility_type = 'electricity');

INSERT INTO public.building_utility_rates (utility_type, pricing_model, base_unit_price, vat_percentage, environment_fee_percentage, is_active)
SELECT 'water', 'fixed', 25000.00, 5.00, 10.00, true
WHERE NOT EXISTS (SELECT 1 FROM public.building_utility_rates WHERE utility_type = 'water');


-- 2. MỞ RỘNG BẢNG meter_reading_submissions ĐO LƯỜNG TIÊU THỤ & LIÊN KẾT HÓA ĐƠN
ALTER TABLE public.meter_reading_submissions
    ADD COLUMN IF NOT EXISTS previous_electric_reading NUMERIC(10, 2),
    ADD COLUMN IF NOT EXISTS previous_water_reading NUMERIC(10, 2),
    ADD COLUMN IF NOT EXISTS electric_consumed NUMERIC(10, 2) GENERATED ALWAYS AS (GREATEST(0, electric_reading - COALESCE(previous_electric_reading, 0))) STORED,
    ADD COLUMN IF NOT EXISTS water_consumed NUMERIC(10, 2) GENERATED ALWAYS AS (GREATEST(0, water_reading - COALESCE(previous_water_reading, 0))) STORED,
    ADD COLUMN IF NOT EXISTS invoice_id UUID REFERENCES public.invoices(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS reader_id UUID REFERENCES public.users(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_meter_submissions_invoice ON public.meter_reading_submissions(invoice_id);


-- 3. HÀM PHỤ TRỢ TÍNH PHÍ TIỆN ÍCH (calculate_utility_charge)
CREATE OR REPLACE FUNCTION public.calculate_utility_charge(
    p_utility_type VARCHAR,
    p_consumed NUMERIC
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_rate RECORD;
    v_subtotal NUMERIC(12, 2) := 0;
    v_vat NUMERIC(12, 2) := 0;
    v_env NUMERIC(12, 2) := 0;
    v_total NUMERIC(12, 2) := 0;
BEGIN
    SELECT * INTO v_rate
    FROM public.building_utility_rates
    WHERE utility_type = p_utility_type AND is_active = true
    ORDER BY effective_from DESC
    LIMIT 1;

    IF NOT FOUND THEN
        -- Fallback đơn giá chuẩn thị trường
        IF p_utility_type = 'electricity' THEN
            v_subtotal := ROUND(p_consumed * 3500.00, 2);
            v_vat := ROUND(v_subtotal * 0.08, 2);
            v_total := v_subtotal + v_vat;
            RETURN jsonb_build_object(
                'subtotal', v_subtotal,
                'vat_amount', v_vat,
                'env_fee_amount', 0,
                'total_amount', v_total,
                'unit_price', 3500.00
            );
        ELSE
            v_subtotal := ROUND(p_consumed * 25000.00, 2);
            v_vat := ROUND(v_subtotal * 0.05, 2);
            v_env := ROUND(v_subtotal * 0.10, 2);
            v_total := v_subtotal + v_vat + v_env;
            RETURN jsonb_build_object(
                'subtotal', v_subtotal,
                'vat_amount', v_vat,
                'env_fee_amount', v_env,
                'total_amount', v_total,
                'unit_price', 25000.00
            );
        END IF;
    END IF;

    -- Tính theo fixed rate
    v_subtotal := ROUND(p_consumed * v_rate.base_unit_price, 2);
    v_vat := ROUND(v_subtotal * (v_rate.vat_percentage / 100.0), 2);
    v_env := ROUND(v_subtotal * (v_rate.environment_fee_percentage / 100.0), 2);
    v_total := v_subtotal + v_vat + v_env;

    RETURN jsonb_build_object(
        'subtotal', v_subtotal,
        'vat_amount', v_vat,
        'env_fee_amount', v_env,
        'total_amount', v_total,
        'unit_price', v_rate.base_unit_price
    );
END;
$$;


-- 4. RPC PHÊ DUYỆT CHỈ SỐ & TỰ ĐỘNG LẬP HÓA ĐƠN THÁNG (approve_meter_reading)
-- Xóa hàm cũ có 1 tham số để cập nhật signature mới
DROP FUNCTION IF EXISTS public.approve_meter_reading(UUID);

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
    v_user_id UUID;
    v_sub RECORD;
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
    v_user_id := auth.uid();
    IF v_user_id IS NULL OR NOT public.is_staff_or_management() THEN
        RAISE EXCEPTION 'Chỉ nhân viên hoặc BQL mới có quyền duyệt chỉ số công tơ.';
    END IF;

    SELECT * INTO v_sub
    FROM public.meter_reading_submissions
    WHERE id = p_submission_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Không tìm thấy bản ghi chỉ số công tơ.';
    END IF;

    IF v_sub.status = 'approved' THEN
        RETURN jsonb_build_object('success', false, 'message', 'Chỉ số này đã được duyệt trước đó.');
    END IF;

    -- Lấy chỉ số cũ kỳ trước nếu chưa có
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
        ELSE
            v_prev_electric := 0;
            v_prev_water := 0;
        END IF;
    END IF;

    v_electric_consumed := GREATEST(0, v_sub.electric_reading - v_prev_electric);
    v_water_consumed := GREATEST(0, v_sub.water_reading - v_prev_water);

    -- Tự động sinh hoặc gộp Hóa đơn nếu p_generate_invoice = true
    IF p_generate_invoice THEN
        v_elec_charge := public.calculate_utility_charge('electricity', v_electric_consumed);
        v_water_charge := public.calculate_utility_charge('water', v_water_consumed);

        v_elec_total := (v_elec_charge->>'total_amount')::NUMERIC;
        v_water_total := (v_water_charge->>'total_amount')::NUMERIC;
        v_utility_total := v_elec_total + v_water_total;

        v_due_date := COALESCE(p_due_date, CURRENT_DATE + INTERVAL '10 days');

        -- Kiểm tra hóa đơn của căn hộ trong kỳ này
        SELECT id, total_amount INTO v_existing_inv
        FROM public.invoices
        WHERE apartment_id = v_sub.apartment_id
          AND period = v_sub.period
          AND status IN ('pending', 'overdue')
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
                apartment_id,
                period,
                due_date,
                total_amount,
                status,
                created_at,
                updated_at
            ) VALUES (
                v_sub.apartment_id,
                v_sub.period,
                v_due_date,
                v_utility_total,
                'pending',
                now(),
                now()
            ) RETURNING id INTO v_invoice_id;
        END IF;

        -- Thêm dòng chi tiết tiền điện vào invoice_items
        IF v_electric_consumed > 0 OR v_elec_total > 0 THEN
            INSERT INTO public.invoice_items (
                invoice_id,
                fee_type,
                unit_price,
                quantity,
                subtotal
            ) VALUES (
                v_invoice_id,
                'electricity',
                (v_elec_charge->>'unit_price')::NUMERIC,
                v_electric_consumed,
                v_elec_total
            );
        END IF;

        -- Thêm dòng chi tiết tiền nước vào invoice_items
        IF v_water_consumed > 0 OR v_water_total > 0 THEN
            INSERT INTO public.invoice_items (
                invoice_id,
                fee_type,
                unit_price,
                quantity,
                subtotal
            ) VALUES (
                v_invoice_id,
                'water',
                (v_water_charge->>'unit_price')::NUMERIC,
                v_water_consumed,
                v_water_total
            );
        END IF;
    END IF;

    -- Cập nhật trạng thái phiếu chỉ số
    UPDATE public.meter_reading_submissions
    SET status = 'approved',
        approved_by = v_user_id,
        approved_at = now(),
        previous_electric_reading = v_prev_electric,
        previous_water_reading = v_prev_water,
        invoice_id = v_invoice_id,
        updated_at = now()
    WHERE id = p_submission_id;

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


-- 5. RPC CHỐT SỐ ĐIỆN NƯỚC HÀNG LOẠT THEO TẦNG (batch_record_meter_readings)
CREATE OR REPLACE FUNCTION public.batch_record_meter_readings(
    p_period TEXT,
    p_readings JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_user_id UUID;
    v_item JSONB;
    v_apt_id UUID;
    v_elec NUMERIC(10, 2);
    v_water NUMERIC(10, 2);
    v_elec_img TEXT;
    v_water_img TEXT;
    v_prev_elec NUMERIC(10, 2);
    v_prev_water NUMERIC(10, 2);
    v_inserted_count INT := 0;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL OR NOT public.is_staff_or_management() THEN
        RAISE EXCEPTION 'Chỉ nhân viên hoặc BQL mới có quyền chốt số hàng loạt.';
    END IF;

    FOR v_item IN SELECT * FROM jsonb_array_elements(p_readings)
    LOOP
        v_apt_id := (v_item->>'apartment_id')::UUID;
        v_elec := (v_item->>'electric_reading')::NUMERIC;
        v_water := (v_item->>'water_reading')::NUMERIC;
        v_elec_img := v_item->>'electric_image_url';
        v_water_img := v_item->>'water_image_url';

        -- Lấy chỉ số cũ kỳ trước
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
            v_user_id,
            v_user_id,
            p_period,
            v_elec,
            v_water,
            v_prev_elec,
            v_prev_water,
            v_elec_img,
            v_water_img,
            'pending',
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
$$;

GRANT EXECUTE ON FUNCTION public.calculate_utility_charge(VARCHAR, NUMERIC) TO authenticated;
GRANT EXECUTE ON FUNCTION public.approve_meter_reading(UUID, BOOLEAN, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION public.batch_record_meter_readings(TEXT, JSONB) TO authenticated;
