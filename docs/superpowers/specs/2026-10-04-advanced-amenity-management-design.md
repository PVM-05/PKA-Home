# Đặc Tả Thiết Kế: Quản Lý Tiện Ích Nâng Cao (Advanced Amenity Management)

**Mã tài liệu:** `SPEC-2026-10-04-AMENITY-V2`  
**Ngày lập:** 04/10/2026  
**Trạng thái:** Đã phê duyệt (Approved)  
**Phạm vi:** Cư dân (Resident) & Ban quản lý (Management)  

---

## 1. Mục Tiêu & Bối Cảnh Nghiệp Vụ

Hệ thống PKA-Home hiện đã có tính năng đặt lịch tiện ích cơ bản, tuy nhiên còn các hạn chế:
- Khung giờ đang là danh sách tĩnh hardcode trên giao diện client.
- Chưa hỗ trợ tiện ích dùng chung (shared capacity - ví dụ hồ bơi, phòng gym cho phép nhiều cư dân cùng vào 1 lúc).
- Chưa có cơ chế quản lý phí sử dụng và tiền đặt cọc (BBQ, phòng sinh hoạt cộng đồng).
- Chưa có danh sách chờ (Waitlist) khi slot đã kín chỗ.
- Chưa có cơ chế khóa lịch tiện ích định kỳ phục vụ công tác vệ sinh, sửa chữa, bảo trì.
- Cần cơ chế khóa đồng thời (Atomic concurrency control) qua Postgres RPC để loại trừ hoàn toàn nguy cơ tranh chấp đặt trùng slot (Race condition).

---

## 2. Thiết Kế Cơ Sở Dữ Liệu & Migration

### 2.1. Nâng cấp bảng `public.building_amenities`
Bổ sung các cột cấu hình tiện ích:
```sql
ALTER TABLE public.building_amenities
ADD COLUMN IF NOT EXISTS booking_type VARCHAR(20) NOT NULL DEFAULT 'exclusive' 
    CHECK (booking_type IN ('exclusive', 'shared')),
ADD COLUMN IF NOT EXISTS max_capacity INT NOT NULL DEFAULT 1 CHECK (max_capacity >= 1),
ADD COLUMN IF NOT EXISTS slot_duration_minutes INT NOT NULL DEFAULT 90 CHECK (slot_duration_minutes >= 30),
ADD COLUMN IF NOT EXISTS fee_amount NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (fee_amount >= 0),
ADD COLUMN IF NOT EXISTS deposit_amount NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (deposit_amount >= 0),
ADD COLUMN IF NOT EXISTS requires_deposit BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT true;
```

### 2.2. Bảng mới: `public.amenity_maintenance_windows`
Quản lý các khoảng thời gian bảo trì tiện ích:
```sql
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

CREATE POLICY "Mọi người xem lịch bảo trì tiện ích"
ON public.amenity_maintenance_windows FOR SELECT
USING (auth.uid() IS NOT NULL);

CREATE POLICY "Ban quản lý quản trị lịch bảo trì"
ON public.amenity_maintenance_windows FOR ALL
USING (public.is_staff());
```

### 2.3. Nâng cấp bảng `public.amenity_bookings`
Mở rộng trạng thái và bổ sung thông tin cọc/khách:
```sql
-- Điều chỉnh ràng buộc status
ALTER TABLE public.amenity_bookings 
DROP CONSTRAINT IF EXISTS amenity_bookings_status_check;

ALTER TABLE public.amenity_bookings 
ADD CONSTRAINT amenity_bookings_status_check 
CHECK (status IN ('confirmed', 'waitlist', 'cancelled', 'completed', 'no_show'));

-- Thêm cột số lượng người và trạng thái tiền cọc
ALTER TABLE public.amenity_bookings
ADD COLUMN IF NOT EXISTS guests_count INT NOT NULL DEFAULT 1 CHECK (guests_count >= 1),
ADD COLUMN IF NOT EXISTS deposit_status VARCHAR(20) NOT NULL DEFAULT 'none' 
    CHECK (deposit_status IN ('none', 'pending', 'received', 'refunded', 'forfeited')),
ADD COLUMN IF NOT EXISTS deposit_notes TEXT;
```

