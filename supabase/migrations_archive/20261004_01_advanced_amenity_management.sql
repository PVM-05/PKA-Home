-- ==============================================================================
-- BẢN NÂNG CẤP MODULE 2.6: QUẢN LÝ TIỆN ÍCH NÂNG CAO (ADVANCED AMENITIES)
-- Migration: 20261004_01_advanced_amenity_management.sql
-- ==============================================================================

-- 1. NÂNG CẤP BẢNG public.building_amenities
-- ------------------------------------------------------------------------------
ALTER TABLE public.building_amenities
ADD COLUMN IF NOT EXISTS booking_type VARCHAR(20) NOT NULL DEFAULT 'exclusive' 
    CHECK (booking_type IN ('exclusive', 'shared')),
ADD COLUMN IF NOT EXISTS max_capacity INT NOT NULL DEFAULT 1 CHECK (max_capacity >= 1),
ADD COLUMN IF NOT EXISTS slot_duration_minutes INT NOT NULL DEFAULT 90 CHECK (slot_duration_minutes >= 30),
ADD COLUMN IF NOT EXISTS fee_amount NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (fee_amount >= 0),
ADD COLUMN IF NOT EXISTS deposit_amount NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (deposit_amount >= 0),
ADD COLUMN IF NOT EXISTS requires_deposit BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT true;


-- 2. BẢNG MỚI public.amenity_maintenance_windows (Lịch bảo trì tiện ích)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.amenity_maintenance_windows (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    amenity_id UUID NOT NULL REFERENCES public.building_amenities(id) ON DELETE CASCADE,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ NOT NULL,
    reason TEXT NOT NULL,
    created_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_maintenance_time CHECK (end_time > start_time)
);

CREATE INDEX IF NOT EXISTS idx_amenity_maint_time 
ON public.amenity_maintenance_windows (amenity_id, start_time, end_time);

ALTER TABLE public.amenity_maintenance_windows ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Mọi người xem lịch bảo trì tiện ích" ON public.amenity_maintenance_windows;
CREATE POLICY "Mọi người xem lịch bảo trì tiện ích"
ON public.amenity_maintenance_windows FOR SELECT
USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Ban quản lý quản trị lịch bảo trì" ON public.amenity_maintenance_windows;
CREATE POLICY "Ban quản lý quản trị lịch bảo trì"
ON public.amenity_maintenance_windows FOR ALL
USING (public.is_staff());


-- 3. NÂNG CẤP BẢNG public.amenity_bookings
-- ------------------------------------------------------------------------------
ALTER TABLE public.amenity_bookings 
DROP CONSTRAINT IF EXISTS amenity_bookings_status_check;

ALTER TABLE public.amenity_bookings 
ADD CONSTRAINT amenity_bookings_status_check 
CHECK (status IN ('confirmed', 'waitlist', 'cancelled', 'completed', 'no_show'));

ALTER TABLE public.amenity_bookings
ADD COLUMN IF NOT EXISTS guests_count INT NOT NULL DEFAULT 1 CHECK (guests_count >= 1),
ADD COLUMN IF NOT EXISTS fee_amount NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (fee_amount >= 0),
ADD COLUMN IF NOT EXISTS deposit_amount NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (deposit_amount >= 0),
ADD COLUMN IF NOT EXISTS deposit_status VARCHAR(20) NOT NULL DEFAULT 'none' 
    CHECK (deposit_status IN ('none', 'pending', 'received', 'refunded', 'forfeited')),
ADD COLUMN IF NOT EXISTS deposit_notes TEXT;

-- Gỡ bỏ partial unique index cũ (vì trước đây chỉ cho 1 đơn confirmed/slot, giờ hỗ trợ shared capacity)
DROP INDEX IF EXISTS uq_active_amenity_slot;


