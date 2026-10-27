-- Khởi tạo Enum Types
CREATE TYPE user_role AS ENUM ('resident', 'management');
CREATE TYPE relation_type AS ENUM ('owner', 'tenant');
CREATE TYPE invoice_status AS ENUM ('unpaid', 'pending_confirmation', 'paid');
CREATE TYPE issue_status AS ENUM ('pending', 'in_progress', 'resolved');

-- 1. Bảng users
CREATE TABLE public.users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name VARCHAR NOT NULL,
    phone VARCHAR,
    role user_role NOT NULL DEFAULT 'resident',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Trigger cập nhật updated_at cho users
CREATE OR REPLACE FUNCTION update_modified_column() 
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_users_modtime
    BEFORE UPDATE ON public.users
    FOR EACH ROW
    EXECUTE FUNCTION update_modified_column();

-- Function tự động thêm user vào public.users khi đăng ký từ auth.users
CREATE OR REPLACE FUNCTION public.handle_new_user() 
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.users (id, full_name, role)
  VALUES (
    new.id, 
    coalesce(new.raw_user_meta_data->>'full_name', 'Người dùng mới'), 
    coalesce((new.raw_user_meta_data->>'role')::public.user_role, 'resident'::public.user_role)
  );
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger cho hàm handle_new_user
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- 2. Bảng apartments
CREATE TABLE public.apartments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR UNIQUE NOT NULL,
    area DECIMAL,
    is_empty BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
CREATE TRIGGER update_apartments_modtime BEFORE UPDATE ON public.apartments FOR EACH ROW EXECUTE FUNCTION update_modified_column();

-- 3. Bảng residents_apartments (Trung gian N-N)
CREATE TABLE public.residents_apartments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    apartment_id UUID REFERENCES public.apartments(id) ON DELETE CASCADE,
    relation_role relation_type NOT NULL DEFAULT 'owner',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, apartment_id)
);
CREATE TRIGGER update_residents_apartments_modtime BEFORE UPDATE ON public.residents_apartments FOR EACH ROW EXECUTE FUNCTION update_modified_column();

-- 4. Bảng invoices
CREATE TABLE public.invoices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    apartment_id UUID REFERENCES public.apartments(id) ON DELETE CASCADE,
    period VARCHAR NOT NULL, -- Ví dụ: '08/2026'
    due_date DATE,
    total_amount DECIMAL DEFAULT 0,
    status invoice_status DEFAULT 'unpaid',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
CREATE TRIGGER update_invoices_modtime BEFORE UPDATE ON public.invoices FOR EACH ROW EXECUTE FUNCTION update_modified_column();

-- 5. Bảng invoice_items
CREATE TABLE public.invoice_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invoice_id UUID REFERENCES public.invoices(id) ON DELETE CASCADE,
    fee_type VARCHAR NOT NULL,
    unit_price DECIMAL DEFAULT 0,
    quantity DECIMAL DEFAULT 1,
    subtotal DECIMAL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
CREATE TRIGGER update_invoice_items_modtime BEFORE UPDATE ON public.invoice_items FOR EACH ROW EXECUTE FUNCTION update_modified_column();

-- 6. Bảng issue_reports
CREATE TABLE public.issue_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    apartment_id UUID REFERENCES public.apartments(id) ON DELETE CASCADE,
    reporter_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    assigned_staff_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    status issue_status DEFAULT 'pending',
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
CREATE TRIGGER update_issue_reports_modtime BEFORE UPDATE ON public.issue_reports FOR EACH ROW EXECUTE FUNCTION update_modified_column();

-- 7. Bảng issue_images
CREATE TABLE public.issue_images (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    issue_report_id UUID REFERENCES public.issue_reports(id) ON DELETE CASCADE,
    image_url VARCHAR NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
CREATE TRIGGER update_issue_images_modtime BEFORE UPDATE ON public.issue_images FOR EACH ROW EXECUTE FUNCTION update_modified_column();

-- 8. Bảng announcements
CREATE TABLE public.announcements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR NOT NULL,
    content TEXT,
    is_urgent BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
CREATE TRIGGER update_announcements_modtime BEFORE UPDATE ON public.announcements FOR EACH ROW EXECUTE FUNCTION update_modified_column();

-- =========================================================================
-- Trigger tính tổng tiền hóa đơn (total_amount) tự động
-- =========================================================================
CREATE OR REPLACE FUNCTION public.recalc_invoice_total() RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.invoices SET total_amount = (
    SELECT COALESCE(SUM(subtotal), 0) FROM public.invoice_items 
    WHERE invoice_id = COALESCE(NEW.invoice_id, OLD.invoice_id)
  ) WHERE id = COALESCE(NEW.invoice_id, OLD.invoice_id);
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_recalc_invoice_total
AFTER INSERT OR UPDATE OR DELETE ON public.invoice_items
FOR EACH ROW EXECUTE FUNCTION public.recalc_invoice_total();

-- =========================================================================
-- RPC xác nhận thanh toán an toàn (Tránh user tự update amount)
-- =========================================================================
CREATE OR REPLACE FUNCTION public.confirm_payment(p_invoice_id UUID)
RETURNS void AS $$
BEGIN
  UPDATE public.invoices 
  SET status = 'pending_confirmation'::invoice_status, updated_at = NOW()
  WHERE id = p_invoice_id 
  AND EXISTS (
    SELECT 1 FROM public.residents_apartments 
    WHERE apartment_id = invoices.apartment_id AND user_id = auth.uid()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
