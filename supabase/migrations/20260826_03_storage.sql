-- Khởi tạo storage bucket
INSERT INTO storage.buckets (id, name, public) 
VALUES ('issue-images', 'issue-images', true)
ON CONFLICT (id) DO NOTHING;

-- Bật RLS cho storage.objects (nơi chứa file)
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- 1. Cho phép bất kỳ ai đọc ảnh trong bucket issue-images
CREATE POLICY "Public Access" 
ON storage.objects FOR SELECT 
USING (bucket_id = 'issue-images');

-- 2. Chỉ người dùng đã đăng nhập mới được upload
CREATE POLICY "Authenticated users can upload" 
ON storage.objects FOR INSERT 
WITH CHECK (
  bucket_id = 'issue-images' AND 
  auth.role() = 'authenticated' AND
  (storage.foldername(name))[1] = auth.uid()::text -- Bắt buộc upload vào folder có tên là user_id
);

-- 3. Chỉ người upload hoặc management mới được sửa/xóa
CREATE POLICY "Users can update/delete their own images"
ON storage.objects FOR UPDATE
USING (
  bucket_id = 'issue-images' AND 
  auth.role() = 'authenticated' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "Users can delete their own images"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'issue-images' AND 
  auth.role() = 'authenticated' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Management có quyền full access đối với bucket (ví dụ như quản lý rác)
CREATE POLICY "Management có toàn quyền trên storage"
ON storage.objects FOR ALL
USING (
  public.is_management()
);
