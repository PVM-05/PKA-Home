-- ==============================================================================
-- PKA-HOME: NOTIFICATION AUTOMATION TRIGGERS MIGRATION
-- Migration: 20261028_03_notification_automation_triggers.sql
-- ==============================================================================

-- 1. Trigger 1: Tự động tạo thông báo khi phát hành hóa đơn mới (invoices AFTER INSERT)
CREATE OR REPLACE FUNCTION public.fn_notify_on_new_invoice()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_apt RECORD;
    v_res RECORD;
BEGIN
    -- Lấy thông tin căn hộ / cơ sở
    SELECT code, building_id INTO v_apt 
    FROM public.apartments 
    WHERE id = NEW.apartment_id;

    -- Quét toàn bộ cư dân thuộc căn hộ đó
    FOR v_res IN
        SELECT user_id FROM public.residents_apartments WHERE apartment_id = NEW.apartment_id
    LOOP
        INSERT INTO public.notifications (
            building_id,
            user_id,
            apartment_id,
            title,
            body,
            type,
            payload,
            is_read,
            created_at
        ) VALUES (
            v_apt.building_id,
            v_res.user_id,
            NEW.apartment_id,
            'Thông báo phát hành hóa đơn mới',
            'Hóa đơn kỳ ' || NEW.period || ' cho phòng ' || COALESCE(v_apt.code, '') || ' với số tiền ' || to_char(NEW.total_amount, 'FM999,999,999,999') || ' đ đã được phát hành. Hạn thanh toán: ' || to_char(NEW.due_date, 'DD/MM/YYYY') || '.',
            'new_invoice',
            jsonb_build_object(
                'invoice_id', NEW.id,
                'period', NEW.period,
                'amount', NEW.total_amount,
                'due_date', NEW.due_date
            ),
            false,
            now()
        );
    END LOOP;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_on_new_invoice ON public.invoices;
CREATE TRIGGER trg_notify_on_new_invoice
AFTER INSERT ON public.invoices
FOR EACH ROW
EXECUTE FUNCTION public.fn_notify_on_new_invoice();


-- 2. Trigger 2: Tự động tạo thông báo khi trạng thái phản ánh sự cố thay đổi (issue_reports AFTER UPDATE)
CREATE OR REPLACE FUNCTION public.fn_notify_on_issue_status_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_apt RECORD;
    v_title TEXT;
    v_body TEXT;
    v_desc_snippet TEXT;
BEGIN
    SELECT code, building_id INTO v_apt 
    FROM public.apartments 
    WHERE id = NEW.apartment_id;

    v_desc_snippet := substring(COALESCE(NEW.description, 'Sự cố') from 1 for 35);
    IF length(COALESCE(NEW.description, '')) > 35 THEN
        v_desc_snippet := v_desc_snippet || '...';
    END IF;

    -- Khi trạng thái sự cố thay đổi, gửi cho người gửi phản ánh (reporter)
    IF OLD.status IS DISTINCT FROM NEW.status THEN
        IF NEW.status = 'in_progress' THEN
            v_title := 'Phản ánh sự cố đang được xử lý';
            v_body := 'Phản ánh "' || v_desc_snippet || '" đã được Ban Quản Lý tiếp nhận và đang tiến hành xử lý.';
        ELSIF NEW.status = 'resolved' THEN
            v_title := 'Phản ánh sự cố đã hoàn tất';
            v_body := 'Phản ánh "' || v_desc_snippet || '" đã được khắc phục hoàn tất. Vui lòng kiểm tra và đánh giá dịch vụ.';
        ELSIF NEW.status = 'rejected' THEN
            v_title := 'Thông báo về phản ánh sự cố';
            v_body := 'Phản ánh "' || v_desc_snippet || '" đã được Ban Quản Lý phản hồi/từ chối tiếp nhận.';
        ELSE
            v_title := 'Cập nhật tiến độ phản ánh sự cố';
            v_body := 'Phản ánh "' || v_desc_snippet || '" đã được cập nhật trạng thái mới: ' || NEW.status;
        END IF;

        IF NEW.reporter_id IS NOT NULL THEN
            INSERT INTO public.notifications (
                building_id,
                user_id,
                apartment_id,
                title,
                body,
                type,
                payload,
                is_read,
                created_at
            ) VALUES (
                v_apt.building_id,
                NEW.reporter_id,
                NEW.apartment_id,
                v_title,
                v_body,
                'issue_update',
                jsonb_build_object(
                    'issue_id', NEW.id,
                    'status', NEW.status,
                    'apartment_id', NEW.apartment_id
                ),
                false,
                now()
            );
        END IF;
    END IF;

    -- Nếu có phân công kỹ thuật viên mới, gửi thông báo cho kỹ thuật viên
    IF NEW.assigned_staff_id IS NOT NULL AND (OLD.assigned_staff_id IS DISTINCT FROM NEW.assigned_staff_id) THEN
        INSERT INTO public.notifications (
            building_id,
            user_id,
            apartment_id,
            title,
            body,
            type,
            payload,
            is_read,
            created_at
        ) VALUES (
            v_apt.building_id,
            NEW.assigned_staff_id,
            NEW.apartment_id,
            'Phân công nhiệm vụ xử lý sự cố',
            'Bạn vừa được phân công xử lý sự cố "' || v_desc_snippet || '" tại phòng ' || COALESCE(v_apt.code, '') || '.',
            'issue_update',
            jsonb_build_object(
                'issue_id', NEW.id,
                'status', NEW.status,
                'role', 'technician'
            ),
            false,
            now()
        );
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_on_issue_status_change ON public.issue_reports;
CREATE TRIGGER trg_notify_on_issue_status_change
AFTER UPDATE ON public.issue_reports
FOR EACH ROW
EXECUTE FUNCTION public.fn_notify_on_issue_status_change();


