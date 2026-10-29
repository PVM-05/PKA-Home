-- ==============================================================================
-- PKA-HOME: PHASE C2 - PROGRESSIVE FEES, EVN TIERS, PRO-RATA & LATE PENALTY ENGINE
-- Migration: 20261029_04_progressive_fees_and_prorata_engine.sql
-- ==============================================================================

-- 1. BẢNG QUẢN LÝ CHÍNH SÁCH BIỂU GIÁ (FEE TIER POLICIES)
CREATE TABLE IF NOT EXISTS public.fee_tier_policies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    building_id UUID NULL REFERENCES public.buildings(id) ON DELETE CASCADE,
    policy_type VARCHAR(30) NOT NULL CHECK (policy_type IN ('ELECTRICITY_TIER', 'WATER_QUOTA_TIER', 'PARKING_PRORATA', 'LATE_PAYMENT_PENALTY', 'MANAGEMENT_FEE')),
    name VARCHAR(100) NOT NULL,
    calculation_method VARCHAR(30) NOT NULL CHECK (calculation_method IN ('PROGRESSIVE_TIER', 'PER_CAPITA_QUOTA', 'PRO_RATA_DAILY', 'PERCENTAGE_DAILY', 'FLAT_RATE')),
    tiers JSONB NOT NULL,
    effective_from DATE NOT NULL DEFAULT CURRENT_DATE,
    effective_to DATE,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ftp_building_type ON public.fee_tier_policies(building_id, policy_type);
CREATE INDEX IF NOT EXISTS idx_ftp_active_type ON public.fee_tier_policies(policy_type, is_active, effective_from);

ALTER TABLE public.fee_tier_policies ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "ftp_read_policy" ON public.fee_tier_policies;
CREATE POLICY "ftp_read_policy" ON public.fee_tier_policies
    FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "ftp_manage_policy" ON public.fee_tier_policies;
CREATE POLICY "ftp_manage_policy" ON public.fee_tier_policies
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.users u
            WHERE u.id = auth.uid()
            AND u.role IN ('admin', 'manager', 'accountant')
        )
    );

-- 2. SEED CÁC CHÍNH SÁCH BIỂU GIÁ MẶC ĐỊNH
-- 2.1. Biểu giá điện sinh hoạt EVN 6 bậc (Quyết định Bộ Công Thương 2024)
INSERT INTO public.fee_tier_policies (
    building_id,
    policy_type,
    name,
    calculation_method,
    tiers,
    effective_from,
    is_active
)
SELECT
    NULL,
    'ELECTRICITY_TIER',
    'Điện sinh hoạt EVN 6 bậc (QĐ 2024)',
    'PROGRESSIVE_TIER',
    '[
        {"tier": 1, "name": "Bậc 1 (0 - 50 kWh)", "from": 0, "to": 50, "rate": 1893},
        {"tier": 2, "name": "Bậc 2 (51 - 100 kWh)", "from": 50, "to": 100, "rate": 1956},
        {"tier": 3, "name": "Bậc 3 (101 - 200 kWh)", "from": 100, "to": 200, "rate": 2271},
        {"tier": 4, "name": "Bậc 4 (201 - 300 kWh)", "from": 200, "to": 300, "rate": 2860},
        {"tier": 5, "name": "Bậc 5 (301 - 400 kWh)", "from": 300, "to": 400, "rate": 3197},
        {"tier": 6, "name": "Bậc 6 (Trên 400 kWh)", "from": 400, "to": null, "rate": 3302}
    ]'::jsonb,
    '2024-01-01'::date,
    true
WHERE NOT EXISTS (
    SELECT 1 FROM public.fee_tier_policies
    WHERE policy_type = 'ELECTRICITY_TIER' AND building_id IS NULL
);

-- 2.2. Biểu giá nước sinh hoạt theo định mức nhân khẩu 4m3/người
INSERT INTO public.fee_tier_policies (
    building_id,
    policy_type,
    name,
    calculation_method,
    tiers,
    effective_from,
    is_active
)
SELECT
    NULL,
    'WATER_QUOTA_TIER',
    'Nước sinh hoạt định mức 4m3/người',
    'PER_CAPITA_QUOTA',
    '{
        "quota_per_resident": 4.0,
        "base_rate": 8500,
        "excess_tier_1_ratio": 1.5,
        "excess_tier_1_rate": 12000,
        "excess_tier_2_rate": 18000
    }'::jsonb,
    '2024-01-01'::date,
    true
