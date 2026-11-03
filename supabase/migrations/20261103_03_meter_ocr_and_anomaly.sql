-- ==============================================================================
-- MIGRATION: 20261103_03_meter_ocr_and_anomaly.sql
-- GIAI ĐOẠN E1: OCR ĐỒNG HỒ ĐIỆN NƯỚC & CẢNH BÁO TIÊU THỤ BẤT THƯỜNG
-- ==============================================================================

-- 1. Bổ sung các cột thông tin điện nước, OCR và phát hiện bất thường vào bảng meter_reading_submissions
ALTER TABLE public.meter_reading_submissions
    ADD COLUMN IF NOT EXISTS electric_reading NUMERIC(10,2) DEFAULT 0.0,
    ADD COLUMN IF NOT EXISTS water_reading NUMERIC(10,2) DEFAULT 0.0,
    ADD COLUMN IF NOT EXISTS electric_image_url TEXT,
    ADD COLUMN IF NOT EXISTS water_image_url TEXT,
    ADD COLUMN IF NOT EXISTS ocr_confidence NUMERIC(4,3) DEFAULT 0.950,
    ADD COLUMN IF NOT EXISTS is_anomaly BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS anomaly_severity VARCHAR(20) NOT NULL DEFAULT 'normal',
    ADD COLUMN IF NOT EXISTS anomaly_reason TEXT,
    ADD COLUMN IF NOT EXISTS previous_electric_reading NUMERIC(10,2),
    ADD COLUMN IF NOT EXISTS previous_water_reading NUMERIC(10,2),
    ADD COLUMN IF NOT EXISTS avg_electric_usage NUMERIC(10,2),
    ADD COLUMN IF NOT EXISTS avg_water_usage NUMERIC(10,2);

-- 2. Chỉ mục tối ưu cho việc truy vấn và lọc các bản ghi có cờ bất thường
CREATE INDEX IF NOT EXISTS idx_meter_submissions_anomaly 
    ON public.meter_reading_submissions(apartment_id, is_anomaly, status);

CREATE INDEX IF NOT EXISTS idx_meter_submissions_period_status
    ON public.meter_reading_submissions(period, status);

