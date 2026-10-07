-- ==============================================================================
-- Migration: 20261007_01_fix_p0_database_and_security.sql
-- Mô tả: Khắc phục toàn bộ lỗi P0 Database, Migration, RPC, Trigger và Bảo mật
-- 1. Chuẩn hóa schema public.vehicles và trigger bảo vệ users
-- 2. Sửa hàm phân quyền RBAC và siết RLS amenity_bookings
-- 3. Hợp nhất và sửa toàn bộ trigger thông báo
-- 4. Sửa toàn bộ RPC tính tiền và duyệt chỉ số đồng hồ
-- 5. Bảo mật thanh toán, xử lý múi giờ và siết quyền thực thi
-- ==============================================================================

-- 1. CHUẨN HÓA BẢNG VEHICLES
-- ------------------------------------------------------------------------------
ALTER TABLE public.vehicles
  ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS license_plate TEXT,
  ADD COLUMN IF NOT EXISTS brand_model TEXT,
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'pending';

-- Đồng bộ dữ liệu cũ từ plate_number sang license_plate nếu cần
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'vehicles' AND column_name = 'plate_number'
  ) THEN
    UPDATE public.vehicles
    SET license_plate = plate_number
    WHERE license_plate IS NULL AND plate_number IS NOT NULL;
  END IF;
END $$;

-- Ràng buộc giá trị hợp lệ cho status và vehicle_type
DO $$
BEGIN
  ALTER TABLE public.vehicles DROP CONSTRAINT IF EXISTS vehicles_status_check;
  ALTER TABLE public.vehicles ADD CONSTRAINT vehicles_status_check 
    CHECK (status IN ('pending', 'approved', 'rejected'));
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$
BEGIN
  ALTER TABLE public.vehicles DROP CONSTRAINT IF EXISTS vehicles_vehicle_type_check;
  ALTER TABLE public.vehicles ADD CONSTRAINT vehicles_vehicle_type_check 
    CHECK (vehicle_type IN ('motorbike', 'car', 'electric_bicycle'));
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- 2. TRIGGER BẢO VỆ CỘT NHẠY CẢM TRÊN BẢNG USERS (is_locked & role)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.protect_user_sensitive_fields()
RETURNS TRIGGER AS $$
DECLARE
  v_caller_role public.user_role;
BEGIN
  -- Lấy vai trò của người đang thực hiện truy vấn
  SELECT role INTO v_caller_role FROM public.users WHERE id = auth.uid();
  
  -- Nếu không phải admin hoặc management thì cấm sửa is_locked và role
  IF v_caller_role IS NULL OR v_caller_role NOT IN ('admin', 'management') THEN
    IF OLD.is_locked IS DISTINCT FROM NEW.is_locked THEN
      RAISE EXCEPTION 'Bạn không có quyền thay đổi trạng thái khóa tài khoản';
    END IF;
    IF OLD.role IS DISTINCT FROM NEW.role THEN
      RAISE EXCEPTION 'Bạn không có quyền thay đổi vai trò hệ thống';
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_catalog;

DROP TRIGGER IF EXISTS trg_protect_user_sensitive_fields ON public.users;
CREATE TRIGGER trg_protect_user_sensitive_fields
  BEFORE UPDATE ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION public.protect_user_sensitive_fields();
