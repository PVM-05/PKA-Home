-- ==============================================================================
-- Migration: 20261029_01_audit_logs_and_role_delegations.sql
-- Description: Triển khai bảng role_delegations có thời hạn, nâng cấp audit_logs
--              bất biến (Append-Only) và kích hoạt Triggers ghi nhật ký kiểm toán.
-- ==============================================================================

-- 1. BẢNG ỦY QUYỀN VAI TRÒ CÓ THỜI HẠN (ROLE DELEGATIONS)
CREATE TABLE IF NOT EXISTS public.role_delegations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    building_id UUID REFERENCES public.buildings(id) ON DELETE CASCADE,
    delegator_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    delegate_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    delegated_role VARCHAR(30) NOT NULL, -- 'accountant', 'technician', 'management'
    starts_at TIMESTAMPTZ NOT NULL,
    ends_at TIMESTAMPTZ NOT NULL,
    note TEXT,
    is_revoked BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_delegation_dates CHECK (ends_at > starts_at)
);

CREATE INDEX IF NOT EXISTS idx_role_delegations_delegate ON public.role_delegations(delegate_id, is_revoked, starts_at, ends_at);
CREATE INDEX IF NOT EXISTS idx_role_delegations_delegator ON public.role_delegations(delegator_id);
CREATE INDEX IF NOT EXISTS idx_role_delegations_building ON public.role_delegations(building_id);

ALTER TABLE public.role_delegations ENABLE ROW LEVEL SECURITY;

-- RLS: Đọc thông tin ủy quyền nếu là người ủy quyền, người được nhận hoặc BQL/Admin
CREATE POLICY "role_delegations_read" ON public.role_delegations
    FOR SELECT TO authenticated
    USING (
        delegator_id = auth.uid() OR
        delegate_id = auth.uid() OR
        public.is_staff_or_management()
    );

-- RLS: Quản trị viên và BQL có quyền thêm/sửa/thu hồi ủy quyền
CREATE POLICY "role_delegations_manage" ON public.role_delegations
    FOR ALL TO authenticated
    USING (public.is_staff_or_management())
    WITH CHECK (public.is_staff_or_management());


-- 2. NÂNG CẤP BẢNG NHẬT KÝ KIỂM TOÁN (AUDIT LOGS) BẤT BIẾN (APPEND-ONLY)
ALTER TABLE public.audit_logs
    ADD COLUMN IF NOT EXISTS building_id UUID REFERENCES public.buildings(id) ON DELETE CASCADE,
    ADD COLUMN IF NOT EXISTS entity_name VARCHAR(50),
    ADD COLUMN IF NOT EXISTS entity_id UUID,
    ADD COLUMN IF NOT EXISTS old_values JSONB DEFAULT '{}'::jsonb,
    ADD COLUMN IF NOT EXISTS new_values JSONB DEFAULT '{}'::jsonb;