WHERE NOT EXISTS (
    SELECT 1 FROM public.fee_tier_policies
    WHERE policy_type = 'WATER_QUOTA_TIER' AND building_id IS NULL
);

-- 2.3. Chính sách lãi phạt trễ hạn thanh toán sau 3 ngày ân hạn
INSERT INTO public.fee_tier_policies (
    building_id,
    policy_type,
    name,
    calculation_method,
    tiers,
    effective_from,
    is_active
)
SELECT
    NULL,
    'LATE_PAYMENT_PENALTY',
    'Lãi phạt trễ hạn 0.05%/ngày',
    'PERCENTAGE_DAILY',
    '{
        "grace_period_days": 3,
        "penalty_rate_per_day": 0.0005
    }'::jsonb,
    '2024-01-01'::date,
    true
WHERE NOT EXISTS (
    SELECT 1 FROM public.fee_tier_policies
    WHERE policy_type = 'LATE_PAYMENT_PENALTY' AND building_id IS NULL
);

-- 3. CÁC HÀM RPCs TÍNH TOÁN (CALCULATION ENGINES)

-- 3.1. RPC Tính Tiền Điện Lũy Tiến 6 Bậc Chuẩn EVN
CREATE OR REPLACE FUNCTION public.calculate_progressive_electricity_fee(
    p_consumption NUMERIC,
    p_building_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_policy RECORD;
    v_tier_item JSONB;
    v_from NUMERIC;
    v_to NUMERIC;
    v_rate NUMERIC;
    v_tier_num INT;
    v_tier_name TEXT;
    v_tier_kwh NUMERIC;
    v_tier_amount NUMERIC;
    v_total_amount NUMERIC := 0;
    v_breakdown JSONB := '[]'::jsonb;
    v_effective_kwh NUMERIC;
BEGIN
    v_effective_kwh := GREATEST(COALESCE(p_consumption, 0), 0);

    -- Tìm chính sách biểu giá áp dụng cho tòa nhà hoặc mặc định hệ thống
    SELECT * INTO v_policy
    FROM public.fee_tier_policies
    WHERE policy_type = 'ELECTRICITY_TIER'
      AND is_active = true
      AND (
          (p_building_id IS NOT NULL AND building_id = p_building_id)
          OR building_id IS NULL
      )
    ORDER BY (CASE WHEN building_id IS NOT NULL THEN 0 ELSE 1 END), effective_from DESC
    LIMIT 1;

    -- Nếu không có trong DB thì fallback sang cấu hình EVN chuẩn
    IF v_policy.id IS NULL THEN
        v_policy.name := 'Điện sinh hoạt EVN 6 bậc (QĐ 2024)';
        v_policy.tiers := '[
            {"tier": 1, "name": "Bậc 1 (0 - 50 kWh)", "from": 0, "to": 50, "rate": 1893},
            {"tier": 2, "name": "Bậc 2 (51 - 100 kWh)", "from": 50, "to": 100, "rate": 1956},
            {"tier": 3, "name": "Bậc 3 (101 - 200 kWh)", "from": 100, "to": 200, "rate": 2271},
            {"tier": 4, "name": "Bậc 4 (201 - 300 kWh)", "from": 200, "to": 300, "rate": 2860},
            {"tier": 5, "name": "Bậc 5 (301 - 400 kWh)", "from": 300, "to": 400, "rate": 3197},
            {"tier": 6, "name": "Bậc 6 (Trên 400 kWh)", "from": 400, "to": null, "rate": 3302}
        ]'::jsonb;
    END IF;

    -- Duyệt qua từng bậc giá để tính toán
    FOR v_tier_item IN SELECT * FROM jsonb_array_elements(v_policy.tiers)
    LOOP
        v_tier_num := (v_tier_item->>'tier')::INT;
        v_tier_name := v_tier_item->>'name';
        v_from := (v_tier_item->>'from')::NUMERIC;
        IF (v_tier_item->>'to') IS NOT NULL AND (v_tier_item->>'to') <> 'null' THEN
            v_to := (v_tier_item->>'to')::NUMERIC;
        ELSE
            v_to := NULL;
        END IF;
        v_rate := (v_tier_item->>'rate')::NUMERIC;

        IF v_effective_kwh <= v_from THEN
            v_tier_kwh := 0;
        ELSE
            IF v_to IS NOT NULL THEN
                v_tier_kwh := LEAST(v_effective_kwh, v_to) - v_from;
            ELSE
                v_tier_kwh := v_effective_kwh - v_from;
            END IF;
        END IF;

        v_tier_amount := ROUND(v_tier_kwh * v_rate);
        v_total_amount := v_total_amount + v_tier_amount;

        v_breakdown := v_breakdown || jsonb_build_object(
            'tier', v_tier_num,
            'name', v_tier_name,
            'from', v_from,
            'to', v_to,
            'rate', v_rate,
            'consumption', v_tier_kwh,
            'amount', v_tier_amount
        );
    END LOOP;

    RETURN jsonb_build_object(
        'policy_id', v_policy.id,
        'policy_name', COALESCE(v_policy.name, 'Điện sinh hoạt EVN 6 bậc (QĐ 2024)'),
        'consumption', v_effective_kwh,
        'total_amount', v_total_amount,
        'breakdown', v_breakdown
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.calculate_progressive_electricity_fee(NUMERIC, UUID) TO authenticated, service_role;

-- 3.2. RPC Tính Tiền Nước Theo Định Mức Nhân Khẩu
CREATE OR REPLACE FUNCTION public.calculate_quota_water_fee(
    p_consumption NUMERIC,
    p_resident_count INT DEFAULT 1,
    p_building_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_policy RECORD;
    v_residents INT;
    v_effective_m3 NUMERIC;
    v_quota_per_resident NUMERIC;
    v_base_rate NUMERIC;
    v_excess_ratio NUMERIC;
    v_excess_rate_1 NUMERIC;
    v_excess_rate_2 NUMERIC;
    v_quota NUMERIC;
    v_limit2 NUMERIC;
    v_tier1_m3 NUMERIC := 0;
    v_tier2_m3 NUMERIC := 0;
    v_tier3_m3 NUMERIC := 0;
    v_tier1_amt NUMERIC := 0;
    v_tier2_amt NUMERIC := 0;
    v_tier3_amt NUMERIC := 0;
    v_total_amount NUMERIC := 0;
BEGIN
    v_effective_m3 := GREATEST(COALESCE(p_consumption, 0), 0);
    v_residents := GREATEST(COALESCE(p_resident_count, 1), 1);

    SELECT * INTO v_policy
    FROM public.fee_tier_policies
    WHERE policy_type = 'WATER_QUOTA_TIER'
      AND is_active = true
      AND (
          (p_building_id IS NOT NULL AND building_id = p_building_id)
          OR building_id IS NULL
      )
    ORDER BY (CASE WHEN building_id IS NOT NULL THEN 0 ELSE 1 END), effective_from DESC
    LIMIT 1;

    v_quota_per_resident := COALESCE((v_policy.tiers->>'quota_per_resident')::NUMERIC, 4.0);
    v_base_rate := COALESCE((v_policy.tiers->>'base_rate')::NUMERIC, 8500);
    v_excess_ratio := COALESCE((v_policy.tiers->>'excess_tier_1_ratio')::NUMERIC, 1.5);
    v_excess_rate_1 := COALESCE((v_policy.tiers->>'excess_tier_1_rate')::NUMERIC, 12000);
    v_excess_rate_2 := COALESCE((v_policy.tiers->>'excess_tier_2_rate')::NUMERIC, 18000);

    v_quota := v_residents * v_quota_per_resident;
    v_limit2 := v_quota * v_excess_ratio;

    -- Bậc 1: Trong định mức [0, v_quota]
    IF v_effective_m3 > 0 THEN
        v_tier1_m3 := LEAST(v_effective_m3, v_quota);
        v_tier1_amt := ROUND(v_tier1_m3 * v_base_rate);
    END IF;

    -- Bậc 2: Vượt định mức cấp 1 (v_quota, v_limit2]
    IF v_effective_m3 > v_quota THEN
        v_tier2_m3 := LEAST(v_effective_m3, v_limit2) - v_quota;
        v_tier2_amt := ROUND(v_tier2_m3 * v_excess_rate_1);
    END IF;

    -- Bậc 3: Vượt định mức cấp 2 (> v_limit2)
    IF v_effective_m3 > v_limit2 THEN
        v_tier3_m3 := v_effective_m3 - v_limit2;
        v_tier3_amt := ROUND(v_tier3_m3 * v_excess_rate_2);
    END IF;

    v_total_amount := v_tier1_amt + v_tier2_amt + v_tier3_amt;

    RETURN jsonb_build_object(
        'policy_id', v_policy.id,
        'policy_name', COALESCE(v_policy.name, 'Nước sinh hoạt định mức 4m3/người'),
        'consumption', v_effective_m3,
        'resident_count', v_residents,
        'quota', v_quota,
        'total_amount', v_total_amount,
        'breakdown', jsonb_build_array(
            jsonb_build_object(
                'tier', 1,
                'name', 'Trong định mức (0 - ' || v_quota || ' m³)',
                'from', 0,
                'to', v_quota,
                'rate', v_base_rate,
                'consumption', v_tier1_m3,
                'amount', v_tier1_amt
            ),
            jsonb_build_object(
                'tier', 2,
                'name', 'Vượt định mức cấp 1 (' || v_quota || ' - ' || v_limit2 || ' m³)',
                'from', v_quota,
                'to', v_limit2,
                'rate', v_excess_rate_1,
                'consumption', v_tier2_m3,
                'amount', v_tier2_amt
            ),
            jsonb_build_object(
                'tier', 3,
                'name', 'Vượt định mức cấp 2 (> ' || v_limit2 || ' m³)',
                'from', v_limit2,
                'to', null,
                'rate', v_excess_rate_2,
                'consumption', v_tier3_m3,
                'amount', v_tier3_amt
            )
        )
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.calculate_quota_water_fee(NUMERIC, INT, UUID) TO authenticated, service_role;

-- 3.3. RPC Tính Phí Xe Theo Tỷ Lệ Ngày Sử Dụng Thực Tế (Pro-rata)
CREATE OR REPLACE FUNCTION public.calculate_prorated_vehicle_fee(
    p_monthly_rate NUMERIC,
    p_start_date DATE,
    p_period VARCHAR(7) -- Định dạng YYYY-MM
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_period_start DATE;
    v_period_end DATE;
    v_days_in_month INT;
    v_days_used INT;
    v_is_prorated BOOLEAN;
    v_rate NUMERIC;
    v_total_amount NUMERIC;
BEGIN
    v_rate := GREATEST(COALESCE(p_monthly_rate, 0), 0);
    v_period_start := to_date(p_period || '-01', 'YYYY-MM-DD');
    v_period_end := (date_trunc('month', v_period_start) + interval '1 month - 1 day')::DATE;
    v_days_in_month := EXTRACT(DAY FROM v_period_end)::INT;

    IF p_start_date IS NULL OR p_start_date <= v_period_start THEN
        v_days_used := v_days_in_month;
        v_is_prorated := false;
        v_total_amount := v_rate;
    ELSIF p_start_date > v_period_end THEN
        v_days_used := 0;
        v_is_prorated := true;
        v_total_amount := 0;
    ELSE
        v_days_used := (v_period_end - p_start_date + 1);
        v_is_prorated := true;
        v_total_amount := ROUND((v_rate * v_days_used) / v_days_in_month);
    END IF;

    RETURN jsonb_build_object(
        'monthly_rate', v_rate,
        'period', p_period,
        'start_date', p_start_date,
        'days_in_month', v_days_in_month,
        'days_used', v_days_used,
        'is_prorated', v_is_prorated,
        'total_amount', v_total_amount
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.calculate_prorated_vehicle_fee(NUMERIC, DATE, VARCHAR) TO authenticated, service_role;

-- 3.4. RPC Tự Động Tính Tiền Phạt Trễ Hạn Thanh Toán Sau Ân Hạn
CREATE OR REPLACE FUNCTION public.calculate_late_payment_penalty(
    p_invoice_id UUID,
    p_as_of_date DATE DEFAULT CURRENT_DATE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
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

    -- Lấy thông tin hóa đơn và tòa nhà
    SELECT i.*, a.building_id
    INTO v_invoice
    FROM public.invoices i
    JOIN public.apartments a ON a.id = i.apartment_id
    WHERE i.id = p_invoice_id;

    IF v_invoice.id IS NULL THEN
        RAISE EXCEPTION 'Không tìm thấy hóa đơn với mã %', p_invoice_id;
    END IF;

    -- Lấy chính sách lãi phạt trễ hạn
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

    -- Nếu hóa đơn đã thanh toán thì không phạt
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
$$;

GRANT EXECUTE ON FUNCTION public.calculate_late_payment_penalty(UUID, DATE) TO authenticated, service_role;
