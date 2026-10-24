# Thiết Kế Kỹ Thuật: Khắc Phục Lỗi Toàn Vẹn Dữ Liệu, Phân Quyền & Kiểm Thử Nghiệp Vụ (P1 Audit Fixes)

## 1. Tổng Quan & Phạm Vi
Tài liệu này xác định phương án kỹ thuật toàn diện nhằm xử lý triệt để các vấn đề an ninh, toàn vẹn dữ liệu và chất lượng kiểm thử được phát hiện trong đợt đánh giá hệ thống (V2 Migration & Pending Requests):
1. **Phân quyền thao tác chờ duyệt (P1)**: Thống nhất quyền sở hữu nghiêm ngặt cho phương tiện và phiếu điện nước — chỉ người trực tiếp tạo (`user_id`, `registered_by`, `submitted_by`) hoặc Ban Quản Lý (`is_staff()`) mới có quyền sửa hoặc hủy.
2. **Làm sạch dữ liệu trùng lặp trong Migration (P1)**: Hợp nhất và dọn dẹp các yêu cầu liên kết căn hộ trùng lặp trước khi thiết lập Partial Unique Index; loại bỏ việc nuốt lỗi trong khối `DO $$` để migration fail-fast.
3. **Hạn mức 2 xe máy (P1)**: Sửa logic đếm xe đang hoạt động ở tầng repository (loại trừ `cancelled`) và cập nhật trigger `check_vehicle_limits()` trên CSDL với khóa tuần tự `FOR UPDATE`.
4. **Xác thực khung giờ & đôn Waitlist đổi lịch tiện ích (P1)**: Kiểm tra định dạng giờ nghiêm ngặt, đối soát khung giờ hoạt động của tiện ích, và kiểm tra sức chứa theo quy tắc Hàng đợi nghiêm ngặt (Strict FIFO) khi đôn Waitlist.
5. **Thông báo đổi lịch phía giao diện (P2)**: Chuẩn hóa kết quả trả về từ RPC để giao diện người dùng hiển thị thông báo chính xác.
6. **Nâng cấp bài kiểm thử (Testing)**: Viết lại toàn bộ bài kiểm thử repository với mock RPC chi tiết và kiểm thử tích hợp luồng dữ liệu.

---

## 2. Thiết Kế Cơ Sở Dữ Liệu & Migration

### 2.1. Dọn Dẹp Dữ Liệu Trùng Lặp & Schema Hardening
Trong file migration `supabase/migrations/20261024_04_pending_requests_correction_and_reschedule.sql`:
- **Dọn dẹp bản ghi trùng trước khi tạo Index**:
  Duyệt các cặp `(user_id, apartment_id)` có nhiều hơn 1 bản ghi ở trạng thái `pending` hoặc `approved`. Giữ lại 1 bản ghi ưu tiên (`approved` trước, sau đó là bản ghi có `created_at` mới nhất), chuyển các bản ghi trùng còn lại sang `cancelled`.
  ```sql
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
  ```
- **Loại bỏ khối nuốt lỗi**:
  Thực hiện trực tiếp `ALTER TABLE` không bọc trong `BEGIN ... EXCEPTION WHEN OTHERS THEN NULL; END;` để nếu có lỗi cú pháp hoặc ràng buộc, migration sẽ dừng lại ngay lập tức và thông báo lỗi rõ ràng.

### 2.2. Thống Nhất Chính Sách Phân Quyền Sở Hữu Nghiêm Ngặt
- **RPC `update_pending_vehicle` & `cancel_pending_vehicle`**:
  Chỉ cho phép `user_id = v_user_id OR registered_by = v_user_id OR public.is_staff()`.
  Bỏ điều kiện cho phép cư dân cùng căn hộ thông qua `residents_apartments`.
- **RPC `update_pending_meter_reading` & `cancel_pending_meter_reading`**:
  Chỉ cho phép `submitted_by = v_user_id OR public.is_staff()`.
  Bỏ điều kiện cho phép cư dân cùng căn hộ thao tác chéo.

### 2.3. Củng Cố Hạn Mức 2 Xe Máy Trên CSDL
Cập nhật trigger function `public.check_vehicle_limits()`:
- Đổi điều kiện kiểm tra từ `NEW.status != 'rejected'` thành:
  ```sql
  IF NEW.vehicle_type = 'motorbike' AND NEW.status IN ('pending', 'approved') THEN
  ```
- Duy trì khóa hàng căn hộ `PERFORM 1 FROM public.apartments WHERE id = NEW.apartment_id FOR UPDATE` để tuần tự hóa các yêu cầu đăng ký/chỉnh sửa đồng thời.

