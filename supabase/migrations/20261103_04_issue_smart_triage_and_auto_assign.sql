-- ==============================================================================
-- MIGRATION: 20261103_04_issue_smart_triage_and_auto_assign.sql
-- GIAI ĐOẠN E2: AI PHÂN LOẠI SỰ CỐ & TỰ ĐỘNG GÁN KỸ THUẬT VIÊN
-- ==============================================================================

-- 1. Bổ sung các cột AI Triage vào bảng issue_reports
ALTER TABLE public.issue_reports
    ADD COLUMN IF NOT EXISTS ai_category_confidence NUMERIC(4,3) DEFAULT 0.000,
    ADD COLUMN IF NOT EXISTS ai_suggested_category VARCHAR(50),
    ADD COLUMN IF NOT EXISTS ai_suggested_priority VARCHAR(20),
    ADD COLUMN IF NOT EXISTS ai_triage_reason TEXT,
    ADD COLUMN IF NOT EXISTS is_hazardous BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS auto_assigned BOOLEAN NOT NULL DEFAULT false;

-- 2. Chỉ mục hỗ trợ lọc sự cố theo mức độ nguy hiểm, phân loại và phân công
CREATE INDEX IF NOT EXISTS idx_issue_reports_triage 
    ON public.issue_reports(category, priority, is_hazardous);

CREATE INDEX IF NOT EXISTS idx_issue_reports_auto_assigned 
    ON public.issue_reports(auto_assigned, assigned_staff_id);

-- 3. RPC tự động tìm kỹ thuật viên phù hợp và phân công thông minh (Load balancing)
CREATE OR REPLACE FUNCTION public.triage_and_auto_assign_issue(
    p_issue_id UUID,
    p_auto_assign BOOLEAN DEFAULT true
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_issue RECORD;
    v_best_staff RECORD;
    v_calling_user_id UUID;
    v_is_authorized BOOLEAN := false;
BEGIN
    v_calling_user_id := auth.uid();

    -- Lấy thông tin bản ghi sự cố
    SELECT * INTO v_issue
    FROM public.issue_reports
    WHERE id = p_issue_id
    FOR UPDATE;

    IF NOT FOUND THEN
      RETURN jsonb_build_object(
          'success', false,
          'message', 'Không tìm thấy sự cố kỹ thuật yêu cầu.'
      );
    END IF;

    -- Nếu sự cố chưa được gán và được bật tự động gán
    IF v_issue.assigned_staff_id IS NULL AND p_auto_assign THEN
        -- Tìm nhân viên kỹ thuật có ít sự cố đang xử lý nhất
        SELECT 
            u.id, 
            u.full_name,
            COUNT(i.id) FILTER (WHERE i.status IN ('reported', 'assigned', 'in_progress')) AS active_workload
        INTO v_best_staff
        FROM public.users u
        LEFT JOIN public.issue_reports i ON i.assigned_staff_id = u.id
        WHERE u.role IN ('staff', 'management')
        GROUP BY u.id, u.full_name
        ORDER BY active_workload ASC, u.created_at ASC
        LIMIT 1;

        IF v_best_staff.id IS NOT NULL THEN
            UPDATE public.issue_reports
            SET assigned_staff_id = v_best_staff.id,
                status = 'assigned',
                auto_assigned = true,
                updated_at = now()
            WHERE id = p_issue_id;

            RETURN jsonb_build_object(
                'success', true,
                'issue_id', p_issue_id,
                'auto_assigned', true,
                'assigned_staff_id', v_best_staff.id,
                'assigned_staff_name', v_best_staff.full_name,
                'workload', v_best_staff.active_workload,
                'category', v_issue.category,
                'priority', v_issue.priority,
                'is_hazardous', v_issue.is_hazardous,
                'message', format('Đã tự động phân công sự cố cho kỹ thuật viên %s.', v_best_staff.full_name)
            );
        END IF;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'issue_id', p_issue_id,
        'auto_assigned', false,
        'assigned_staff_id', v_issue.assigned_staff_id,
        'category', v_issue.category,
        'priority', v_issue.priority,
        'is_hazardous', v_issue.is_hazardous,
        'message', 'Thông tin sự cố đã được phân loại thành công.'
    );
END;
$$;

-- 4. Cấp quyền thực thi RPC cho người dùng đã xác thực
GRANT EXECUTE ON FUNCTION public.triage_and_auto_assign_issue(UUID, BOOLEAN) TO authenticated;
