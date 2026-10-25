-- ==============================================================================
-- Migration: 20261025_02_add_announcement_target_fields.sql
-- Mô tả: Bổ sung các cột target_type và target_apartment cho bảng announcements,
--        đồng thời chuẩn hóa ràng buộc dữ liệu và chính sách RLS cho ban quản lý.
-- ==============================================================================

-- 1. Bổ sung các cột phân loại đối tượng nhận thông báo
ALTER TABLE public.announcements 
  ADD COLUMN IF NOT EXISTS target_type VARCHAR(20) NOT NULL DEFAULT 'all',
  ADD COLUMN IF NOT EXISTS target_apartment VARCHAR(20),
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW());

-- 2. Thêm ràng buộc giá trị hợp lệ cho target_type
ALTER TABLE public.announcements 
  DROP CONSTRAINT IF EXISTS announcements_target_type_check;

ALTER TABLE public.announcements 
  ADD CONSTRAINT announcements_target_type_check 
  CHECK (target_type IN ('all', 'block_a', 'block_b', 'apartment'));

-- 3. Chuẩn hóa chính sách RLS cho Ban quản lý / Nhân viên
DROP POLICY IF EXISTS "Management toàn quyền announcements" ON public.announcements;
CREATE POLICY "Management toàn quyền announcements"
  ON public.announcements
  FOR ALL
  TO authenticated
  USING (public.is_staff_or_management())
  WITH CHECK (public.is_staff_or_management());

-- 4. Chính sách đọc thông báo cho tất cả người dùng đã xác thực
DROP POLICY IF EXISTS "User đăng nhập xem announcements" ON public.announcements;
CREATE POLICY "User đăng nhập xem announcements"
  ON public.announcements
  FOR SELECT
  TO authenticated
  USING (auth.uid() IS NOT NULL);