-- 4. RPC ATOMIC: public.book_amenity_slot
-- ------------------------------------------------------------------------------
-- Khóa dòng tiện ích bằng FOR UPDATE, kiểm tra khoảng giao cắt bảo trì,
-- xác thực quyền căn hộ và validate chặt chẽ dữ liệu đầu vào.
CREATE OR REPLACE FUNCTION public.book_amenity_slot(
    p_amenity_id UUID,
    p_apartment_id UUID,
    p_booking_date DATE,
    p_time_slot VARCHAR,
    p_guests_count INT DEFAULT 1,
    p_allow_waitlist BOOLEAN DEFAULT false
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_amenity RECORD;
    v_maint_count INT;
    v_current_confirmed_count INT := 0;
    v_new_status VARCHAR := 'confirmed';
    v_booking_id UUID;
    v_slot_start_time TIMESTAMPTZ;
    v_slot_end_time TIMESTAMPTZ;
    v_start_time_str TEXT;
    v_end_time_str TEXT;
    v_has_access BOOLEAN;
BEGIN
    -- 1. Xác thực đăng nhập
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Bạn cần đăng nhập để đặt tiện ích.';
    END IF;

    -- 2. Kiểm tra quyền sở hữu/cư trú của user với apartment_id (fail-closed)
    IF NOT public.is_staff() THEN
        SELECT EXISTS (
            SELECT 1 FROM public.residents_apartments 
            WHERE user_id = v_user_id AND apartment_id = p_apartment_id
        ) INTO v_has_access;

        IF NOT v_has_access THEN
            RAISE EXCEPTION 'Bạn không có quyền đại diện căn hộ này để đặt tiện ích.';
        END IF;
    END IF;

    -- 3. Kiểm tra tính hợp lệ dữ liệu đầu vào (Input validation)
    IF p_booking_date < CURRENT_DATE THEN
        RAISE EXCEPTION 'Không thể đặt tiện ích cho ngày trong quá khứ.';
    END IF;

    IF p_guests_count <= 0 THEN
        RAISE EXCEPTION 'Số lượng người tham gia phải lớn hơn 0.';
    END IF;

    IF position(' - ' IN p_time_slot) = 0 THEN
        RAISE EXCEPTION 'Định dạng khung giờ không hợp lệ (Phải có dạng HH:mm - HH:mm).';
    END IF;

    v_start_time_str := split_part(p_time_slot, ' - ', 1);
    v_end_time_str := split_part(p_time_slot, ' - ', 2);
    v_slot_start_time := (p_booking_date::text || ' ' || v_start_time_str || ':00')::timestamptz;
    v_slot_end_time := (p_booking_date::text || ' ' || v_end_time_str || ':00')::timestamptz;

    -- Chặn khung giờ đã trôi qua nếu đặt cho ngày hôm nay
    IF p_booking_date = CURRENT_DATE AND v_slot_start_time <= NOW() THEN
        RAISE EXCEPTION 'Khung giờ này đã bắt đầu hoặc đã qua trong hôm nay.';
    END IF;

    -- 4. Khóa dòng tiện ích bằng FOR UPDATE để serialize các giao dịch đồng thời
    SELECT * INTO v_amenity 
    FROM public.building_amenities 
    WHERE id = p_amenity_id AND is_active = true
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Tiện ích không tồn tại hoặc đang tạm ngưng hoạt động.';
    END IF;

    -- Kiểm tra số khách không vượt quá max_capacity của tiện ích
    IF p_guests_count > v_amenity.max_capacity THEN
        RAISE EXCEPTION 'Số lượng người đặt (% người) vượt quá sức chứa tối đa của tiện ích (% người).', 
            p_guests_count, v_amenity.max_capacity;
    END IF;

    -- 5. Kiểm tra khoảng giao cắt bảo trì (Interval Overlap Check)
    -- Giao cắt khi: slot_start < maint_end AND slot_end > maint_start
    SELECT count(*) INTO v_maint_count
    FROM public.amenity_maintenance_windows
    WHERE amenity_id = p_amenity_id
      AND v_slot_start_time < end_time
      AND v_slot_end_time > start_time;

    IF v_maint_count > 0 THEN
        RAISE EXCEPTION 'Khung giờ này tiện ích đang tạm đóng để bảo trì/vệ sinh.';
    END IF;

    -- 6. Tính tổng lượng khách/lượt đã confirmed trong slot
    IF v_amenity.booking_type = 'exclusive' THEN
        SELECT count(*) INTO v_current_confirmed_count
        FROM public.amenity_bookings
        WHERE amenity_id = p_amenity_id
          AND booking_date = p_booking_date
          AND time_slot = p_time_slot
          AND status = 'confirmed';
    ELSE
        SELECT COALESCE(SUM(guests_count), 0) INTO v_current_confirmed_count
        FROM public.amenity_bookings
        WHERE amenity_id = p_amenity_id
          AND booking_date = p_booking_date
          AND time_slot = p_time_slot
          AND status = 'confirmed';
    END IF;

    -- 7. Đánh giá tính khả dụng
    IF (v_current_confirmed_count + p_guests_count) <= v_amenity.max_capacity THEN
        v_new_status := 'confirmed';
    ELSE
        IF p_allow_waitlist THEN
            v_new_status := 'waitlist';
        ELSE
            RAISE EXCEPTION 'Khung giờ này đã hết chỗ (Sức chứa còn lại: % chỗ).', 
                GREATEST(0, v_amenity.max_capacity - v_current_confirmed_count);
        END IF;
    END IF;

    -- 8. Thực hiện Insert và lưu snapshot giá phí/tiền cọc
    INSERT INTO public.amenity_bookings (
        amenity_id,
        apartment_id,
        booked_by,
        booking_date,
        time_slot,
        status,
        guests_count,
        fee_amount,
        deposit_amount,
        deposit_status
    ) VALUES (
        p_amenity_id,
        p_apartment_id,
        v_user_id,
        p_booking_date,
        p_time_slot,
        v_new_status,
        p_guests_count,
        v_amenity.fee_amount,
        v_amenity.deposit_amount,
        CASE WHEN v_amenity.requires_deposit THEN 'pending' ELSE 'none' END
    ) RETURNING id INTO v_booking_id;

    RETURN jsonb_build_object(
        'success', true,
        'booking_id', v_booking_id,
        'status', v_new_status,
        'message', CASE 
            WHEN v_new_status = 'confirmed' THEN 'Đặt lịch thành công!'
            ELSE 'Khung giờ đã kín chỗ, bạn đã được thêm vào Danh Sách Chờ.'
        END
    );
END;
$$;

-- Phân quyền thực thi: Chỉ người dùng đã đăng nhập mới được gọi RPC
REVOKE EXECUTE ON FUNCTION public.book_amenity_slot(UUID, UUID, DATE, VARCHAR, INT, BOOLEAN) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.book_amenity_slot(UUID, UUID, DATE, VARCHAR, INT, BOOLEAN) TO authenticated;


-- 5. TRIGGER TỰ ĐỘNG ĐÔN WAITLIST KHI CÓ NGƯỜI HỦY LỊCH (FIFO & FOR UPDATE SKIP LOCKED)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_amenity_booking_cancellation()
RETURNS TRIGGER AS $$
DECLARE
    v_amenity RECORD;
    v_waitlist_rec RECORD;
    v_current_confirmed_count INT := 0;
    v_available_capacity INT := 0;
BEGIN
    -- Chỉ kích hoạt khi một lượt đặt confirmed chuyển sang cancelled
    IF OLD.status = 'confirmed' AND NEW.status = 'cancelled' THEN
        -- Khóa tiện ích để tính toán lại sức chứa
        SELECT * INTO v_amenity 
        FROM public.building_amenities 
        WHERE id = NEW.amenity_id 
        FOR UPDATE;

        IF FOUND THEN
            -- Tính số chỗ hiện còn trống
            IF v_amenity.booking_type = 'exclusive' THEN
                SELECT count(*) INTO v_current_confirmed_count
                FROM public.amenity_bookings
                WHERE amenity_id = NEW.amenity_id
                  AND booking_date = NEW.booking_date
                  AND time_slot = NEW.time_slot
                  AND status = 'confirmed';
            ELSE
                SELECT COALESCE(SUM(guests_count), 0) INTO v_current_confirmed_count
                FROM public.amenity_bookings
                WHERE amenity_id = NEW.amenity_id
                  AND booking_date = NEW.booking_date
                  AND time_slot = NEW.time_slot
                  AND status = 'confirmed';
            END IF;

            v_available_capacity := v_amenity.max_capacity - v_current_confirmed_count;

            -- Tìm người đầu tiên trong waitlist có số khách vừa vặn với số chỗ còn trống
            FOR v_waitlist_rec IN
                SELECT id, booked_by, guests_count
                FROM public.amenity_bookings
                WHERE amenity_id = NEW.amenity_id
                  AND booking_date = NEW.booking_date
                  AND time_slot = NEW.time_slot
                  AND status = 'waitlist'
                  AND guests_count <= v_available_capacity
                ORDER BY created_at ASC
                FOR UPDATE SKIP LOCKED
            LOOP
                -- Đôn lên confirmed
                UPDATE public.amenity_bookings
                SET status = 'confirmed', updated_at = NOW()
                WHERE id = v_waitlist_rec.id;

                -- Gửi thông báo đến cư dân vừa được đôn lên
                INSERT INTO public.notifications (user_id, title, content, type)
                VALUES (
                    v_waitlist_rec.booked_by,
                    'Lịch tiện ích đã được xác nhận!',
                    format('Khung giờ %s ngày %s cho tiện ích %s đã có chỗ trống và tự động xác nhận cho bạn.', 
                        NEW.time_slot, NEW.booking_date, v_amenity.name),
                    'amenity'
                );

                v_available_capacity := v_available_capacity - v_waitlist_rec.guests_count;
                EXIT WHEN v_available_capacity <= 0;
            END LOOP;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_amenity_booking_cancellation ON public.amenity_bookings;
CREATE TRIGGER trg_amenity_booking_cancellation
AFTER UPDATE OF status ON public.amenity_bookings
FOR EACH ROW EXECUTE FUNCTION public.handle_amenity_booking_cancellation();


-- 6. REALTIME REGISTRATION
-- ------------------------------------------------------------------------------
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.amenity_maintenance_windows;
    END IF;
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;
