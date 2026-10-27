-- Migration: Tạo bảng issue_ratings và thiết lập chính sách RLS
-- Đánh giá chất lượng dịch vụ sự cố đa tiêu chí và tính điểm trung bình tự động qua Generated Column

CREATE TABLE IF NOT EXISTS public.issue_ratings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    issue_report_id UUID NOT NULL UNIQUE REFERENCES public.issue_reports(id) ON DELETE CASCADE,
    reporter_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    speed_rating INT NOT NULL CHECK (speed_rating BETWEEN 1 AND 5),
    attitude_rating INT NOT NULL CHECK (attitude_rating BETWEEN 1 AND 5),
    quality_rating INT NOT NULL CHECK (quality_rating BETWEEN 1 AND 5),
    overall_rating DECIMAL GENERATED ALWAYS AS (
        ROUND((speed_rating + attitude_rating + quality_rating)::numeric / 3.0, 1)
    ) STORED,
    comment TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Trigger tự động cập nhật updated_at
DROP TRIGGER IF EXISTS update_issue_ratings_modtime ON public.issue_ratings;
CREATE TRIGGER update_issue_ratings_modtime 
BEFORE UPDATE ON public.issue_ratings 
FOR EACH ROW EXECUTE FUNCTION update_modified_column();

-- Bật Row Level Security (RLS)
ALTER TABLE public.issue_ratings ENABLE ROW LEVEL SECURITY;

-- 1. Policy SELECT
DROP POLICY IF EXISTS "Nhân viên xem toàn bộ đánh giá dịch vụ" ON public.issue_ratings;
CREATE POLICY "Nhân viên xem toàn bộ đánh giá dịch vụ"
ON public.issue_ratings FOR SELECT
TO authenticated
USING (public.is_staff());

DROP POLICY IF EXISTS "Cư dân xem đánh giá sự cố của chính mình" ON public.issue_ratings;
CREATE POLICY "Cư dân xem đánh giá sự cố của chính mình"
ON public.issue_ratings FOR SELECT
TO authenticated
USING (auth.uid() = reporter_id);

-- 2. Policy INSERT: Chỉ cư dân là người báo cáo sự cố đã hoàn thành (resolved) mới được gửi đánh giá
DROP POLICY IF EXISTS "Cư dân gửi đánh giá cho sự cố đã hoàn thành" ON public.issue_ratings;
CREATE POLICY "Cư dân gửi đánh giá cho sự cố đã hoàn thành"
ON public.issue_ratings FOR INSERT
TO authenticated
WITH CHECK (
    auth.uid() = reporter_id AND
    EXISTS (
        SELECT 1 FROM public.issue_reports
        WHERE id = issue_report_id 
          AND reporter_id = auth.uid() 
          AND status = 'resolved'
    )
);

-- 3. Policy UPDATE: Cư dân cập nhật lại đánh giá của chính mình
DROP POLICY IF EXISTS "Cư dân cập nhật đánh giá của chính mình" ON public.issue_ratings;
CREATE POLICY "Cư dân cập nhật đánh giá của chính mình"
ON public.issue_ratings FOR UPDATE
TO authenticated
USING (auth.uid() = reporter_id)
WITH CHECK (auth.uid() = reporter_id);

-- 4. Policy DELETE: Admin hoặc người đánh giá
DROP POLICY IF EXISTS "Admin hoặc người đánh giá có quyền xóa đánh giá" ON public.issue_ratings;
CREATE POLICY "Admin hoặc người đánh giá có quyền xóa đánh giá"
ON public.issue_ratings FOR DELETE
TO authenticated
USING (public.is_admin() OR auth.uid() = reporter_id);

-- Thêm vào realtime publication
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'issue_ratings'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.issue_ratings;
    END IF;
END $$;
