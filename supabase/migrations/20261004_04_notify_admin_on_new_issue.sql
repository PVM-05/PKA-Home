-- Migration: Tự động gửi thông báo cho Ban Quản Lý khi Cư Dân tạo phản ánh sự cố mới hoặc xác nhận thanh toán
-- File: supabase/migrations/20261004_04_notify_admin_on_new_issue.sql

-- 1. Hàm trigger xử lý toàn bộ vòng đời phản ánh sự cố (Tạo mới, Cập nhật trạng thái, Phân công)
CREATE OR REPLACE FUNCTION public.trigger_notify_on_issue_lifecycle()
RETURNS TRIGGER AS $$
DECLARE
    v_apt_code TEXT;
    v_title TEXT;
    v_body TEXT;
BEGIN
    -- Lấy mã căn hộ
    SELECT code INTO v_apt_code FROM public.apartments WHERE id = NEW.apartment_id;

    -- =========================================================================
    -- A. KHI CƯ DÂN TẠO PHẢN ÁNH MỚI (INSERT) -> BÁO CHO BAN QUẢN LÝ & KỸ THUẬT VIÊN
    -- =========================================================================
    IF TG_OP = 'INSERT' THEN
        IF NEW.priority = 'urgent' THEN
            v_title := '🚨 PHẢN ÁNH KHẨN: Căn hộ ' || COALESCE(v_apt_code, 'N/A');
        ELSE
            v_title := 'Phản ánh sự cố mới: Căn hộ ' || COALESCE(v_apt_code, 'N/A');
        END IF;

        v_body := LEFT(COALESCE(NEW.description, 'Cư dân vừa gửi một phản ánh sự cố mới.'), 120);

        INSERT INTO public.notifications (
            user_id,
            apartment_id,
            title,
            body,
            type,
            payload
        )
        SELECT 
            u.id,
            NEW.apartment_id,
            v_title,
            v_body,
            'issue_update',
            jsonb_build_object(
                'issue_id', NEW.id,
                'apartment_id', NEW.apartment_id,
                'priority', NEW.priority
            )
        FROM public.users u
        WHERE u.role IN ('admin', 'management', 'technician');

        RETURN NEW;
    END IF;

    -- =========================================================================
    -- B. KHI BAN QUẢN LÝ CẬP NHẬT TRẠNG THÁI SỰ CỐ (UPDATE) -> BÁO CHO CƯ DÂN
    -- =========================================================================
    IF TG_OP = 'UPDATE' THEN
        IF OLD.status IS DISTINCT FROM NEW.status THEN
            IF NEW.status = 'in_progress' THEN
                v_title := 'Sự cố đang được tiếp nhận xử lý';
                v_body := 'Phản ánh "' || LEFT(COALESCE(NEW.description, 'sự cố'), 50) || '..." đang được Ban Quản Lý xử lý.';
            ELSIF NEW.status = 'resolved' THEN
                v_title := 'Sự cố đã được giải quyết hoàn tất';
                v_body := 'Phản ánh "' || LEFT(COALESCE(NEW.description, 'sự cố'), 50) || '..." đã được giải quyết xong. Quý Cư dân vui lòng đánh giá chất lượng dịch vụ.';
            ELSIF NEW.status = 'cancelled' THEN
                v_title := 'Phản ánh sự cố đã bị hủy';
                v_body := 'Phản ánh "' || LEFT(COALESCE(NEW.description, 'sự cố'), 50) || '..." đã được Ban Quản Lý cập nhật trạng thái hủy.';
            ELSE
                v_title := 'Cập nhật tiến độ xử lý sự cố';
                v_body := 'Phản ánh "' || LEFT(COALESCE(NEW.description, 'sự cố'), 50) || '..." chuyển sang trạng thái: ' || NEW.status || '.';
            END IF;

            IF NEW.reporter_id IS NOT NULL THEN
                INSERT INTO public.notifications (
                    user_id,
                    apartment_id,
                    title,
                    body,
                    type,
                    payload
                ) VALUES (
                    NEW.reporter_id,
                    NEW.apartment_id,
                    v_title,
                    v_body,
                    'issue_update',
                    jsonb_build_object(
                        'issue_id', NEW.id,
                        'status', NEW.status
                    )
                );
            END IF;
        END IF;

        -- =========================================================================
        -- C. KHI BAN QUẢN LÝ PHÂN CÔNG KỸ THUẬT VIÊN -> BÁO CHO KỸ THUẬT VIÊN ĐƯỢC CHỈ ĐỊNH
        -- =========================================================================
        IF NEW.assigned_staff_id IS NOT NULL AND (OLD.assigned_staff_id IS DISTINCT FROM NEW.assigned_staff_id) THEN
            INSERT INTO public.notifications (
                user_id,
                apartment_id,
                title,
                body,
                type,
                payload
            ) VALUES (
                NEW.assigned_staff_id,
                NEW.apartment_id,
                'Bạn được phân công xử lý sự cố mới',
                'Bạn vừa được Ban Quản Lý phân công xử lý sự cố tại Căn hộ ' || COALESCE(v_apt_code, 'N/A') || ': "' || LEFT(COALESCE(NEW.description, ''), 50) || '...".',
                'issue_update',
                jsonb_build_object(
                    'issue_id', NEW.id,
                    'status', NEW.status
                )
            );
        END IF;

        RETURN NEW;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_catalog;

-- Áp dụng trigger cho bảng issue_reports
DROP TRIGGER IF EXISTS trg_notify_on_issue_lifecycle ON public.issue_reports;
CREATE TRIGGER trg_notify_on_issue_lifecycle
    AFTER INSERT OR UPDATE ON public.issue_reports
    FOR EACH ROW
    EXECUTE FUNCTION public.trigger_notify_on_issue_lifecycle();


-- 2. Hàm trigger thông báo cho Kế toán & Quản trị khi Cư dân xác nhận đã thanh toán hóa đơn
CREATE OR REPLACE FUNCTION public.trigger_notify_on_invoice_payment_submission()
RETURNS TRIGGER AS $$
DECLARE
    v_apt_code TEXT;
BEGIN
    IF OLD.status IS DISTINCT FROM NEW.status AND NEW.status = 'pending_confirmation' THEN
        SELECT code INTO v_apt_code FROM public.apartments WHERE id = NEW.apartment_id;

        INSERT INTO public.notifications (
            user_id,
            apartment_id,
            title,
            body,
            type,
            payload
        )
        SELECT 
            u.id,
            NEW.apartment_id,
            'Xác nhận thanh toán mới: Căn hộ ' || COALESCE(v_apt_code, 'N/A'),
            'Cư dân căn hộ ' || COALESCE(v_apt_code, 'N/A') || ' vừa xác nhận thanh toán hóa đơn kỳ ' || NEW.period || '. Vui lòng đối soát.',
            'new_invoice',
            jsonb_build_object(
                'invoice_id', NEW.id,
                'period', NEW.period
            )
        FROM public.users u
        WHERE u.role IN ('admin', 'accountant', 'management');
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_catalog;

-- Áp dụng trigger cho bảng invoices
DROP TRIGGER IF EXISTS trg_notify_on_invoice_payment_submission ON public.invoices;
CREATE TRIGGER trg_notify_on_invoice_payment_submission
    AFTER UPDATE ON public.invoices
    FOR EACH ROW
    WHEN (OLD.status IS DISTINCT FROM NEW.status AND NEW.status = 'pending_confirmation')
    EXECUTE FUNCTION public.trigger_notify_on_invoice_payment_submission();
