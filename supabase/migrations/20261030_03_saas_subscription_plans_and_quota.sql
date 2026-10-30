-- ==============================================================================
-- PKA-HOME: SAAS SUBSCRIPTION PLANS & QUOTA MANAGEMENT MIGRATION
-- Migration: 20261030_03_saas_subscription_plans_and_quota.sql
-- ==============================================================================

-- 1. Bảng danh mục gói dịch vụ SaaS (subscription_plans)
CREATE TABLE IF NOT EXISTS public.subscription_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT NOT NULL UNIQUE, -- 'starter', 'pro', 'enterprise'
    name TEXT NOT NULL,        -- 'Gói Tiêu Chuẩn', 'Gói Nâng Cao', 'Gói Doanh Nghiệp'
    description TEXT,
    max_apartments INT NOT NULL DEFAULT 100, -- -1 nếu không giới hạn
    max_buildings INT NOT NULL DEFAULT 1,    -- -1 nếu không giới hạn
    max_staff INT NOT NULL DEFAULT 2,        -- -1 nếu không giới hạn
    price_monthly NUMERIC(12, 2) NOT NULL DEFAULT 0,
    price_yearly NUMERIC(12, 2) NOT NULL DEFAULT 0,
    features JSONB NOT NULL DEFAULT '{}'::jsonb,
    is_active BOOLEAN NOT NULL DEFAULT true,
    sort_order INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.subscription_plans ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "subscription_plans_read_all" ON public.subscription_plans;
CREATE POLICY "subscription_plans_read_all" ON public.subscription_plans
    FOR SELECT TO authenticated USING (true);

-- 2. Bảng đăng ký thuê bao của tổ chức (organization_subscriptions)
CREATE TABLE IF NOT EXISTS public.organization_subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    plan_id UUID NOT NULL REFERENCES public.subscription_plans(id) ON DELETE RESTRICT,
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'trialing', 'past_due', 'cancelled', 'expired')),
    start_date TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ,
    billing_cycle TEXT NOT NULL DEFAULT 'monthly' CHECK (billing_cycle IN ('monthly', 'yearly', 'custom')),
    auto_renew BOOLEAN NOT NULL DEFAULT true,
    custom_max_apartments INT, -- Hạn mức thỏa thuận riêng nếu có
    custom_max_buildings INT,
    custom_max_staff INT,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(organization_id)
);

ALTER TABLE public.organization_subscriptions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "org_subscriptions_read_authenticated" ON public.organization_subscriptions;
CREATE POLICY "org_subscriptions_read_authenticated" ON public.organization_subscriptions
    FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "org_subscriptions_admin_update" ON public.organization_subscriptions;
CREATE POLICY "org_subscriptions_admin_update" ON public.organization_subscriptions
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.users
            WHERE users.id = auth.uid()
            AND (users.role IN ('admin', 'management'))
        )
    );

-- 3. Khởi tạo (Seed) 3 gói cước tiêu chuẩn thị trường Việt Nam
INSERT INTO public.subscription_plans (
    code, name, description, max_apartments, max_buildings, max_staff, price_monthly, price_yearly, features, sort_order
) VALUES
(
    'starter',
    'Gói Tiêu Chuẩn',
    'Phù hợp tòa nhà chung cư mini, khu nhà trọ hoặc tòa nhà đơn lẻ dưới 100 căn hộ',
    100,
    1,
    2,
    499000,
    4990000,
    '{"batch_excel_import": true, "basic_invoicing": true, "issue_management": true, "vietqr_payment": true, "push_notifications": true}'::jsonb,
    1
),
(
    'pro',
    'Gói Nâng Cao',
    'Lựa chọn tối ưu cho chung cư vừa và lớn (100 - 500 căn), mở khóa phân tích tài chính và đối soát tự động',
    500,
    5,
    10,
    1499000,
    14990000,
    '{"batch_excel_import": true, "basic_invoicing": true, "issue_management": true, "vietqr_payment": true, "push_notifications": true, "financial_aging_report": true, "progressive_fees": true, "vietqr_automated_webhook": true, "audit_trail": true, "equipment_management": true}'::jsonb,
    2
),
(
    'enterprise',
    'Gói Doanh Nghiệp',
    'Giải pháp toàn diện cho chuỗi bất động sản, khu đô thị lớn với hạn mức không giới hạn và hóa đơn điện tử',
    -1,
    -1,
    -1,
    3999000,
    39990000,
    '{"all_features": true, "unlimited_units": true, "electronic_invoices": true, "dedicated_support_24_7": true, "api_integration": true, "custom_domain": true}'::jsonb,
    3
)
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    max_apartments = EXCLUDED.max_apartments,
    max_buildings = EXCLUDED.max_buildings,
    max_staff = EXCLUDED.max_staff,
    price_monthly = EXCLUDED.price_monthly,
    price_yearly = EXCLUDED.price_yearly,
    features = EXCLUDED.features,
    sort_order = EXCLUDED.sort_order;

