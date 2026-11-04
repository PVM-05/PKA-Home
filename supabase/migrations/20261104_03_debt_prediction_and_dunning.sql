-- ============================================================================
-- Migration: 20261104_03_debt_prediction_and_dunning.sql
-- Mô tả: Thuật toán định lượng rủi ro nợ xấu căn hộ (Debt Risk Prediction)
--        và hệ thống đôn đốc đa tầng (Multi-Tier Dunning Strategy)
-- Phân loại: Phase E3 Commercial Product Roadmap
-- ============================================================================

-- 1. Bảng lưu trữ điểm số rủi ro nợ xấu căn hộ
CREATE TABLE IF NOT EXISTS public.debt_risk_scores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    apartment_id UUID NOT NULL REFERENCES public.apartments(id) ON DELETE CASCADE,
    building_id UUID NOT NULL REFERENCES public.buildings(id) ON DELETE CASCADE,
    risk_score INTEGER NOT NULL CHECK (risk_score >= 0 AND risk_score <= 100),
    risk_level VARCHAR(20) NOT NULL CHECK (risk_level IN ('low', 'medium', 'high')),
    overdue_days INTEGER NOT NULL DEFAULT 0,
    unpaid_amount NUMERIC(15, 2) NOT NULL DEFAULT 0,
    monthly_fee_avg NUMERIC(15, 2) NOT NULL DEFAULT 0,
    late_payment_count INTEGER NOT NULL DEFAULT 0,
    recommended_tier VARCHAR(20) NOT NULL CHECK (recommended_tier IN ('tier_1', 'tier_2', 'tier_3')),
    risk_factors JSONB NOT NULL DEFAULT '[]'::jsonb,
    assessed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_debt_risk_apartment UNIQUE (apartment_id)
);

CREATE INDEX IF NOT EXISTS idx_debt_risk_building ON public.debt_risk_scores(building_id);
CREATE INDEX IF NOT EXISTS idx_debt_risk_level ON public.debt_risk_scores(risk_level);
CREATE INDEX IF NOT EXISTS idx_debt_risk_score ON public.debt_risk_scores(risk_score DESC);

-- 2. Bảng nhật ký các hành động đôn đốc công nợ đa tầng
CREATE TABLE IF NOT EXISTS public.dunning_actions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    apartment_id UUID NOT NULL REFERENCES public.apartments(id) ON DELETE CASCADE,
    building_id UUID NOT NULL REFERENCES public.buildings(id) ON DELETE CASCADE,
    tier VARCHAR(20) NOT NULL CHECK (tier IN ('tier_1', 'tier_2', 'tier_3')),
    action_type VARCHAR(50) NOT NULL DEFAULT 'notification',
    action_title TEXT NOT NULL,
    action_content TEXT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'sent' CHECK (status IN ('draft', 'sent', 'acknowledged', 'resolved')),
    performed_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_dunning_apartment ON public.dunning_actions(apartment_id);
CREATE INDEX IF NOT EXISTS idx_dunning_building ON public.dunning_actions(building_id);
CREATE INDEX IF NOT EXISTS idx_dunning_created_at ON public.dunning_actions(created_at DESC);

-- 3. Thiết lập RLS cho các bảng
ALTER TABLE public.debt_risk_scores ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dunning_actions ENABLE ROW LEVEL SECURITY;

-- 3.1 Policy cho debt_risk_scores
-- Nhân viên BQL/Kế toán có quyền xem điểm rủi ro của tòa nhà mình quản lý
CREATE POLICY debt_risk_scores_staff_manage ON public.debt_risk_scores
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.users u
            WHERE u.id = auth.uid()
              AND u.role IN ('admin', 'management', 'accountant')
        )
        OR EXISTS (
            SELECT 1 FROM public.building_memberships bm
            WHERE bm.user_id = auth.uid()
              AND bm.building_id = debt_risk_scores.building_id
              AND bm.is_active = TRUE
              AND bm.role IN ('admin', 'manager', 'accountant')
        )
    );

-- 3.2 Policy cho dunning_actions
-- Nhân viên BQL/Kế toán quản lý toàn bộ hành động đôn đốc của tòa nhà
CREATE POLICY dunning_actions_staff_manage ON public.dunning_actions
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.users u
            WHERE u.id = auth.uid()
              AND u.role IN ('admin', 'management', 'accountant')
        )
        OR EXISTS (
            SELECT 1 FROM public.building_memberships bm
            WHERE bm.user_id = auth.uid()
              AND bm.building_id = dunning_actions.building_id
              AND bm.is_active = TRUE
              AND bm.role IN ('admin', 'manager', 'accountant')
        )
    );

