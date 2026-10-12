-- ==============================================================================
-- Migration: 20261012_01_fix_p1_p2_security_rpcs_and_storage.sql
-- Mục tiêu:
-- 1. [Lỗi 2 & 5]: book_amenity_slot kiểm tra quyền sở hữu căn hộ, khóa đồng bộ pg_advisory_xact_lock
--    và chuẩn hóa tên cột schema (booked_by thay vì user_id, đảm bảo cột notes, guests_count, fee...)
-- 2. [Lỗi 3]: record_manual_amenity_payment chống ghi nhận giao dịch trùng (Idempotent)
--    kèm partial unique index và bổ sung cột confirmed_by, confirmed_at cho payment_transactions
-- 3. [Lỗi 1]: approve_meter_reading đồng bộ 3 tham số (p_submission_id, p_generate_invoice, p_due_date)
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 0. ĐỒNG BỘ DDL: ĐẢM BẢO CÁC CỘT VÀ RÀNG BUỘC CỦA amenity_bookings VÀ payment_transactions
-- ------------------------------------------------------------------------------
ALTER TABLE public.amenity_bookings
ADD COLUMN IF NOT EXISTS notes TEXT,
ADD COLUMN IF NOT EXISTS guests_count INT NOT NULL DEFAULT 1,
ADD COLUMN IF NOT EXISTS fee_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
ADD COLUMN IF NOT EXISTS deposit_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
ADD COLUMN IF NOT EXISTS deposit_status VARCHAR(20) NOT NULL DEFAULT 'none',
ADD COLUMN IF NOT EXISTS deposit_notes TEXT;

-- Bỏ index độc quyền cũ chỉ cho phép 1 booking/slot để hỗ trợ tiện ích có max_capacity > 1
DROP INDEX IF EXISTS public.uq_active_amenity_slot;

-- Đảm bảo bảng payment_transactions có đầy đủ cột xác nhận
ALTER TABLE public.payment_transactions 
ADD COLUMN IF NOT EXISTS confirmed_by UUID REFERENCES public.users(id),
ADD COLUMN IF NOT EXISTS confirmed_at TIMESTAMPTZ;

-- ------------------------------------------------------------------------------
-- 1. [Lỗi 2 & 5]: CẬP NHẬT RPC book_amenity_slot (BẢO MẬT CĂN HỘ & CHỐNG VƯỢT SỨC CHỨA)
-- ------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.book_amenity_slot(UUID, DATE, VARCHAR, INT, TEXT);
DROP FUNCTION IF EXISTS public.book_amenity_slot(UUID, UUID, DATE, VARCHAR, INT, BOOLEAN);
DROP FUNCTION IF EXISTS public.book_amenity_slot(UUID, DATE, VARCHAR, INT, UUID, BOOLEAN, TEXT);

