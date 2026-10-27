-- ==============================================================================
-- Migration: 20261004_03_automatic_notifications_triggers.sql
-- Mô tả: Tự động hóa tạo thông báo In-app cho Cư dân & Kỹ thuật viên
-- 1. Trigger thông báo bảo trì thiết bị gián đoạn sinh hoạt (trg_notify_on_equipment_maintenance)
-- 2. Trigger thông báo tiến độ xử lý phản ánh sự cố (trg_notify_on_issue_status_change)
-- ==============================================================================

-- 1. Trigger thông báo Bảo trì thiết bị khi có gián đoạn dịch vụ
CREATE OR REPLACE FUNCTION public.trigger_notify_on_equipment_maintenance()
RETURNS TRIGGER AS $$
DECLARE
    v_eq_name TEXT;
    v_eq_code TEXT;
    v_building TEXT;
    v_resident RECORD;
    v_title TEXT;
    v_body TEXT;
    v_start_str TEXT;
    v_end_str TEXT;
BEGIN
    -- Lấy thông tin thiết bị
    SELECT name, code, building
    INTO v_eq_name, v_eq_code, v_building
    FROM public.building_equipments
    WHERE id = NEW.equipment_id;

    v_eq_name := COALESCE(v_eq_name, 'Thiết bị kỹ thuật');
    v_eq_code := COALESCE(v_eq_code, 'N/A');
    v_building := COALESCE(v_building, 'Toàn khu');

    v_start_str := to_char(NEW.scheduled_start, 'HH24:MI DD/MM/YYYY');
    v_end_str := to_char(NEW.scheduled_end, 'HH24:MI DD/MM/YYYY');

    v_title := 'Bảo trì thiết bị: ' || v_eq_name;
    v_body := 'Thiết bị ' || v_eq_name || ' (' || v_eq_code || ') tại khu vực ' || v_building || 
              ' đang được bảo dưỡng định kỳ và tạm gián đoạn dịch vụ từ ' || v_start_str || 
              ' đến ' || v_end_str || 
              CASE WHEN NEW.service_interruption_note IS NOT NULL AND NEW.service_interruption_note <> ''
                   THEN '. Lưu ý: ' || NEW.service_interruption_note
                   ELSE ''
              END || '.';

    -- Quét danh sách cư dân chịu ảnh hưởng
    IF v_building = 'Toàn khu' OR v_building = '' THEN
        -- Gửi toàn thể cư dân
        FOR v_resident IN
            SELECT DISTINCT user_id FROM public.residents_apartments
        LOOP
            INSERT INTO public.notifications (
                user_id,
                title,
                body,
                type,
                payload
            ) VALUES (
                v_resident.user_id,
                v_title,
                v_body,
                'equipment_maintenance',
                jsonb_build_object(
                    'task_id', NEW.id,
                    'equipment_id', NEW.equipment_id,
                    'equipment_name', v_eq_name,
                    'equipment_code', v_eq_code,
                    'building', v_building,
                    'scheduled_start', NEW.scheduled_start,
                    'scheduled_end', NEW.scheduled_end
                )
            );
        END LOOP;
    ELSE
        -- Gửi cư dân thuộc tòa nhà tương ứng
        FOR v_resident IN
            SELECT DISTINCT ra.user_id 
            FROM public.residents_apartments ra
            JOIN public.apartments a ON a.id = ra.apartment_id
            WHERE a.building_code = v_building 
               OR ('Tòa ' || a.building_code) = v_building
               OR v_building LIKE '%' || a.building_code || '%'
        LOOP
            INSERT INTO public.notifications (
                user_id,
                title,
                body,
                type,
                payload
            ) VALUES (
                v_resident.user_id,
                v_title,
                v_body,
                'equipment_maintenance',
                jsonb_build_object(
                    'task_id', NEW.id,
                    'equipment_id', NEW.equipment_id,
                    'equipment_name', v_eq_name,
                    'equipment_code', v_eq_code,
                    'building', v_building,
                    'scheduled_start', NEW.scheduled_start,
                    'scheduled_end', NEW.scheduled_end
                )
            );
        END LOOP;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_catalog;

