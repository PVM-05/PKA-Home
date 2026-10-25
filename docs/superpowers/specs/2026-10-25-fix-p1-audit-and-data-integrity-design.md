# Thiết Kế Kỹ Thuật: Khắc Phục Lỗi Toàn Vẹn Dữ Liệu, Phân Quyền & Kiểm Thử Nghiệp Vụ (P1 Audit Fixes)

## 1. Tổng Quan & Phạm Vi
Tài liệu này xác định phương án kỹ thuật toàn diện nhằm xử lý triệt để các vấn đề an ninh, toàn vẹn dữ liệu và chất lượng kiểm thử được phát hiện trong đợt đánh giá hệ thống (V2 Migration & Pending Requests), đồng thời tiếp thu toàn bộ 5 điểm rà soát kỹ thuật chuyên sâu:
1. **Phân quyền thao tác chờ duyệt (P1)**: Thống nhất quyền sở hữu nghiêm ngặt cho phương tiện và phiếu điện nước — chỉ người trực tiếp tạo (`user_id`, `registered_by`, `submitted_by`) hoặc Ban Quản Lý (`is_staff()`) mới có quyền sửa hoặc hủy. Loại bỏ hoàn toàn nhánh cấp quyền thao tác chéo của cư dân cùng căn hộ (`residents_apartments`).
2. **Thứ tự chuyển đổi Schema & Dọn dẹp dữ liệu trùng lặp trong Migration (P1)**: 
   - Đảm bảo xử lý drop default, chuyển cột `status` sang `VARCHAR(20)`, gán default mới và áp dụng CHECK constraint hợp lệ (bao gồm `'cancelled'`) **trước khi** chạy UPDATE dọn dẹp.
   - Cập nhật các đối tượng phụ thuộc: RPC `approve_link_request` và policy RLS để không bị lỗi ép kiểu enum cũ `link_request_status`.
   - Dọn sạch các yêu cầu liên kết căn hộ trùng cặp `(user_id, apartment_id)` đang hoạt động (`pending`/`approved`) bằng CTE, ưu tiên giữ bản ghi `approved` hoặc `created_at` mới nhất, chuyển bản ghi thừa sang `cancelled`.
   - Loại bỏ hoàn toàn khối nuốt lỗi `EXCEPTION WHEN OTHERS THEN NULL` để migration fail-fast nếu gặp lỗi DDL.
   - Thiết lập Partial Unique Index `uq_link_requests_active`.