-- 4. Tự động cấp gói 'pro' dùng thử 1 năm cho các tổ chức hiện có (bảo toàn hệ thống đang chạy)
INSERT INTO public.organization_subscriptions (organization_id, plan_id, status, start_date, expires_at, billing_cycle)
SELECT 
    org.id,
    p.id,
    'active',
    now(),
    now() + INTERVAL '1 year',
    'yearly'
FROM public.organizations org
CROSS JOIN LATERAL (
    SELECT id FROM public.subscription_plans WHERE code = 'pro' LIMIT 1
) p
ON CONFLICT (organization_id) DO NOTHING;

-- 5. Trigger kiểm soát trần hạn mức căn hộ khi thêm căn hộ mới
CREATE OR REPLACE FUNCTION public.enforce_apartment_quota()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_org_id UUID;
    v_max_apartments INT;
    v_current_count INT;
    v_plan_name TEXT;
BEGIN
    -- Lấy organization_id của tòa nhà
    SELECT b.organization_id INTO v_org_id
    FROM public.buildings b
    WHERE b.id = NEW.building_id;

    -- Nếu không có tổ chức (mô hình cũ hoặc test lẻ), cho phép tiếp tục
    IF v_org_id IS NULL THEN
        RETURN NEW;
    END IF;

    -- Lấy hạn mức tối đa của tổ chức
    SELECT 
        COALESCE(sub.custom_max_apartments, plan.max_apartments, 500),
        plan.name
    INTO 
        v_max_apartments,
        v_plan_name
    FROM public.organization_subscriptions sub
    JOIN public.subscription_plans plan ON sub.plan_id = plan.id
    WHERE sub.organization_id = v_org_id
    AND sub.status IN ('active', 'trialing');

    -- Nếu không tìm thấy subscription hoặc gói không giới hạn (-1), cho phép tiếp tục
    IF v_max_apartments IS NULL OR v_max_apartments < 0 THEN
        RETURN NEW;
    END IF;

    -- Đếm tổng số căn hộ hiện có trong toàn bộ tổ chức
    SELECT count(a.id) INTO v_current_count
    FROM public.apartments a
    JOIN public.buildings b ON a.building_id = b.id
    WHERE b.organization_id = v_org_id;

    -- Nếu đã đạt hoặc vượt quá hạn mức, ném lỗi tiếng Việt rõ ràng
    IF v_current_count >= v_max_apartments THEN
        RAISE EXCEPTION 'Tổ chức đã đạt giới hạn tối đa % căn hộ của % (hiện có % căn). Vui lòng nâng cấp gói cước để tiếp tục thêm căn hộ mới.',
            v_max_apartments, COALESCE(v_plan_name, 'Gói dịch vụ'), v_current_count;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_apartment_quota ON public.apartments;
CREATE TRIGGER trg_enforce_apartment_quota
    BEFORE INSERT ON public.apartments
    FOR EACH ROW
    EXECUTE FUNCTION public.enforce_apartment_quota();