-- 3. Trigger 3: Tự động tạo thông báo khi phê duyệt liên kết căn hộ (apartment_link_requests AFTER UPDATE)
CREATE OR REPLACE FUNCTION public.fn_notify_on_link_request_status()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_apt RECORD;
    v_title TEXT;
    v_body TEXT;
BEGIN
    IF OLD.status IS DISTINCT FROM NEW.status AND NEW.status IN ('approved', 'rejected') THEN
        SELECT code, building_id INTO v_apt 
        FROM public.apartments 
        WHERE id = NEW.apartment_id;

        IF NEW.status = 'approved' THEN
            v_title := 'Yêu cầu liên kết căn hộ đã được phê duyệt';
            v_body := 'Yêu cầu liên kết với căn hộ/phòng ' || COALESCE(v_apt.code, '') || ' của bạn đã được Ban Quản Lý phê duyệt thành công.';
        ELSE
            v_title := 'Yêu cầu liên kết căn hộ không được duyệt';
            v_body := 'Yêu cầu liên kết với căn hộ/phòng ' || COALESCE(v_apt.code, '') || ' đã bị từ chối' || 
                      CASE WHEN NEW.rejection_reason IS NOT NULL AND NEW.rejection_reason != '' 
                           THEN ': ' || NEW.rejection_reason 
                           ELSE '.' 
                      END;
        END IF;

        INSERT INTO public.notifications (
            building_id,
            user_id,
            apartment_id,
            title,
            body,
            type,
            payload,
            is_read,
            created_at
        ) VALUES (
            v_apt.building_id,
            NEW.user_id,
            NEW.apartment_id,
            v_title,
            v_body,
            'link_request',
            jsonb_build_object(
                'request_id', NEW.id,
                'apartment_id', NEW.apartment_id,
                'status', NEW.status,
                'rejection_reason', NEW.rejection_reason
            ),
            false,
            now()
        );
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_on_link_request_status ON public.apartment_link_requests;
CREATE TRIGGER trg_notify_on_link_request_status
AFTER UPDATE ON public.apartment_link_requests
FOR EACH ROW
EXECUTE FUNCTION public.fn_notify_on_link_request_status();


-- 4. Trigger 4: Tự động thông báo xác nhận thanh toán thành công (invoices AFTER UPDATE)
CREATE OR REPLACE FUNCTION public.fn_notify_on_invoice_paid()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_apt RECORD;
    v_res RECORD;
BEGIN
    -- Chỉ kích hoạt khi trạng thái chuyển sang 'paid'
    IF OLD.status IS DISTINCT FROM NEW.status AND NEW.status = 'paid' THEN
        SELECT code, building_id INTO v_apt 
        FROM public.apartments 
        WHERE id = NEW.apartment_id;

        FOR v_res IN
            SELECT user_id FROM public.residents_apartments WHERE apartment_id = NEW.apartment_id
        LOOP
            INSERT INTO public.notifications (
                building_id,
                user_id,
                apartment_id,
                title,
                body,
                type,
                payload,
                is_read,
                created_at
            ) VALUES (
                v_apt.building_id,
                v_res.user_id,
                NEW.apartment_id,
                'Xác nhận thanh toán hóa đơn thành công',
                'Hóa đơn kỳ ' || NEW.period || ' căn hộ ' || COALESCE(v_apt.code, '') || ' số tiền ' || to_char(NEW.total_amount, 'FM999,999,999,999') || ' đ đã được thanh toán thành công. Biên lai điện tử đã sẵn sàng.',
                'payment_success',
                jsonb_build_object(
                    'invoice_id', NEW.id,
                    'period', NEW.period,
                    'amount', NEW.total_amount,
                    'paid_at', now()
                ),
                false,
                now()
            );
        END LOOP;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_on_invoice_paid ON public.invoices;
CREATE TRIGGER trg_notify_on_invoice_paid
AFTER UPDATE ON public.invoices
FOR EACH ROW
EXECUTE FUNCTION public.fn_notify_on_invoice_paid();
