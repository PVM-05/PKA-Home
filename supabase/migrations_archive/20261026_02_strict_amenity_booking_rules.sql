-- ==============================================================================
-- Migration: 20261026_02_strict_amenity_booking_rules.sql
-- Mô tả:
--   1. Ràng buộc chống đặt trùng: Tạo Partial Unique Index trên amenity_bookings.
--      Một người dùng không thể có nhiều hơn 1 bản ghi đang active (confirmed, pending_payment, waitlist, pending)
--      trong cùng một khung giờ của một tiện ích.
--   2. Cập nhật RPC book_amenity_slot:
--      - Kiểm tra nghiêm ngặt lượt đặt trùng của cùng user và trả lỗi tiếng Việt rõ ràng.
--      - Kiểm tra sức chứa (shared vs exclusive) và xếp vào waitlist nếu kín chỗ.
--      - Tính toán chuẩn xác phí và tiền cọc.
--   3. Cập nhật RPC cancel_amenity_booking:
--      - Cho phép người đặt (cư dân) hoặc Ban quản lý (admin/staff) hủy lịch.
--      - Hủy các giao dịch chờ thanh toán (payment_transactions PENDING -> CANCELLED).
--      - Cập nhật trạng thái thành 'cancelled' (kích hoạt trigger đôn waitlist).
-- ==============================================================================

-- 1. PARTIAL UNIQUE INDEX CHỐNG ĐẶT TRÙNG CHO CÙNG MỘT NGƯỜI DÙNG TRONG KHUNG GIỜ
CREATE UNIQUE INDEX IF NOT EXISTS uq_amenity_bookings_active_user_slot
ON public.amenity_bookings (amenity_id, booking_date, time_slot, booked_by)
WHERE status IN ('confirmed', 'pending_payment', 'waitlist', 'pending');

-- 2. CẬP NHẬT RPC: book_amenity_slot
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
    v_user_id UUID := auth.uid();
    v_amenity RECORD;
    v_target_apartment UUID;
    v_today DATE;
    v_current_occupancy INT := 0;
    v_booking_id UUID;
    v_status VARCHAR;
    v_is_waitlist BOOLEAN := false;
    v_fee NUMERIC(12,2) := 0;
    v_deposit NUMERIC(12,2) := 0;
    v_deposit_status VARCHAR(20) := 'none';
    v_max_capacity INT := 1;
