-- ==============================================================================
-- 1. Bổ sung mức độ ưu tiên (Priority) cho issue_reports
-- ==============================================================================
DO $$ BEGIN
    CREATE TYPE public.issue_priority AS ENUM ('low', 'medium', 'high');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

ALTER TABLE public.issue_reports 
ADD COLUMN IF NOT EXISTS priority public.issue_priority DEFAULT 'medium';

-- ==============================================================================
-- 2. Tạo trigger phân loại ưu tiên dựa trên từ khóa (Rule-based AI)
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.classify_issue_priority()
RETURNS TRIGGER AS $$
DECLARE
  v_desc TEXT;
BEGIN
  v_desc := NEW.description;
  
  -- Sử dụng Regex case-insensitive (~*) để quét từ khóa
  IF v_desc ~* '(cháy|nổ|rò nước|rỉ nước|khẩn cấp|ngập|hỏng khóa|chập điện|mất điện|mất nước)' THEN
    NEW.priority := 'high'::public.issue_priority;
  ELSIF v_desc ~* '(bóng đèn|mạng|wifi|vệ sinh|ồn ào|rác|cây cảnh|tường)' THEN
    NEW.priority := 'low'::public.issue_priority;
  ELSE
    NEW.priority := 'medium'::public.issue_priority;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_classify_issue_priority ON public.issue_reports;
CREATE TRIGGER trigger_classify_issue_priority
BEFORE INSERT OR UPDATE OF description ON public.issue_reports
FOR EACH ROW
EXECUTE FUNCTION public.classify_issue_priority();

-- ==============================================================================
-- 3. Bật Supabase Realtime cho các bảng vận hành
-- ==============================================================================
-- Thêm bảng vào publication supabase_realtime để client có thể lắng nghe
ALTER PUBLICATION supabase_realtime ADD TABLE public.issue_reports;
ALTER PUBLICATION supabase_realtime ADD TABLE public.invoices;
ALTER PUBLICATION supabase_realtime ADD TABLE public.apartment_link_requests;
