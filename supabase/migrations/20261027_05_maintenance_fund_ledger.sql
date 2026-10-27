-- ==============================================================================
-- PKA-HOME: PHASE D - MAINTENANCE FUND LEDGER & VOUCHERS
-- Migration: 20261027_05_maintenance_fund_ledger.sql
-- ==============================================================================

-- 1. Bổ sung building_id vào maintenance_funds
ALTER TABLE public.maintenance_funds
    ADD COLUMN IF NOT EXISTS building_id UUID REFERENCES public.buildings(id) ON DELETE CASCADE;

-- 2. Tạo bảng sổ quỹ biến động maintenance_fund_transactions
CREATE TABLE IF NOT EXISTS public.maintenance_fund_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    building_id UUID NOT NULL REFERENCES public.buildings(id) ON DELETE CASCADE,
    fund_id UUID NOT NULL REFERENCES public.maintenance_funds(id) ON DELETE CASCADE,
    voucher_number VARCHAR(30) NOT NULL, -- PT-YYYYMM-XXXXX hoặc PC-YYYYMM-XXXXX
    transaction_type VARCHAR(20) NOT NULL, -- 'INCOME' (Thu) hoặc 'EXPENSE' (Chi)
    category VARCHAR(50) NOT NULL, -- 'MAINTENANCE_FEE', 'EQUIPMENT_REPAIR', 'BANK_INTEREST', 'OTHER'
    amount NUMERIC(15,2) NOT NULL CHECK (amount > 0),
    balance_after NUMERIC(15,2) NOT NULL,
    reference_type VARCHAR(30), -- 'INVOICE', 'EQUIPMENT_TASK', 'BANK_INTEREST', 'MANUAL'
    reference_id UUID,
    recipient_or_payer TEXT NOT NULL,
    description TEXT NOT NULL,
    created_by UUID REFERENCES public.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_mft_building ON public.maintenance_fund_transactions(building_id);
CREATE INDEX IF NOT EXISTS idx_mft_voucher ON public.maintenance_fund_transactions(voucher_number);
CREATE INDEX IF NOT EXISTS idx_mft_created_at ON public.maintenance_fund_transactions(created_at DESC);

-- Bật RLS
ALTER TABLE public.maintenance_fund_transactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "mft_read_policy" ON public.maintenance_fund_transactions;
CREATE POLICY "mft_read_policy" ON public.maintenance_fund_transactions
    FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "mft_admin_manage_policy" ON public.maintenance_fund_transactions;
CREATE POLICY "mft_admin_manage_policy" ON public.maintenance_fund_transactions
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.users u
            WHERE u.id = auth.uid()
            AND u.role IN ('admin', 'manager', 'accountant')
        )
    );

-- 3. RPC Ghi sổ quỹ và cập nhật số dư an toàn (ACID Safe)
CREATE OR REPLACE FUNCTION public.record_maintenance_fund_transaction(
    p_building_id UUID,
    p_transaction_type VARCHAR(20),
    p_category VARCHAR(50),
    p_amount NUMERIC(15,2),
    p_description TEXT,
    p_recipient_or_payer TEXT,
    p_reference_type VARCHAR(30) DEFAULT NULL,
    p_reference_id UUID DEFAULT NULL,
    p_created_by UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_fund_id UUID;
    v_current_balance NUMERIC(15,2);
    v_new_balance NUMERIC(15,2);
    v_period TEXT;
    v_prefix TEXT;
    v_seq INT;
    v_voucher_number TEXT;
    v_tx_id UUID;
BEGIN
    -- 1. Tìm hoặc tạo bản ghi quỹ bảo trì cho tòa nhà
    SELECT id, total_balance INTO v_fund_id, v_current_balance
    FROM public.maintenance_funds
    WHERE building_id = p_building_id
    LIMIT 1
    FOR UPDATE;

    IF v_fund_id IS NULL THEN
        SELECT id, total_balance INTO v_fund_id, v_current_balance
        FROM public.maintenance_funds
        WHERE building_id IS NULL
        LIMIT 1
        FOR UPDATE;
        
        IF v_fund_id IS NOT NULL THEN
            UPDATE public.maintenance_funds SET building_id = p_building_id WHERE id = v_fund_id;
        ELSE
            INSERT INTO public.maintenance_funds (building_id, total_balance)
            VALUES (p_building_id, 0.00)
            RETURNING id, total_balance INTO v_fund_id, v_current_balance;
        END IF;
    END IF;

    -- 2. Tính số dư mới
    IF p_transaction_type = 'INCOME' THEN
        v_new_balance := v_current_balance + p_amount;
        v_prefix := 'PT-';
    ELSIF p_transaction_type = 'EXPENSE' THEN
        IF v_current_balance < p_amount THEN
            RAISE EXCEPTION 'Số dư quỹ bảo trì không đủ để chi (Số dư hiện tại: %, Cần chi: %)', v_current_balance, p_amount;
        END IF;
        v_new_balance := v_current_balance - p_amount;
        v_prefix := 'PC-';
    ELSE
        RAISE EXCEPTION 'Loại giao dịch không hợp lệ: %', p_transaction_type;
    END IF;

    -- 3. Sinh số chứng từ kế toán (PT-YYYYMM-XXXXX hoặc PC-YYYYMM-XXXXX)
    SELECT to_char(CURRENT_DATE, 'YYYYMM') INTO v_period;
    SELECT COALESCE(COUNT(*), 0) + 1 INTO v_seq
    FROM public.maintenance_fund_transactions
    WHERE voucher_number LIKE v_prefix || v_period || '-%';

    v_voucher_number := v_prefix || v_period || '-' || LPAD(v_seq::text, 5, '0');

    -- 4. Cập nhật số dư bảng chính
    UPDATE public.maintenance_funds
    SET total_balance = v_new_balance,
        updated_at = now()
    WHERE id = v_fund_id;

    -- 5. Ghi sổ giao dịch
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
        created_by,
        created_at
    ) VALUES (
        p_building_id,
        v_fund_id,
        v_voucher_number,
        p_transaction_type,
        p_category,
        p_amount,
        v_new_balance,
        p_reference_type,
        p_reference_id,
        p_recipient_or_payer,
        p_description,
        p_created_by,
        now()
    ) RETURNING id INTO v_tx_id;

    RETURN jsonb_build_object(
        'success', true,
        'transaction_id', v_tx_id,
        'voucher_number', v_voucher_number,
        'new_balance', v_new_balance
    );
END;
$$;