### 2.4. Khắc Phục Toàn Vẹn Đổi Lịch Tiện Ích (`reschedule_amenity_booking`)
- **Xác thực định dạng chuỗi giờ**:
  - Kiểm tra `p_new_time_slot` khớp mẫu `^\d{2}:\d{2}\s*-\s*\d{2}:\d{2}$`. Nếu không khớp, `RAISE EXCEPTION 'Định dạng khung giờ không hợp lệ, yêu cầu HH:mm - HH:mm'`.
  - Loại bỏ khối `EXCEPTION WHEN invalid_datetime_format THEN NULL`. Nếu không ép kiểu được sang `TIME`, báo lỗi ngay.
- **Xác thực giờ hoạt động (`open_hours`)**:
  - Trích xuất giờ bắt đầu và kết thúc của tiện ích từ `v_amenity.open_hours`.
  - Đảm bảo khung giờ mới nằm hoàn toàn trong khoảng giờ mở cửa của tiện ích.
- **Đôn Waitlist theo Hàng đợi nghiêm ngặt (Strict FIFO)**:
  - Khi dời lịch sang slot khác, slot cũ giải phóng chỗ:
    - Nếu tiện ích dạng `exclusive`: Có sẵn 1 lượt trống -> Đôn lượt đầu tiên trong Waitlist (ORDER BY `created_at` ASC LIMIT 1).
    - Nếu tiện ích dạng `shared`:
      - Tính sức chứa còn lại của slot cũ: `v_avail := v_amenity.max_capacity - v_current_old_capacity`.
      - Lấy lượt đầu tiên trong Waitlist.
      - **Kiểm tra**: Nếu `v_next_waitlist.guests_count <= v_avail`, đôn lên `pending_payment` (hoặc `confirmed` nếu 0 đồng).
      - Nếu `v_next_waitlist.guests_count > v_avail`: Không đôn, giữ nguyên trong Waitlist (Strict FIFO — không nhảy cóc qua người khác).

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

### 3.2. Chuẩn Hóa Thông Báo Đổi Lịch Trong `AmenityBookingScreen`
Tại file `lib/features/resident/screens/amenity_booking_screen.dart`:
RPC trả về `action` hoặc `status`:
```dart
final status = res['status'] as String?;
final isWaitlist = status == 'waitlist';
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text(
      isWaitlist
          ? 'Đã chuyển sang danh sách chờ của khung giờ mới thành công.'
          : 'Đổi lịch đặt chỗ thành công!',
    ),
    backgroundColor: AppTheme.success,
  ),
);
```

---

## 4. Kế Hoạch Kiểm Thử (Testing Strategy)

### 4.1. Unit Test Repository Với Mocktail
Viết lại file `test/data/repositories/pending_requests_correction_repository_test.dart`:
- Mock `SupabaseClient.rpc(...)`.
- `VehicleRepository.updatePendingVehicle`: Xác nhận gọi đúng RPC `'update_pending_vehicle'` với các tham số `p_vehicle_id`, `p_license_plate`, `p_vehicle_type`, `p_brand_model`.
- `VehicleRepository.cancelPendingVehicle`: Xác nhận gọi đúng RPC `'cancel_pending_vehicle'`.
- `VehicleRepository.getActiveMotorbikeCount`: Kiểm tra lọc đúng trạng thái `['pending', 'approved']`.
- `AmenityBookingRepository.rescheduleBooking`: Xác nhận gọi đúng RPC `'reschedule_amenity_booking'` với các tham số ngày, giờ, số khách.
- `MeterReadingRepository.updatePendingSubmission` & `cancelPendingSubmission`: Xác nhận gọi đúng RPC và tham số.
- Kiểm tra ném ngoại lệ khi `res['success'] != true`.

### 4.2. Migration Test
Cập nhật file `test/data/repositories/pending_correction_migration_test.dart`:
- Kiểm tra SQL chứa đoạn xử lý trùng lặp dữ liệu `WITH duplicates AS (...)`.
- Kiểm tra loại bỏ `EXCEPTION WHEN OTHERS THEN NULL`.
- Kiểm tra điều kiện phân quyền chỉ cho người tạo hoặc staff.
- Kiểm tra kiểm tra định dạng giờ và logic đôn Waitlist có điều kiện sức chứa.

### 4.3. Xác Minh Toàn Diện
- Chạy `dart analyze`.
- Chạy toàn bộ test suite: `flutter test`.
