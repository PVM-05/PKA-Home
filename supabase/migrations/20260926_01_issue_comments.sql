-- Migration: Thêm bảng issue_comments cho hệ thống trao đổi trên phản ánh sự cố
-- Date: 2026-09-26

-- 1. Bảng issue_comments
CREATE TABLE IF NOT EXISTS public.issue_comments (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  issue_report_id uuid NOT NULL REFERENCES public.issue_reports(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  content text NOT NULL CHECK (char_length(content) > 0),
  created_at timestamptz DEFAULT now() NOT NULL
);

-- 2. Index cho truy vấn nhanh
CREATE INDEX IF NOT EXISTS idx_issue_comments_report ON public.issue_comments(issue_report_id, created_at);

-- 3. Bật RLS
ALTER TABLE public.issue_comments ENABLE ROW LEVEL SECURITY;

-- 4. Kích hoạt REPLICA IDENTITY FULL cho Realtime
ALTER TABLE public.issue_comments REPLICA IDENTITY FULL;

-- 5. Policy: Cư dân xem comment của sự cố thuộc căn hộ mình hoặc do mình tạo, BQL xem tất cả
DROP POLICY IF EXISTS "residents_view_own_comments" ON public.issue_comments;
CREATE POLICY "residents_view_own_comments" ON public.issue_comments
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.issue_reports ir
      LEFT JOIN public.residents_apartments ra ON ra.apartment_id = ir.apartment_id
      WHERE ir.id = issue_comments.issue_report_id
        AND (ra.user_id = auth.uid() OR ir.reporter_id = auth.uid())
    )
    OR
    EXISTS (
      SELECT 1 FROM public.users u WHERE u.id = auth.uid() AND u.role IN ('admin', 'management', 'technician', 'accountant')
    )
  );

-- 6. Policy: Người dùng chỉ tạo comment với user_id của mình nếu có quyền với sự cố
DROP POLICY IF EXISTS "users_insert_own_comments" ON public.issue_comments;
CREATE POLICY "users_insert_own_comments" ON public.issue_comments
  FOR INSERT WITH CHECK (
    user_id = auth.uid()
    AND (
      EXISTS (
        SELECT 1 FROM public.issue_reports ir
        LEFT JOIN public.residents_apartments ra ON ra.apartment_id = ir.apartment_id
        WHERE ir.id = issue_comments.issue_report_id
          AND (ra.user_id = auth.uid() OR ir.reporter_id = auth.uid())
      )
      OR
      EXISTS (
        SELECT 1 FROM public.users u WHERE u.id = auth.uid() AND u.role IN ('admin', 'management', 'technician', 'accountant')
      )
    )
  );

-- 7. Bật realtime cho issue_comments (idempotent)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' 
      AND schemaname = 'public' 
      AND tablename = 'issue_comments'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.issue_comments;
  END IF;
END $$;

