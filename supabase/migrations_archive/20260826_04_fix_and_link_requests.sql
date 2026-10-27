-- ==============================================================================
-- 1. FIX: Ngăn chặn Privilege Escalation (Leo thang đặc quyền) qua tham số role
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.handle_new_user() 
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.users (id, full_name, role)
  VALUES (
    new.id, 
    coalesce(new.raw_user_meta_data->>'full_name', 'Người dùng mới'), 
    'resident'::public.user_role   -- Cố định role là resident, bỏ hoàn toàn field role từ metadata
  );
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==============================================================================
-- 2. FIX: Ngăn chặn chuyển ngược trạng thái hóa đơn trong RPC confirm_payment
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.confirm_payment(p_invoice_id UUID)
RETURNS void AS $$
DECLARE
  v_status public.invoice_status;
BEGIN
  -- Lấy trạng thái hiện tại của hóa đơn
  SELECT status INTO v_status FROM public.invoices WHERE id = p_invoice_id;
  
  IF v_status IS NULL THEN
    RAISE EXCEPTION 'Hóa đơn không tồn tại.';
  END IF;

  IF v_status != 'unpaid'::public.invoice_status THEN
    RAISE EXCEPTION 'Hóa đơn đã được xử lý (trạng thái hiện tại: %).', v_status;
  END IF;

  UPDATE public.invoices 
  SET status = 'pending_confirmation'::public.invoice_status, updated_at = NOW()
  WHERE id = p_invoice_id 
  AND EXISTS (
    SELECT 1 FROM public.residents_apartments 
    WHERE apartment_id = invoices.apartment_id AND user_id = auth.uid()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==============================================================================
-- 3. NEW FEATURE: Bảng apartment_link_requests để cư dân tự xin liên kết căn hộ
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.find_apartment_by_code(p_code VARCHAR)
RETURNS TABLE(id UUID, code VARCHAR, is_empty BOOLEAN)
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  RETURN QUERY 
  SELECT a.id, a.code, a.is_empty FROM public.apartments a WHERE a.code = p_code;
END;
$$;

DO $$ BEGIN
    CREATE TYPE public.link_request_status AS ENUM ('pending', 'approved', 'rejected');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DROP TABLE IF EXISTS public.apartment_link_requests CASCADE;
CREATE TABLE public.apartment_link_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    apartment_id UUID REFERENCES public.apartments(id) ON DELETE CASCADE,
    requested_relation_role public.relation_type NOT NULL,
    status public.link_request_status DEFAULT 'pending',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, apartment_id)
);

CREATE TRIGGER update_apartment_link_requests_modtime 
BEFORE UPDATE ON public.apartment_link_requests 
FOR EACH ROW EXECUTE FUNCTION public.update_modified_column();

-- RLS cho bảng apartment_link_requests
ALTER TABLE public.apartment_link_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Resident xem yêu cầu của mình" 
ON public.apartment_link_requests FOR SELECT 
USING (user_id = auth.uid());

CREATE POLICY "Resident tạo yêu cầu mới" 
ON public.apartment_link_requests FOR INSERT 
WITH CHECK (user_id = auth.uid() AND status = 'pending'::public.link_request_status);

CREATE POLICY "Management toàn quyền trên yêu cầu liên kết" 
ON public.apartment_link_requests FOR ALL 
USING (public.is_management());

-- ==============================================================================
-- RPC: Ban quản lý duyệt yêu cầu liên kết (Approve Link Request)
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.approve_link_request(p_request_id UUID)
RETURNS void AS $$
DECLARE
  v_user_id UUID;
  v_apartment_id UUID;
  v_status public.link_request_status;
  v_requested_role public.relation_type;
BEGIN
  -- 1. Kiểm tra quyền management
  IF NOT public.is_management() THEN
    RAISE EXCEPTION 'Bạn không có quyền duyệt yêu cầu này.';
  END IF;

  -- 2. Lấy thông tin request
  SELECT user_id, apartment_id, status, requested_relation_role 
  INTO v_user_id, v_apartment_id, v_status, v_requested_role 
  FROM public.apartment_link_requests 
  WHERE id = p_request_id;

  IF v_status != 'pending'::public.link_request_status THEN
    RAISE EXCEPTION 'Yêu cầu này đã được xử lý.';
  END IF;

  -- 3. Cập nhật trạng thái thành approved
  UPDATE public.apartment_link_requests 
  SET status = 'approved'::public.link_request_status, updated_at = NOW() 
  WHERE id = p_request_id;

  -- 4. Thêm vào residents_apartments
  INSERT INTO public.residents_apartments (user_id, apartment_id, relation_role)
  VALUES (v_user_id, v_apartment_id, v_requested_role)
  ON CONFLICT (user_id, apartment_id) DO NOTHING;

  -- 5. Đánh dấu căn hộ có người ở
  UPDATE public.apartments SET is_empty = false WHERE id = v_apartment_id;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