DROP TRIGGER IF EXISTS trg_notify_on_equipment_maintenance ON public.equipment_maintenance_tasks;
CREATE TRIGGER trg_notify_on_equipment_maintenance
    AFTER INSERT OR UPDATE ON public.equipment_maintenance_tasks
    FOR EACH ROW
    WHEN (
        NEW.status = 'in_progress' AND NEW.affects_service = true AND
        (TG_OP = 'INSERT' OR OLD.status IS DISTINCT FROM 'in_progress' OR OLD.affects_service IS DISTINCT FROM true)
    )
    EXECUTE FUNCTION public.trigger_notify_on_equipment_maintenance();


-- 2. Trigger thông báo Cập nhật tiến độ xử lý phản ánh sự cố
CREATE OR REPLACE FUNCTION public.trigger_notify_on_issue_status_change()
RETURNS TRIGGER AS $$
DECLARE
    v_title TEXT;
    v_body TEXT;
BEGIN
    -- A. Thông báo cho Cư dân (người phản ánh) khi trạng thái sự cố thay đổi
    IF OLD.status IS DISTINCT FROM NEW.status THEN
        IF NEW.status = 'in_progress' THEN
            v_title := 'Sự cố đã được tiếp nhận xử lý';
            v_body := 'Phản ánh "' || NEW.title || '" của bạn đã được Ban Quản Lý tiếp nhận và cử kỹ thuật viên tiến hành xử lý.';
        ELSIF NEW.status = 'resolved' THEN
            v_title := 'Sự cố đã được xử lý hoàn tất';
            v_body := 'Phản ánh "' || NEW.title || '" đã được xử lý xong. Quý Cư dân vui lòng kiểm tra và gửi đánh giá dịch vụ.';
        ELSIF NEW.status = 'cancelled' THEN
            v_title := 'Phản ánh sự cố đã bị hủy';
            v_body := 'Phản ánh "' || NEW.title || '" đã được Ban Quản Lý cập nhật trạng thái hủy.';
        ELSE
            v_title := 'Cập nhật tiến độ xử lý sự cố';
            v_body := 'Phản ánh "' || NEW.title || '" vừa được cập nhật sang trạng thái: ' || NEW.status || '.';
        END IF;

        IF NEW.reporter_id IS NOT NULL THEN
            INSERT INTO public.notifications (
                user_id,
                title,
                body,
                type,
                payload
            ) VALUES (
                NEW.reporter_id,
                v_title,
                v_body,
                'issue_update',
                jsonb_build_object(
                    'issue_id', NEW.id,
                    'title', NEW.title,
                    'status', NEW.status
                )
            );
        END IF;
    END IF;

    -- B. Thông báo cho Kỹ thuật viên khi được phân công việc mới
    IF NEW.assigned_staff_id IS NOT NULL AND (OLD.assigned_staff_id IS DISTINCT FROM NEW.assigned_staff_id) THEN
        INSERT INTO public.notifications (
            user_id,
            title,
            body,
            type,
            payload
        ) VALUES (
            NEW.assigned_staff_id,
            'Bạn được phân công xử lý sự cố mới',
            'Bạn vừa được Ban Quản Lý phân công xử lý sự cố: "' || NEW.title || '". Vui lòng kiểm tra và tiếp nhận.',
            'issue_update',
            jsonb_build_object(
                'issue_id', NEW.id,
                'title', NEW.title,
                'status', NEW.status
            )
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_catalog;

DROP TRIGGER IF EXISTS trg_notify_on_issue_status_change ON public.issue_reports;
CREATE TRIGGER trg_notify_on_issue_status_change
    AFTER UPDATE ON public.issue_reports
    FOR EACH ROW
    WHEN (
        OLD.status IS DISTINCT FROM NEW.status OR
        (NEW.assigned_staff_id IS NOT NULL AND OLD.assigned_staff_id IS DISTINCT FROM NEW.assigned_staff_id)
    )
    EXECUTE FUNCTION public.trigger_notify_on_issue_status_change();
