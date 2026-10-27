-- ==============================================================================
-- BẢN VÁ LỖI BẢO MẬT, RBAC, STORAGE VÀ RPC QUAN TRỌNG (PHASE 1)
-- Migration: 20260929_02_fix_critical_rbac_storage_and_rpcs.sql
-- ==============================================================================

-- 1. SỬA LỖI RPC approve_link_request: ÉP KIỂU ENUM VÀ BẢO TỒN ON CONFLICT
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.approve_link_request(p_request_id UUID)
RETURNS void AS $$
DECLARE
  v_user_id UUID;
  v_apartment_id UUID;
  v_status public.link_request_status;
  v_requested_role public.relation_type;
BEGIN
  -- Chỉ Admin mới có quyền duyệt yêu cầu liên kết căn hộ
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Chỉ Quản trị viên mới có quyền duyệt yêu cầu liên kết căn hộ.';
  END IF;

  SELECT user_id, apartment_id, status, requested_relation_role 
  INTO v_user_id, v_apartment_id, v_status, v_requested_role 
  FROM public.apartment_link_requests 
  WHERE id = p_request_id;

  IF v_status IS NULL THEN
    RAISE EXCEPTION 'Không tìm thấy yêu cầu liên kết.';
  END IF;

  IF v_status != 'pending'::public.link_request_status THEN
    RAISE EXCEPTION 'Yêu cầu này đã được xử lý.';
  END IF;

  -- Cập nhật trạng thái yêu cầu thành approved
  UPDATE public.apartment_link_requests
  SET status = 'approved',
      updated_at = now()
  WHERE id = p_request_id;

  -- Thêm vào bảng liên kết cư dân - căn hộ (giữ nguyên kiểu enum, chống trùng lặp)
  INSERT INTO public.residents_apartments (user_id, apartment_id, relation_role)
  VALUES (v_user_id, v_apartment_id, v_requested_role)
  ON CONFLICT (user_id, apartment_id) DO NOTHING;

  -- Cập nhật căn hộ không còn trống
  UPDATE public.apartments
  SET is_empty = false
  WHERE id = v_apartment_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_catalog;

REVOKE EXECUTE ON FUNCTION public.approve_link_request(UUID) FROM anon;


-- 2. KHÔI PHỤC QUYỀN ĐỌC CHO KẾ TOÁN VÀ KỸ THUẬT VIÊN (is_staff)
-- ------------------------------------------------------------------------------

-- 2.1 Bảng users: Staff (Kế toán, Kỹ thuật viên, Admin) được xem danh sách users
DROP POLICY IF EXISTS "Staff có thể xem danh sách users" ON public.users;
CREATE POLICY "Staff có thể xem danh sách users" 
ON public.users FOR SELECT 
USING (public.is_staff());

-- 2.2 Bảng apartments: Staff được xem danh sách căn hộ
DROP POLICY IF EXISTS "Staff có thể xem danh sách apartments" ON public.apartments;
CREATE POLICY "Staff có thể xem danh sách apartments" 
ON public.apartments FOR SELECT 
USING (public.is_staff());

-- 2.3 Bảng residents_apartments: Staff được xem danh sách liên kết căn hộ
DROP POLICY IF EXISTS "Staff có thể xem residents_apartments" ON public.residents_apartments;
CREATE POLICY "Staff có thể xem residents_apartments" 
ON public.residents_apartments FOR SELECT 
USING (public.is_staff());

-- 2.4 Bảng issue_reports: Kỹ thuật viên & Kế toán được xem tất cả sự cố
DROP POLICY IF EXISTS "Staff xem tất cả sự cố" ON public.issue_reports;
CREATE POLICY "Staff xem tất cả sự cố" 
ON public.issue_reports FOR SELECT 
USING (
  public.is_staff() OR 
  reporter_id = auth.uid() OR 
  EXISTS (
    SELECT 1 FROM public.residents_apartments 
    WHERE apartment_id = issue_reports.apartment_id AND user_id = auth.uid()
  )
);

-- 2.5 Bảng issue_images: Kỹ thuật viên & Kế toán được xem và thêm ảnh sự cố
DROP POLICY IF EXISTS "Người liên quan xem issue_images" ON public.issue_images;
CREATE POLICY "Người liên quan xem issue_images" 
ON public.issue_images FOR SELECT 
USING (
  EXISTS (
    SELECT 1 FROM public.issue_reports ir
    WHERE ir.id = issue_images.issue_report_id
    AND (
      ir.reporter_id = auth.uid() OR 
      public.is_staff() OR 
      EXISTS (
        SELECT 1 FROM public.residents_apartments 
        WHERE apartment_id = ir.apartment_id AND user_id = auth.uid()
      )
    )
  )
);

DROP POLICY IF EXISTS "Staff và người báo cáo có thể thêm issue_images" ON public.issue_images;
DROP POLICY IF EXISTS "Resident tạo issue_images" ON public.issue_images;
CREATE POLICY "Staff và người báo cáo có thể thêm issue_images" 
ON public.issue_images FOR INSERT 
WITH CHECK (
  public.is_staff() OR 
  EXISTS (
    SELECT 1 FROM public.issue_reports 
    WHERE id = issue_images.issue_report_id AND reporter_id = auth.uid()
  )
);


