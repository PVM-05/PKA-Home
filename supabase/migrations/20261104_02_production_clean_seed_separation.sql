-- ==============================================================================
-- Migration: 20261104_02_production_clean_seed_separation.sql
-- Mục tiêu: 
--   1. Gỡ bỏ giá trị mặc định hardcode demo khỏi bảng buildings và maintenance_funds.
--   2. Tạo RPC onboard_building_commercial_config thiết lập tài khoản ngân hàng thật
--      và số dư quỹ ban đầu có xác thực quyền quản trị và ghi vết audit_logs.
-- ==============================================================================

-- 1. GỠ BỎ DEFAULT HARDCODE DEMO TRÊN BẢNG BUILDINGS
ALTER TABLE public.buildings ALTER COLUMN bank_bin DROP DEFAULT;
ALTER TABLE public.buildings ALTER COLUMN bank_name DROP DEFAULT;
ALTER TABLE public.buildings ALTER COLUMN bank_account_number DROP DEFAULT;
ALTER TABLE public.buildings ALTER COLUMN bank_account_name DROP DEFAULT;

-- 2. GỠ BỎ DEFAULT HARDCODE DEMO TRÊN BẢNG MAINTENANCE_FUNDS
ALTER TABLE public.maintenance_funds ALTER COLUMN bank_name DROP DEFAULT;
ALTER TABLE public.maintenance_funds ALTER COLUMN bank_account_number DROP DEFAULT;
ALTER TABLE public.maintenance_funds ALTER COLUMN total_balance SET DEFAULT 0.00;

-- 3. BAN HÀNH RPC ONBOARDING CẤU HÌNH NGÂN HÀNG & QUỸ BẢO TRÌ CÓ KIỂM TOÁN
CREATE OR REPLACE FUNCTION public.onboard_building_commercial_config(
    p_building_id UUID,
    p_bank_bin VARCHAR(10),
    p_bank_name TEXT,
    p_bank_account_number TEXT,
    p_bank_account_name TEXT,
    p_initial_maintenance_balance NUMERIC(15,2) DEFAULT 0.00
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_user_id UUID;
    v_fund_id UUID;
    v_now TIMESTAMPTZ := now();
BEGIN
    -- 1. Xác thực người dùng
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Yêu cầu đăng nhập để cấu hình thông tin tòa nhà.';
    END IF;

    -- 2. Kiểm tra thẩm quyền quản trị tòa nhà (Admin, Manager, Head of Management)
    IF NOT public.has_building_role(p_building_id, ARRAY['admin', 'manager', 'head_of_management']) THEN
        RAISE EXCEPTION 'Bạn không có quyền quản trị để cấu hình thông tin thương mại tòa nhà này.';
    END IF;

    -- 3. Cập nhật thông tin tài khoản ngân hàng chính thức của tòa nhà
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

    -- 4. Khởi tạo / cập nhật số dư đầu kỳ Quỹ bảo trì
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

    -- 5. Ghi nhật ký kiểm toán bất biến (Audit Logs)
    INSERT INTO public.audit_logs (
        table_name,
        record_id,
        action,
        user_id,
        new_data,
        created_at
    ) VALUES (
        'buildings',
        p_building_id,
        'ONBOARD_COMMERCIAL_CONFIG',
        v_user_id,
        jsonb_build_object(
            'building_id', p_building_id,
            'bank_bin', p_bank_bin,
            'bank_name', p_bank_name,
            'bank_account_number', p_bank_account_number,
            'bank_account_name', p_bank_account_name,
            'initial_maintenance_balance', p_initial_maintenance_balance,
            'onboarded_at', v_now
        ),
        v_now
    );

    RETURN jsonb_build_object(
        'success', true,
        'building_id', p_building_id,
        'message', 'Cấu hình thông tin ngân hàng và quỹ bảo trì tòa nhà thành công.'
    );
END;
$$;

-- Cấp quyền thực thi cho authenticated
GRANT EXECUTE ON FUNCTION public.onboard_building_commercial_config(UUID, VARCHAR, TEXT, TEXT, TEXT, NUMERIC) TO authenticated;
