-- Bật RLS cho toàn bộ các bảng
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.apartments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.residents_apartments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoice_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.issue_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.issue_images ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;

-- Helper function kiểm tra Management role
CREATE OR REPLACE FUNCTION public.is_management()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.users 
    WHERE id = auth.uid() AND role = 'management'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-------------------------------------------------------------------------
-- 1. Bảng users
-------------------------------------------------------------------------
CREATE POLICY "Users có thể xem dữ liệu của chính mình" 
ON public.users FOR SELECT 
USING (auth.uid() = id);

CREATE POLICY "Management có toàn quyền trên users" 
ON public.users FOR ALL 
USING (public.is_management());

-------------------------------------------------------------------------
-- 2. Bảng apartments
-------------------------------------------------------------------------
CREATE POLICY "Resident xem được apartments của mình" 
ON public.apartments FOR SELECT 
USING (
  EXISTS (
    SELECT 1 FROM public.residents_apartments 
    WHERE apartment_id = apartments.id AND user_id = auth.uid()
  )
);

CREATE POLICY "Management có toàn quyền trên apartments" 
ON public.apartments FOR ALL 
USING (public.is_management());

-------------------------------------------------------------------------
-- 3. Bảng residents_apartments
-------------------------------------------------------------------------
CREATE POLICY "Resident xem được liên kết của mình" 
ON public.residents_apartments FOR SELECT 
USING (user_id = auth.uid());

CREATE POLICY "Management có toàn quyền trên residents_apartments" 
ON public.residents_apartments FOR ALL 
USING (public.is_management());

-------------------------------------------------------------------------
-- 4. Bảng invoices và invoice_items
-------------------------------------------------------------------------
CREATE POLICY "Resident xem được invoices của mình" 
ON public.invoices FOR SELECT 
USING (
  EXISTS (
    SELECT 1 FROM public.residents_apartments 
    WHERE apartment_id = invoices.apartment_id AND user_id = auth.uid()
  )
);

CREATE POLICY "Resident update status invoices" 
ON public.invoices FOR UPDATE 
USING (
  EXISTS (
    SELECT 1 FROM public.residents_apartments 
    WHERE apartment_id = invoices.apartment_id AND user_id = auth.uid()
  )
)
WITH CHECK (
  status = 'pending_confirmation'::invoice_status
);

CREATE POLICY "Management có toàn quyền trên invoices" 
ON public.invoices FOR ALL 
USING (public.is_management());

-- invoice_items
CREATE POLICY "Resident xem được invoice_items của mình" 
ON public.invoice_items FOR SELECT 
USING (
  EXISTS (
    SELECT 1 FROM public.invoices i
    JOIN public.residents_apartments ra ON ra.apartment_id = i.apartment_id
    WHERE i.id = invoice_items.invoice_id AND ra.user_id = auth.uid()
  )
);

CREATE POLICY "Management có toàn quyền trên invoice_items" 
ON public.invoice_items FOR ALL 
USING (public.is_management());

-------------------------------------------------------------------------
-- 5. Bảng issue_reports và issue_images
-------------------------------------------------------------------------
CREATE POLICY "Resident xem issue_reports của mình" 
ON public.issue_reports FOR SELECT 
USING (
  reporter_id = auth.uid() OR
  EXISTS (
    SELECT 1 FROM public.residents_apartments 
    WHERE apartment_id = issue_reports.apartment_id AND user_id = auth.uid()
  )
);

CREATE POLICY "Resident tạo issue_reports mới" 
ON public.issue_reports FOR INSERT 
WITH CHECK (reporter_id = auth.uid());

CREATE POLICY "Management có toàn quyền trên issue_reports" 
ON public.issue_reports FOR ALL 
USING (public.is_management());

-- issue_images
CREATE POLICY "Mọi người xem issue_images" 
ON public.issue_images FOR SELECT 
USING (true);

CREATE POLICY "Resident tạo issue_images" 
ON public.issue_images FOR INSERT 
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.issue_reports 
    WHERE id = issue_images.issue_report_id AND reporter_id = auth.uid()
  )
);

CREATE POLICY "Management có toàn quyền trên issue_images" 
ON public.issue_images FOR ALL 
USING (public.is_management());

-------------------------------------------------------------------------
-- 6. Bảng announcements
-------------------------------------------------------------------------
CREATE POLICY "Mọi user login đều xem được announcements" 
ON public.announcements FOR SELECT 
USING (auth.uid() IS NOT NULL);

CREATE POLICY "Management có toàn quyền trên announcements" 
ON public.announcements FOR ALL 
USING (public.is_management());
