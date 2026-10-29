-- ==============================================================================
-- PKA-HOME: PHASE C1 - APARTMENT LEDGER, CREDIT NOTES & INVOICE IMMUTABILITY
-- Migration: 20261029_03_apartment_ledger_and_credit_notes.sql
-- ==============================================================================

-- 1. BẢNG KỲ KẾ TOÁN (ACCOUNTING PERIODS)
CREATE TABLE IF NOT EXISTS public.accounting_periods (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    building_id UUID NOT NULL REFERENCES public.buildings(id) ON DELETE CASCADE,
    period VARCHAR(7) NOT NULL, -- Định dạng YYYY-MM
    status VARCHAR(20) NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN', 'CLOSED')),
    opened_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    closed_at TIMESTAMPTZ,
    closed_by UUID REFERENCES public.users(id),
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_building_period UNIQUE(building_id, period)
);

CREATE INDEX IF NOT EXISTS idx_ap_building_period ON public.accounting_periods(building_id, period);

ALTER TABLE public.accounting_periods ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "ap_read_policy" ON public.accounting_periods;
CREATE POLICY "ap_read_policy" ON public.accounting_periods
    FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "ap_manage_policy" ON public.accounting_periods;
CREATE POLICY "ap_manage_policy" ON public.accounting_periods
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.users u
            WHERE u.id = auth.uid()
            AND u.role IN ('admin', 'manager', 'accountant')
        )
    );

-- 2. BẢNG SỔ CÁI CÔNG NỢ CĂN HỘ (APARTMENT LEDGER ENTRIES) - APPEND-ONLY
CREATE TABLE IF NOT EXISTS public.apartment_ledger_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    building_id UUID NOT NULL REFERENCES public.buildings(id) ON DELETE CASCADE,
    apartment_id UUID NOT NULL REFERENCES public.apartments(id) ON DELETE CASCADE,
    entry_code VARCHAR(30) UNIQUE NOT NULL, -- LE-YYYYMM-XXXXX
    entry_type VARCHAR(20) NOT NULL CHECK (entry_type IN ('DEBIT', 'CREDIT', 'CREDIT_NOTE', 'DEBIT_NOTE', 'REFUND')),
    amount NUMERIC(15,2) NOT NULL CHECK (amount > 0),
    balance_after NUMERIC(15,2) NOT NULL, -- Số dư nợ lũy kế: > 0 còn nợ, = 0 hết nợ, < 0 nộp thừa
    period VARCHAR(7) NOT NULL, -- YYYY-MM
    reference_type VARCHAR(30) NOT NULL CHECK (reference_type IN ('INVOICE', 'PAYMENT', 'CREDIT_NOTE', 'REFUND', 'MANUAL')),
    reference_id UUID,
    description TEXT NOT NULL,
    created_by UUID REFERENCES public.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ale_apartment_created ON public.apartment_ledger_entries(apartment_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ale_building_period ON public.apartment_ledger_entries(building_id, period);
CREATE INDEX IF NOT EXISTS idx_ale_entry_code ON public.apartment_ledger_entries(entry_code);

ALTER TABLE public.apartment_ledger_entries ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "ale_read_policy" ON public.apartment_ledger_entries;
CREATE POLICY "ale_read_policy" ON public.apartment_ledger_entries
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.users u
            WHERE u.id = auth.uid() AND u.role IN ('admin', 'manager', 'accountant')
        )
        OR
        EXISTS (
            SELECT 1 FROM public.residents_apartments ra
            WHERE ra.user_id = auth.uid()
            AND ra.apartment_id = apartment_ledger_entries.apartment_id
        )
    );

DROP POLICY IF EXISTS "ale_insert_policy" ON public.apartment_ledger_entries;
CREATE POLICY "ale_insert_policy" ON public.apartment_ledger_entries
    FOR INSERT TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.users u
            WHERE u.id = auth.uid() AND u.role IN ('admin', 'manager', 'accountant')
        )
    );