BEGIN
    -- 2.1. Xác thực người dùng
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Yêu cầu đăng nhập để thực hiện đặt chỗ';
    END IF;

    -- 2.2. Xác định căn hộ của người đặt
    IF p_apartment_id IS NOT NULL THEN
        v_target_apartment := p_apartment_id;
    ELSE
        SELECT apartment_id INTO v_target_apartment
        FROM public.residents_apartments
        WHERE user_id = v_user_id
        ORDER BY created_at ASC
        LIMIT 1;
    END IF;

    IF v_target_apartment IS NULL THEN
        RAISE EXCEPTION 'Bạn chưa liên kết với căn hộ nào để thực hiện đặt chỗ';
    END IF;

    -- 2.3. Kiểm tra ngày đặt chỗ không ở quá khứ
    v_today := (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date;
    IF p_booking_date < v_today THEN
        RAISE EXCEPTION 'Không thể đặt lịch cho ngày trong quá khứ';
    END IF;

    -- 2.4. Khóa và kiểm tra thông tin tiện ích
    SELECT * INTO v_amenity 
    FROM public.building_amenities 
    WHERE id = p_amenity_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Tiện ích không tồn tại';
    END IF;

    IF NOT COALESCE(v_amenity.is_active, true) THEN
        RAISE EXCEPTION 'Tiện ích này hiện đang tạm ngưng phục vụ';
    END IF;

    v_max_capacity := GREATEST(COALESCE(v_amenity.max_capacity, 1), 1);

    IF COALESCE(p_guests_count, 1) > v_max_capacity THEN
        RAISE EXCEPTION 'Số lượng người đặt (% người) vượt quá sức chứa tối đa của tiện ích (% người)', 
            COALESCE(p_guests_count, 1), v_max_capacity;
    END IF;

    -- 2.5. Kiểm tra người dùng đã có lượt đặt còn hiệu lực trong khung giờ này chưa
    IF EXISTS (
        SELECT 1 FROM public.amenity_bookings
        WHERE amenity_id = p_amenity_id
          AND booking_date = p_booking_date
          AND time_slot = p_time_slot
          AND booked_by = v_user_id
          AND status IN ('confirmed', 'pending_payment', 'waitlist', 'pending')
    ) THEN
        RAISE EXCEPTION 'Bạn đã có lượt đặt trong khung giờ này. Vui lòng hủy lịch hiện tại trước nếu muốn đặt lại.';
    END IF;

    -- 2.6. Kiểm tra xung đột lịch bảo trì nếu có
    IF EXISTS (
        SELECT 1 FROM public.amenity_maintenance_windows
        WHERE amenity_id = p_amenity_id
          AND start_time::date <= p_booking_date
          AND end_time::date >= p_booking_date
    ) THEN
        RAISE EXCEPTION 'Tiện ích đang trong khung giờ bảo trì vào ngày này';
    END IF;

    -- 2.7. Tính toán lượng chiếm dụng hiện tại trong khung giờ
    IF COALESCE(v_amenity.booking_type, 'exclusive') = 'exclusive' THEN
        SELECT COUNT(*) INTO v_current_occupancy
        FROM public.amenity_bookings
        WHERE amenity_id = p_amenity_id
          AND booking_date = p_booking_date
          AND time_slot = p_time_slot
          AND status IN ('confirmed', 'pending_payment');
    ELSE
        SELECT COALESCE(SUM(guests_count), 0) INTO v_current_occupancy
        FROM public.amenity_bookings
        WHERE amenity_id = p_amenity_id
          AND booking_date = p_booking_date
          AND time_slot = p_time_slot
          AND status IN ('confirmed', 'pending_payment');
    END IF;

    -- 2.8. Tính toán phí dịch vụ và tiền cọc theo công thức chuẩn
    v_fee := COALESCE(v_amenity.fee_amount, 0) * GREATEST(COALESCE(p_guests_count, 1), 1);
    IF COALESCE(v_amenity.requires_deposit, false) THEN
        v_deposit := COALESCE(v_amenity.deposit_amount, 0);
        v_deposit_status := 'pending';
    END IF;

    -- 2.9. Đánh giá khả dụng hoặc xếp vào danh sách chờ
    IF (v_current_occupancy + GREATEST(COALESCE(p_guests_count, 1), 1)) > v_max_capacity THEN
        IF p_allow_waitlist THEN
            v_status := 'waitlist';
            v_is_waitlist := true;
        ELSE
            RAISE EXCEPTION 'Khung giờ này đã kín chỗ. Vui lòng chọn khung giờ khác.';
        END IF;
    ELSE
        IF (v_fee + v_deposit) > 0 THEN
            v_status := 'pending_payment';
        ELSE
            v_status := 'confirmed';
        END IF;
    END IF;

    -- 2.10. Tạo bản ghi đặt chỗ
    INSERT INTO public.amenity_bookings (
        amenity_id,
        apartment_id,
        booked_by,
        booking_date,
        time_slot,
        guests_count,
        fee_amount,
        deposit_amount,
        deposit_status,
        status,
        notes,
        created_at,
        updated_at
    ) VALUES (
        p_amenity_id,
        v_target_apartment,
        v_user_id,
        p_booking_date,
        p_time_slot,
        GREATEST(COALESCE(p_guests_count, 1), 1),
        v_fee,
        v_deposit,
        v_deposit_status,
        v_status,
        p_notes,
        NOW(),
        NOW()
    ) RETURNING id INTO v_booking_id;

    RETURN jsonb_build_object(
        'success', true,
        'message', CASE 
            WHEN v_is_waitlist THEN 'Đã thêm vào danh sách chờ thành công'
            WHEN v_status = 'pending_payment' THEN 'Đã tạo lịch đặt, đang chờ thanh toán'
            ELSE 'Đặt lịch tiện ích thành công'
        END,
        'booking_id', v_booking_id,
        'status', v_status,
        'is_waitlist', v_is_waitlist,
        'fee_amount', v_fee,
        'deposit_amount', v_deposit,
        'total_amount', (v_fee + v_deposit)
    );
END;
$$;

REVOKE ALL ON FUNCTION public.book_amenity_slot(UUID, DATE, VARCHAR, INT, UUID, BOOLEAN, TEXT) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.book_amenity_slot(UUID, DATE, VARCHAR, INT, UUID, BOOLEAN, TEXT) TO authenticated;

-- 3. CẬP NHẬT RPC: cancel_amenity_booking
CREATE OR REPLACE FUNCTION public.cancel_amenity_booking(p_booking_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_booking RECORD;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Bạn chưa đăng nhập vào hệ thống';
    END IF;

    SELECT * INTO v_booking
    FROM public.amenity_bookings
    WHERE id = p_booking_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Không tìm thấy lượt đặt chỗ với mã ID đã cho';
    END IF;

    -- Kiểm tra quyền: Người đặt hoặc Ban quản lý
    IF v_booking.booked_by <> v_user_id AND NOT public.is_staff_or_management() THEN
        RAISE EXCEPTION 'Bạn không có quyền hủy lượt đặt chỗ của người khác';
    END IF;

    IF v_booking.status = 'cancelled' THEN
        RETURN jsonb_build_object(
            'success', true,
            'message', 'Lịch đặt chỗ này đã được hủy trước đó',
            'booking_id', p_booking_id
        );
    END IF;

    -- Hủy các giao dịch thanh toán tạm liên quan nếu có
    UPDATE public.payment_transactions
    SET status = 'CANCELLED', updated_at = NOW()
    WHERE booking_id = p_booking_id AND status = 'PENDING';

    -- Đánh dấu trạng thái hủy (Trigger sau đó sẽ tự động đôn Waitlist nếu có)
    UPDATE public.amenity_bookings
    SET status = 'cancelled', updated_at = NOW()
    WHERE id = p_booking_id;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Đã hủy lịch đặt tiện ích thành công',
        'booking_id', p_booking_id
    );
END;
$$;

REVOKE ALL ON FUNCTION public.cancel_amenity_booking(UUID) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.cancel_amenity_booking(UUID) TO authenticated;
