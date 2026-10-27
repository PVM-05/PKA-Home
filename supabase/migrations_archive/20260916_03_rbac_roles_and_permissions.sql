-- ==============================================================================
-- 1. CHUYỂN ĐỔI DỮ LIỆU CŨ SANG ROLE MỚI
-- ==============================================================================
-- Toàn bộ tài khoản 'management' cũ được chuẩn hóa về 'admin'
UPDATE public.users SET role = 'admin' WHERE role = 'management';

-- ==============================================================================
-- 2. HÀM KIỂM TRA PHÂN QUYỀN (SECURITY DEFINER)
-- ==============================================================================

-- Kiểm tra xem người dùng có phải là Quản trị viên (Admin) không
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.users 
    WHERE id = auth.uid() AND role IN ('admin', 'management')
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Kiểm tra xem người dùng có quyền Kế toán hoặc Quản trị không
CREATE OR REPLACE FUNCTION public.is_accountant()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.users 
    WHERE id = auth.uid() AND role IN ('accountant', 'admin', 'management')
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Kiểm tra xem người dùng có quyền Kỹ thuật viên hoặc Quản trị không
CREATE OR REPLACE FUNCTION public.is_technician()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.users 
    WHERE id = auth.uid() AND role IN ('technician', 'admin', 'management')
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Cập nhật is_management() để bao quát mọi vai trò thuộc Ban quản lý (Tương thích ngược)
CREATE OR REPLACE FUNCTION public.is_management()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.users 
    WHERE id = auth.uid() AND role IN ('admin', 'accountant', 'technician', 'management')
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==============================================================================
-- 3. BẢNG AUDIT TRAIL ĐỔI VAI TRÒ (role_change_log)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.role_change_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  target_user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  old_role public.user_role NOT NULL,
  new_role public.user_role NOT NULL,
  changed_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
  changed_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.role_change_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Chỉ Admin mới xem được role_change_log" ON public.role_change_log;
CREATE POLICY "Chỉ Admin mới xem được role_change_log"
ON public.role_change_log FOR SELECT
USING (public.is_admin());

