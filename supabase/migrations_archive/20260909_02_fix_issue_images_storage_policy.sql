-- Migration: Fix RLS Policy for issue-images Storage Bucket
-- Cho phép upload theo cả 2 cấu trúc folder:
-- 1. {user_id}/{issue_id}/{filename} (storage.foldername[1] = auth.uid())
-- 2. {issue_id}/{filename} (với điều kiện issue_report thuộc về reporter_id = auth.uid())

DROP POLICY IF EXISTS "Authenticated users can upload" ON storage.objects;
CREATE POLICY "Authenticated users can upload" 
ON storage.objects FOR INSERT 
WITH CHECK (
  bucket_id = 'issue-images' AND 
  auth.role() = 'authenticated' AND (
    (storage.foldername(name))[1] = auth.uid()::text OR
    EXISTS (
      SELECT 1 FROM public.issue_reports 
      WHERE id::text = (storage.foldername(name))[1] 
      AND reporter_id = auth.uid()
    )
  )
);

DROP POLICY IF EXISTS "Authenticated Read Access" ON storage.objects;
CREATE POLICY "Authenticated Read Access" 
ON storage.objects FOR SELECT 
USING (bucket_id = 'issue-images');

DROP POLICY IF EXISTS "Users can update their own images" ON storage.objects;
CREATE POLICY "Users can update their own images"
ON storage.objects FOR UPDATE
USING (
  bucket_id = 'issue-images' AND 
  auth.role() = 'authenticated' AND (
    (storage.foldername(name))[1] = auth.uid()::text OR
    EXISTS (
      SELECT 1 FROM public.issue_reports 
      WHERE id::text = (storage.foldername(name))[1] 
      AND reporter_id = auth.uid()
    )
  )
);

DROP POLICY IF EXISTS "Users can delete their own images" ON storage.objects;
CREATE POLICY "Users can delete their own images"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'issue-images' AND 
  auth.role() = 'authenticated' AND (
    (storage.foldername(name))[1] = auth.uid()::text OR
    EXISTS (
      SELECT 1 FROM public.issue_reports 
      WHERE id::text = (storage.foldername(name))[1] 
      AND reporter_id = auth.uid()
    )
  )
);
