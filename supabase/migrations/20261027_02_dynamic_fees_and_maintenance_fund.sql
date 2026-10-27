-- ==============================================================================
-- PKA-HOME: DYNAMIC FEES & MAINTENANCE FUND MIGRATION
-- Migration: 20261027_02_dynamic_fees_and_maintenance_fund.sql
-- ==============================================================================

-- 1. Seed initial fee schedules if not already present
INSERT INTO public.fee_schedules (fee_type, name, unit, unit_price, effective_from, is_active)
SELECT v.fee_type, v.name, v.unit, v.unit_price, v.effective_from::date, v.is_active
FROM (VALUES
    ('electricity', 'Tiền điện', 'kWh', 3500.00, '2026-01-01', true),
    ('water', 'Tiền nước', 'm3', 18000.00, '2026-01-01', true),
    ('management', 'Phí quản lý', 'm2', 16500.00, '2026-01-01', true),
    ('parking_motorcycle', 'Phí gửi xe máy', 'xe/tháng', 100000.00, '2026-01-01', true),
    ('parking_car', 'Phí gửi ô tô', 'xe/tháng', 1200000.00, '2026-01-01', true)
) AS v(fee_type, name, unit, unit_price, effective_from, is_active)
WHERE NOT EXISTS (
    SELECT 1 FROM public.fee_schedules fs WHERE fs.fee_type = v.fee_type AND fs.is_active = true
);

-- 2. Create maintenance_funds table
CREATE TABLE IF NOT EXISTS public.maintenance_funds (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    total_balance NUMERIC(15,2) NOT NULL DEFAULT 0.00,
    annual_interest_earned NUMERIC(15,2) NOT NULL DEFAULT 0.00,
    interest_rate_percent NUMERIC(5,2) NOT NULL DEFAULT 5.20,
    collected_percent NUMERIC(5,2) NOT NULL DEFAULT 100.00,
    bank_name TEXT NOT NULL DEFAULT 'Ngân hàng TMCP Đầu tư và Phát triển Việt Nam (BIDV)',
    bank_account_number TEXT NOT NULL DEFAULT '1234567890',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.maintenance_funds ENABLE ROW LEVEL SECURITY;

-- Policies
DROP POLICY IF EXISTS "maintenance_funds_read" ON public.maintenance_funds;
CREATE POLICY "maintenance_funds_read" ON public.maintenance_funds
    FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "maintenance_funds_manage_admin" ON public.maintenance_funds;
CREATE POLICY "maintenance_funds_manage_admin" ON public.maintenance_funds
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.users u
            WHERE u.id = auth.uid()
            AND u.role IN ('admin', 'manager', 'accountant')
        )
    );

-- Seed initial maintenance fund record
INSERT INTO public.maintenance_funds (
    total_balance,
    annual_interest_earned,
    interest_rate_percent,
    collected_percent,
    bank_name,
    bank_account_number
)
SELECT 
    2450000000.00,
    127400000.00,
    5.20,
    98.50,
    'Ngân hàng TMCP Đầu tư và Phát triển Việt Nam (BIDV)',
    '1234567890'
WHERE NOT EXISTS (SELECT 1 FROM public.maintenance_funds);

-- 3. Create helper function to lookup effective rate
CREATE OR REPLACE FUNCTION public.get_effective_fee_schedule(
    p_fee_type TEXT,
    p_date DATE DEFAULT CURRENT_DATE
)
RETURNS NUMERIC
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_unit_price NUMERIC(12,2);
BEGIN
    SELECT unit_price INTO v_unit_price
    FROM public.fee_schedules
    WHERE fee_type = p_fee_type
      AND is_active = true
      AND effective_from <= p_date
      AND (effective_to IS NULL OR effective_to >= p_date)
    ORDER BY effective_from DESC
    LIMIT 1;

    RETURN COALESCE(v_unit_price, 0.00);
END;
$$;
