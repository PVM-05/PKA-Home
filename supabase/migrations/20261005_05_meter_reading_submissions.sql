-- ==============================================================================
-- Migration: Bảng Khai Báo Chỉ Số Điện Nước Cư Dân & RPC Phê Duyệt / Hóa Đơn
-- Ngày tạo: 2026-10-05
-- ==============================================================================

-- 1. Bảng lưu trữ lượt gửi chỉ số điện nước từ cư dân
CREATE TABLE IF NOT EXISTS public.meter_reading_submissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    apartment_id UUID NOT NULL REFERENCES public.apartments(id) ON DELETE CASCADE,
    submitted_by UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    period TEXT NOT NULL, -- Định dạng: '10/2026'
    electric_reading NUMERIC NOT NULL CHECK (electric_reading >= 0),
    water_reading NUMERIC NOT NULL CHECK (water_reading >= 0),
    electric_image_url TEXT,
    water_image_url TEXT,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    reject_reason TEXT,
    reviewed_by UUID REFERENCES public.users(id),
    reviewed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Bật RLS
ALTER TABLE public.meter_reading_submissions ENABLE ROW LEVEL SECURITY;

-- Cư dân đọc các bản ghi thuộc căn hộ mình, BQL đọc toàn bộ
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'meter_reading_submissions' AND policyname = 'Users can view meter submissions'
    ) THEN
        CREATE POLICY "Users can view meter submissions"
            ON public.meter_reading_submissions FOR SELECT
            USING (
                apartment_id IN (
                    SELECT apartment_id FROM public.residents_apartments WHERE user_id = auth.uid()
                )
                OR EXISTS (
                    SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('management', 'admin')
                )
            );
    END IF;
END $$;

-- Cư dân tạo lượt gửi chỉ số cho căn hộ của mình
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'meter_reading_submissions' AND policyname = 'Residents can insert meter submissions'
    ) THEN
        CREATE POLICY "Residents can insert meter submissions"
            ON public.meter_reading_submissions FOR INSERT
            WITH CHECK (
                apartment_id IN (
                    SELECT apartment_id FROM public.residents_apartments WHERE user_id = auth.uid()
                )
            );
    END IF;
END $$;

-- BQL cập nhật trạng thái duyệt
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'meter_reading_submissions' AND policyname = 'Management can update meter submissions'
    ) THEN
        CREATE POLICY "Management can update meter submissions"
            ON public.meter_reading_submissions FOR UPDATE
            USING (
                EXISTS (
                    SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('management', 'admin')
                )
            );
    END IF;
END $$;

