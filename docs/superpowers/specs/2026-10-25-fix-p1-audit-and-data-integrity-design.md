# Thiết Kế Kỹ Thuật: Khắc Phục Lỗi Toàn Vẹn Dữ Liệu, Phân Quyền & Kiểm Thử Nghiệp Vụ (P1 Audit Fixes)

## 1. Tổng Quan & Phạm Vi
Tài liệu này xác định phương án kỹ thuật toàn diện nhằm xử lý triệt để các vấn đề an ninh, toàn vẹn dữ liệu và chất lượng kiểm thử được phát hiện trong đợt đánh giá hệ thống (V2 Migration & Pending Requests):
1. **Phân quyền thao tác chờ duyệt (P1)**: Thống nhất quyền sở hữu nghiêm ngặt cho phương tiện và phiếu điện nước — chỉ người trực tiếp tạo (`user_id`, `registered_by`, `submitted_by`) hoặc Ban Quản Lý (`is_staff()`) mới có quyền sửa hoặc hủy. Loại bỏ hoàn toàn nhánh cấp quyền thao tác chéo của cư dân cùng căn hộ (`residents_apartments`).
2. **Thứ tự chuyển đổi Schema & Dọn dẹp dữ liệu trùng lặp trong Migration (P1)**: 
   - Đảm bảo cột `status` chuyển sang `VARCHAR(20)` và áp dụng CHECK constraint hợp lệ (bao gồm `'cancelled'`) **trước khi** chạy UPDATE dọn dẹp.
   - Dọn sạch các yêu cầu liên kết căn hộ trùng cặp `(user_id, apartment_id)` đang hoạt động (`pending`/`approved`) bằng CTE, ưu tiên giữ bản ghi `approved` hoặc `created_at` mới nhất, chuyển bản ghi thừa sang `cancelled`.
   - Loại bỏ hoàn toàn khối nuốt lỗi `EXCEPTION WHEN OTHERS THEN NULL` để migration fail-fast nếu gặp lỗi DDL.
   - Thiết lập Partial Unique Index `uq_link_requests_active`.