CREATE OR REPLACE FUNCTION public.book_amenity_slot(
    p_amenity_id UUID,
    p_booking_date DATE,
    p_time_slot VARCHAR,
    p_guests_count INT DEFAULT 1,
    p_apartment_id UUID DEFAULT NULL,
    p_allow_waitlist BOOLEAN DEFAULT TRUE,
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_amenity RECORD;
    v_total_bookings INT;
    v_booking_id UUID;
    v_status VARCHAR;
    v_today DATE;
    v_target_apartment UUID;
    v_user_apts UUID[];
    v_is_waitlist BOOLEAN := false;
    v_fee NUMERIC(12,2) := 0;
    v_deposit NUMERIC(12,2) := 0;
    v_deposit_status VARCHAR(20) := 'none';
    v_lock_key BIGINT;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Yêu cầu đăng nhập để thực hiện đặt chỗ';
    END IF;

    -- 1.1 BẢO MẬT PHÂN QUYỀN CĂN HỘ (Lỗi 2: Không tin tưởng apartment_id từ client)
    IF p_apartment_id IS NOT NULL THEN
        -- Nếu caller truyền cụ thể p_apartment_id:
        -- BQL hoặc Nhân viên có quyền đặt thay cư dân
        IF NOT (public.is_admin_or_accountant() OR public.is_staff()) THEN
            -- Cư dân chỉ được phép đặt cho căn hộ thuộc quyền sở hữu của mình
            IF NOT EXISTS (
                SELECT 1 FROM public.residents_apartments
                WHERE user_id = auth.uid() AND apartment_id = p_apartment_id
            ) THEN
                RAISE EXCEPTION 'Bạn không có quyền đặt tiện ích cho căn hộ này';
            END IF;
        END IF;
        v_target_apartment := p_apartment_id;
    ELSE
        -- Nếu client không truyền căn hộ:
        -- Chỉ tự suy ra căn hộ nếu cư dân chỉ liên kết đúng 1 căn hộ duy nhất
        SELECT ARRAY_AGG(apartment_id) INTO v_user_apts
        FROM public.residents_apartments
        WHERE user_id = auth.uid();

        IF v_user_apts IS NULL OR CARDINALITY(v_user_apts) = 0 THEN
            RAISE EXCEPTION 'Bạn chưa liên kết với căn hộ nào để thực hiện đặt chỗ';
        ELSIF CARDINALITY(v_user_apts) > 1 THEN
            RAISE EXCEPTION 'Bạn đang liên kết nhiều căn hộ, vui lòng chọn cụ thể căn hộ cần đặt tiện ích';
        ELSE
            v_target_apartment := v_user_apts[1];
        END IF;
    END IF;

    -- Kiểm tra ngày đặt chỗ không ở quá khứ theo múi giờ Việt Nam
    v_today := (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date;
    IF p_booking_date < v_today THEN
        RAISE EXCEPTION 'Không thể đặt lịch cho ngày trong quá khứ';
    END IF;

    -- 1.2 KHÓA ĐỒNG BỘ THEO SLOT TIỆN ÍCH CHỐNG VƯỢT SỨC CHỨA (Lỗi 5)
    -- Hash tiện ích + ngày + slot thành 64-bit bigint để thực hiện pg_advisory_xact_lock
    -- Khóa được giải phóng tự động khi kết thúc transaction
    v_lock_key := ('x' || substr(md5(p_amenity_id::text || '_' || p_booking_date::text || '_' || p_time_slot), 1, 16))::bit(64)::bigint;
    PERFORM pg_advisory_xact_lock(v_lock_key);

    -- Khóa và kiểm tra thông tin tiện ích
    SELECT * INTO v_amenity FROM public.building_amenities WHERE id = p_amenity_id FOR SHARE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Tiện ích không tồn tại';
    END IF;

    IF NOT COALESCE(v_amenity.is_active, true) THEN
        RAISE EXCEPTION 'Tiện ích này hiện đang tạm ngưng phục vụ';
    END IF;

    -- Kiểm tra xung đột lịch bảo trì nếu có
    IF EXISTS (
        SELECT 1 FROM public.amenity_maintenance_windows
        WHERE amenity_id = p_amenity_id
          AND start_time::date <= p_booking_date
          AND end_time::date >= p_booking_date
    ) THEN
        RAISE EXCEPTION 'Tiện ích đang trong khung giờ bảo trì vào ngày này';
    END IF;

    -- Đếm số lượng đặt chỗ thực tế đang chiếm chỗ (confirmed, completed, pending_payment)
    SELECT COUNT(*) INTO v_total_bookings
    FROM public.amenity_bookings
    WHERE amenity_id = p_amenity_id
      AND booking_date = p_booking_date
      AND time_slot = p_time_slot
      AND status IN ('confirmed', 'completed', 'pending_payment');

    -- Tính toán phí dịch vụ và tiền cọc theo tiện ích
    v_fee := COALESCE(v_amenity.fee_amount, 0) * GREATEST(COALESCE(p_guests_count, 1), 1);
    IF COALESCE(v_amenity.requires_deposit, false) THEN
        v_deposit := COALESCE(v_amenity.deposit_amount, 0);
        v_deposit_status := 'pending';
    END IF;

    -- Xử lý sức chứa
    IF v_total_bookings >= COALESCE(v_amenity.max_capacity, 1) THEN
        IF p_allow_waitlist THEN
            v_status := 'waitlist';
            v_is_waitlist := true;
        ELSE
            RAISE EXCEPTION 'Khung giờ này đã đủ số lượng đặt tối đa (Hết chỗ)';
        END IF;
    ELSE
        IF v_fee > 0 OR v_deposit > 0 THEN
            v_status := 'pending_payment';
        ELSE
            v_status := 'confirmed';
        END IF;
    END IF;

    -- Chèn bản ghi đặt chỗ (DÙNG ĐÚNG booked_by theo schema CSDL)
    INSERT INTO public.amenity_bookings (
        amenity_id,
        booked_by,
        apartment_id,
        booking_date,
        time_slot,
        guests_count,
        status,
        notes,
        fee_amount,
        deposit_amount,
        deposit_status
    ) VALUES (
        p_amenity_id,
        auth.uid(),
        v_target_apartment,
        p_booking_date,
        p_time_slot,
        COALESCE(p_guests_count, 1),
        v_status,
        p_notes,
        v_fee,
        v_deposit,
        v_deposit_status
    )
    RETURNING id INTO v_booking_id;

    RETURN jsonb_build_object(
        'success', true,
        'booking_id', v_booking_id,
        'status', v_status,
        'is_waitlist', v_is_waitlist,
        'fee_amount', v_fee,
        'deposit_amount', v_deposit,
        'message', CASE 
            WHEN v_is_waitlist THEN 'Đã thêm vào danh sách chờ do khung giờ đã kín chỗ'
            WHEN v_status = 'pending_payment' THEN 'Đặt chỗ thành công! Vui lòng thanh toán phí dịch vụ/tiền cọc.'
            ELSE 'Đặt tiện ích thành công!'
        END
    );
END;
$$;

REVOKE ALL ON FUNCTION public.book_amenity_slot(UUID, DATE, VARCHAR, INT, UUID, BOOLEAN, TEXT) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.book_amenity_slot(UUID, DATE, VARCHAR, INT, UUID, BOOLEAN, TEXT) TO authenticated;


-- ------------------------------------------------------------------------------
-- 2. [Lỗi 3]: CHỐNG GHI NHẬN TRÙNG GIAO DỊCH THU PHÍ (record_manual_amenity_payment)
-- ------------------------------------------------------------------------------
CREATE UNIQUE INDEX IF NOT EXISTS uq_payment_transactions_booking_success
ON public.payment_transactions (booking_id)
WHERE booking_id IS NOT NULL AND status = 'SUCCESS' AND type = 'SERVICE';

DROP FUNCTION IF EXISTS public.record_manual_amenity_payment(UUID, VARCHAR, TEXT);

CREATE OR REPLACE FUNCTION public.record_manual_amenity_payment(
    p_booking_id UUID,
    p_payment_method VARCHAR DEFAULT 'CASH',
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_booking RECORD;
    v_amenity RECORD;
    v_txn_id UUID;
    v_txn_code VARCHAR(100);
    v_existing_success_txn RECORD;
    v_pending_txn RECORD;
    v_staff_id UUID := auth.uid();
    v_total_fee NUMERIC(12,2) := 0;
BEGIN
    -- 1. Kiểm tra quyền Ban Quản Lý hoặc Nhân viên
    IF NOT (public.is_admin_or_accountant() OR public.is_staff()) THEN
        RAISE EXCEPTION 'Bạn không có quyền xác nhận thu phí dịch vụ tiện ích';
    END IF;

    -- 2. Khóa dòng booking FOR UPDATE
    SELECT b.*, a.name AS amenity_name, a.fee_amount AS a_fee, a.deposit_amount AS a_deposit, a.requires_deposit AS a_req_deposit
    INTO v_booking
    FROM public.amenity_bookings b
    JOIN public.building_amenities a ON b.amenity_id = a.id
    WHERE b.id = p_booking_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Lịch đặt tiện ích không tồn tại: %', p_booking_id;
    END IF;

    IF v_booking.status = 'cancelled' THEN
        RAISE EXCEPTION 'Lịch đặt này đã bị hủy, không thể xác nhận thu tiền';
    END IF;

    -- 3. CHỐNG GHI NHẬN TRÙNG GIAO DỊCH THÀNH CÔNG (IDEMPOTENCY)
    SELECT * INTO v_existing_success_txn
    FROM public.payment_transactions
    WHERE booking_id = p_booking_id AND status = 'SUCCESS'
    ORDER BY created_at DESC
    LIMIT 1
    FOR UPDATE;

    IF FOUND THEN
        -- IDEMPOTENT: Trả về kết quả của giao dịch thành công đã có, không chèn thêm giao dịch mới!
        RETURN jsonb_build_object(
            'success', true,
            'message', 'Lịch đặt tiện ích này đã được xác nhận thanh toán trước đó',
            'already_paid', true,
            'booking_id', p_booking_id,
            'transaction_id', v_existing_success_txn.id,
            'transaction_code', v_existing_success_txn.transaction_code
        );
    END IF;

    -- Tính tổng phí cần thu
    v_total_fee := COALESCE(v_booking.fee_amount, 0) + COALESCE(v_booking.deposit_amount, 0);
    IF v_total_fee <= 0 THEN
        v_total_fee := (COALESCE(v_booking.a_fee, 0) * GREATEST(COALESCE(v_booking.guests_count, 1), 1))
            + (CASE WHEN COALESCE(v_booking.a_req_deposit, false) THEN COALESCE(v_booking.a_deposit, 0) ELSE 0 END);
    END IF;

    -- 4. Tìm giao dịch PENDING đang chờ của booking này
    SELECT * INTO v_pending_txn
    FROM public.payment_transactions
    WHERE booking_id = p_booking_id AND status = 'PENDING'
    ORDER BY created_at DESC
    LIMIT 1
    FOR UPDATE;

    IF FOUND THEN
        -- Cập nhật giao dịch PENDING hiện có sang SUCCESS, giữ nguyên transaction_code
        v_txn_code := v_pending_txn.transaction_code;
        v_txn_id := v_pending_txn.id;

        UPDATE public.payment_transactions
        SET status = 'SUCCESS',
            payment_method = COALESCE(p_payment_method, v_pending_txn.payment_method),
            title = COALESCE(p_notes, 'Thanh toán dịch vụ ' || v_booking.amenity_name),
            confirmed_by = v_staff_id,
            confirmed_at = NOW(),
            failure_reason = NULL
        WHERE id = v_txn_id;
    ELSE
        -- Chưa có giao dịch nào: BQL thu tiền trực tiếp tại quầy
        v_txn_code := 'MANUAL-SRV-' || to_char(NOW(), 'YYYYMMDDHH24MISS') || '-' || upper(substr(gen_random_uuid()::text, 1, 8));

        INSERT INTO public.payment_transactions (
            transaction_code,
            booking_id,
            apartment_id,
            amount,
            payment_method,
            type,
            status,
            title,
            confirmed_by,
            confirmed_at
        ) VALUES (
            v_txn_code,
            p_booking_id,
            v_booking.apartment_id,
            v_total_fee,
            p_payment_method,
            'SERVICE',
            'SUCCESS',
            COALESCE(p_notes, 'Thanh toán trực tiếp dịch vụ ' || v_booking.amenity_name),
            v_staff_id,
            NOW()
        ) RETURNING id INTO v_txn_id;
    END IF;

    -- Cập nhật trạng thái đặt chỗ sang confirmed và tiền cọc sang received (nếu có cọc)
    UPDATE public.amenity_bookings
    SET status = 'confirmed',
        deposit_status = CASE 
            WHEN COALESCE(deposit_amount, 0) > 0 OR COALESCE(v_booking.a_deposit, 0) > 0 THEN 'received' 
            ELSE deposit_status 
        END,
        deposit_notes = COALESCE(p_notes, deposit_notes),
        updated_at = NOW()
    WHERE id = p_booking_id;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Xác nhận thu phí dịch vụ tiện ích thành công',
        'already_paid', false,
        'booking_id', p_booking_id,
        'transaction_id', v_txn_id,
        'transaction_code', v_txn_code
    );
END;
$$;

REVOKE ALL ON FUNCTION public.record_manual_amenity_payment(UUID, VARCHAR, TEXT) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.record_manual_amenity_payment(UUID, VARCHAR, TEXT) TO authenticated;


-- ------------------------------------------------------------------------------
-- 3. [Lỗi 1]: ĐỒNG BỘ CHỮ KÝ approve_meter_reading VÀ TÙY CHỌN TẠO HÓA ĐƠN
-- ------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.approve_meter_reading(UUID);
DROP FUNCTION IF EXISTS public.approve_meter_reading(UUID, BOOLEAN, DATE);

CREATE OR REPLACE FUNCTION public.approve_meter_reading(
    p_submission_id UUID,
    p_generate_invoice BOOLEAN DEFAULT FALSE,
    p_due_date DATE DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_sub RECORD;
    v_area NUMERIC;
    v_old_elec NUMERIC;
    v_old_water NUMERIC;
    v_elec_diff NUMERIC;
    v_water_diff NUMERIC;
    v_mgmt_fee NUMERIC;
    v_motorbike_count INT;
    v_car_count INT;
    v_parking_fee NUMERIC;
    v_total_amount NUMERIC;
    v_invoice_id UUID;
    v_invoice_created BOOLEAN := false;
    v_due_date DATE;
BEGIN
    -- Chỉ Admin hoặc Kế toán có quyền duyệt và sinh hóa đơn tài chính
    IF NOT public.is_admin_or_accountant() THEN
        RAISE EXCEPTION 'Chỉ Quản trị viên hoặc Kế toán mới có quyền duyệt chỉ số và lập hóa đơn';
    END IF;

    SELECT * INTO v_sub FROM public.meter_reading_submissions WHERE id = p_submission_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Bản ghi chỉ số không tồn tại: %', p_submission_id;
    END IF;

    IF v_sub.status <> 'pending' THEN
        RAISE EXCEPTION 'Bản ghi chỉ số đã được xử lý trước đó (Trạng thái: %)', v_sub.status;
    END IF;

    SELECT area, COALESCE(electric_reading, 0), COALESCE(water_reading, 0)
    INTO v_area, v_old_elec, v_old_water
    FROM public.apartments
    WHERE id = v_sub.apartment_id FOR UPDATE;

    IF v_sub.electric_reading < v_old_elec THEN
        RAISE EXCEPTION 'Chỉ số điện mới (%) không được nhỏ hơn chỉ số cũ (%) của căn hộ', v_sub.electric_reading, v_old_elec;
    END IF;

    IF v_sub.water_reading < v_old_water THEN
        RAISE EXCEPTION 'Chỉ số nước mới (%) không được nhỏ hơn chỉ số cũ (%) của căn hộ', v_sub.water_reading, v_old_water;
    END IF;

    v_elec_diff := v_sub.electric_reading - v_old_elec;
    v_water_diff := v_sub.water_reading - v_old_water;
    v_mgmt_fee := ROUND(COALESCE(v_area, 70) * 16500);

    -- Đếm số xe approved của căn hộ (nếu 0 xe thì phí = 0đ)
    SELECT 
        COUNT(*) FILTER (WHERE vehicle_type = 'motorbike'),
        COUNT(*) FILTER (WHERE vehicle_type = 'car')
    INTO v_motorbike_count, v_car_count
    FROM public.vehicles
    WHERE apartment_id = v_sub.apartment_id AND status = 'approved';

    IF (v_motorbike_count + v_car_count) = 0 THEN
        v_parking_fee := 0;
    ELSE
        v_parking_fee := (v_motorbike_count * 100000) + (v_car_count * 1200000);
    END IF;

    v_total_amount := v_mgmt_fee + v_parking_fee + (v_elec_diff * 3500) + (v_water_diff * 18000);

    -- 1. Cập nhật chỉ số mới vào bảng apartments
    UPDATE public.apartments
    SET electric_reading = v_sub.electric_reading,
        water_reading = v_sub.water_reading,
        updated_at = now()
    WHERE id = v_sub.apartment_id;

    -- 2. Đánh dấu bản ghi nộp chỉ số là approved
    UPDATE public.meter_reading_submissions
    SET status = 'approved',
        reviewed_by = auth.uid(),
        reviewed_at = now(),
        updated_at = now()
    WHERE id = p_submission_id;

    -- 3. Tạo hóa đơn tương ứng (CHỈ KHI p_generate_invoice = TRUE)
    IF p_generate_invoice = TRUE THEN
        IF NOT EXISTS (
            SELECT 1 FROM public.invoices WHERE apartment_id = v_sub.apartment_id AND period = v_sub.period
        ) THEN
            v_due_date := COALESCE(p_due_date, CURRENT_DATE + INTERVAL '10 days');

            INSERT INTO public.invoices (
                apartment_id,
                period,
                due_date,
                total_amount,
                status,
                created_at,
                updated_at
            ) VALUES (
                v_sub.apartment_id,
                v_sub.period,
                v_due_date,
                v_total_amount,
                'unpaid',
                now(),
                now()
            ) RETURNING id INTO v_invoice_id;

            -- Hạng mục phí quản lý
            INSERT INTO public.invoice_items (invoice_id, fee_type, unit_price, quantity)
            VALUES (v_invoice_id, 'Phí quản lý vận hành', 16500, COALESCE(v_area, 70));

            -- Hạng mục gửi xe (nếu có xe)
            IF v_parking_fee > 0 THEN
                IF v_motorbike_count > 0 THEN
                    INSERT INTO public.invoice_items (invoice_id, fee_type, unit_price, quantity)
                    VALUES (v_invoice_id, 'Phí gửi xe máy', 100000, v_motorbike_count);
                END IF;
                IF v_car_count > 0 THEN
                    INSERT INTO public.invoice_items (invoice_id, fee_type, unit_price, quantity)
                    VALUES (v_invoice_id, 'Phí gửi ô tô', 1200000, v_car_count);
                END IF;
            END IF;

            -- Hạng mục điện nước
            IF v_elec_diff > 0 THEN
                INSERT INTO public.invoice_items (invoice_id, fee_type, unit_price, quantity)
                VALUES (v_invoice_id, 'Tiền điện sinh hoạt', 3500, v_elec_diff);
            END IF;

            IF v_water_diff > 0 THEN
                INSERT INTO public.invoice_items (invoice_id, fee_type, unit_price, quantity)
                VALUES (v_invoice_id, 'Tiền nước sinh hoạt', 18000, v_water_diff);
            END IF;

            v_invoice_created := true;
        END IF;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'message', CASE 
            WHEN v_invoice_created THEN 'Duyệt chỉ số thành công và đã tạo hóa đơn cho kỳ này'
            WHEN p_generate_invoice = TRUE THEN 'Duyệt chỉ số thành công (hóa đơn cho kỳ này đã tồn tại trước đó)'
            ELSE 'Duyệt chỉ số thành công (không tạo hóa đơn theo yêu cầu)'
        END,
        'invoice_created', v_invoice_created,
        'invoice_id', v_invoice_id
    );
END;
$$;

REVOKE ALL ON FUNCTION public.approve_meter_reading(UUID, BOOLEAN, DATE) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.approve_meter_reading(UUID, BOOLEAN, DATE) TO authenticated;