-- 3. BẢNG PHIẾU ĐIỀU CHỈNH CÔNG NỢ (CREDIT NOTES / DEBIT NOTES)
CREATE TABLE IF NOT EXISTS public.credit_notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    credit_note_code VARCHAR(30) UNIQUE NOT NULL, -- CN-YYYYMM-XXXXX
    building_id UUID NOT NULL REFERENCES public.buildings(id) ON DELETE CASCADE,
    apartment_id UUID NOT NULL REFERENCES public.apartments(id) ON DELETE CASCADE,
    invoice_id UUID REFERENCES public.invoices(id) ON DELETE SET NULL,
    note_type VARCHAR(20) NOT NULL DEFAULT 'CREDIT' CHECK (note_type IN ('CREDIT', 'DEBIT')),
    amount NUMERIC(15,2) NOT NULL CHECK (amount > 0),
    reason TEXT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'APPROVED' CHECK (status IN ('DRAFT', 'APPROVED', 'REJECTED')),
    approved_by UUID REFERENCES public.users(id),
    approved_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cn_apartment ON public.credit_notes(apartment_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_cn_invoice ON public.credit_notes(invoice_id);
CREATE INDEX IF NOT EXISTS idx_cn_code ON public.credit_notes(credit_note_code);

ALTER TABLE public.credit_notes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "cn_read_policy" ON public.credit_notes;
CREATE POLICY "cn_read_policy" ON public.credit_notes
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.users u
            WHERE u.id = auth.uid() AND u.role IN ('admin', 'manager', 'accountant')
        )
        OR
        EXISTS (
            SELECT 1 FROM public.residents_apartments ra
            WHERE ra.user_id = auth.uid()
            AND ra.apartment_id = credit_notes.apartment_id
        )
    );

DROP POLICY IF EXISTS "cn_manage_policy" ON public.credit_notes;
CREATE POLICY "cn_manage_policy" ON public.credit_notes
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.users u
            WHERE u.id = auth.uid() AND u.role IN ('admin', 'manager', 'accountant')
        )
    );

-- 4. TRIGGERS BẢO VỆ TÍNH TOÀN VẸN & BẤT BIẾN

-- 4.1 Trigger bảo vệ hóa đơn bất biến khi đã thanh toán hoặc kỳ đã chốt
CREATE OR REPLACE FUNCTION public.fn_enforce_invoice_immutability()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_building_id UUID;
    v_is_period_closed BOOLEAN := false;
BEGIN
    -- Tìm building_id của căn hộ
    SELECT building_id INTO v_building_id
    FROM public.apartments
    WHERE id = OLD.apartment_id;

    -- Kiểm tra kỳ kế toán có bị đóng không
    IF v_building_id IS NOT NULL THEN
        SELECT (status = 'CLOSED') INTO v_is_period_closed
        FROM public.accounting_periods
        WHERE building_id = v_building_id
          AND period = OLD.period;
    END IF;

    -- Nếu kỳ kế toán đã đóng
    IF v_is_period_closed IS TRUE THEN
        IF TG_OP = 'DELETE' THEN
            RAISE EXCEPTION 'Kỳ kế toán % đã đóng. Không thể xóa hóa đơn thuộc kỳ đã đóng.', OLD.period;
        END IF;
        IF TG_OP = 'UPDATE' THEN
            IF NEW.total_amount != OLD.total_amount OR NEW.apartment_id != OLD.apartment_id OR NEW.period != OLD.period THEN
                RAISE EXCEPTION 'Kỳ kế toán % đã đóng. Không thể sửa đổi số liệu hóa đơn thuộc kỳ đã đóng.', OLD.period;
            END IF;
        END IF;
    END IF;

    -- Nếu hóa đơn đã ở trạng thái paid hoặc pending_confirmation
    IF OLD.status IN ('paid', 'pending_confirmation') THEN
        IF TG_OP = 'DELETE' THEN
            RAISE EXCEPTION 'Không thể xóa hóa đơn đã thanh toán hoặc đang chờ xác nhận gạch nợ.';
        END IF;
        IF TG_OP = 'UPDATE' THEN
            IF NEW.total_amount != OLD.total_amount OR NEW.apartment_id != OLD.apartment_id OR NEW.period != OLD.period THEN
                RAISE EXCEPTION 'Hóa đơn đã chốt/thanh toán là bất biến. Vui lòng lập Phiếu điều chỉnh (Credit Note) nếu cần thay đổi số tiền.';
            END IF;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_invoice_immutability ON public.invoices;
CREATE TRIGGER trg_enforce_invoice_immutability
    BEFORE UPDATE OR DELETE ON public.invoices
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_enforce_invoice_immutability();