### 2.4. Lưu trữ Atomic Booking qua Postgres RPC: `book_amenity_slot`
Hàm xử lý đặt slot atomic, ngăn chặn race condition:
```sql
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
    v_start_time_str TEXT;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Bạn cần đăng nhập để đặt tiện ích.';
    END IF;

    -- 1. Lấy thông tin tiện ích
    SELECT * INTO v_amenity FROM public.building_amenities WHERE id = p_amenity_id AND is_active = true;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Tiện ích không tồn tại hoặc đang tạm ngưng hoạt động.';
    END IF;

    -- 2. Kiểm tra lịch bảo trì trùng với ngày đặt
    v_start_time_str := split_part(p_time_slot, ' - ', 1);
    IF v_start_time_str <> '' THEN
        v_slot_start_time := (p_booking_date::text || ' ' || v_start_time_str || ':00')::timestamptz;
        SELECT count(*) INTO v_maint_count
        FROM public.amenity_maintenance_windows
        WHERE amenity_id = p_amenity_id
          AND start_time <= v_slot_start_time
          AND end_time > v_slot_start_time;

        IF v_maint_count > 0 THEN
            RAISE EXCEPTION 'Khung giờ này tiện ích đang tạm đóng để bảo trì/vệ sinh.';
        END IF;
    END IF;

    -- 3. Khóa dòng và tính tổng lượng khách/lượt đã confirmed
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

    -- 4. Đánh giá tính khả dụng
    IF (v_current_confirmed_count + p_guests_count) <= v_amenity.max_capacity THEN
        v_new_status := 'confirmed';
    ELSE
        IF p_allow_waitlist THEN
            v_new_status := 'waitlist';
        ELSE
            RAISE EXCEPTION 'Khung giờ này đã hết chỗ (Sức chứa tối đa: % chỗ).', v_amenity.max_capacity;
        END IF;
    END IF;

    -- 5. Thực hiện Insert
    INSERT INTO public.amenity_bookings (
        amenity_id,
        apartment_id,
        booked_by,
        booking_date,
        time_slot,
        status,
        guests_count,
        deposit_status
    ) VALUES (
        p_amenity_id,
        p_apartment_id,
        v_user_id,
        p_booking_date,
        p_time_slot,
        v_new_status,
        p_guests_count,
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
```

### 2.5. Trigger Tự Động Đôn Waitlist khi có người hủy lịch
```sql
CREATE OR REPLACE FUNCTION public.handle_amenity_booking_cancellation()
RETURNS TRIGGER AS $$
DECLARE
    v_waitlist_id UUID;
    v_waitlist_user UUID;
    v_amenity_name TEXT;
BEGIN
    -- Chỉ kích hoạt khi một lượt đặt được chuyển sang cancelled
    IF OLD.status = 'confirmed' AND NEW.status = 'cancelled' THEN
        -- Tìm người đăng ký waitlist sớm nhất
        SELECT id, booked_by INTO v_waitlist_id, v_waitlist_user
        FROM public.amenity_bookings
        WHERE amenity_id = NEW.amenity_id
          AND booking_date = NEW.booking_date
          AND time_slot = NEW.time_slot
          AND status = 'waitlist'
        ORDER BY created_at ASC
        LIMIT 1;

        IF v_waitlist_id IS NOT NULL THEN
            UPDATE public.amenity_bookings
            SET status = 'confirmed', updated_at = NOW()
            WHERE id = v_waitlist_id;

            -- Gửi thông báo đến cư dân vừa được đôn lên
            SELECT name INTO v_amenity_name FROM public.building_amenities WHERE id = NEW.amenity_id;
            
            INSERT INTO public.notifications (user_id, title, content, type)
            VALUES (
                v_waitlist_user,
                'Lịch tiện ích đã được xác nhận!',
                format('Khung giờ %s ngày %s cho tiện ích %s đã có chỗ trống và tự động xác nhận cho bạn.', NEW.time_slot, NEW.booking_date, v_amenity_name),
                'amenity'
            );
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_amenity_booking_cancellation ON public.amenity_bookings;
CREATE TRIGGER trg_amenity_booking_cancellation
AFTER UPDATE OF status ON public.amenity_bookings
FOR EACH ROW EXECUTE FUNCTION public.handle_amenity_booking_cancellation();
```

