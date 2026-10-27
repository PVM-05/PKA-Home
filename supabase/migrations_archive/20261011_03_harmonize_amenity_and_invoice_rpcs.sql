-- ==============================================================================
-- PKA-Home: Migration 20261011_03_harmonize_amenity_and_invoice_rpcs.sql
-- Mục đích:
-- 1. Khôi phục RPC nguyên tử update_invoice_with_items trong 1 transaction ACID
-- 2. Chuẩn hóa chữ ký RPC book_amenity_slot nhận đầy đủ p_apartment_id và p_allow_waitlist
-- ==============================================================================

-- 1. KHÔI PHỤC RPC NGUYÊN TỬ: update_invoice_with_items
-- ------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.update_invoice_with_items(UUID, VARCHAR, DATE, JSONB, UUID, VARCHAR);

CREATE OR REPLACE FUNCTION public.update_invoice_with_items(
    p_invoice_id UUID,
    p_period VARCHAR,
    p_due_date DATE,
    p_items JSONB,
    p_apartment_id UUID DEFAULT NULL,
    p_status VARCHAR DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_inv RECORD;
    v_item JSONB;
BEGIN
    -- Chỉ admin, management hoặc accountant mới có quyền cập nhật hóa đơn
    IF NOT public.is_admin_or_accountant() THEN
        RAISE EXCEPTION 'Bạn không có quyền thực hiện thao tác này';
    END IF;

    -- Khóa bản ghi hóa đơn để tránh cập nhật đồng thời
    SELECT * INTO v_inv FROM public.invoices WHERE id = p_invoice_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Hóa đơn không tồn tại: %', p_invoice_id;
    END IF;

    -- 1. Cập nhật thông tin tiêu đề hóa đơn
    UPDATE public.invoices
    SET 
        period = p_period,
        due_date = p_due_date,
        apartment_id = COALESCE(p_apartment_id, apartment_id),
        status = CASE 
            WHEN p_status IS NOT NULL THEN p_status::public.invoice_status 
            ELSE status 
        END,
        updated_at = NOW()
    WHERE id = p_invoice_id;

    -- 2. Xóa các mục chi phí cũ
    DELETE FROM public.invoice_items WHERE invoice_id = p_invoice_id;

    -- 3. Chèn lại các mục chi phí mới trong cùng transaction nguyên tử
    IF p_items IS NOT NULL AND jsonb_array_length(p_items) > 0 THEN
        FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
        LOOP
            INSERT INTO public.invoice_items (
                invoice_id,
                fee_type,
                unit_price,
                quantity
            ) VALUES (
                p_invoice_id,
                v_item->>'fee_type',
                COALESCE((v_item->>'unit_price')::DECIMAL, 0),
                COALESCE((v_item->>'quantity')::DECIMAL, 1)
            );
        END LOOP;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Cập nhật hóa đơn và các hạng mục chi phí thành công',
        'invoice_id', p_invoice_id
    );
END;
$$;

REVOKE ALL ON FUNCTION public.update_invoice_with_items(UUID, VARCHAR, DATE, JSONB, UUID, VARCHAR) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.update_invoice_with_items(UUID, VARCHAR, DATE, JSONB, UUID, VARCHAR) TO authenticated;

-- 2. ĐỒNG BỘ CHỮ KÝ RPC: book_amenity_slot
-- ------------------------------------------------------------------------------
-- Xóa toàn bộ các biến thể cũ tránh trùng lặp
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
    v_is_waitlist BOOLEAN := false;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Yêu cầu đăng nhập để thực hiện đặt chỗ';
    END IF;

    -- Xác định căn hộ của người đặt
    IF p_apartment_id IS NOT NULL THEN
        -- Kiểm tra căn hộ hợp lệ
        v_target_apartment := p_apartment_id;
    ELSE
        SELECT apartment_id INTO v_target_apartment
        FROM public.residents_apartments
        WHERE user_id = auth.uid()
        LIMIT 1;
    END IF;

    IF v_target_apartment IS NULL THEN
        RAISE EXCEPTION 'Bạn chưa liên kết với căn hộ nào để thực hiện đặt chỗ';
    END IF;

    -- Kiểm tra ngày đặt chỗ không ở quá khứ
    v_today := (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date;
    IF p_booking_date < v_today THEN
        RAISE EXCEPTION 'Không thể đặt lịch cho ngày trong quá khứ';
    END IF;

    -- Kiểm tra thông tin tiện ích
    SELECT * INTO v_amenity FROM public.building_amenities WHERE id = p_amenity_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Tiện ích không tồn tại';
    END IF;

    IF NOT v_amenity.is_active THEN
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

    -- Kiểm tra số lượng lượt đặt trong khung giờ
    SELECT COUNT(*) INTO v_total_bookings
    FROM public.amenity_bookings
    WHERE amenity_id = p_amenity_id
      AND booking_date = p_booking_date
      AND time_slot = p_time_slot
      AND status IN ('confirmed', 'completed', 'pending_payment');

    IF v_total_bookings > 0 THEN
        IF p_allow_waitlist THEN
            v_status := 'waitlist';
            v_is_waitlist := true;
        ELSE
            RAISE EXCEPTION 'Khung giờ này đã kín chỗ. Vui lòng chọn khung giờ khác.';
        END IF;
    ELSE
        -- Khung giờ còn trống
        IF COALESCE(v_amenity.price, 0) > 0 OR COALESCE(v_amenity.deposit_amount, 0) > 0 THEN
            v_status := 'pending_payment';
        ELSE
            v_status := 'confirmed';
        END IF;
    END IF;

    -- Tạo bản ghi đặt chỗ
    INSERT INTO public.amenity_bookings (
        amenity_id,
        apartment_id,
        booked_by,
        booking_date,
        time_slot,
        guests_count,
        status,
        notes,
        created_at,
        updated_at
    ) VALUES (
        p_amenity_id,
        v_target_apartment,
        auth.uid(),
        p_booking_date,
        p_time_slot,
        p_guests_count,
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
        'is_waitlist', v_is_waitlist
    );
END;
$$;

REVOKE ALL ON FUNCTION public.book_amenity_slot(UUID, DATE, VARCHAR, INT, UUID, BOOLEAN, TEXT) FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.book_amenity_slot(UUID, DATE, VARCHAR, INT, UUID, BOOLEAN, TEXT) TO authenticated;