-- 3. RPC SECURITY DEFINER: LẤY THÀNH VIÊN CÙNG CĂN HỘ (get_co_residents)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_co_residents(p_apartment_id UUID)
RETURNS TABLE(user_id UUID, full_name TEXT, phone TEXT, relation_role TEXT)
LANGUAGE sql SECURITY DEFINER SET search_path = public, pg_catalog AS $$
  SELECT u.id, u.full_name, u.phone, ra.relation_role::TEXT
  FROM public.residents_apartments ra 
  JOIN public.users u ON u.id = ra.user_id
  WHERE ra.apartment_id = p_apartment_id
    AND (
      public.is_staff()
      OR EXISTS (
        SELECT 1 FROM public.residents_apartments me
        WHERE me.apartment_id = p_apartment_id AND me.user_id = auth.uid()
      )
    );
$$;

REVOKE EXECUTE ON FUNCTION public.get_co_residents(UUID) FROM anon;


-- 4. BUCKET issue-images CÔNG KHAI ĐỂ getPublicUrl HOẠT ĐỘNG CHUẨN XÁC
-- ------------------------------------------------------------------------------
UPDATE storage.buckets SET public = true WHERE id = 'issue-images';

DROP POLICY IF EXISTS "Public Access for issue-images" ON storage.objects;
CREATE POLICY "Public Access for issue-images" 
ON storage.objects FOR SELECT 
USING (bucket_id = 'issue-images');


-- 5. SỬA THÔNG BÁO HÓA ĐƠN MỚI HIỂN THỊ 0 ĐỒNG VÀ TRANSACTION RPC
-- ------------------------------------------------------------------------------
-- Gỡ bỏ trigger thông báo vội vã lúc INSERT invoices (khi items chưa được chèn)
DROP TRIGGER IF EXISTS trg_notify_on_new_invoice ON public.invoices;

-- Cập nhật create_invoice_with_items để tính đúng tổng tiền và gửi thông báo chuẩn xác
CREATE OR REPLACE FUNCTION public.create_invoice_with_items(
    p_apartment_id UUID,
    p_period VARCHAR,
    p_due_date DATE,
    p_items JSONB
)
RETURNS UUID AS $$
DECLARE
    v_invoice_id UUID;
    v_item JSONB;
    v_total DECIMAL := 0;
    v_resident RECORD;
    v_apt_code TEXT;
BEGIN
    -- 1. Tạo hóa đơn
    INSERT INTO public.invoices (apartment_id, period, due_date, status)
    VALUES (p_apartment_id, p_period, p_due_date, 'unpaid'::public.invoice_status)
    RETURNING id INTO v_invoice_id;

    -- 2. Chèn từng hạng mục chi phí nếu có
    IF p_items IS NOT NULL AND jsonb_array_length(p_items) > 0 THEN
        FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
        LOOP
            INSERT INTO public.invoice_items (
                invoice_id,
                fee_type,
                unit_price,
                quantity
            ) VALUES (
                v_invoice_id,
                v_item->>'fee_type',
                COALESCE((v_item->>'unit_price')::DECIMAL, 0),
                COALESCE((v_item->>'quantity')::DECIMAL, 1)
            );
        END LOOP;
    END IF;

    -- 3. Cập nhật và lấy tổng tiền chính xác
    SELECT COALESCE(SUM(subtotal), 0) INTO v_total
    FROM public.invoice_items
    WHERE invoice_id = v_invoice_id;

    UPDATE public.invoices
    SET total_amount = v_total
    WHERE id = v_invoice_id;

    -- 4. Gửi thông báo đến toàn bộ cư dân thuộc căn hộ với đúng số tiền thực tế
    SELECT code INTO v_apt_code FROM public.apartments WHERE id = p_apartment_id;

    FOR v_resident IN
        SELECT user_id FROM public.residents_apartments WHERE apartment_id = p_apartment_id
    LOOP
        INSERT INTO public.notifications (
            user_id,
            apartment_id,
            title,
            body,
            type,
            payload
        ) VALUES (
            v_resident.user_id,
            p_apartment_id,
            'Hóa đơn mới kỳ ' || p_period,
            'Căn hộ ' || COALESCE(v_apt_code, 'N/A') || ' vừa nhận được hóa đơn kỳ ' || p_period || 
            ' với tổng tiền ' || to_char(v_total, 'FM999,999,999') || ' đ. Hạn thanh toán: ' || 
            to_char(p_due_date, 'DD/MM/YYYY') || '.',
            'new_invoice',
            jsonb_build_object(
                'invoice_id', v_invoice_id,
                'period', p_period,
                'total_amount', v_total,
                'due_date', p_due_date
            )
        );
    END LOOP;

    RETURN v_invoice_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_catalog;

REVOKE EXECUTE ON FUNCTION public.create_invoice_with_items(UUID, VARCHAR, DATE, JSONB) FROM anon;
