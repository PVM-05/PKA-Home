-- Migration: Thêm bảng issue_comments cho hệ thống trao đổi trên phản ánh sự cố
-- Date: 2026-09-26

-- 1. Bảng issue_comments
CREATE TABLE IF NOT EXISTS issue_comments (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  issue_report_id uuid NOT NULL REFERENCES public.issue_reports(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  content text NOT NULL CHECK (char_length(content) > 0),
  created_at timestamptz DEFAULT now() NOT NULL
);

-- 2. Index cho truy vấn nhanh
CREATE INDEX idx_issue_comments_report ON issue_comments(issue_report_id, created_at);

-- 3. Bật RLS
ALTER TABLE issue_comments ENABLE ROW LEVEL SECURITY;

-- 4. Policy: Cư dân xem comment của sự cố thuộc căn hộ mình, BQL xem tất cả
CREATE POLICY "residents_view_own_comments" ON issue_comments
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM issue_reports ir
      JOIN residents_apartments ra ON ra.apartment_id = ir.apartment_id
      WHERE ir.id = issue_comments.issue_report_id
        AND ra.user_id = auth.uid()
    )
    OR
    EXISTS (
      SELECT 1 FROM users u WHERE u.id = auth.uid() AND u.role IN ('admin', 'management', 'technician', 'accountant')
    )
  );

-- 5. Policy: Người dùng chỉ tạo comment với user_id của mình
CREATE POLICY "users_insert_own_comments" ON issue_comments
  FOR INSERT WITH CHECK (
    user_id = auth.uid()
    AND (
      EXISTS (
        SELECT 1 FROM issue_reports ir
        JOIN residents_apartments ra ON ra.apartment_id = ir.apartment_id
        WHERE ir.id = issue_comments.issue_report_id
          AND ra.user_id = auth.uid()
      )
      OR
      EXISTS (
        SELECT 1 FROM users u WHERE u.id = auth.uid() AND u.role IN ('admin', 'management', 'technician', 'accountant')
      )
    )
  );

-- 6. Bật realtime cho issue_comments
ALTER PUBLICATION supabase_realtime ADD TABLE issue_comments;
