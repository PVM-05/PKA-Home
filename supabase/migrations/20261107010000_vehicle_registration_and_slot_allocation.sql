-- ==============================================================================
-- MIGRATION: 20261107010000_vehicle_registration_and_slot_allocation.sql
-- Mục tiêu: Bổ sung registration_image_url, approved_at, approved_by vào bảng vehicles,
--          cấu hình bucket vehicle-docs trong Storage và các chỉ mục tối ưu hóa.
-- ==============================================================================

-- 1. Bổ sung các cột mới vào bảng vehicles
ALTER TABLE public.vehicles
  ADD COLUMN IF NOT EXISTS registration_image_url TEXT,
  ADD COLUMN IF NOT EXISTS approved_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS approved_by UUID REFERENCES public.users(id);

-- 2. Tạo chỉ mục hỗ trợ truy vấn xe theo căn hộ, trạng thái và ô đỗ
CREATE INDEX IF NOT EXISTS idx_vehicles_apartment_status ON public.vehicles (apartment_id, status);
CREATE INDEX IF NOT EXISTS idx_vehicles_parking_slot ON public.vehicles (parking_slot_id);

-- 3. Khởi tạo Storage Bucket vehicle-docs cho giấy đăng ký xe
INSERT INTO storage.buckets (id, name, public)
VALUES ('vehicle-docs', 'vehicle-docs', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- 4. RLS Policies an toàn cho storage.objects
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'objects' AND schemaname = 'storage' AND policyname = 'Cho phép người dùng đã xác thực upload ảnh giấy tờ xe'
  ) THEN
    CREATE POLICY "Cho phép người dùng đã xác thực upload ảnh giấy tờ xe"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (bucket_id = 'vehicle-docs');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'objects' AND schemaname = 'storage' AND policyname = 'Cho phép đọc ảnh giấy tờ xe'
  ) THEN
    CREATE POLICY "Cho phép đọc ảnh giấy tờ xe"
    ON storage.objects FOR SELECT
    TO authenticated
    USING (bucket_id = 'vehicle-docs');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'objects' AND schemaname = 'storage' AND policyname = 'Cho phép xóa ảnh giấy tờ xe'
  ) THEN
    CREATE POLICY "Cho phép xóa ảnh giấy tờ xe"
    ON storage.objects FOR DELETE
    TO authenticated
    USING (bucket_id = 'vehicle-docs');
  END IF;
END $$;
