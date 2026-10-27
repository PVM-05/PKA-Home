-- Khởi tạo storage bucket
INSERT INTO storage.buckets (id, name, public) 
VALUES ('issue-images', 'issue-images', false)
ON CONFLICT (id) DO NOTHING;

-- Bật RLS cho storage.objects (nơi chứa file)
-- (Bỏ qua vì Supabase đã tự động bật RLS cho bảng này, và chạy lệnh ALTER TABLE có thể gây lỗi quyền)

-- 1. Cho phép người dùng đăng nhập đọc ảnh trong bucket issue-images
DROP POLICY IF EXISTS "Public Access" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated Read Access" ON storage.objects;
CREATE POLICY "Authenticated Read Access" 
ON storage.objects FOR SELECT 
USING (bucket_id = 'issue-images' AND auth.role() = 'authenticated');

-- 2. Chỉ người dùng đã đăng nhập mới được upload
DROP POLICY IF EXISTS "Authenticated users can upload" ON storage.objects;
CREATE POLICY "Authenticated users can upload" 
ON storage.objects FOR INSERT 
WITH CHECK (
  bucket_id = 'issue-images' AND 
  auth.role() = 'authenticated' AND
  (storage.foldername(name))[1] = auth.uid()::text -- Bắt buộc upload vào folder có tên là user_id
);

-- 3. Chỉ người upload hoặc management mới được sửa/xóa
DROP POLICY IF EXISTS "Users can update/delete their own images" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their own images" ON storage.objects;
CREATE POLICY "Users can update their own images"
ON storage.objects FOR UPDATE
USING (
  bucket_id = 'issue-images' AND 
  auth.role() = 'authenticated' AND
  (storage.foldername(name))[1] = auth.uid()::text
)
WITH CHECK (
  bucket_id = 'issue-images' AND 
  auth.role() = 'authenticated' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

DROP POLICY IF EXISTS "Users can delete their own images" ON storage.objects;
CREATE POLICY "Users can delete their own images"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'issue-images' AND 
  auth.role() = 'authenticated' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Management có quyền full access đối với bucket (ví dụ như quản lý rác)
DROP POLICY IF EXISTS "Management có toàn quyền trên storage" ON storage.objects;
CREATE POLICY "Management có toàn quyền trên storage"
ON storage.objects FOR ALL
USING (
  public.is_management()
);
