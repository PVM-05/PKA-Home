-- ============================================================================
-- Migration: 20261030_01_financial_aging_report_rpc.sql
-- Mô tả: RPC get_financial_aging_report tính toán dòng tiền, gom nhóm 4 xô tuổi nợ (0-30, 31-60, 61-90, >90 ngày),
--        tỷ lệ thu hồi theo Block, và danh sách con nợ cho BQL (Thuộc Giai đoạn C6 Commercial Roadmap).
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_financial_aging_report(
    p_building_id UUID DEFAULT NULL,
    p_period TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_calling_user_id UUID;
    v_is_authorized BOOLEAN;
    v_result JSONB;
BEGIN
    -- 1. Xác thực phân quyền: Chỉ Admin, Ban Quản Lý hoặc Kế toán
    v_calling_user_id := auth.uid();
    
    SELECT EXISTS (
        SELECT 1 FROM public.users
        WHERE id = v_calling_user_id
          AND role IN ('admin', 'management', 'accountant')
    ) INTO v_is_authorized;

    IF NOT v_is_authorized THEN
        -- Kiểm tra quyền ủy quyền (role_delegations)
        SELECT EXISTS (
            SELECT 1 FROM public.role_delegations
            WHERE delegate_id = v_calling_user_id
              AND is_active = TRUE
              AND (expires_at IS NULL OR expires_at > CURRENT_TIMESTAMP)
              AND delegated_role IN ('admin', 'management', 'accountant')
        ) INTO v_is_authorized;
    END IF;

    -- Cho phép chạy nếu caller được cấp quyền hoặc chạy dưới supabase admin/service role
    IF NOT v_is_authorized AND v_calling_user_id IS NOT NULL THEN
        RAISE EXCEPTION 'Truy cập bị từ chối: Chỉ Ban Quản Lý hoặc Kế toán mới có quyền xem báo cáo tài chính';
    END IF;

    -- 2. Gom nhóm tính toán dữ liệu tài chính & tuổi nợ
    WITH filtered_invoices AS (
        SELECT 
            i.id,
            i.apartment_id,
            i.period,
            i.total_amount,
            i.status,
            i.due_date,
            a.code AS apartment_code,
            a.building_id,
            COALESCE(u.full_name, 'Chưa đăng ký') AS owner_name,
            COALESCE(u.phone, '') AS owner_phone,
            GREATEST(0, (CURRENT_DATE - i.due_date::date)) AS days_overdue
        FROM public.invoices i
        JOIN public.apartments a ON i.apartment_id = a.id
        LEFT JOIN public.residents_apartments ra ON ra.apartment_id = a.id AND ra.relation_role = 'owner'
        LEFT JOIN public.users u ON ra.user_id = u.id
        WHERE i.status != 'cancelled'
          AND (p_building_id IS NULL OR a.building_id = p_building_id)
          AND (p_period IS NULL OR i.period = p_period)
    ),
    summary_calc AS (
        SELECT
            COALESCE(SUM(total_amount), 0) AS total_billed,
            COALESCE(SUM(CASE WHEN status = 'paid' THEN total_amount ELSE 0 END), 0) AS actual_collected,
            COALESCE(SUM(CASE WHEN status IN ('unpaid', 'overdue') THEN total_amount ELSE 0 END), 0) AS total_outstanding,
            COUNT(id) AS total_invoice_count,
            COUNT(CASE WHEN status = 'paid' THEN 1 END) AS paid_invoice_count,
            COUNT(CASE WHEN status IN ('unpaid', 'overdue') THEN 1 END) AS unpaid_invoice_count
        FROM filtered_invoices
    ),
    aging_calc AS (
        SELECT
            -- 0-30 ngày
            COALESCE(SUM(CASE WHEN status IN ('unpaid', 'overdue') AND days_overdue BETWEEN 0 AND 30 THEN total_amount ELSE 0 END), 0) AS amount_0_30,
            COUNT(CASE WHEN status IN ('unpaid', 'overdue') AND days_overdue BETWEEN 0 AND 30 THEN 1 END) AS count_0_30,
            -- 31-60 ngày
            COALESCE(SUM(CASE WHEN status IN ('unpaid', 'overdue') AND days_overdue BETWEEN 31 AND 60 THEN total_amount ELSE 0 END), 0) AS amount_31_60,
            COUNT(CASE WHEN status IN ('unpaid', 'overdue') AND days_overdue BETWEEN 31 AND 60 THEN 1 END) AS count_31_60,
            -- 61-90 ngày
            COALESCE(SUM(CASE WHEN status IN ('unpaid', 'overdue') AND days_overdue BETWEEN 61 AND 90 THEN total_amount ELSE 0 END), 0) AS amount_61_90,
            COUNT(CASE WHEN status IN ('unpaid', 'overdue') AND days_overdue BETWEEN 61 AND 90 THEN 1 END) AS count_61_90,
            -- > 90 ngày
            COALESCE(SUM(CASE WHEN status IN ('unpaid', 'overdue') AND days_overdue > 90 THEN total_amount ELSE 0 END), 0) AS amount_over_90,
            COUNT(CASE WHEN status IN ('unpaid', 'overdue') AND days_overdue > 90 THEN 1 END) AS count_over_90
        FROM filtered_invoices
    ),
    debtors AS (
        SELECT
            apartment_id,
            apartment_code,
            owner_name,
            owner_phone,
            SUM(total_amount) AS total_debt,
            MAX(days_overdue) AS max_days_overdue,
            COUNT(id) AS unpaid_invoices_count,
            MIN(due_date) AS oldest_due_date,
            CASE 
                WHEN MAX(days_overdue) > 90 THEN 'over_90'
                WHEN MAX(days_overdue) >= 61 THEN '61_90'
                WHEN MAX(days_overdue) >= 31 THEN '31_60'
                ELSE '0_30'
            END AS risk_level
        FROM filtered_invoices
        WHERE status IN ('unpaid', 'overdue')
        GROUP BY apartment_id, apartment_code, owner_name, owner_phone
        ORDER BY total_debt DESC, max_days_overdue DESC
    ),
    collection_by_block AS (
        SELECT
            COALESCE(SUBSTRING(apartment_code FROM '^[A-Za-z]+'), 'Chung') AS block_name,
            COALESCE(SUM(total_amount), 0) AS block_billed,
            COALESCE(SUM(CASE WHEN status = 'paid' THEN total_amount ELSE 0 END), 0) AS block_collected,
            COALESCE(SUM(CASE WHEN status IN ('unpaid', 'overdue') THEN total_amount ELSE 0 END), 0) AS block_outstanding,
            CASE 
                WHEN SUM(total_amount) > 0 THEN ROUND((SUM(CASE WHEN status = 'paid' THEN total_amount ELSE 0 END)::numeric / SUM(total_amount)::numeric) * 100, 2)
                ELSE 0 
            END AS collection_rate
        FROM filtered_invoices
        GROUP BY COALESCE(SUBSTRING(apartment_code FROM '^[A-Za-z]+'), 'Chung')
        ORDER BY block_name
    )
    SELECT jsonb_build_object(
        'generated_at', CURRENT_TIMESTAMP,
        'filter_building_id', p_building_id,
        'filter_period', p_period,
        'summary', (
            SELECT jsonb_build_object(
                'total_billed', total_billed,
                'actual_collected', actual_collected,
                'total_outstanding', total_outstanding,
                'total_invoice_count', total_invoice_count,
                'paid_invoice_count', paid_invoice_count,
                'unpaid_invoice_count', unpaid_invoice_count,
                'collection_rate', CASE WHEN total_billed > 0 THEN ROUND((actual_collected::numeric / total_billed::numeric) * 100, 2) ELSE 0 END
            ) FROM summary_calc
        ),
        'aging_buckets', (
            SELECT jsonb_build_object(
                'bucket_0_30', jsonb_build_object('amount', amount_0_30, 'count', count_0_30),
                'bucket_31_60', jsonb_build_object('amount', amount_31_60, 'count', count_31_60),
                'bucket_61_90', jsonb_build_object('amount', amount_61_90, 'count', count_61_90),
                'bucket_over_90', jsonb_build_object('amount', amount_over_90, 'count', count_over_90)
            ) FROM aging_calc
        ),
        'collection_by_block', (
            SELECT COALESCE(jsonb_agg(to_jsonb(b)), '[]'::jsonb) FROM collection_by_block b
        ),
        'debtors', (
            SELECT COALESCE(jsonb_agg(to_jsonb(d)), '[]'::jsonb) FROM debtors d
        )
    ) INTO v_result;

    RETURN v_result;
END;
$$;

-- Cấp quyền gọi hàm cho người dùng đã xác thực
GRANT EXECUTE ON FUNCTION public.get_financial_aging_report(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_financial_aging_report(UUID, TEXT) TO service_role;