3. **Củng cố hạn mức 2 xe máy & An toàn Trigger (P1)**: 
   - Sửa logic đếm xe đang hoạt động ở [vehicle_repository.dart](file:///c:/Users/ADMIN/StudioProjects/pka_home/lib/data/repositories/vehicle_repository.dart) dùng `.inFilter('status', ['pending', 'approved'])` (loại trừ `cancelled`).
   - Cập nhật trigger `check_vehicle_limits()` trên bảng `public.vehicles`: đặt `SECURITY DEFINER` với `SET search_path = public, pg_catalog`, cấp quyền tối thiểu (`authenticated`, `service_role`). Khóa dòng căn hộ `FOR UPDATE`, kiểm tra `NEW.status IN ('pending', 'approved')`, loại trừ `id != NEW.id`, bắt buộc tồn tại căn hộ hợp lệ. Tương thích với toàn bộ luồng duyệt xe (`approved`), từ chối (`rejected`), hủy xe (`cancelled`) và cập nhật thông tin (`pending`).
4. **Xác thực khung giờ & đôn Waitlist đổi lịch tiện ích an toàn (P1)**: 
   - Regex kiểm tra định dạng giờ `^[0-2][0-9]:[0-5][0-9]\s*-\s*[0-2][0-9]:[0-5][0-9]$`.
   - Ép kiểu `TIME`, loại bỏ hoàn toàn khối nuốt lỗi `invalid_datetime_format`.
   - Kiểm tra logic giờ: giờ bắt đầu < giờ kết thúc (chặn qua đêm vì tiện ích chung cư chỉ hoạt động ban ngày).
   - Kiểm tra giờ mở cửa (`open_hours`): trích xuất giờ mở/đóng cửa và đảm bảo khung giờ mới nằm trọn vẹn trong khoảng hoạt động.
   - Đôn Waitlist theo Hàng đợi nghiêm ngặt (Strict FIFO): tính sức chứa còn trống từ **chính slot cũ** sau khi lượt đặt chuyển đi; chỉ đôn lượt đầu tiên nếu vừa sức chứa còn lại; nếu không vừa, giữ nguyên trong Waitlist (không nhảy cóc).
   - Đồng bộ tài chính: cập nhật `fee_amount`, `deposit_amount`, `deposit_status` và đồng bộ `payment_transactions` PENDING nếu có khi đôn lượt.
5. **Chuẩn hóa phản hồi RPC & Thông báo đổi lịch phía giao diện (P2)**: 
   - RPC trả về các trường trạng thái rõ ràng: `action` (`rescheduled_confirmed`, `rescheduled_pending_payment`), `status`, `waitlist_promoted`.
   - Giao diện [amenity_booking_screen.dart](file:///c:/Users/ADMIN/StudioProjects/pka_home/lib/features/resident/screens/amenity_booking_screen.dart) dựa vào `action` và `status` để hiển thị SnackBar chuẩn xác; hiển thị thông báo lỗi màu đỏ khi đổi lịch thất bại.
6. **Chiến lược kiểm thử 3 lớp thực chất (Testing)**: 
   - Lớp 1: Repository unit test với mocktail kiểm tra tên RPC, toàn bộ tham số, kết quả và lỗi.
   - Lớp 2: Database / Migration test xác minh thứ tự DDL, logic dọn trùng, trigger hạn mức xe máy, và RPC đổi lịch.
   - Lớp 3: Widget test kiểm tra UI phản hồi với các trạng thái khác nhau.
   - Chạy xác minh thực tế qua `dart analyze` và `flutter test`.

---

## 2. Thiết Kế Cơ Sở Dữ Liệu & Migration

### 2.1. Thứ Tự Migration Chuẩn Hóa & Schema Hardening
Trong file migration `supabase/migrations/20261024_04_pending_requests_correction_and_reschedule.sql`:

```sql
-- Bước 1: Nâng cấp kiểu dữ liệu cột status của public.apartment_link_requests sang VARCHAR(20)
-- 1.1 Xóa default cũ để tránh ràng buộc phụ thuộc vào enum link_request_status
ALTER TABLE public.apartment_link_requests 
  ALTER COLUMN status DROP DEFAULT;

-- 1.2 Chuyển kiểu dữ liệu sang VARCHAR(20)
ALTER TABLE public.apartment_link_requests 
  ALTER COLUMN status TYPE VARCHAR(20) USING status::text;

-- 1.3 Thiết lập default mới
ALTER TABLE public.apartment_link_requests 
  ALTER COLUMN status SET DEFAULT 'pending';

-- 1.4 Áp dụng check constraint mới chứa 4 trạng thái
ALTER TABLE public.apartment_link_requests DROP CONSTRAINT IF EXISTS apartment_link_requests_status_check;
ALTER TABLE public.apartment_link_requests ADD CONSTRAINT apartment_link_requests_status_check 
  CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled'));

-- 1.5 Xóa constraint UNIQUE cũ không điều kiện (nếu có)
ALTER TABLE public.apartment_link_requests DROP CONSTRAINT IF EXISTS apartment_link_requests_user_id_apartment_id_key;

-- 1.6 Cập nhật RLS Policy "Resident tạo yêu cầu" tránh ép kiểu enum cũ
DROP POLICY IF EXISTS "Resident tạo yêu cầu" ON public.apartment_link_requests;
CREATE POLICY "Resident tạo yêu cầu" 
ON public.apartment_link_requests FOR INSERT 
WITH CHECK (user_id = auth.uid() AND status = 'pending');

-- 1.7 Cập nhật RPC approve_link_request để biến v_status dùng VARCHAR(20) thay vì enum cũ
CREATE OR REPLACE FUNCTION public.approve_link_request(p_request_id UUID)
RETURNS void AS $$
DECLARE
  v_user_id UUID;
  v_apartment_id UUID;
  v_status VARCHAR(20);
  v_requested_role public.relation_type;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Chỉ Quản trị viên mới có quyền duyệt yêu cầu liên kết căn hộ.';
  END IF;

  SELECT user_id, apartment_id, status, requested_relation_role 
  INTO v_user_id, v_apartment_id, v_status, v_requested_role 
  FROM public.apartment_link_requests 
  WHERE id = p_request_id;

  IF v_status IS NULL THEN
    RAISE EXCEPTION 'Không tìm thấy yêu cầu liên kết.';
  END IF;

  IF v_status != 'pending' THEN
    RAISE EXCEPTION 'Yêu cầu này đã được xử lý.';
  END IF;

  UPDATE public.apartment_link_requests
  SET status = 'approved',
      updated_at = now()
  WHERE id = p_request_id;

  INSERT INTO public.residents_apartments (user_id, apartment_id, relation_role)
  VALUES (v_user_id, v_apartment_id, v_requested_role)
  ON CONFLICT (user_id, apartment_id) DO NOTHING;

  UPDATE public.apartments
  SET is_empty = false
  WHERE id = v_apartment_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_catalog;

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

### 2.3. Trigger Kiểm Tra Hạn Mức 2 Xe Máy Cấp CSDL & An Toàn Thực Thi
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

-- Giới hạn quyền thực thi trigger function
REVOKE ALL ON FUNCTION public.check_vehicle_limits() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.check_vehicle_limits() TO authenticated, service_role;

DROP TRIGGER IF EXISTS trg_check_vehicle_limits ON public.vehicles;
CREATE TRIGGER trg_check_vehicle_limits
BEFORE INSERT OR UPDATE ON public.vehicles
FOR EACH ROW EXECUTE FUNCTION public.check_vehicle_limits();
```
*Tương thích*:
- Thao tác BQL phê duyệt (`status = 'approved'`): `id != NEW.id` loại trừ bản ghi hiện tại, số lượng xe không tăng thêm -> Thành công.
- Thao tác BQL từ chối (`status = 'rejected'`): `NEW.status` không nằm trong `('pending', 'approved')` -> Bỏ qua kiểm tra -> Thành công.
- Thao tác Hủy (`status = 'cancelled'`): Bỏ qua kiểm tra -> Giải phóng hạn mức xe máy ngay lập tức.
- Thao tác Chỉnh sửa (`update_pending_vehicle`): `id != NEW.id` loại trừ chính mình, chỉ kiểm tra các xe khác cùng căn hộ.

### 2.4. Khắc Phục Toàn Vẹn Đổi Lịch Tiện Ích (`reschedule_amenity_booking`)
Cải tiến toàn diện function `public.reschedule_amenity_booking`:
1. **Xác thực định dạng giờ & logic thời gian**:
   - Sử dụng regex kiểm tra cấu trúc:
     ```sql
     IF p_new_time_slot !~ '^[0-2][0-9]:[0-5][0-9]\s*-\s*[0-2][0-9]:[0-5][0-9]$' THEN
         RAISE EXCEPTION 'Định dạng khung giờ không hợp lệ. Yêu cầu định dạng HH:mm - HH:mm (VD: 08:00 - 10:00).';
     END IF;
     ```
   - Chuyển đổi giờ bắt đầu/kết thúc sang `TIME` trực tiếp; nếu xảy ra lỗi chuyển kiểu, để Postgres báo lỗi trực tiếp, **không dùng** `WHEN invalid_datetime_format THEN NULL`:
     ```sql
     v_slot_start_time := TRIM(SPLIT_PART(p_new_time_slot, '-', 1))::time;
     v_slot_end_time := TRIM(SPLIT_PART(p_new_time_slot, '-', 2))::time;

     IF v_slot_start_time >= v_slot_end_time THEN
         RAISE EXCEPTION 'Khung giờ không hợp lệ: giờ bắt đầu (%) phải nhỏ hơn giờ kết thúc (%).', 
             v_slot_start_time, v_slot_end_time;
     END IF;
     ```
2. **Kiểm tra giờ mở cửa (`open_hours`)**:
   - Trích xuất `open_hours` của tiện ích (VD: `"06:00 - 22:00"`). Nếu tiện ích có giờ mở cửa:
     ```sql
     IF v_amenity.open_hours IS NOT NULL AND v_amenity.open_hours ~ '^[0-2][0-9]:[0-5][0-9]\s*-\s*[0-2][0-9]:[0-5][0-9]$' THEN
         v_open_start := TRIM(SPLIT_PART(v_amenity.open_hours, '-', 1))::time;
         v_open_end := TRIM(SPLIT_PART(v_amenity.open_hours, '-', 2))::time;
         IF v_slot_start_time < v_open_start OR v_slot_end_time > v_open_end THEN
             RAISE EXCEPTION 'Khung giờ mới (%) nằm ngoài giờ mở cửa của tiện ích (%).',
                 p_new_time_slot, v_amenity.open_hours;
         END IF;
     END IF;
     ```
3. **Kiểm tra giờ đã qua nếu là ngày hôm nay**:
   - Nếu `p_new_date = (v_now_vn::date)` và `v_slot_start_time <= (v_now_vn::time)` -> ném ngoại lệ rõ ràng.
4. **Sắp xếp Advisory Lock chống Deadlock**:
   - Sắp xếp thứ tự giá trị băm: `v_lock1 := LEAST(v_h_old, v_h_new); v_lock2 := GREATEST(v_h_old, v_h_new);` khóa tuần tự cả slot cũ và slot mới.
5. **Kiểm tra sức chứa slot mới**:
   - Exclusive: không có ai đặt trước (`status IN ('confirmed', 'pending_payment')`).
   - Shared: `SUM(guests_count) + v_final_guests <= max_capacity`.
6. **Đôn Waitlist cho slot cũ theo Strict FIFO & Đồng bộ thanh toán**:
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
     - Exclusive: `v_old_slot_used_count = 0`.
     - Shared: `v_next_waitlist.guests_count <= v_old_slot_avail`.
   - **Thực thi đôn**:
     - Nếu thỏa mãn:
       - Tính phí: `v_promoted_fee := COALESCE(v_amenity.fee_amount, 0) * v_next_waitlist.guests_count;`
       - Tiền cọc: `v_promoted_deposit := COALESCE(v_amenity.deposit_amount, 0);`
       - Nếu `(v_promoted_fee + v_promoted_deposit) > 0`:
         ```sql
         UPDATE public.amenity_bookings
         SET status = 'pending_payment',
             fee_amount = v_promoted_fee,
             deposit_amount = v_promoted_deposit,
             deposit_status = CASE WHEN v_promoted_deposit > 0 THEN 'pending' ELSE 'none' END,
             updated_at = NOW()
         WHERE id = v_next_waitlist.id;

         -- Đồng bộ số tiền trong payment_transactions PENDING nếu đã có
         UPDATE public.payment_transactions
         SET amount = (v_promoted_fee + v_promoted_deposit),
             updated_at = NOW()
         WHERE booking_id = v_next_waitlist.id AND status = 'PENDING';
         ```
       - Nếu miễn phí: chuyển sang `'confirmed'`.
       - Đánh dấu `v_waitlist_promoted := true`.
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

### 4.2. Lớp 2: Database / Migration Schema & Integrity Tests
Cập nhật file `test/data/repositories/pending_correction_migration_test.dart`:
- Kiểm tra thứ tự chuyển kiểu dữ liệu: `status DROP DEFAULT`, `ALTER COLUMN status TYPE VARCHAR(20)`, `status SET DEFAULT 'pending'` xuất hiện trước đoạn dọn trùng `WITH duplicates AS (...)`.
- Kiểm tra loại bỏ hoàn toàn `EXCEPTION WHEN OTHERS THEN NULL`.
- Kiểm tra trigger `check_vehicle_limits`: có `FOR UPDATE` khóa dòng căn hộ, có kiểm tra `NEW.status IN ('pending', 'approved')`, có `DROP TRIGGER IF EXISTS` và `CREATE TRIGGER`, có `SECURITY DEFINER` và `SET search_path = public, pg_catalog`.
- Kiểm tra phân quyền: không chứa nhánh `residents_apartments` trong `update_pending_vehicle` và các RPC sửa/hủy.
- Kiểm tra `reschedule_amenity_booking`: kiểm tra định dạng giờ regex, logic `v_slot_start_time < v_slot_end_time`, tính toán sức chứa slot cũ `v_old_slot_avail` và logic Strict FIFO trước khi đôn Waitlist.

### 4.3. Lớp 3: Widget / Flutter Tests & Chạy Xác Minh Thực Tế
- Kiểm tra giao diện `AmenityBookingScreen` hiển thị nút Đổi lịch cho booking hợp lệ.
- Kiểm tra thông báo SnackBar thành công hiển thị đúng nội dung theo `action`.
- Kiểm tra hiển thị SnackBar lỗi khi đổi lịch thất bại.
- Chạy `dart analyze` và toàn bộ `flutter test` để xác minh mọi bài kiểm thử vượt qua trước khi hoàn tất.

---

## 5. Củng Cố Giao Dịch Waitlist, Định Dạng Giờ & Quyền RPC (Audit Follow-up)

### 5.1. Tự Động Tạo Bản Ghi Giao Dịch PENDING Khi Đôn Waitlist
Trong `reschedule_amenity_booking` và trigger `handle_amenity_booking_cancellation`:
Khi một booking trong Waitlist được đôn lên `pending_payment` (có `v_promoted_fee + v_promoted_deposit > 0`):
- Kiểm tra xem đã có giao dịch `PENDING` cho booking đó chưa:
  - Nếu đã có: Cập nhật `amount = (v_promoted_fee + v_promoted_deposit), updated_at = NOW()`.
  - Nếu chưa có: `INSERT` vào `public.payment_transactions` bản ghi mới với `status = 'PENDING'`, `type = 'SERVICE'`, `amount = (v_promoted_fee + v_promoted_deposit)`, `transaction_code = 'SVC' || ...`.

### 5.2. Chuẩn Hóa Regex 24 Giờ & Xác Thực Giờ Mở Cửa (open_hours)
- Áp dụng regex 24h chặt chẽ: `^([01][0-9]|2[0-3]):[0-5][0-9]\s*-\s*([01][0-9]|2[0-3]):[0-5][0-9]$`.
- Nếu `open_hours IS NOT NULL`:
  - Kiểm tra regex: Ném ngoại lệ `'Giờ mở cửa của tiện ích (%) không đúng định dạng chuẩn HH:mm - HH:mm'` nếu không khớp.
  - Kiểm tra `v_open_start >= v_open_end`: Ném ngoại lệ `'Giờ mở cửa của tiện ích không hợp lệ (giờ mở phải trước giờ đóng)'`.
  - Kiểm tra `v_slot_start_time < v_open_start OR v_slot_end_time > v_open_end`: Ném ngoại lệ `'Khung giờ mới (%) nằm ngoài giờ mở cửa của tiện ích (%)'`.

### 5.3. Bổ Sung Phân Quyền EXECUTE Tường Minh Cho approve_link_request
- `REVOKE ALL ON FUNCTION public.approve_link_request(UUID) FROM PUBLIC, anon;`
- `GRANT EXECUTE ON FUNCTION public.approve_link_request(UUID) TO authenticated;`

