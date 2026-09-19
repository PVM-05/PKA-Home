-- ==============================================================================
-- BẢN NÂNG CẤP RBAC TOÀN DIỆN, LEAST PRIVILEGE VÀ ỦY QUYỀN VAI TRÒ TẠM THỜI
-- Migration: 20260920_01_comprehensive_rbac_and_delegations.sql
-- ==============================================================================

-- 1. CHUẨN HÓA VÀ TÁCH BẠCH QUYỀN QUẢN TRỊ (is_management, is_admin, is_staff)
-- ------------------------------------------------------------------------------
-- is_admin() là nguồn sự thật cho Quản trị viên cấp cao nhất
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.users 
    WHERE id = auth.uid() AND role IN ('admin', 'management')
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- is_management() là alias trực tiếp của is_admin() để tương thích ngược hoàn toàn
-- với các RLS policy cũ, triệt tiêu nguy cơ trôi dạt logic (drift)
CREATE OR REPLACE FUNCTION public.is_management()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN public.is_admin();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- is_staff() đại diện cho toàn bộ nhân sự nội bộ thuộc Ban Quản Lý
CREATE OR REPLACE FUNCTION public.is_staff()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.users 
    WHERE id = auth.uid() AND role IN ('management', 'admin', 'accountant', 'technician')
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 2. EXTENSION & BẢNG ỦY QUYỀN VAI TRÒ TẠM THỜI (role_delegations)
-- ------------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE TABLE IF NOT EXISTS public.role_delegations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  delegator_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  delegate_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  delegated_role public.user_role NOT NULL,
  starts_at TIMESTAMPTZ NOT NULL,
  ends_at TIMESTAMPTZ NOT NULL,
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  
  -- Ràng buộc 1: Chặn ủy quyền vai trò admin / management (chống leo thang đặc quyền)
  CONSTRAINT chk_no_admin_delegation CHECK (delegated_role IN ('accountant', 'technician')),
  -- Ràng buộc 2: Thời điểm kết thúc phải lớn hơn thời điểm bắt đầu
  CONSTRAINT chk_valid_time_range CHECK (ends_at > starts_at),
  -- Ràng buộc 3: Không tự ủy quyền cho chính mình
  CONSTRAINT chk_no_self_delegation CHECK (delegator_id <> delegate_id),
  -- Ràng buộc 4: Chống chồng lấn khoảng thời gian ủy quyền cho cùng một vai trò của một người
  CONSTRAINT no_overlapping_delegations EXCLUDE USING gist (
    delegate_id WITH =,
    delegated_role WITH =,
    tstzrange(starts_at, ends_at) WITH &&
  )
);

ALTER TABLE public.role_delegations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admin toàn quyền trên role_delegations" ON public.role_delegations;
CREATE POLICY "Admin toàn quyền trên role_delegations"
ON public.role_delegations FOR ALL
USING (public.is_admin());

DROP POLICY IF EXISTS "Delegate xem ủy quyền của mình" ON public.role_delegations;
CREATE POLICY "Delegate xem ủy quyền của mình"
ON public.role_delegations FOR SELECT
USING (delegate_id = auth.uid());


-- 3. MỞ RỘNG HÀM RLS ĐỂ NHẬN DIỆN ỦY QUYỀN CÒN HIỆU LỰC
-- ------------------------------------------------------------------------------
-- is_accountant(): Kiểm tra role chính thức hoặc có ủy quyền accountant active
CREATE OR REPLACE FUNCTION public.is_accountant()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.users 
    WHERE id = auth.uid() AND role IN ('accountant', 'admin', 'management')
  ) OR EXISTS (
    SELECT 1 FROM public.role_delegations
    WHERE delegate_id = auth.uid() 
      AND delegated_role = 'accountant'
      AND now() BETWEEN starts_at AND ends_at
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- is_technician(): Kiểm tra role chính thức hoặc có ủy quyền technician active
CREATE OR REPLACE FUNCTION public.is_technician()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.users 
    WHERE id = auth.uid() AND role IN ('technician', 'admin', 'management')
  ) OR EXISTS (
    SELECT 1 FROM public.role_delegations
    WHERE delegate_id = auth.uid() 
      AND delegated_role = 'technician'
      AND now() BETWEEN starts_at AND ends_at
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 4. ĐỒNG BỘ CHÍNH SÁCH BẢNG APARTMENT_LINK_REQUESTS (APPROVE & REJECT)
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "Management toàn quyền trên yêu cầu liên kết" ON public.apartment_link_requests;
DROP POLICY IF EXISTS "Admin toàn quyền trên yêu cầu liên kết" ON public.apartment_link_requests;

CREATE POLICY "Admin toàn quyền trên yêu cầu liên kết" 
ON public.apartment_link_requests FOR ALL 
USING (public.is_admin());

-- Cập nhật RPC approve_link_request đảm bảo gate is_admin() đồng bộ
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