-- Cư dân được xem các đôn đốc nợ gửi tới căn hộ của mình
CREATE POLICY dunning_actions_resident_read ON public.dunning_actions
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.residents_apartments ra
            WHERE ra.apartment_id = dunning_actions.apartment_id
              AND ra.user_id = auth.uid()
        )
    );

-- 4. RPC: calculate_apartment_debt_risk
-- Tính toán tức thời điểm rủi ro nợ xấu cho 1 căn hộ và cập nhật vào debt_risk_scores
CREATE OR REPLACE FUNCTION public.calculate_apartment_debt_risk(
    p_building_id UUID,
    p_apartment_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_calling_user_id UUID;
    v_has_access BOOLEAN;
    v_unpaid_amount NUMERIC(15, 2) := 0;
    v_overdue_days INTEGER := 0;
    v_monthly_fee_avg NUMERIC(15, 2) := 0;
    v_late_payment_count INTEGER := 0;
    v_score_overdue NUMERIC := 0;
    v_score_ratio NUMERIC := 0;
    v_score_history NUMERIC := 0;
    v_total_score INTEGER := 0;
    v_risk_level VARCHAR(20) := 'low';
    v_recommended_tier VARCHAR(20) := 'tier_1';
    v_debt_ratio NUMERIC := 0;
    v_factors JSONB := '[]'::jsonb;
    v_result JSONB;
BEGIN
    v_calling_user_id := auth.uid();

    -- Xác thực quyền
    IF v_calling_user_id IS NOT NULL THEN
        SELECT EXISTS (
            SELECT 1 FROM public.users u
            WHERE u.id = v_calling_user_id
              AND u.role IN ('admin', 'management', 'accountant')
        ) OR EXISTS (
            SELECT 1 FROM public.building_memberships bm
            WHERE bm.user_id = v_calling_user_id
              AND bm.building_id = p_building_id
              AND bm.is_active = TRUE
              AND bm.role IN ('admin', 'manager', 'accountant')
        ) INTO v_has_access;

        IF NOT v_has_access THEN
            RAISE EXCEPTION 'Truy cập bị từ chối: Chỉ Ban Quản Lý hoặc Kế toán mới có quyền tính toán rủi ro nợ xấu';
        END IF;
    END IF;

    -- A. Tính toán số tiền nợ và số ngày quá hạn cao nhất
    SELECT 
        COALESCE(SUM(total_amount), 0),
        COALESCE(MAX(GREATEST(0, (CURRENT_DATE - due_date::date))), 0)
    INTO v_unpaid_amount, v_overdue_days
    FROM public.invoices
    WHERE apartment_id = p_apartment_id
      AND status IN ('unpaid', 'overdue');

    -- B. Tính phí trung bình 1 tháng (lấy bình quân các hóa đơn hợp lệ gần nhất)
    SELECT COALESCE(AVG(total_amount), 0)
    INTO v_monthly_fee_avg
    FROM (
        SELECT total_amount FROM public.invoices
        WHERE apartment_id = p_apartment_id
          AND status != 'cancelled'
        ORDER BY created_at DESC
        LIMIT 6
    ) sub;

    IF v_monthly_fee_avg <= 0 THEN
        v_monthly_fee_avg := 1500000; -- Mức phí cơ sở mặc định 1.500.000đ nếu căn hộ mới
    END IF;

    -- C. Tính số lần từng nộp muộn trong quá khứ (trong 6 hóa đơn đã thanh toán gần nhất)
    SELECT COUNT(*)
    INTO v_late_payment_count
    FROM public.invoices
    WHERE apartment_id = p_apartment_id
      AND status = 'paid'
      AND updated_at::date > due_date::date;

    -- D. Tính điểm thành phần 1: S_overdue (Trọng số 40%)
    IF v_overdue_days = 0 THEN
        v_score_overdue := 0;
    ELSIF v_overdue_days <= 15 THEN
        v_score_overdue := LEAST(40, v_overdue_days * 2.6);
    ELSIF v_overdue_days <= 30 THEN
        v_score_overdue := LEAST(70, 40 + (v_overdue_days - 15) * 2.0);
    ELSE
        v_score_overdue := LEAST(100, 70 + (v_overdue_days - 30) * 1.5);
    END IF;

    -- E. Tính điểm thành phần 2: S_ratio (Trọng số 35%)
    v_debt_ratio := v_unpaid_amount / v_monthly_fee_avg;
    IF v_debt_ratio <= 0 THEN
        v_score_ratio := 0;
    ELSIF v_debt_ratio <= 1.0 THEN
        v_score_ratio := LEAST(40, v_debt_ratio * 40);
    ELSIF v_debt_ratio <= 2.0 THEN
        v_score_ratio := LEAST(70, 40 + (v_debt_ratio - 1.0) * 30);
    ELSE
        v_score_ratio := LEAST(100, 70 + (v_debt_ratio - 2.0) * 30);
    END IF;

    -- F. Tính điểm thành phần 3: S_history (Trọng số 25%)
    IF v_late_payment_count = 0 THEN
        v_score_history := 0;
    ELSIF v_late_payment_count = 1 THEN
        v_score_history := 25;
    ELSIF v_late_payment_count = 2 THEN
        v_score_history := 50;
    ELSIF v_late_payment_count = 3 THEN
        v_score_history := 75;
    ELSE
        v_score_history := 100;
    END IF;

    -- G. Tổng hợp điểm rủi ro từ 0 đến 100
    v_total_score := LEAST(100, GREATEST(0, ROUND(0.40 * v_score_overdue + 0.35 * v_score_ratio + 0.25 * v_score_history)));

    -- H. Xác định cấp độ rủi ro & Tầng đôn đốc
    IF v_total_score >= 70 THEN
        v_risk_level := 'high';
        v_recommended_tier := 'tier_3';
    ELSIF v_total_score >= 40 THEN
        v_risk_level := 'medium';
        v_recommended_tier := 'tier_2';
    ELSE
        v_risk_level := 'low';
        v_recommended_tier := 'tier_1';
    END IF;

    -- Nếu quá hạn nặng > 45 ngày thì tự động nâng lên tier_3
    IF v_overdue_days > 45 THEN
        v_recommended_tier := 'tier_3';
    END IF;

    -- I. Xây dựng danh sách yếu tố rủi ro tiếng Việt
    IF v_overdue_days > 0 THEN
        v_factors := v_factors || jsonb_build_object(
            'factor', 'overdue_duration',
            'label', 'Quá hạn ' || v_overdue_days || ' ngày',
            'severity', CASE WHEN v_overdue_days > 30 THEN 'high' WHEN v_overdue_days > 15 THEN 'medium' ELSE 'low' END
        );
    END IF;

    IF v_debt_ratio >= 1.5 THEN
        v_factors := v_factors || jsonb_build_object(
            'factor', 'debt_ratio',
            'label', 'Nợ vượt ' || ROUND(v_debt_ratio, 1) || ' lần phí định kỳ',
            'severity', CASE WHEN v_debt_ratio >= 2.0 THEN 'high' ELSE 'medium' END
        );
    END IF;

    IF v_late_payment_count >= 2 THEN
        v_factors := v_factors || jsonb_build_object(
            'factor', 'late_history',
            'label', 'Từng nộp muộn ' || v_late_payment_count || ' kỳ trong quá khứ',
            'severity', CASE WHEN v_late_payment_count >= 3 THEN 'high' ELSE 'medium' END
        );
    END IF;

    -- J. Lưu hoặc cập nhật vào bảng debt_risk_scores
    INSERT INTO public.debt_risk_scores (
        apartment_id,
        building_id,
        risk_score,
        risk_level,
        overdue_days,
        unpaid_amount,
        monthly_fee_avg,
        late_payment_count,
        recommended_tier,
        risk_factors,
        assessed_at,
        updated_at
    )
    VALUES (
        p_apartment_id,
        p_building_id,
        v_total_score,
        v_risk_level,
        v_overdue_days,
        v_unpaid_amount,
        v_monthly_fee_avg,
        v_late_payment_count,
        v_recommended_tier,
        v_factors,
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
    )
    ON CONFLICT (apartment_id) DO UPDATE SET
        building_id = EXCLUDED.building_id,
        risk_score = EXCLUDED.risk_score,
        risk_level = EXCLUDED.risk_level,
        overdue_days = EXCLUDED.overdue_days,
        unpaid_amount = EXCLUDED.unpaid_amount,
        monthly_fee_avg = EXCLUDED.monthly_fee_avg,
        late_payment_count = EXCLUDED.late_payment_count,
        recommended_tier = EXCLUDED.recommended_tier,
        risk_factors = EXCLUDED.risk_factors,
        assessed_at = CURRENT_TIMESTAMP,
        updated_at = CURRENT_TIMESTAMP;

    v_result := jsonb_build_object(
        'apartment_id', p_apartment_id,
        'building_id', p_building_id,
        'risk_score', v_total_score,
        'risk_level', v_risk_level,
        'overdue_days', v_overdue_days,
        'unpaid_amount', v_unpaid_amount,
        'monthly_fee_avg', v_monthly_fee_avg,
        'late_payment_count', v_late_payment_count,
        'recommended_tier', v_recommended_tier,
        'risk_factors', v_factors
    );

    RETURN v_result;
END;
$$;

-- 5. RPC: get_building_debt_radar
-- Lấy radar rủi ro toàn bộ các căn hộ có nợ hoặc rủi ro trong tòa nhà
CREATE OR REPLACE FUNCTION public.get_building_debt_radar(
    p_building_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_calling_user_id UUID;
    v_has_access BOOLEAN;
    v_apartments JSONB;
    v_kpi JSONB;
BEGIN
    v_calling_user_id := auth.uid();

    IF v_calling_user_id IS NOT NULL THEN
        SELECT EXISTS (
            SELECT 1 FROM public.users u
            WHERE u.id = v_calling_user_id
              AND u.role IN ('admin', 'management', 'accountant')
        ) OR EXISTS (
            SELECT 1 FROM public.building_memberships bm
            WHERE bm.user_id = v_calling_user_id
              AND bm.building_id = p_building_id
              AND bm.is_active = TRUE
              AND bm.role IN ('admin', 'manager', 'accountant')
        ) INTO v_has_access;

        IF NOT v_has_access THEN
            RAISE EXCEPTION 'Truy cập bị từ chối: Chỉ Ban Quản Lý hoặc Kế toán mới có quyền xem radar rủi ro nợ xấu';
        END IF;
    END IF;

    -- Tự động đánh giá các căn hộ có hóa đơn chưa thanh toán mà chưa được chấm điểm
    PERFORM public.calculate_apartment_debt_risk(a.building_id, a.id)
    FROM public.apartments a
    WHERE a.building_id = p_building_id
      AND EXISTS (
          SELECT 1 FROM public.invoices i
          WHERE i.apartment_id = a.id
            AND i.status IN ('unpaid', 'overdue')
      )
      AND NOT EXISTS (
          SELECT 1 FROM public.debt_risk_scores drs
          WHERE drs.apartment_id = a.id
            AND drs.assessed_at > (CURRENT_TIMESTAMP - INTERVAL '1 hour')
      );

    -- Lấy danh sách căn hộ kèm điểm số và thông tin chủ hộ
    SELECT COALESCE(jsonb_agg(item ORDER BY item->>'risk_score' DESC), '[]'::jsonb)
    INTO v_apartments
    FROM (
        SELECT jsonb_build_object(
            'apartment_id', a.id,
            'apartment_code', a.code,
            'building_id', a.building_id,
            'owner_name', COALESCE(u.full_name, 'Chưa đăng ký'),
            'owner_phone', COALESCE(u.phone, ''),
            'risk_score', COALESCE(drs.risk_score, 0),
            'risk_level', COALESCE(drs.risk_level, 'low'),
            'overdue_days', COALESCE(drs.overdue_days, 0),
            'unpaid_amount', COALESCE(drs.unpaid_amount, 0),
            'monthly_fee_avg', COALESCE(drs.monthly_fee_avg, 0),
            'late_payment_count', COALESCE(drs.late_payment_count, 0),
            'recommended_tier', COALESCE(drs.recommended_tier, 'tier_1'),
            'risk_factors', COALESCE(drs.risk_factors, '[]'::jsonb),
            'last_dunning_tier', (
                SELECT tier FROM public.dunning_actions da
                WHERE da.apartment_id = a.id
                ORDER BY created_at DESC
                LIMIT 1
            ),
            'last_dunning_at', (
                SELECT created_at FROM public.dunning_actions da
                WHERE da.apartment_id = a.id
                ORDER BY created_at DESC
                LIMIT 1
            ),
            'dunning_count', (
                SELECT COUNT(*) FROM public.dunning_actions da
                WHERE da.apartment_id = a.id
            )
        ) AS item
        FROM public.apartments a
        LEFT JOIN public.debt_risk_scores drs ON drs.apartment_id = a.id
        LEFT JOIN public.residents_apartments ra ON ra.apartment_id = a.id AND ra.relation_role = 'owner'
        LEFT JOIN public.users u ON ra.user_id = u.id
        WHERE a.building_id = p_building_id
          AND (COALESCE(drs.unpaid_amount, 0) > 0 OR COALESCE(drs.risk_score, 0) > 0)
    ) sub;

    -- Thống kê KPI radar
    SELECT jsonb_build_object(
        'total_at_risk_apartments', COUNT(*),
        'high_risk_count', COUNT(CASE WHEN drs.risk_level = 'high' THEN 1 END),
        'medium_risk_count', COUNT(CASE WHEN drs.risk_level = 'medium' THEN 1 END),
        'low_risk_count', COUNT(CASE WHEN drs.risk_level = 'low' THEN 1 END),
        'total_overdue_debt', COALESCE(SUM(drs.unpaid_amount), 0),
        'high_risk_debt', COALESCE(SUM(CASE WHEN drs.risk_level = 'high' THEN drs.unpaid_amount ELSE 0 END), 0)
    )
    INTO v_kpi
    FROM public.debt_risk_scores drs
    WHERE drs.building_id = p_building_id
      AND drs.unpaid_amount > 0;

    RETURN jsonb_build_object(
        'building_id', p_building_id,
        'kpi', COALESCE(v_kpi, '{}'::jsonb),
        'apartments', v_apartments
    );
END;
$$;

-- 6. RPC: execute_dunning_action
-- Ghi nhận đôn đốc công nợ và tự động gửi thông báo hệ thống đến cư dân
CREATE OR REPLACE FUNCTION public.execute_dunning_action(
    p_building_id UUID,
    p_apartment_id UUID,
    p_tier VARCHAR,
    p_title TEXT,
    p_content TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_calling_user_id UUID;
    v_has_access BOOLEAN;
    v_action_id UUID;
    v_resident_id UUID;
BEGIN
    v_calling_user_id := auth.uid();

    -- Xác thực quyền kế toán / BQL
    IF v_calling_user_id IS NOT NULL THEN
        SELECT EXISTS (
            SELECT 1 FROM public.users u
            WHERE u.id = v_calling_user_id
              AND u.role IN ('admin', 'management', 'accountant')
        ) OR EXISTS (
            SELECT 1 FROM public.building_memberships bm
            WHERE bm.user_id = v_calling_user_id
              AND bm.building_id = p_building_id
              AND bm.is_active = TRUE
              AND bm.role IN ('admin', 'manager', 'accountant')
        ) INTO v_has_access;

        IF NOT v_has_access THEN
            RAISE EXCEPTION 'Truy cập bị từ chối: Bạn không có quyền thực thi đôn đốc công nợ';
        END IF;
    END IF;

    -- Kiểm tra tier hợp lệ
    IF p_tier NOT IN ('tier_1', 'tier_2', 'tier_3') THEN
        RAISE EXCEPTION 'Cấp độ đôn đốc không hợp lệ: %', p_tier;
    END IF;

    -- Ghi nhật ký vào dunning_actions
    INSERT INTO public.dunning_actions (
        apartment_id,
        building_id,
        tier,
        action_type,
        action_title,
        action_content,
        status,
        performed_by
    )
    VALUES (
        p_apartment_id,
        p_building_id,
        p_tier,
        'notification',
        p_title,
        p_content,
        'sent',
        v_calling_user_id
    )
    RETURNING id INTO v_action_id;

    -- Tự động gửi thông báo đến các cư dân liên kết căn hộ (nếu bảng notifications tồn tại)
    FOR v_resident_id IN
        SELECT user_id FROM public.residents_apartments
        WHERE apartment_id = p_apartment_id
    LOOP
        INSERT INTO public.notifications (
            user_id,
            title,
            body,
            type,
            is_read,
            created_at
        )
        VALUES (
            v_resident_id,
            p_title,
            p_content,
            'payment_reminder',
            FALSE,
            CURRENT_TIMESTAMP
        );
    END LOOP;

    RETURN jsonb_build_object(
        'success', TRUE,
        'action_id', v_action_id,
        'apartment_id', p_apartment_id,
        'tier', p_tier,
        'status', 'sent',
        'created_at', CURRENT_TIMESTAMP
    );
END;
$$;

-- Cấp quyền thực thi các RPC cho authenticated
GRANT EXECUTE ON FUNCTION public.calculate_apartment_debt_risk(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_building_debt_radar(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.execute_dunning_action(UUID, UUID, VARCHAR, TEXT, TEXT) TO authenticated;