-- 3. RPC tính toán và phát hiện bất thường: detect_meter_reading_anomaly
CREATE OR REPLACE FUNCTION public.detect_meter_reading_anomaly(
    p_apartment_id UUID,
    p_electric_reading NUMERIC,
    p_water_reading NUMERIC,
    p_period VARCHAR DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_prev_sub RECORD;
    v_avg_elec NUMERIC := NULL;
    v_avg_water NUMERIC := NULL;
    v_is_anomaly BOOLEAN := false;
    v_severity VARCHAR(20) := 'normal';
    v_reasons TEXT[] := ARRAY[]::TEXT[];
    v_elec_delta NUMERIC := 0.0;
    v_water_delta NUMERIC := 0.0;
    v_elec_pct NUMERIC := NULL;
    v_water_pct NUMERIC := NULL;
BEGIN
    -- Lấy bản ghi đã duyệt gần nhất của căn hộ
    SELECT electric_reading, water_reading INTO v_prev_sub
    FROM public.meter_reading_submissions
    WHERE apartment_id = p_apartment_id
      AND status = 'approved'
      AND (p_period IS NULL OR period < p_period)
    ORDER BY created_at DESC
    LIMIT 1;

    -- Lấy mức tiêu thụ trung bình 3 kỳ đã duyệt gần nhất
    WITH recent_readings AS (
        SELECT 
            electric_reading - LAG(electric_reading) OVER (ORDER BY created_at) AS e_diff,
            water_reading - LAG(water_reading) OVER (ORDER BY created_at) AS w_diff
        FROM public.meter_reading_submissions
        WHERE apartment_id = p_apartment_id
          AND status = 'approved'
          AND (p_period IS NULL OR period < p_period)
        ORDER BY created_at DESC
        LIMIT 4
    )
    SELECT 
        ROUND(AVG(e_diff)::numeric, 1),
        ROUND(AVG(w_diff)::numeric, 1)
    INTO v_avg_elec, v_avg_water
    FROM recent_readings
    WHERE e_diff IS NOT NULL AND w_diff IS NOT NULL AND e_diff >= 0 AND w_diff >= 0;

    -- Kiểm tra điện
    IF v_prev_sub.electric_reading IS NOT NULL THEN
        v_elec_delta := p_electric_reading - v_prev_sub.electric_reading;
        
        -- Chỉ số lùi (nguy hiểm)
        IF v_elec_delta < 0 THEN
            v_is_anomaly := true;
            v_severity := 'danger';
            v_reasons := array_append(v_reasons, format('Chỉ số điện mới (%s kWh) nhỏ hơn chỉ số kỳ trước (%s kWh).', p_electric_reading, v_prev_sub.electric_reading));
        ELSIF v_avg_elec IS NOT NULL AND v_avg_elec > 0 THEN
            v_elec_pct := ROUND(((v_elec_delta - v_avg_elec) / v_avg_elec * 100)::numeric, 1);
            IF v_elec_delta >= v_avg_elec * 2.5 AND (v_elec_delta - v_avg_elec) >= 40 THEN
                v_is_anomaly := true;
                v_severity := 'danger';
                v_reasons := array_append(v_reasons, format('Tiêu thụ điện tăng đột biến %s%% (%s kWh so với trung bình %s kWh).', v_elec_pct, v_elec_delta, v_avg_elec));
            ELSIF v_elec_delta >= v_avg_elec * 1.5 AND (v_elec_delta - v_avg_elec) >= 20 THEN
                v_is_anomaly := true;
                IF v_severity <> 'danger' THEN v_severity := 'warning'; END IF;
                v_reasons := array_append(v_reasons, format('Tiêu thụ điện tăng cao %s%% so với mức trung bình (%s kWh).', v_elec_pct, v_avg_elec));
            END IF;
        END IF;
    END IF;

    -- Kiểm tra nước
    IF v_prev_sub.water_reading IS NOT NULL THEN
        v_water_delta := p_water_reading - v_prev_sub.water_reading;
        
        -- Chỉ số lùi (nguy hiểm)
        IF v_water_delta < 0 THEN
            v_is_anomaly := true;
            v_severity := 'danger';
            v_reasons := array_append(v_reasons, format('Chỉ số nước mới (%s m³) nhỏ hơn chỉ số kỳ trước (%s m³).', p_water_reading, v_prev_sub.water_reading));
        ELSIF v_avg_water IS NOT NULL AND v_avg_water > 0 THEN
            v_water_pct := ROUND(((v_water_delta - v_avg_water) / v_avg_water * 100)::numeric, 1);
            IF v_water_delta >= v_avg_water * 2.5 AND (v_water_delta - v_avg_water) >= 5 THEN
                v_is_anomaly := true;
                v_severity := 'danger';
                v_reasons := array_append(v_reasons, format('Tiêu thụ nước tăng đột biến %s%% (%s m³ so với trung bình %s m³ - Nghi ngờ rò rỉ).', v_water_pct, v_water_delta, v_avg_water));
            ELSIF v_water_delta >= v_avg_water * 1.5 AND (v_water_delta - v_avg_water) >= 3 THEN
                v_is_anomaly := true;
                IF v_severity <> 'danger' THEN v_severity := 'warning'; END IF;
                v_reasons := array_append(v_reasons, format('Tiêu thụ nước tăng cao %s%% so với mức trung bình (%s m³).', v_water_pct, v_avg_water));
            END IF;
        END IF;
    END IF;

    RETURN jsonb_build_object(
        'is_anomaly', v_is_anomaly,
        'anomaly_severity', v_severity,
        'anomaly_reason', array_to_string(v_reasons, ' | '),
        'previous_electric_reading', v_prev_sub.electric_reading,
        'previous_water_reading', v_prev_sub.water_reading,
        'avg_electric_usage', v_avg_elec,
        'avg_water_usage', v_avg_water,
        'electric_delta', v_elec_delta,
        'water_delta', v_water_delta,
        'electric_percent_change', v_elec_pct,
        'water_percent_change', v_water_pct
    );
END;
$$;

-- 4. Trigger Function tự động tính toán và gắn cờ khi INSERT hoặc UPDATE chỉ số
CREATE OR REPLACE FUNCTION public.fn_check_meter_reading_anomaly()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_analysis JSONB;
BEGIN
    -- Gọi RPC phân tích bất thường
    v_analysis := public.detect_meter_reading_anomaly(
        NEW.apartment_id,
        COALESCE(NEW.electric_reading, 0.0),
        COALESCE(NEW.water_reading, 0.0),
        NEW.period
    );

    NEW.is_anomaly := COALESCE((v_analysis->>'is_anomaly')::boolean, false);
    NEW.anomaly_severity := COALESCE(v_analysis->>'anomaly_severity', 'normal');
    NEW.anomaly_reason := v_analysis->>'anomaly_reason';
    NEW.previous_electric_reading := (v_analysis->>'previous_electric_reading')::numeric;
    NEW.previous_water_reading := (v_analysis->>'previous_water_reading')::numeric;
    NEW.avg_electric_usage := (v_analysis->>'avg_electric_usage')::numeric;
    NEW.avg_water_usage := (v_analysis->>'avg_water_usage')::numeric;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_check_meter_reading_anomaly ON public.meter_reading_submissions;
CREATE TRIGGER trg_check_meter_reading_anomaly
    BEFORE INSERT OR UPDATE OF electric_reading, water_reading
    ON public.meter_reading_submissions
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_check_meter_reading_anomaly();

-- 5. Cấp quyền truy cập cho authenticated users
GRANT EXECUTE ON FUNCTION public.detect_meter_reading_anomaly(UUID, NUMERIC, NUMERIC, VARCHAR) TO authenticated;