CREATE INDEX IF NOT EXISTS idx_audit_logs_building ON public.audit_logs(building_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_entity ON public.audit_logs(entity_name, entity_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_actor ON public.audit_logs(actor_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created ON public.audit_logs(created_at DESC);

ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- RLS: Chỉ BQL và Quản trị viên mới được đọc nhật ký kiểm toán
CREATE POLICY "audit_logs_read" ON public.audit_logs
    FOR SELECT TO authenticated
    USING (public.is_staff_or_management());

-- RLS: Cho phép hệ thống và người dùng authenticated thêm bản ghi nhật ký
CREATE POLICY "audit_logs_insert" ON public.audit_logs
    FOR INSERT TO authenticated
    WITH CHECK (true);

-- LƯU Ý BẢO MẬT PHÁP LÝ: Tuyệt đối KHÔNG TẠO policy UPDATE hoặc DELETE trên bảng audit_logs
-- để đảm bảo tính bất biến (Append-Only Immutability) phục vụ kiểm toán tài chính và pháp lý.


-- 3. TRIGGERS TỰ ĐỘNG GHI NHẬT KÝ KIỂM TOÁN (AUTOMATIC AUDIT TRIGGERS)

-- 3.1. Audit Trigger cho Hóa đơn (Invoices)
CREATE OR REPLACE FUNCTION public.fn_audit_invoice_changes()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_action TEXT;
    v_actor_id UUID;
BEGIN
    v_actor_id := auth.uid();
    
    IF TG_OP = 'INSERT' THEN
        v_action := 'CREATE_INVOICE';
        INSERT INTO public.audit_logs (
            building_id, actor_id, action, entity_name, entity_id, new_values
        ) VALUES (
            NEW.building_id,
            COALESCE(v_actor_id, NEW.confirmed_by),
            v_action,
            'invoices',
            NEW.id,
            jsonb_build_object('period', NEW.period, 'total_amount', NEW.total_amount, 'status', NEW.status)
        );
    ELSIF TG_OP = 'UPDATE' AND (OLD.status IS DISTINCT FROM NEW.status OR OLD.total_amount IS DISTINCT FROM NEW.total_amount) THEN
        v_action := 'UPDATE_INVOICE_STATUS';
        IF NEW.status = 'paid' THEN
            v_action := 'CONFIRM_PAYMENT';
        END IF;

        INSERT INTO public.audit_logs (
            building_id, actor_id, action, entity_name, entity_id, old_values, new_values
        ) VALUES (
            NEW.building_id,
            COALESCE(v_actor_id, NEW.confirmed_by),
            v_action,
            'invoices',
            NEW.id,
            jsonb_build_object('status', OLD.status, 'total_amount', OLD.total_amount),
            jsonb_build_object('status', NEW.status, 'total_amount', NEW.total_amount, 'payment_method', NEW.payment_method)
        );
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_audit_invoice_changes ON public.invoices;
CREATE TRIGGER trg_audit_invoice_changes
    AFTER INSERT OR UPDATE ON public.invoices
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_audit_invoice_changes();


-- 3.2. Audit Trigger cho Phê duyệt / Từ chối thẻ xe (Vehicles)
CREATE OR REPLACE FUNCTION public.fn_audit_vehicle_changes()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_building_id UUID;
BEGIN
    IF TG_OP = 'UPDATE' AND (OLD.status IS DISTINCT FROM NEW.status) THEN
        -- Lấy building_id từ apartment
        SELECT building_id INTO v_building_id FROM public.apartments WHERE id = NEW.apartment_id;

        INSERT INTO public.audit_logs (
            building_id, actor_id, action, entity_name, entity_id, old_values, new_values
        ) VALUES (
            v_building_id,
            auth.uid(),
            'UPDATE_VEHICLE_STATUS',
            'vehicles',
            NEW.id,
            jsonb_build_object('license_plate', OLD.license_plate, 'status', OLD.status),
            jsonb_build_object('license_plate', NEW.license_plate, 'status', NEW.status, 'rejection_reason', NEW.rejection_reason)
        );
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_audit_vehicle_changes ON public.vehicles;
CREATE TRIGGER trg_audit_vehicle_changes
    AFTER UPDATE OF status ON public.vehicles
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_audit_vehicle_changes();


-- 3.3. Audit Trigger cho Ủy quyền vai trò (Role Delegations)
CREATE OR REPLACE FUNCTION public.fn_audit_role_delegation_changes()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO public.audit_logs (
            building_id, actor_id, action, entity_name, entity_id, new_values
        ) VALUES (
            NEW.building_id,
            NEW.delegator_id,
            'CREATE_ROLE_DELEGATION',
            'role_delegations',
            NEW.id,
            jsonb_build_object('delegate_id', NEW.delegate_id, 'delegated_role', NEW.delegated_role, 'starts_at', NEW.starts_at, 'ends_at', NEW.ends_at)
        );
    ELSIF TG_OP = 'UPDATE' AND (OLD.is_revoked IS DISTINCT FROM NEW.is_revoked) THEN
        INSERT INTO public.audit_logs (
            building_id, actor_id, action, entity_name, entity_id, old_values, new_values
        ) VALUES (
            NEW.building_id,
            auth.uid(),
            'REVOKE_ROLE_DELEGATION',
            'role_delegations',
            NEW.id,
            jsonb_build_object('is_revoked', OLD.is_revoked),
            jsonb_build_object('is_revoked', NEW.is_revoked)
        );
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_audit_role_delegation_changes ON public.role_delegations;
CREATE TRIGGER trg_audit_role_delegation_changes
    AFTER INSERT OR UPDATE ON public.role_delegations
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_audit_role_delegation_changes();


-- 4. RPC KIỂM TRA QUYỀN THỰC TẾ CÓ THỜI HẠN (GET EFFECTIVE USER ROLE)
CREATE OR REPLACE FUNCTION public.get_effective_user_role(
    p_user_id UUID,
    p_building_id UUID DEFAULT NULL
)
RETURNS VARCHAR(30)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_base_role VARCHAR(30);
    v_delegated_role VARCHAR(30);
BEGIN
    -- 1. Lấy vai trò gốc từ bảng users
    SELECT role INTO v_base_role FROM public.users WHERE id = p_user_id;

    -- Nếu đã là admin cấp cao, giữ nguyên toàn quyền
    IF v_base_role = 'admin' THEN
        RETURN 'admin';
    END IF;

    -- 2. Kiểm tra xem có ủy quyền còn hiệu lực trong khoảng starts_at <= now() <= ends_at
    SELECT delegated_role INTO v_delegated_role
    FROM public.role_delegations
    WHERE delegate_id = p_user_id
      AND is_revoked = false
      AND starts_at <= now()
      AND ends_at >= now()
      AND (p_building_id IS NULL OR building_id IS NULL OR building_id = p_building_id)
    ORDER BY starts_at DESC
    LIMIT 1;

    IF v_delegated_role IS NOT NULL THEN
        RETURN v_delegated_role;
    END IF;

    RETURN COALESCE(v_base_role, 'resident');
END;
$$;