-- Trigger tự động ghi log khi có thay đổi role
CREATE OR REPLACE FUNCTION public.log_role_change()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.role IS DISTINCT FROM OLD.role THEN
    INSERT INTO public.role_change_log (
      target_user_id,
      old_role,
      new_role,
      changed_by,
      changed_at
    ) VALUES (
      NEW.id,
      OLD.role,
      NEW.role,
      auth.uid(),
      now()
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_log_role_change ON public.users;
CREATE TRIGGER trg_log_role_change
AFTER UPDATE OF role ON public.users
FOR EACH ROW
EXECUTE FUNCTION public.log_role_change();

-- ==============================================================================
-- 4. RÀNG BUỘC PHÂN QUYỀN NÂNG CAO TRÊN CÁC BẢNG (RLS POLICIES)
-- ==============================================================================

-- 4.1 Bảng users: Chỉ Admin mới có quyền đổi role của tài khoản khác
-- Hỗ trợ bootstrap bypass (service_role / postgres direct) và chống Admin tự khóa tài khoản
CREATE OR REPLACE FUNCTION public.prevent_role_self_escalation()
RETURNS TRIGGER AS $$
DECLARE
  v_jwt_claims json;
  v_role text;
BEGIN
  -- Cho phép bypass khi chạy trực tiếp từ DB / superuser (không có JWT)
  IF auth.uid() IS NULL THEN
    RETURN NEW;
  END IF;

  -- Cho phép bypass khi request đến từ service_role (Admin API, migrations, seed)
  BEGIN
    v_jwt_claims := current_setting('request.jwt.claims', true)::json;
    v_role := v_jwt_claims->>'role';
    IF v_role = 'service_role' THEN
      RETURN NEW;
    END IF;
  EXCEPTION WHEN OTHERS THEN
  END;

  -- Ngăn Admin tự hạ quyền của chính mình (chống vô tình tự khóa tài khoản)
  IF NEW.id = auth.uid() AND OLD.role IN ('admin', 'management') AND NEW.role NOT IN ('admin', 'management') THEN
    RAISE EXCEPTION 'Không thể tự hạ quyền Quản trị viên của chính mình để tránh mất quyền quản trị hệ thống.';
  END IF;

  -- Chặn việc đổi vai trò nếu không phải Quản trị viên
  IF NEW.role IS DISTINCT FROM OLD.role AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Chỉ Quản trị viên (Admin) mới có quyền thay đổi vai trò người dùng.';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_prevent_role_self_escalation ON public.users;
CREATE TRIGGER trg_prevent_role_self_escalation
BEFORE UPDATE ON public.users
FOR EACH ROW
EXECUTE FUNCTION public.prevent_role_self_escalation();

-- 4.2 Bảng invoices & invoice_items: Chỉ Admin và Accountant được tạo/sửa/xóa hóa đơn
DROP POLICY IF EXISTS "Management có toàn quyền trên invoices" ON public.invoices;
DROP POLICY IF EXISTS "Admin và Accountant toàn quyền trên invoices" ON public.invoices;
DROP POLICY IF EXISTS "Resident xem hóa đơn của căn hộ mình" ON public.invoices;

CREATE POLICY "Resident xem hóa đơn của căn hộ mình" 
ON public.invoices FOR SELECT 
USING (
  EXISTS (
    SELECT 1 FROM public.residents_apartments 
    WHERE residents_apartments.apartment_id = invoices.apartment_id 
    AND residents_apartments.user_id = auth.uid()
  )
);

CREATE POLICY "Admin và Accountant toàn quyền trên invoices" 
ON public.invoices FOR ALL 
USING (public.is_accountant());

DROP POLICY IF EXISTS "Management có toàn quyền trên invoice_items" ON public.invoice_items;
DROP POLICY IF EXISTS "Admin và Accountant toàn quyền trên invoice_items" ON public.invoice_items;
DROP POLICY IF EXISTS "Resident xem chi tiết hóa đơn căn hộ mình" ON public.invoice_items;

CREATE POLICY "Resident xem chi tiết hóa đơn căn hộ mình" 
ON public.invoice_items FOR SELECT 
USING (
  EXISTS (
    SELECT 1 FROM public.invoices
    JOIN public.residents_apartments ON residents_apartments.apartment_id = invoices.apartment_id
    WHERE invoices.id = invoice_items.invoice_id 
    AND residents_apartments.user_id = auth.uid()
  )
);

CREATE POLICY "Admin và Accountant toàn quyền trên invoice_items" 
ON public.invoice_items FOR ALL 
USING (public.is_accountant());

-- 4.3 Bảng issue_reports: Admin & Kỹ thuật viên có quyền sửa trạng thái sự cố
DROP POLICY IF EXISTS "Management toàn quyền trên issue_reports" ON public.issue_reports;
DROP POLICY IF EXISTS "Admin và Kỹ thuật viên cập nhật issue_reports" ON public.issue_reports;
DROP POLICY IF EXISTS "Staff xem tất cả sự cố" ON public.issue_reports;

CREATE POLICY "Staff xem tất cả sự cố" 
ON public.issue_reports FOR SELECT 
USING (public.is_management() OR reporter_id = auth.uid());

CREATE POLICY "Admin và Kỹ thuật viên cập nhật issue_reports" 
ON public.issue_reports FOR UPDATE 
USING (public.is_technician());

-- 4.4 RPC approve_link_request: Chỉ Admin mới có quyền duyệt
CREATE OR REPLACE FUNCTION public.approve_link_request(p_request_id UUID)
RETURNS void AS $$
DECLARE
  v_user_id UUID;
  v_apartment_id UUID;
  v_status public.link_request_status;
  v_requested_role public.relation_type;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Chỉ Quản trị viên mới có quyền duyệt yêu cầu liên kết căn hộ.';
  END IF;

  SELECT user_id, apartment_id, status, requested_relation_role 
  INTO v_user_id, v_apartment_id, v_status, v_requested_role 
  FROM public.apartment_link_requests 
  WHERE id = p_request_id;

  IF v_status != 'pending'::public.link_request_status THEN
    RAISE EXCEPTION 'Yêu cầu này đã được xử lý.';
  END IF;

  -- Cập nhật trạng thái yêu cầu
  UPDATE public.apartment_link_requests
  SET status = 'approved',
      updated_at = now()
  WHERE id = p_request_id;

  -- Thêm vào bảng liên kết cư dân - căn hộ
  INSERT INTO public.residents_apartments (user_id, apartment_id, relation_role)
  VALUES (v_user_id, v_apartment_id, v_requested_role::text);

  -- Cập nhật căn hộ không còn trống
  UPDATE public.apartments
  SET is_empty = false
  WHERE id = v_apartment_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