---

## 3. Kiến Trúc Ứng Dụng & Luồng Dữ Liệu (Flutter)

### 3.1. Models
* **`BuildingAmenityModel`**: Thêm `bookingType`, `maxCapacity`, `slotDurationMinutes`, `feeAmount`, `depositAmount`, `requiresDeposit`, `isActive`.
* **`AmenityBookingModel`**: Mở rộng `status` (confirmed, waitlist, cancelled, completed, no_show), thêm `guestsCount`, `depositStatus`, `depositNotes`.
* **`AmenityMaintenanceModel`**: Model đại diện cho các khoảng bảo trì.

### 3.2. Repositories & Providers
* **`AmenityBookingRepository`**:
  * `createBooking(...)`: Gọi RPC `book_amenity_slot`.
  * `cancelBooking(...)`: Gọi update `status = 'cancelled'`.
  * `updateDepositStatus(...)`: Ban quản lý cập nhật tiền cọc.
  * `markBookingAttendance(...)`: Ban quản lý đánh dấu `completed` hoặc `no_show`.
  * `getMaintenanceWindows(...)`: Lấy các khoảng bảo trì.
  * `createMaintenanceWindow(...)`: Tạo lịch bảo trì (Admin/BQL).
* **Providers**:
  * `amenityBookingsForDateProvider`: Cập nhật logic tính tổng số lượng slot đã đăng ký.
  * `amenityMaintenanceProvider`: Cung cấp danh sách bảo trì để làm mờ slot trên UI.

### 3.3. Giao Diện Người Dùng (UI/UX)
* **Slot Generator Động**:
  * Tính toán slot dựa trên `open_hours` (VD `06:00 - 21:00`) và `slot_duration_minutes` (90 phút $\rightarrow$ các khung `06:00 - 07:30`, `07:30 - 09:00`,...).
  * Nếu ngày được chọn là ngày hiện tại: Tự động khóa và làm mờ các khung giờ đã bắt đầu/trôi qua trong ngày.
  * Nếu trùng lịch bảo trì: Hiển thị badge màu cam *"Đang bảo trì"*, vô hiệu hóa chọn.
* **Hiển thị Sức Chứa (Capacity Badge)**:
  * Độc quyền (exclusive): Hiển thị badge *"Trống"* hoặc *"Đã có người đặt"*.
  * Dùng chung (shared): Hiển thị *"Còn X/Y chỗ"*.
* **Hỗ trợ Waitlist**:
  * Khi slot hết chỗ $\rightarrow$ Hiện nút bấm *"Gia nhập danh sách chờ"* màu tím/xanh nhạt.
* **Tab Quản lý của BQL (`ManagementAmenityScreen`)**:
  * Quản lý check-in: Cư dân đến quầy thì BQL ấn "Xác nhận nhận chỗ" / "Hoàn thành".
  * Xử lý cọc: Nút đổi trạng thái "Đã nhận cọc" $\leftrightarrow$ "Đã hoàn cọc".
  * Thêm lịch bảo trì tiện ích: Modal dialog chọn ngày giờ bắt đầu, kết thúc, lý do.

---

## 4. Kế Hoạch Kiểm Thử (Testing Matrix)

1. **Unit Test / Model Test**: Kiểm tra parse JSON các trường mới của `BuildingAmenityModel` và `AmenityBookingModel`.
2. **Logic Test**: Kiểm tra hàm sinh slot động theo `open_hours` và kiểm tra logic chặn khung giờ quá khứ.
3. **RPC & Concurrency Test**: Test RPC `book_amenity_slot` khi:
   - Đặt khi slot còn chỗ $\rightarrow$ Trả về `confirmed`.
   - Đặt khi slot đã kín và `allow_waitlist = false` $\rightarrow$ Ném lỗi `Khung giờ đã hết chỗ`.
   - Đặt khi slot đã kín và `allow_waitlist = true` $\rightarrow$ Trả về `waitlist`.
4. **Trigger Waitlist Test**: Test khi đơn `confirmed` bị hủy $\rightarrow$ Đơn `waitlist` đầu tiên tự động chuyển thành `confirmed`.
