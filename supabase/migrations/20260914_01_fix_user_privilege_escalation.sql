-- ==============================================================================
-- Migration: Khắc phục lỗ hổng leo thang đặc quyền (Privilege Escalation) trên bảng users
-- Ngày: 14/09/2026
-- Mô tả:
-- 1. Chặn việc tự ý thay đổi cột 'role' bằng TRIGGER BEFORE UPDATE.
-- 2. Thay thế RLS Policy cũ bằng Policy có kiểm tra cột role (WITH CHECK).
-- 3. Tạo RPC function update_own_profile() với SECURITY DEFINER chỉ cho phép sửa full_name và phone.
-- ==============================================================================

-- 1. Trigger chặn việc tự đổi role (Kể cả khi bypass được RLS)
CREATE OR REPLACE FUNCTION public.prevent_role_self_escalation()
RETURNS TRIGGER AS $$
BEGIN
  -- Nếu cột role bị thay đổi và người thực hiện không phải là Ban Quản Lý (hoặc đang tự sửa role của chính mình)
  IF NEW.role IS DISTINCT FROM OLD.role AND NOT public.is_management() THEN
    RAISE EXCEPTION 'Không được phép tự thay đổi vai trò (role) của tài khoản.';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_prevent_role_self_escalation ON public.users;
CREATE TRIGGER trg_prevent_role_self_escalation
  BEFORE UPDATE ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION public.prevent_role_self_escalation();

-- 2. Thay thế Policy UPDATE cũ trên bảng users
-- Thu hồi policy cũ không an toàn
DROP POLICY IF EXISTS "Users có thể cập nhật thông tin của chính mình" ON public.users;

-- Thiết lập policy mới: Cư dân chỉ có thể update nếu id trùng khớp VÀ giá trị role mới trùng với role hiện tại trong DB
CREATE POLICY "Users có thể cập nhật thông tin của chính mình" 
ON public.users FOR UPDATE 
USING (auth.uid() = id)
WITH CHECK (
  auth.uid() = id 
  AND role = (SELECT u.role FROM public.users u WHERE u.id = auth.uid())
);

-- 3. Cung cấp RPC an toàn cập nhật hồ sơ cá nhân
CREATE OR REPLACE FUNCTION public.update_own_profile(
  p_full_name VARCHAR DEFAULT NULL,
  p_phone VARCHAR DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_user RECORD;
BEGIN
  -- Chỉ cập nhật nếu user đã đăng nhập
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Yêu cầu đăng nhập để cập nhật hồ sơ.';
  END IF;

  UPDATE public.users 
  SET 
    full_name = COALESCE(p_full_name, full_name),
    phone = COALESCE(p_phone, phone),
    updated_at = NOW()
  WHERE id = auth.uid()
  RETURNING id, full_name, phone, role, created_at, updated_at INTO v_user;

  RETURN to_jsonb(v_user);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
