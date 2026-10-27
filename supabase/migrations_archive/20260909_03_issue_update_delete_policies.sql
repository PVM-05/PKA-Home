-- Migration: Cho phép Resident sửa và xóa issue_reports và issue_images khi status = 'pending'

-- 1. Policies trên issue_reports
DROP POLICY IF EXISTS "Resident sửa issue_reports khi pending" ON public.issue_reports;
CREATE POLICY "Resident sửa issue_reports khi pending"
ON public.issue_reports FOR UPDATE
USING (reporter_id = auth.uid() AND status = 'pending')
WITH CHECK (reporter_id = auth.uid() AND status = 'pending');

DROP POLICY IF EXISTS "Resident xóa issue_reports khi pending" ON public.issue_reports;
CREATE POLICY "Resident xóa issue_reports khi pending"
ON public.issue_reports FOR DELETE
USING (reporter_id = auth.uid() AND status = 'pending');

-- 2. Policies trên issue_images
DROP POLICY IF EXISTS "Resident xóa issue_images khi pending" ON public.issue_images;
CREATE POLICY "Resident xóa issue_images khi pending"
ON public.issue_images FOR DELETE
USING (
  EXISTS (
    SELECT 1 FROM public.issue_reports ir
    WHERE ir.id = issue_images.issue_report_id
    AND ir.reporter_id = auth.uid()
    AND ir.status = 'pending'
  )
);

DROP POLICY IF EXISTS "Resident thêm issue_images khi pending" ON public.issue_images;
CREATE POLICY "Resident thêm issue_images khi pending"
ON public.issue_images FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.issue_reports ir
    WHERE ir.id = issue_images.issue_report_id
    AND ir.reporter_id = auth.uid()
    AND ir.status = 'pending'
  )
);
