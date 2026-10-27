-- ==============================================================================
-- BẢN VÁ PHÂN LOẠI ƯU TIÊN SỰ CỐ THÔNG MINH VÀ IDEMPOTENT REALTIME (PHASE P1)
-- Migration: 20260930_01_smart_priority_and_idempotent_realtime.sql
-- ==============================================================================

-- 1. NÂNG CẤP TRIGGER PHÂN LOẠI ƯU TIÊN THÔNG MINH
-- ------------------------------------------------------------------------------
-- Khắc phục lỗi: "Bóng đèn hành lang bị cháy" bị xếp nhầm thành khẩn cấp (high)
-- Bổ sung nhận diện từ khóa cả có dấu và không dấu
-- Tôn trọng mức độ ưu tiên do người dùng hoặc BQL chủ động thiết lập
CREATE OR REPLACE FUNCTION public.classify_issue_priority()
RETURNS TRIGGER AS $$
DECLARE
  v_desc TEXT;
BEGIN
  -- Nếu mức độ ưu tiên đã được chủ động chọn khác 'medium', không tự ý ghi đè
  IF TG_OP = 'UPDATE' AND NEW.priority IS DISTINCT FROM OLD.priority THEN
    RETURN NEW;
  END IF;

  IF NEW.priority IS NOT NULL AND NEW.priority != 'medium'::public.issue_priority THEN
    RETURN NEW;
  END IF;

  v_desc := lower(coalesce(NEW.description, ''));

  -- Trường hợp đặc biệt: "Bóng đèn bị cháy / cháy bóng đèn" -> Xếp vào mức LOW thay vì HIGH
  IF v_desc ~* '(bóng đèn|bong den|đèn|den).*(cháy|chay)' OR v_desc ~* '(cháy|chay).*(bóng|bong|đèn|den)' THEN
    NEW.priority := 'low'::public.issue_priority;
    RETURN NEW;
  END IF;

  -- 1.1 Khẩn cấp (High): Hỏa hoạn, rò rỉ gas, chập điện, kẹt thang máy, vỡ ống nước lớn
  IF v_desc ~* '(hỏa hoạn|hoa hoan|cháy nhà|chay nha|bốc cháy|boc chay|đám cháy|dam chay|báo cháy|bao chay|khói độc|khoi doc|chập điện|chap dien|rò rỉ gas|ro ri gas|khí gas|khi gas|kẹt thang máy|ket thang may|sập|sap|nổ|no)' THEN
    NEW.priority := 'high'::public.issue_priority;

  -- 1.2 Thấp (Low): Bóng đèn, mạng wifi, rác, vệ sinh, tiếng ồn, cây cảnh, thẩm mỹ
  ELSIF v_desc ~* '(bóng đèn|bong den|mạng|mang|wifi|vệ sinh|ve sinh|ồn ào|on ao|rác|rac|cây cảnh|cay canh|sơn tường|son tuong|thẩm mỹ|tham my)' THEN
    NEW.priority := 'low'::public.issue_priority;

  -- 1.3 Trung bình (Medium): Rò rỉ nước, mất nước, mất điện căn hộ, hỏng khóa
  ELSIF v_desc ~* '(rò nước|ro nuoc|rỉ nước|ri nuoc|ngập|ngap|khẩn cấp|khan cap|hỏng khóa|hong khoa|mất điện|mat dien|mất nước|mat nuoc)' THEN
    NEW.priority := 'medium'::public.issue_priority;

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


-- 2. ĐẢM BẢO IDEMPOTENT CHO REALTIME PUBLICATION
-- ------------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'issue_reports'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.issue_reports;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'invoices'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.invoices;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'apartment_link_requests'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.apartment_link_requests;
  END IF;
EXCEPTION
  WHEN undefined_object THEN
    NULL;
END $$;