-- 2. RPC Phê duyệt chỉ số & tùy chọn tự động phát hành hóa đơn tháng
CREATE OR REPLACE FUNCTION public.approve_meter_reading(
    p_submission_id UUID,
    p_generate_invoice BOOLEAN DEFAULT FALSE,
    p_due_date DATE DEFAULT (CURRENT_DATE + INTERVAL '15 days')::DATE,
    p_mgmt_rate NUMERIC DEFAULT 10000,
    p_electric_rate NUMERIC DEFAULT 3000,
    p_water_rate NUMERIC DEFAULT 15000
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_sub RECORD;
    v_old_elec NUMERIC;
    v_old_water NUMERIC;
    v_area NUMERIC;
    v_invoice_id UUID;
    v_motorbike_count INT := 0;
    v_car_count INT := 0;
    v_total_amount NUMERIC := 0;
    v_elec_diff NUMERIC := 0;
    v_water_diff NUMERIC := 0;
    v_mgmt_fee NUMERIC := 0;
    v_parking_fee NUMERIC := 0;
BEGIN
    SELECT * INTO v_sub FROM public.meter_reading_submissions WHERE id = p_submission_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Không tìm thấy bản ghi khai báo chỉ số.');
    END IF;

    -- Lấy chỉ số cũ & diện tích căn hộ
    SELECT COALESCE(electric_reading, 0), COALESCE(water_reading, 0), COALESCE(area, 60)
    INTO v_old_elec, v_old_water, v_area
    FROM public.apartments WHERE id = v_sub.apartment_id;

    -- Cập nhật chỉ số mới vào căn hộ
    UPDATE public.apartments
    SET electric_reading = v_sub.electric_reading,
        water_reading = v_sub.water_reading,
        updated_at = now()
    WHERE id = v_sub.apartment_id;

    -- Cập nhật trạng thái duyệt
    UPDATE public.meter_reading_submissions
    SET status = 'approved',
        reviewed_by = auth.uid(),
        reviewed_at = now(),
        updated_at = now()
    WHERE id = p_submission_id;

    -- Nếu có yêu cầu tạo ngay hóa đơn tháng cho căn hộ này
    IF p_generate_invoice THEN
        v_elec_diff := GREATEST(0, v_sub.electric_reading - v_old_elec);
        v_water_diff := GREATEST(0, v_sub.water_reading - v_old_water);
        v_mgmt_fee := v_area * p_mgmt_rate;

        -- Đếm xe đã duyệt của căn hộ
        SELECT COUNT(*) FILTER (WHERE vehicle_type = 'motorbike' AND status = 'approved'),
               COUNT(*) FILTER (WHERE vehicle_type = 'car' AND status = 'approved')
        INTO v_motorbike_count, v_car_count
        FROM public.vehicles WHERE apartment_id = v_sub.apartment_id;

        v_parking_fee := (v_motorbike_count * 100000) + (v_car_count * 1200000);
        v_total_amount := v_mgmt_fee + (v_elec_diff * p_electric_rate) + (v_water_diff * p_water_rate) + v_parking_fee;

        -- Tạo hóa đơn
        INSERT INTO public.invoices (apartment_id, period, due_date, total_amount, status, created_at, updated_at)
        VALUES (v_sub.apartment_id, v_sub.period, p_due_date, v_total_amount, 'pending', now(), now())
        RETURNING id INTO v_invoice_id;

        -- Tạo các khoản chi tiết hóa đơn
        INSERT INTO public.invoice_items (invoice_id, fee_type, unit_price, quantity, subtotal)
        VALUES
            (v_invoice_id, 'Phí quản lý', p_mgmt_rate, v_area, v_mgmt_fee),
            (v_invoice_id, 'Tiền điện', p_electric_rate, v_elec_diff, v_elec_diff * p_electric_rate),
            (v_invoice_id, 'Tiền nước', p_water_rate, v_water_diff, v_water_diff * p_water_rate);

        IF v_parking_fee > 0 THEN
            INSERT INTO public.invoice_items (invoice_id, fee_type, unit_price, quantity, subtotal)
            VALUES (v_invoice_id, 'Phí gửi xe', v_parking_fee, 1, v_parking_fee);
        END IF;

        RETURN jsonb_build_object(
            'success', true,
            'message', 'Đã phê duyệt chỉ số và tự động tạo hóa đơn tháng!',
            'invoice_id', v_invoice_id
        );
    END IF;

    RETURN jsonb_build_object('success', true, 'message', 'Đã phê duyệt chỉ số thành công!');
END;
$$;

-- 3. RPC Từ chối chỉ số: `reject_meter_reading`
CREATE OR REPLACE FUNCTION public.reject_meter_reading(
    p_submission_id UUID,
    p_reason TEXT DEFAULT 'Chỉ số không hợp lệ hoặc ảnh mờ'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE public.meter_reading_submissions
    SET status = 'rejected',
        reject_reason = p_reason,
        reviewed_by = auth.uid(),
        reviewed_at = now(),
        updated_at = now()
    WHERE id = p_submission_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Không tìm thấy bản ghi khai báo chỉ số.');
    END IF;

    RETURN jsonb_build_object('success', true, 'message', 'Đã từ chối chỉ số.');
END;
$$;