-- 6. RPC: Lấy thông tin trạng thái thuê bao & mức độ sử dụng hạn mức của tòa nhà
CREATE OR REPLACE FUNCTION public.get_organization_subscription_status(
    p_building_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_org_id UUID;
    v_plan RECORD;
    v_sub RECORD;
    v_used_apartments INT := 0;
    v_max_apartments INT := 100;
    v_used_buildings INT := 0;
    v_max_buildings INT := 1;
    v_used_staff INT := 0;
    v_max_staff INT := 2;
    v_days_remaining INT := 0;
    v_apt_percent NUMERIC(5, 2) := 0;
BEGIN
    -- 1. Tìm organization_id từ p_building_id
    SELECT b.organization_id INTO v_org_id
    FROM public.buildings b
    WHERE b.id = p_building_id;

    -- Fallback nếu không có tòa nhà: lấy organization đầu tiên
    IF v_org_id IS NULL THEN
        SELECT id INTO v_org_id FROM public.organizations ORDER BY created_at ASC LIMIT 1;
    END IF;

    -- 2. Lấy thông tin subscription
    SELECT 
        sub.*,
        p.code AS plan_code,
        p.name AS plan_name,
        p.description AS plan_description,
        p.max_apartments AS plan_max_apartments,
        p.max_buildings AS plan_max_buildings,
        p.max_staff AS plan_max_staff,
        p.price_monthly,
        p.price_yearly,
        p.features
    INTO v_sub
    FROM public.organization_subscriptions sub
    JOIN public.subscription_plans p ON sub.plan_id = p.id
    WHERE sub.organization_id = v_org_id;

    -- Nếu chưa có subscription, fallback sang gói 'pro' mặc định
    IF v_sub.id IS NULL THEN
        SELECT 
            gen_random_uuid() AS id,
            v_org_id AS organization_id,
            p.id AS plan_id,
            'active' AS status,
            now() AS start_date,
            now() + INTERVAL '1 year' AS expires_at,
            'monthly' AS billing_cycle,
            true AS auto_renew,
            NULL::INT AS custom_max_apartments,
            NULL::INT AS custom_max_buildings,
            NULL::INT AS custom_max_staff,
            p.code AS plan_code,
            p.name AS plan_name,
            p.description AS plan_description,
            p.max_apartments AS plan_max_apartments,
            p.max_buildings AS plan_max_buildings,
            p.max_staff AS plan_max_staff,
            p.price_monthly,
            p.price_yearly,
            p.features
        INTO v_sub
        FROM public.subscription_plans p
        WHERE p.code = 'pro'
        LIMIT 1;
    END IF;

    -- 3. Xác định hạn mức
    v_max_apartments := COALESCE(v_sub.custom_max_apartments, v_sub.plan_max_apartments, 500);
    v_max_buildings := COALESCE(v_sub.custom_max_buildings, v_sub.plan_max_buildings, 5);
    v_max_staff := COALESCE(v_sub.custom_max_staff, v_sub.plan_max_staff, 10);

    -- 4. Đo lường mức độ sử dụng thực tế
    IF v_org_id IS NOT NULL THEN
        SELECT count(a.id) INTO v_used_apartments
        FROM public.apartments a
        JOIN public.buildings b ON a.building_id = b.id
        WHERE b.organization_id = v_org_id;

        SELECT count(id) INTO v_used_buildings
        FROM public.buildings
        WHERE organization_id = v_org_id;

        SELECT count(DISTINCT user_id) INTO v_used_staff
        FROM public.building_staff bs
        JOIN public.buildings b ON bs.building_id = b.id
        WHERE b.organization_id = v_org_id;
    ELSE
        SELECT count(*) INTO v_used_apartments FROM public.apartments;
        SELECT count(*) INTO v_used_buildings FROM public.buildings;
        SELECT count(*) INTO v_used_staff FROM public.building_staff;
    END IF;

    -- 5. Tính số ngày còn lại
    IF v_sub.expires_at IS NOT NULL THEN
        v_days_remaining := GREATEST(0, EXTRACT(DAY FROM (v_sub.expires_at - now()))::INT);
    ELSE
        v_days_remaining := 365;
    END IF;

    -- 6. Tính % sử dụng căn hộ
    IF v_max_apartments > 0 THEN
        v_apt_percent := ROUND((v_used_apartments::NUMERIC / v_max_apartments::NUMERIC) * 100, 1);
    ELSE
        v_apt_percent := 0;
    END IF;

    RETURN jsonb_build_object(
        'organization_id', v_org_id,
        'subscription_id', v_sub.id,
        'plan_code', COALESCE(v_sub.plan_code, 'pro'),
        'plan_name', COALESCE(v_sub.plan_name, 'Gói Nâng Cao'),
        'plan_description', v_sub.plan_description,
        'status', COALESCE(v_sub.status, 'active'),
        'start_date', v_sub.start_date,
        'expires_at', v_sub.expires_at,
        'days_remaining', v_days_remaining,
        'is_expiring_soon', (v_days_remaining <= 15),
        'billing_cycle', COALESCE(v_sub.billing_cycle, 'monthly'),
        'auto_renew', COALESCE(v_sub.auto_renew, true),
        'price_monthly', v_sub.price_monthly,
        'price_yearly', v_sub.price_yearly,
        'features', COALESCE(v_sub.features, '{}'::jsonb),
        'usage', jsonb_build_object(
            'used_apartments', v_used_apartments,
            'max_apartments', v_max_apartments,
            'apartment_usage_percent', v_apt_percent,
            'is_near_limit', (v_apt_percent >= 80.0 AND v_max_apartments > 0),
            'is_at_limit', (v_used_apartments >= v_max_apartments AND v_max_apartments > 0),
            'used_buildings', v_used_buildings,
            'max_buildings', v_max_buildings,
            'used_staff', v_used_staff,
            'max_staff', v_max_staff
        )
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_organization_subscription_status(UUID) TO authenticated;

