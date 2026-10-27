-- ==============================================================================
-- PKA-HOME: COMMERCIAL BANKING, VIETQR & RECEIPTS MIGRATION
-- Migration: 20261027_04_commercial_banking_and_receipts.sql
-- ==============================================================================

-- 1. Add banking configuration columns to buildings table
ALTER TABLE public.buildings
    ADD COLUMN IF NOT EXISTS bank_bin VARCHAR(10) DEFAULT '970418',
    ADD COLUMN IF NOT EXISTS bank_name TEXT DEFAULT 'Ngân hàng TMCP Đầu tư và Phát triển Việt Nam (BIDV)',
    ADD COLUMN IF NOT EXISTS bank_account_number TEXT DEFAULT '1234567890',
    ADD COLUMN IF NOT EXISTS bank_account_name TEXT DEFAULT 'BQL TOA NHA LANDMARK PKA';

-- Backfill default bank config for canonical building
UPDATE public.buildings
SET bank_bin = '970418',
    bank_name = 'Ngân hàng TMCP Đầu tư và Phát triển Việt Nam (BIDV)',
    bank_account_number = '1234567890',
    bank_account_name = 'BQL TOA NHA LANDMARK PKA'
WHERE id = '00000000-0000-0000-0000-000000000002';

-- 2. Add receipt, lookup code and paid amount columns to invoices and payment_transactions
ALTER TABLE public.invoices
    ADD COLUMN IF NOT EXISTS receipt_number VARCHAR(30),
    ADD COLUMN IF NOT EXISTS einvoice_lookup_code VARCHAR(32),
    ADD COLUMN IF NOT EXISTS paid_amount NUMERIC(12,2);

ALTER TABLE public.payment_transactions
    ADD COLUMN IF NOT EXISTS receipt_number VARCHAR(30),
    ADD COLUMN IF NOT EXISTS einvoice_lookup_code VARCHAR(32);

-- 3. Function to generate sequential receipt number PT-YYYYMM-XXXXX and lookup code
CREATE OR REPLACE FUNCTION public.generate_receipt_number(p_invoice_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_seq INT;
    v_period TEXT;
    v_receipt_number TEXT;
    v_lookup_code TEXT;
    v_total_amount NUMERIC(12,2);
BEGIN
    SELECT to_char(CURRENT_DATE, 'YYYYMM') INTO v_period;
    
    SELECT total_amount INTO v_total_amount
    FROM public.invoices
    WHERE id = p_invoice_id;

    -- Đếm số thứ tự phiếu thu trong tháng hiện tại
    SELECT COALESCE(COUNT(*), 0) + 1 INTO v_seq
    FROM public.invoices
    WHERE receipt_number LIKE 'PT-' || v_period || '-%';
    
    v_receipt_number := 'PT-' || v_period || '-' || LPAD(v_seq::text, 5, '0');
    v_lookup_code := UPPER(SUBSTRING(MD5(p_invoice_id::text || clock_timestamp()::text) FROM 1 FOR 8));
    
    UPDATE public.invoices
    SET receipt_number = v_receipt_number,
        einvoice_lookup_code = v_lookup_code,
        paid_amount = COALESCE(v_total_amount, 0)
    WHERE id = p_invoice_id AND receipt_number IS NULL;
    
    RETURN v_receipt_number;
END;
$$;