-- 4.2 Trigger ngăn chèn/sửa/xóa sổ cái trên kỳ kế toán đã đóng
CREATE OR REPLACE FUNCTION public.fn_prevent_closed_period_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_period VARCHAR(7);
    v_building_id UUID;
    v_is_closed BOOLEAN := false;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_period := OLD.period;
        v_building_id := OLD.building_id;
    ELSE
        v_period := NEW.period;
        v_building_id := NEW.building_id;
    END IF;

    SELECT (status = 'CLOSED') INTO v_is_closed
    FROM public.accounting_periods
    WHERE building_id = v_building_id AND period = v_period;

    IF v_is_closed IS TRUE THEN
        RAISE EXCEPTION 'Kỳ kế toán % đã đóng. Không thể thay đổi dữ liệu sổ cái thuộc kỳ đã đóng.', v_period;
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_prevent_closed_period_mutation ON public.apartment_ledger_entries;
CREATE TRIGGER trg_prevent_closed_period_mutation
    BEFORE INSERT OR UPDATE OR DELETE ON public.apartment_ledger_entries
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_prevent_closed_period_mutation();

-- 4.3 Trigger tự động hạch toán CREDIT vào sổ cái khi hóa đơn chuyển paid
CREATE OR REPLACE FUNCTION public.fn_auto_post_ledger_on_invoice_paid()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_building_id UUID;
    v_exists BOOLEAN;
BEGIN
    IF NEW.status = 'paid' AND OLD.status != 'paid' THEN
        SELECT building_id INTO v_building_id
        FROM public.apartments
        WHERE id = NEW.apartment_id;

        IF v_building_id IS NOT NULL THEN
            -- Kiểm tra xem đã có bút toán cho hóa đơn này chưa
            SELECT EXISTS(
                SELECT 1 FROM public.apartment_ledger_entries
                WHERE apartment_id = NEW.apartment_id
                  AND reference_type = 'PAYMENT'
                  AND reference_id = NEW.id
            ) INTO v_exists;

            IF NOT v_exists THEN
                PERFORM public.record_apartment_ledger_entry(
                    p_building_id := v_building_id,
                    p_apartment_id := NEW.apartment_id,
                    p_entry_type := 'CREDIT',
                    p_amount := NEW.total_amount,
                    p_period := NEW.period,
                    p_reference_type := 'PAYMENT',
                    p_reference_id := NEW.id,
                    p_description := 'Thanh toán hóa đơn kỳ ' || NEW.period,
                    p_created_by := NULL
                );
            END IF;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_auto_post_ledger_on_invoice_paid ON public.invoices;
CREATE TRIGGER trg_auto_post_ledger_on_invoice_paid
    AFTER UPDATE ON public.invoices
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_auto_post_ledger_on_invoice_paid();

-- 5. REMOTE PROCEDURE CALLS (RPCs)