3. **Củng cố hạn mức 2 xe máy ở cả 2 tầng (P1)**: 
   - Sửa logic đếm xe đang hoạt động ở [vehicle_repository.dart](file:///c:/Users/ADMIN/StudioProjects/pka_home/lib/data/repositories/vehicle_repository.dart) dùng `.inFilter('status', ['pending', 'approved'])` (loại trừ `cancelled`).
   - Cập nhật và kích hoạt trigger `check_vehicle_limits()` trên bảng `public.vehicles` trong migration: khóa dòng căn hộ `FOR UPDATE`, kiểm tra `NEW.status IN ('pending', 'approved')`, loại trừ `id != NEW.id`, bắt buộc tồn tại căn hộ hợp lệ, áp dụng cho cả `INSERT` và `UPDATE`.
4. **Xác thực khung giờ & đôn Waitlist đổi lịch tiện ích an toàn (P1)**: 
   - Kiểm tra regex định dạng giờ nghiêm ngặt `^\d{2}:\d{2}\s*-\s*\d{2}:\d{2}$`, loại bỏ khối nuốt lỗi `invalid_datetime_format`.
   - Đối soát khung giờ mới nằm trong khoảng giờ hoạt động (`open_hours`) của tiện ích.
   - Đôn Waitlist theo Hàng đợi nghiêm ngặt (Strict FIFO): tính sức chứa còn trống từ **chính slot cũ** sau khi lượt đặt chuyển đi; chỉ đôn lượt đầu tiên nếu vừa sức chứa còn lại; nếu không vừa, giữ nguyên trong Waitlist (không nhảy cóc).
5. **Chuẩn hóa phản hồi RPC & Thông báo đổi lịch phía giao diện (P2)**: 
   - RPC trả về các trường trạng thái rõ ràng: `action` (`rescheduled_confirmed`, `rescheduled_pending_payment`), `status`, `waitlist_promoted`.
   - Giao diện [amenity_booking_screen.dart](file:///c:/Users/ADMIN/StudioProjects/pka_home/lib/features/resident/screens/amenity_booking_screen.dart) dựa vào `action` và `status` để hiển thị SnackBar chuẩn xác; hiển thị thông báo lỗi màu đỏ khi đổi lịch thất bại.
6. **Chiến lược kiểm thử 3 lớp (Testing)**: 
   - Lớp 1: Repository unit test với mocktail kiểm tra tên RPC, toàn bộ tham số, kết quả và lỗi.
   - Lớp 2: Database / Migration test xác minh thứ tự DDL, logic dọn trùng, trigger hạn mức xe máy, và RPC đổi lịch.
   - Lớp 3: Widget test kiểm tra UI phản hồi với các trạng thái khác nhau.

---

## 2. Thiết Kế Cơ Sở Dữ Liệu & Migration

### 2.1. Thứ Tự Migration Chuẩn Hóa & Schema Hardening
Trong file migration `supabase/migrations/20261024_04_pending_requests_correction_and_reschedule.sql`:

```sql
-- Bước 1: Nâng cấp kiểu dữ liệu cột status của public.apartment_link_requests sang VARCHAR(20)
-- Bỏ khối DO có EXCEPTION WHEN OTHERS THEN NULL để đảm bảo lỗi DDL sẽ làm migration dừng ngay lập tức.
ALTER TABLE public.apartment_link_requests 
  ALTER COLUMN status TYPE VARCHAR(20) USING status::text;

-- Xóa check constraint cũ nếu có và áp dụng constraint mới chứa 4 trạng thái
ALTER TABLE public.apartment_link_requests DROP CONSTRAINT IF EXISTS apartment_link_requests_status_check;
ALTER TABLE public.apartment_link_requests ADD CONSTRAINT apartment_link_requests_status_check 
  CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled'));

-- Xóa constraint UNIQUE cũ không điều kiện (nếu có)
ALTER TABLE public.apartment_link_requests DROP CONSTRAINT IF EXISTS apartment_link_requests_user_id_apartment_id_key;

-- Bước 2: Dọn dẹp bản ghi trùng lặp lịch sử trước khi tạo Partial Unique Index
-- Ưu tiên giữ lại bản ghi 'approved', nếu cùng trạng thái thì lấy bản ghi mới nhất (created_at DESC).
-- Các bản ghi trùng còn lại được chuyển sang 'cancelled'.
WITH duplicates AS (
    SELECT id,
           ROW_NUMBER() OVER (
               PARTITION BY user_id, apartment_id 
               ORDER BY (CASE WHEN status = 'approved' THEN 1 ELSE 2 END), created_at DESC
           ) as rn
    FROM public.apartment_link_requests
    WHERE status IN ('pending', 'approved')
)
UPDATE public.apartment_link_requests
SET status = 'cancelled', updated_at = NOW()
WHERE id IN (SELECT id FROM duplicates WHERE rn > 1);

-- Bước 3: Thiết lập Partial Unique Index đảm bảo tại một thời điểm mỗi cặp (user, apartment) chỉ có tối đa 1 yêu cầu active
CREATE UNIQUE INDEX IF NOT EXISTS uq_link_requests_active 
ON public.apartment_link_requests(user_id, apartment_id) 
WHERE status IN ('pending', 'approved');
```

### 2.2. Thống Nhất Chính Sách Phân Quyền Sở Hữu Nghiêm Ngặt
Loại bỏ hoàn toàn nhánh kiểm tra cư dân cùng căn hộ thông qua `residents_apartments`. Chỉ người trực tiếp đăng ký/gửi hoặc nhân sự Ban Quản Lý mới có quyền:
- **`cancel_pending_vehicle(p_vehicle_id UUID)`**:
  ```sql
  WHERE id = p_vehicle_id 
    AND status = 'pending'
    AND (user_id = v_user_id OR registered_by = v_user_id OR public.is_staff());
  ```
- **`update_pending_vehicle(...)`**:
  ```sql
  IF v_vehicle.user_id != v_user_id 
     AND v_vehicle.registered_by != v_user_id 
     AND NOT public.is_staff() THEN
      RAISE EXCEPTION 'Bạn không có quyền chỉnh sửa thông tin phương tiện này.';
  END IF;
  ```
- **`update_pending_meter_reading(...)`**:
  ```sql
  IF v_sub.submitted_by != v_user_id AND NOT public.is_staff() THEN
      RAISE EXCEPTION 'Bạn không có quyền chỉnh sửa phiếu chỉ số này.';
  END IF;
  ```
- **`cancel_pending_meter_reading(p_submission_id UUID)`**:
  ```sql
  WHERE id = p_submission_id 
    AND status = 'pending'
    AND (submitted_by = v_user_id OR public.is_staff());
  ```

### 2.3. Trigger Kiểm Tra Hạn Mức 2 Xe Máy Cấp CSDL
Định nghĩa và gắn trigger `trg_check_vehicle_limits` ngay trong migration:
```sql
CREATE OR REPLACE FUNCTION public.check_vehicle_limits()
RETURNS TRIGGER 
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    current_motorbike_count INT;
    v_apt_exists BOOLEAN;
BEGIN
    -- Chỉ kiểm tra khi là xe máy và bản ghi ở trạng thái hoạt động (pending hoặc approved)
    IF NEW.vehicle_type = 'motorbike' AND NEW.status IN ('pending', 'approved') THEN
        IF NEW.apartment_id IS NULL THEN
            RAISE EXCEPTION 'Căn hộ không hợp lệ (apartment_id không được để trống).';
        END IF;

        -- Khóa dòng căn hộ để tuần tự hóa chống Race Condition đăng ký đồng thời
        PERFORM 1 FROM public.apartments WHERE id = NEW.apartment_id FOR UPDATE;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Không tìm thấy căn hộ tương ứng trong hệ thống.';
        END IF;

        -- Đếm số xe máy active của căn hộ, loại trừ chính bản ghi đang cập nhật
        SELECT count(*) INTO current_motorbike_count
        FROM public.vehicles
        WHERE apartment_id = NEW.apartment_id 
          AND vehicle_type = 'motorbike'
          AND status IN ('pending', 'approved')
          AND id != COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000'::uuid);

        IF current_motorbike_count >= 2 THEN
            RAISE EXCEPTION 'Mỗi căn hộ chỉ được đăng ký tối đa 2 xe máy theo quy định của tòa nhà.';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_check_vehicle_limits ON public.vehicles;
CREATE TRIGGER trg_check_vehicle_limits
BEFORE INSERT OR UPDATE ON public.vehicles
FOR EACH ROW EXECUTE FUNCTION public.check_vehicle_limits();
```

### 2.4. Khắc Phục Toàn Vẹn Đổi Lịch Tiện Ích (`reschedule_amenity_booking`)
Cải tiến toàn diện function `public.reschedule_amenity_booking`:
1. **Xác thực định dạng giờ**:
   - Sử dụng regex kiểm tra cấu trúc:
     ```sql
     IF p_new_time_slot !~ '^[0-2][0-9]:[0-5][0-9]\s*-\s*[0-2][0-9]:[0-5][0-9]$' THEN
         RAISE EXCEPTION 'Định dạng khung giờ không hợp lệ. Yêu cầu định dạng HH:mm - HH:mm (VD: 08:00 - 10:00).';
     END IF;
     ```
   - Chuyển đổi giờ bắt đầu/kết thúc sang `TIME` trực tiếp; nếu xảy ra lỗi chuyển kiểu, để Postgres báo lỗi trực tiếp, **không dùng** `WHEN invalid_datetime_format THEN NULL`.
2. **Kiểm tra giờ mở cửa (`open_hours`)**:
   - Trích xuất `open_hours` của tiện ích (VD: `"06:00 - 22:00"`). Đảm bảo giờ bắt đầu của `p_new_time_slot` >= giờ mở cửa và giờ kết thúc <= giờ đóng cửa.
3. **Kiểm tra giờ đã qua nếu là ngày hôm nay**:
   - Nếu `p_new_date = (v_now_vn::date)` và giờ bắt đầu <= `(v_now_vn::time)` -> ném ngoại lệ rõ ràng.
4. **Sắp xếp Advisory Lock chống Deadlock**:
   - Giữ nguyên cơ chế `v_lock1 := LEAST(v_h_old, v_h_new); v_lock2 := GREATEST(v_h_old, v_h_new);` khóa tuần tự cả slot cũ và slot mới.
5. **Kiểm tra sức chứa slot mới**:
   - Exclusive: không có ai đặt trước (`status IN ('confirmed', 'pending_payment')`).
   - Shared: `SUM(guests_count) + v_final_guests <= max_capacity`.
6. **Đôn Waitlist cho slot cũ theo Strict FIFO**:
   - Sau khi cập nhật booking hiện tại sang slot mới:
   - Tính sức chứa đã sử dụng của slot cũ:
     ```sql
     SELECT COALESCE(SUM(guests_count), 0), COUNT(*) 
     INTO v_old_slot_used_guests, v_old_slot_used_count
     FROM public.amenity_bookings
     WHERE amenity_id = v_booking.amenity_id
       AND booking_date = v_booking.booking_date
       AND time_slot = v_booking.time_slot
       AND status IN ('confirmed', 'pending_payment');
     ```
   - Sức chứa còn trống của slot cũ: `v_old_slot_avail := v_amenity.max_capacity - v_old_slot_used_guests`.
   - Tìm lượt Waitlist đầu tiên:
     ```sql
     SELECT * INTO v_next_waitlist
     FROM public.amenity_bookings
     WHERE amenity_id = v_booking.amenity_id
       AND booking_date = v_booking.booking_date
       AND time_slot = v_booking.time_slot
       AND status = 'waitlist'
     ORDER BY created_at ASC
     LIMIT 1
     FOR UPDATE;
     ```
   - **Xét điều kiện đôn**:
     - Nếu `v_amenity.booking_type = 'exclusive'`: điều kiện là `v_old_slot_used_count = 0`.
     - Nếu `v_amenity.booking_type = 'shared'`: điều kiện là `v_next_waitlist.guests_count <= v_old_slot_avail`.
   - **Thực thi đôn**:
     - Nếu thỏa mãn: chuyển `v_next_waitlist.status` sang `pending_payment` (nếu có phí/cọc) hoặc `confirmed` (nếu miễn phí). Đánh dấu `v_waitlist_promoted := true`.
     - Nếu không thỏa mãn: giữ nguyên lượt đó trong Waitlist (Strict FIFO — không bỏ qua để đôn lượt sau).
7. **Hợp đồng phản hồi JSONB**:
   ```sql
   RETURN jsonb_build_object(
       'success', true,
       'action', CASE 
           WHEN v_booking.status = 'confirmed' THEN 'rescheduled_confirmed'
           ELSE 'rescheduled_pending_payment'
       END,
       'status', v_booking.status,
       'waitlist_promoted', v_waitlist_promoted,
       'message', 'Đổi lịch đặt tiện ích thành công',
       'booking_id', p_booking_id,
       'new_date', p_new_date,
       'new_time_slot', p_new_time_slot
   );
   ```

---

## 3. Thiết Kế Tầng Ứng Dụng (Flutter)

### 3.1. Sửa Bộ Đếm Xe Máy Trong `VehicleRepository`
Tại file `lib/data/repositories/vehicle_repository.dart`:
```dart
Future<int> getActiveMotorbikeCount(String apartmentId) async {
  final response = await _client
      .from('vehicles')
      .select('id')
      .eq('apartment_id', apartmentId)
      .eq('vehicle_type', 'motorbike')
      .inFilter('status', ['pending', 'approved']);

  return (response as List).length;
}
```

### 3.2. Cập Nhật Xử Lý Phản Hồi Trong `AmenityBookingScreen`
Tại file `lib/features/resident/screens/amenity_booking_screen.dart`:
```dart
final action = res['action'] as String?;
final status = res['status'] as String?;

String successMsg;
if (action == 'rescheduled_pending_payment' || status == 'pending_payment') {
  successMsg = 'Đổi lịch thành công! Vui lòng hoàn tất thanh toán cho lịch đặt mới.';
} else {
  successMsg = 'Đổi lịch đặt chỗ thành công!';
}

ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text(successMsg),
    backgroundColor: AppTheme.success,
  ),
);
```
Trong trường hợp bắt được exception từ `rescheduleBooking`: hiển thị SnackBar màu đỏ (`AppTheme.error`), giữ nguyên form và không đóng modal để người dùng có thể chọn khung giờ khác.

---

## 4. Chiến Lược Kiểm Thử (3 Lớp Toàn Diện)

### 4.1. Lớp 1: Repository Unit Tests Với Mocktail
Viết lại file `test/data/repositories/pending_requests_correction_repository_test.dart`:
- Mock `SupabaseClient.rpc(...)` và `SupabaseClient.from(...)`.
- `VehicleRepository.updatePendingVehicle`: Xác minh truyền đúng RPC `'update_pending_vehicle'`, đúng map tham số `p_vehicle_id`, `p_license_plate`, `p_vehicle_type`, `p_brand_model`.
- `VehicleRepository.cancelPendingVehicle`: Xác minh truyền đúng RPC `'cancel_pending_vehicle'` và `p_vehicle_id`.
- `VehicleRepository.getActiveMotorbikeCount`: Xác minh gọi truy vấn lọc đúng `inFilter('status', ['pending', 'approved'])`.
- `AmenityBookingRepository.rescheduleBooking`: Xác minh truyền đúng RPC `'reschedule_amenity_booking'`, định dạng ngày `YYYY-MM-DD`, giờ, số khách.
- `MeterReadingRepository.updatePendingSubmission` & `cancelPendingSubmission`: Xác minh truyền đúng tên RPC và các tham số tương ứng.
- Kiểm tra xử lý ngoại lệ: khi RPC trả về `success: false` hoặc client ném `PostgrestException`, repository phải ném ra Exception có thông điệp tiếng Việt thân thiện.

### 4.2. Lớp 2: Database / Migration Schema Tests
Cập nhật file `test/data/repositories/pending_correction_migration_test.dart`:
- Kiểm tra thứ tự chuyển kiểu dữ liệu: `ALTER COLUMN status TYPE VARCHAR(20)` xuất hiện trước đoạn dọn trùng `WITH duplicates AS (...)`.
- Kiểm tra loại bỏ hoàn toàn `EXCEPTION WHEN OTHERS THEN NULL`.
- Kiểm tra trigger `check_vehicle_limits`: có `FOR UPDATE` khóa dòng căn hộ, có kiểm tra `NEW.status IN ('pending', 'approved')`, có `DROP TRIGGER IF EXISTS` và `CREATE TRIGGER`.
- Kiểm tra phân quyền: không chứa nhánh `residents_apartments` trong `update_pending_vehicle` và các RPC sửa/hủy.
- Kiểm tra `reschedule_amenity_booking`: kiểm tra định dạng giờ regex, tính toán sức chứa slot cũ `v_old_slot_avail` và logic Strict FIFO trước khi đôn Waitlist.

### 4.3. Lớp 3: Widget / Flutter Tests
- Kiểm tra giao diện `AmenityBookingScreen` hiển thị nút Đổi lịch cho booking hợp lệ.
- Kiểm tra thông báo SnackBar thành công hiển thị đúng nội dung theo `action`.
- Kiểm tra hiển thị SnackBar lỗi khi đổi lịch thất bại.
- Chạy `dart analyze` và `flutter test` xác nhận 100% kiểm thử vượt qua.
