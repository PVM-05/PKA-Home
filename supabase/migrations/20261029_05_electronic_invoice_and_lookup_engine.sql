-- ==============================================================================
-- PKA-HOME: PHASE C4 - ELECTRONIC INVOICE, PDF RECEIPT & LOOKUP VERIFICATION ENGINE
-- Migration: 20261029_05_electronic_invoice_and_lookup_engine.sql
-- ==============================================================================

-- 1. THÊM CỘT MÃ TRA CỨU BẢO MẬT VÀ TẠO CHỈ MỤC
ALTER TABLE public.invoices 
    ADD COLUMN IF NOT EXISTS lookup_code VARCHAR(32) UNIQUE;

CREATE INDEX IF NOT EXISTS idx_invoices_lookup_code 
    ON public.invoices(lookup_code);

-- 2. HÀM TỰ ĐỘNG SINH MÃ TRA CỨU HÓA ĐƠN & BIÊN LAI
CREATE OR REPLACE FUNCTION public.ensure_invoice_lookup_code()
RETURNS TRIGGER AS $$
DECLARE
    v_period TEXT;
    v_rand TEXT;
BEGIN
    IF NEW.lookup_code IS NULL OR trim(NEW.lookup_code) = '' THEN
        -- Chuẩn hóa kỳ hóa đơn (lấy 6 chữ số YYYYMM)
        v_period := regexp_replace(COALESCE(NEW.period, to_char(COALESCE(NEW.created_at, now()), 'YYYYMM')), '[^0-9]', '', 'g');
        IF length(v_period) < 6 THEN
            v_period := to_char(now(), 'YYYYMM');
        ELSE
            v_period := substr(v_period, 1, 6);
        END IF;

        -- Sinh hậu tố ngẫu nhiên 5 ký tự in hoa bảo mật
        v_rand := upper(substr(md5(gen_random_uuid()::text), 1, 5));

        NEW.lookup_code := 'INV-' || v_period || '-' || v_rand;
    ELSE
        -- Viết hoa và cắt tỉa khoảng trắng
        NEW.lookup_code := upper(trim(NEW.lookup_code));
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. TRIGGER TỰ ĐỘNG GÁN MÃ TRA CỨU TRƯỚC KHI TẠO HÓA ĐƠN
DROP TRIGGER IF EXISTS trg_ensure_invoice_lookup_code ON public.invoices;
CREATE TRIGGER trg_ensure_invoice_lookup_code
    BEFORE INSERT ON public.invoices
    FOR EACH ROW
    EXECUTE FUNCTION public.ensure_invoice_lookup_code();

-- 4. BACKFILL DỮ LIỆU MÃ TRA CỨU CHO TOÀN BỘ HÓA ĐƠN HIỆN HỮU
UPDATE public.invoices
SET lookup_code = 'INV-' || 
    CASE 
        WHEN length(regexp_replace(period, '[^0-9]', '', 'g')) >= 6 THEN substr(regexp_replace(period, '[^0-9]', '', 'g'), 1, 6)
        ELSE to_char(created_at, 'YYYYMM')
    END || '-' || upper(substr(md5(id::text || gen_random_uuid()::text), 1, 5))
WHERE lookup_code IS NULL OR trim(lookup_code) = '';

-- 5. RPC TRA CỨU ĐỐI SOÁT CHỨNG TỪ BẢO MẬT TRỰC TUYẾN (ONLINE LOOKUP VERIFICATION)
CREATE OR REPLACE FUNCTION public.verify_document_lookup(p_lookup_code TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_clean_code TEXT;
    v_rec RECORD;
    v_document_type TEXT;
    v_document_type_display TEXT;
    v_issuer TEXT;
BEGIN
    v_clean_code := upper(trim(COALESCE(p_lookup_code, '')));

    IF v_clean_code = '' THEN
        RETURN jsonb_build_object(
            'valid', false,
            'lookup_code', '',
            'message', 'Mã tra cứu không được để trống'
        );
    END IF;

    -- Tìm kiếm hóa đơn tương ứng với mã tra cứu
    SELECT 
        inv.id AS invoice_id,
        inv.lookup_code,
        inv.period,
        inv.due_date,
        inv.paid_at,
        inv.payment_method,
        inv.total_amount,
        inv.status,
        apt.code AS apartment_code,
        COALESCE(bld.name, 'Tòa nhà Landmark PKA') AS building_name,
        COALESCE(org.name, 'Công ty Quản lý Vận hành Bất động sản PKA') AS organization_name
    INTO v_rec
    FROM public.invoices inv
    JOIN public.apartments apt ON apt.id = inv.apartment_id
    LEFT JOIN public.buildings bld ON bld.id = apt.building_id
    LEFT JOIN public.organizations org ON org.id = bld.organization_id
    WHERE upper(trim(inv.lookup_code)) = v_clean_code
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'valid', false,
            'lookup_code', v_clean_code,
            'message', 'Không tìm thấy chứng từ với mã tra cứu tương ứng'
        );
    END IF;

    -- Xác định loại chứng từ (Hóa đơn dịch vụ hoặc Biên lai thu tiền điện tử khi đã thanh toán)
    IF v_rec.status = 'paid' THEN
        v_document_type := 'RECEIPT';
        v_document_type_display := 'Biên lai thu tiền điện tử';
    ELSE
        v_document_type := 'INVOICE';
        v_document_type_display := 'Hóa đơn dịch vụ chung cư';
    END IF;

    v_issuer := COALESCE(v_rec.building_name, v_rec.organization_name, 'Ban Quản Lý Tòa Nhà');

    RETURN jsonb_build_object(
        'valid', true,
        'lookup_code', v_rec.lookup_code,
        'document_type', v_document_type,
        'document_type_display', v_document_type_display,
        'invoice_id', v_rec.invoice_id,
        'period', v_rec.period,
        'due_date', v_rec.due_date,
        'paid_at', v_rec.paid_at,
        'payment_method', v_rec.payment_method,
        'total_amount', v_rec.total_amount,
        'status', v_rec.status,
        'apartment_code', v_rec.apartment_code,
        'building_name', v_rec.building_name,
        'organization_name', v_rec.organization_name,
        'issuer', v_issuer,
        'verified_at', now(),
        'message', 'Chứng từ hợp lệ và có nguồn gốc chính thức từ hệ thống PKA-Home'
    );
END;
$$;

-- Cấp quyền thực thi RPC cho người dùng vãng lai (tra cứu qua QR) và người dùng đăng nhập
GRANT EXECUTE ON FUNCTION public.verify_document_lookup(TEXT) TO anon, authenticated, service_role;