-- 5.1 Ghi nhận bút toán sổ cái công nợ an toàn (ACID Safe với FOR UPDATE)
CREATE OR REPLACE FUNCTION public.record_apartment_ledger_entry(
    p_building_id UUID,
    p_apartment_id UUID,
    p_entry_type VARCHAR(20),
    p_amount NUMERIC(15,2),
    p_period VARCHAR(7),
    p_reference_type VARCHAR(30),
    p_reference_id UUID DEFAULT NULL,
    p_description TEXT DEFAULT '',
    p_created_by UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_current_balance NUMERIC(15,2) := 0.00;
    v_new_balance NUMERIC(15,2);
    v_entry_code TEXT;
    v_seq INT;
    v_entry_id UUID;
BEGIN
    IF p_amount <= 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Số tiền bút toán phải lớn hơn 0');
    END IF;

    -- Khóa hàng căn hộ để chống Race Condition khi có đồng thời nhiều thanh toán
    PERFORM id FROM public.apartments WHERE id = p_apartment_id FOR UPDATE;

    -- Lấy số dư nợ mới nhất của căn hộ
    SELECT balance_after INTO v_current_balance
    FROM public.apartment_ledger_entries
    WHERE apartment_id = p_apartment_id
    ORDER BY created_at DESC, id DESC
    LIMIT 1;

    IF v_current_balance IS NULL THEN
        v_current_balance := 0.00;
    END IF;

    -- Tính số dư nợ sau bút toán
    IF p_entry_type IN ('DEBIT', 'DEBIT_NOTE', 'REFUND') THEN
        v_new_balance := v_current_balance + p_amount;
    ELSIF p_entry_type IN ('CREDIT', 'CREDIT_NOTE') THEN
        v_new_balance := v_current_balance - p_amount;
    ELSE
        RETURN jsonb_build_object('success', false, 'error', 'Loại bút toán không hợp lệ: ' || p_entry_type);
    END IF;

    -- Sinh mã bút toán dạng LE-YYYYMM-XXXXX
    SELECT COALESCE(MAX(SUBSTRING(entry_code FROM 11)::INT), 0) + 1 INTO v_seq
    FROM public.apartment_ledger_entries
    WHERE entry_code LIKE 'LE-' || REPLACE(p_period, '-', '') || '-%';

    v_entry_code := 'LE-' || REPLACE(p_period, '-', '') || '-' || LPAD(v_seq::TEXT, 5, '0');

    -- Chèn bản ghi sổ cái
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
        p_created_by,
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
$$;

-- 5.2 Lập phiếu điều chỉnh công nợ (Credit Note / Debit Note)
CREATE OR REPLACE FUNCTION public.issue_credit_note(
    p_building_id UUID,
    p_apartment_id UUID,
    p_invoice_id UUID DEFAULT NULL,
    p_note_type VARCHAR(20) DEFAULT 'CREDIT',
    p_amount NUMERIC(15,2) DEFAULT 0.00,
    p_reason TEXT DEFAULT '',
    p_approved_by UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_credit_note_id UUID;
    v_credit_note_code TEXT;
    v_seq INT;
    v_period TEXT;
    v_ledger_result JSONB;
    v_entry_type TEXT;
BEGIN
    IF p_amount <= 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Số tiền điều chỉnh phải lớn hơn 0');
    END IF;

    -- Lấy kỳ hiện tại YYYY-MM
    v_period := TO_CHAR(now(), 'YYYY-MM');

    -- Sinh mã phiếu dạng CN-YYYYMM-XXXXX
    SELECT COALESCE(MAX(SUBSTRING(credit_note_code FROM 11)::INT), 0) + 1 INTO v_seq
    FROM public.credit_notes
    WHERE credit_note_code LIKE 'CN-' || REPLACE(v_period, '-', '') || '-%';

    v_credit_note_code := 'CN-' || REPLACE(v_period, '-', '') || '-' || LPAD(v_seq::TEXT, 5, '0');

    -- Tạo phiếu điều chỉnh
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
        p_approved_by,
        now(),
        now()
    )
    RETURNING id INTO v_credit_note_id;

    -- Xác định loại bút toán sổ cái
    IF p_note_type = 'CREDIT' THEN
        v_entry_type := 'CREDIT_NOTE';
    ELSE
        v_entry_type := 'DEBIT_NOTE';
    END IF;

    -- Ghi bút toán sổ cái công nợ
    v_ledger_result := public.record_apartment_ledger_entry(
        p_building_id := p_building_id,
        p_apartment_id := p_apartment_id,
        p_entry_type := v_entry_type,
        p_amount := p_amount,
        p_period := v_period,
        p_reference_type := 'CREDIT_NOTE',
        p_reference_id := v_credit_note_id,
        p_description := 'Phiếu điều chỉnh ' || v_credit_note_code || ': ' || p_reason,
        p_created_by := p_approved_by
    );

    RETURN jsonb_build_object(
        'success', true,
        'credit_note_id', v_credit_note_id,
        'credit_note_code', v_credit_note_code,
        'balance_after', v_ledger_result->>'balance_after'
    );
END;
$$;

-- 5.3 Chốt kỳ kế toán tòa nhà (Khóa sổ)
CREATE OR REPLACE FUNCTION public.close_accounting_period(
    p_building_id UUID,
    p_period VARCHAR(7),
    p_closed_by UUID DEFAULT NULL,
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_period_id UUID;
    v_status TEXT;
BEGIN
    SELECT id, status INTO v_period_id, v_status
    FROM public.accounting_periods
    WHERE building_id = p_building_id AND period = p_period;

    IF v_period_id IS NOT NULL THEN
        IF v_status = 'CLOSED' THEN
            RETURN jsonb_build_object('success', false, 'error', 'Kỳ kế toán ' || p_period || ' đã được khóa sổ trước đó.');
        END IF;

        UPDATE public.accounting_periods
        SET status = 'CLOSED',
            closed_at = now(),
            closed_by = p_closed_by,
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
            p_closed_by,
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
$$;

-- 5.4 Lấy số dư nợ hiện tại của căn hộ
CREATE OR REPLACE FUNCTION public.get_apartment_ledger_balance(
    p_apartment_id UUID
)
RETURNS NUMERIC(15,2)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_balance NUMERIC(15,2);
BEGIN
    SELECT balance_after INTO v_balance
    FROM public.apartment_ledger_entries
    WHERE apartment_id = p_apartment_id
    ORDER BY created_at DESC, id DESC
    LIMIT 1;

    RETURN COALESCE(v_balance, 0.00);
END;
$$;
