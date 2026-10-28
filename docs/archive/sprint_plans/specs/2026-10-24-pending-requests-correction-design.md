# Thiết Kế Kỹ Thuật: Cơ Chế Sửa Sai và Hủy Yêu Cầu Đang Chờ Duyệt (Gói 1) - Bản Hiệu Chỉnh V2

> **Mục tiêu**: Cung cấp cơ chế sửa sai và hủy an toàn cho cư dân đối với 4 nhóm yêu cầu nghiệp vụ đang chờ duyệt (`pending`), đảm bảo tính toàn vẹn dữ liệu, chống Deadlock & Race Condition ở cấp CSDL, bảo vệ lịch sử tài chính và kiểm toán.
> **Ngày lập**: 2026-10-24
> **Nhánh thực hiện**: `main`

---

## 1. Bối Cảnh & Vấn Đề (Problem Statement)
Trên PKA-Home, một số luồng nghiệp vụ khi cư dân nhập nhầm thông tin hoặc đổi ý thì rơi vào trạng thái bế tắc:
1. **Phương tiện**: Cư dân đăng ký sai biển số hoặc loại xe nhưng không thể sửa. Phương thức `deleteVehicle` hiện tại xóa trực tiếp qua ID mà không kiểm tra trạng thái và quyền sở hữu chặt chẽ.
2. **Đặt tiện ích**: Chưa có cơ chế đổi ngày/giờ cho lượt đặt trong tương lai; việc đổi slot nếu không kiểm soát đồng bộ thứ tự khóa sẽ gây Deadlock hoặc overbooking, sai lệch trạng thái thanh toán và đôn Waitlist sai quy trình.
3. **Chỉ số điện nước**: Chưa có cơ chế cho cư dân sửa số liệu hoặc hủy phiếu gửi đang `pending`. Giá trị ảnh minh chứng cần có quy tắc cập nhật rõ ràng để tránh vô tình ghi đè `null`.
4. **Liên kết căn hộ**: Cư dân nhập nhầm mã căn hộ bị kẹt ở trạng thái `pending` và không thể gửi lại yêu cầu mới do ràng buộc `UNIQUE(user_id, apartment_id)` và `uq_apartment_link_requests_user_pending`.

---

## 2. Kiến Trúc Cơ Sở Dữ Liệu & Atomic RPCs

### 2.1. File Migration
`supabase/migrations/20261024_04_pending_requests_correction_and_reschedule.sql`

### 2.2. Xử Lý Ràng Buộc & Tương Thích Dữ Liệu (Schema Hardening)
1. **Tránh bẫy PostgreSQL Enum DDL Transaction**:
   - Trong PostgreSQL, lệnh `ALTER TYPE ... ADD VALUE` không thể dùng ngay giá trị mới trong cùng một transaction block.
   - **Giải pháp**: Chuyển đổi cột `apartment_link_requests.status` từ enum sang `VARCHAR(20)` có ràng buộc `CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled'))`. Cách này nhất quán 100% với các bảng khác và cho phép chạy migration an toàn trong một transaction duy nhất.
2. **Mở rộng CHECK Constraint cho `vehicles` và `meter_reading_submissions`**:
   - Cập nhật constraint của `vehicles.status`: `CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled'))`.
   - Cập nhật constraint của `meter_reading_submissions.status`: `CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled'))`.
3. **Làm sạch dữ liệu và tạo Partial Unique Index an toàn**:
   - Trước khi tạo Partial Unique Index trên `apartment_link_requests`, câu lệnh migration sẽ tự động dọn dẹp các bản ghi rác/trùng lịch sử (nếu có).
   - Xóa bỏ ràng buộc bảng cứng `UNIQUE(user_id, apartment_id)` cũ.
   - Tạo Partial Unique Index mới:
     ```sql
     CREATE UNIQUE INDEX IF NOT EXISTS uq_link_requests_active 
     ON public.apartment_link_requests(user_id, apartment_id) 
     WHERE status IN ('pending', 'approved');
     ```

---

### 2.3. Chi Tiết Các RPCs

#### A. Phân Hệ Đặt Tiện Ích (Amenity Bookings)
**`reschedule_amenity_booking(p_booking_id UUID, p_new_date DATE, p_new_time_slot VARCHAR, p_new_guests_count INT, p_new_notes TEXT)`**:
1. **Chống Deadlock bằng Thứ Tự Khóa Chuẩn (Canonical Advisory Lock Ordering)**:
   - Băm mã khóa cho slot cũ và slot mới:
     ```sql
     v_h_old := hashtext(v_amenity_id::text || '_' || v_old_date::text || '_' || v_old_slot);
     v_h_new := hashtext(v_amenity_id::text || '_' || p_new_date::text || '_' || p_new_time_slot);
     v_lock1 := LEAST(v_h_old, v_h_new);
     v_lock2 := GREATEST(v_h_old, v_h_new);

     PERFORM pg_advisory_xact_lock(v_lock1);
     IF v_lock1 <> v_lock2 THEN
         PERFORM pg_advisory_xact_lock(v_lock2);
     END IF;
     ```
   - Cơ chế này triệt tiêu hoàn toàn khả năng Deadlock khi 2 cư dân cùng đổi lịch ngược chiều nhau tại cùng thời điểm.
2. **Xử lý chọn lại chính slot hiện tại (Self-Slot Protection)**:
   - Trong các truy vấn kiểm tra sức chứa khả dụng của slot mới, luôn có điều kiện `AND id <> p_booking_id` để không tự tính lượt đặt của chính mình thành đối thủ cạnh tranh chỗ.
3. **Xác minh điều kiện tiên quyết**:
   - Quyền: `booked_by = auth.uid()` hoặc `public.is_staff()`.
   - Trạng thái: `status IN ('confirmed', 'pending_payment', 'waitlist')`.
   - Lịch cũ chưa diễn ra: So sánh thời điểm bắt đầu slot cũ với múi giờ Việt Nam `(now() AT TIME ZONE 'Asia/Ho_Chi_Minh')`.
   - Lịch mới hợp lệ: Phải ở tương lai, không trùng khoảng bảo trì `amenity_maintenance_windows`.
4. **Quy tắc Tài chính & Số khách**:
   - **Booking đã `confirmed` (đã thanh toán)**: Giữ nguyên số tiền phí & cọc đã đóng; **bắt buộc giữ nguyên `guests_count`** để không làm phát sinh sai lệch tiền tệ ngoài luồng.
   - **Booking `pending_payment`**: Cho phép sửa `guests_count` ($1 \le \text{guests} \le \text{max\_capacity}$). Tính lại `fee_amount = fee_per_guest * guests` nếu là tiện ích dùng chung (`shared`). Đồng thời nếu có bản ghi giao dịch `payment_transactions` đang `PENDING`, cập nhật lại `amount` của giao dịch đó cho khớp.
   - **Booking `waitlist` chuyển sang slot mới còn chỗ**: Không tiếp tục ở trạng thái chờ; chuyển sang `pending_payment` (nếu tiện ích có phí/cọc > 0) hoặc `confirmed` (nếu tiện ích miễn phí).
5. **Quy trình Đôn Waitlist slot cũ an toàn**:
   - Nếu slot cũ thực sự thay đổi (khác slot mới):
     Tìm người xếp hàng đầu tiên `status = 'waitlist'` tại slot cũ theo thứ tự `created_at ASC`.
   - **Tuyệt đối không đôn thẳng lên `confirmed` nếu tiện ích có phí**:
     - Nếu tiện ích có phí hoặc cọc: Chuyển người được đôn sang `status = 'pending_payment'` để họ tiến hành thanh toán trong thời hạn quy định.
     - Nếu tiện ích miễn phí: Chuyển sang `status = 'confirmed'`.

---

#### B. Phân Hệ Phương Tiện (Vehicles)
1. **Phân Quyền Hủy Nghiêm Ngặt (`cancel_pending_vehicle`)**:
   - **Nguyên tắc**: Thành viên cùng căn hộ **KHÔNG** được tự ý hủy xe của nhau.
   - **Điều kiện**: Chỉ cho phép chính người đã đăng ký xe (`user_id = auth.uid()` hoặc `registered_by = auth.uid()`) HOẶC nhân sự BQL (`public.is_staff()`).
   - Cập nhật nguyên tử:
     ```sql
     UPDATE public.vehicles
     SET status = 'cancelled', updated_at = NOW()
     WHERE id = p_vehicle_id 
       AND status = 'pending'
       AND (user_id = v_user_id OR registered_by = v_user_id OR public.is_staff());
     ```
     Nếu không khớp dòng nào: Bắn lỗi rõ ràng.

2. **Chỉnh Sửa Thông Tin Xe (`update_pending_vehicle`)**:
   - Khóa advisory theo căn hộ: `PERFORM pg_advisory_xact_lock(hashtext('vehicle_limit_' || v_apt_id::text));`.
   - Kiểm tra hạn mức 2 xe máy: Đếm số xe máy active (`status IN ('pending', 'approved') AND id <> p_vehicle_id`).
   - Cập nhật đồng bộ cả 2 cặp cột `license_plate` và `plate_number` (viết hoa chuẩn hóa), `vehicle_type`, `brand_model`.

---

#### C. Phân Hệ Chỉ Số Điện Nước (Meter Readings)
1. **`update_pending_meter_reading`**:
   - Ràng buộc: `electric_reading >= 0` và `water_reading >= 0`.
   - Quyền: Chính người gửi hoặc BQL.
   - Quy tắc ảnh công tơ:
     - `p_clear_electric_image = true` $\rightarrow$ Set `electric_image_url = NULL`.
     - `p_electric_image_url IS NOT NULL` $\rightarrow$ Cập nhật link ảnh mới.
     - `p_electric_image_url IS NULL` và `clear = false` $\rightarrow$ Giữ nguyên ảnh cũ (`COALESCE`).
   - Chỉ cập nhật khi `status = 'pending'`. Từ chối nếu đã duyệt hoặc đã tạo hóa đơn.

2. **`cancel_pending_meter_reading`**:
   - Cập nhật `status = 'cancelled'`, `updated_at = NOW()` khi `id = p_submission_id AND status = 'pending'`.

---

#### D. Phân Hệ Liên Kết Căn Hộ (Apartment Link Requests)
1. **`cancel_apartment_link_request`**:
   - Cập nhật `status = 'cancelled'`, `updated_at = NOW()` khi `id = p_request_id AND user_id = auth.uid() AND status = 'pending'`.
   - Nhờ Partial Unique Index, trạng thái `cancelled` không chặn người dùng gửi yêu cầu mới cho cùng căn hộ hoặc căn hộ khác.

---

## 3. Đặc Tả Tầng Repository & Riverpod Providers

### 3.1. Chữ Ký Phương Thức
```dart
// VehicleRepository
Future<void> updatePendingVehicle({
  required String vehicleId,
  required String licensePlate,
  required String vehicleType,
  String? brandModel,
});
Future<void> cancelPendingVehicle(String vehicleId);

// AmenityBookingRepository
Future<Map<String, dynamic>> rescheduleBooking({
  required String bookingId,
  required DateTime newDate,
  required String newTimeSlot,
  int? newGuestsCount,
  String? newNotes,
});

// MeterReadingRepository
Future<void> updatePendingSubmission({
  required String submissionId,
  required double electricReading,
  required double waterReading,
  String? electricImageUrl,
  String? waterImageUrl,
  bool clearElectricImage = false,
  bool clearWaterImage = false,
});
Future<void> cancelPendingSubmission(String submissionId);

// LinkRequestNotifier
Future<void> cancelPendingRequest(String requestId);
```

### 3.2. Quản Lý Trạng Thái Riverpod & Chống Thành Công Giả
- Mọi thao tác UI đều bọc trong `try/catch`.
- Nút bấm bị vô hiệu hóa (`isLoading = true`) trong suốt quá trình gọi máy chủ.
- Chỉ khi hàm Repository hoàn tất mà không throw Exception:
  - Đóng dialog/bottom sheet.
  - Vô hiệu hóa đúng provider phụ thuộc: `ref.invalidate(...)`.
  - Hiển thị SnackBar thành công.
- Nếu xảy ra lỗi: Bắt Exception, hiển thị thông báo lỗi chi tiết bằng tiếng Việt, **giữ nguyên form nhập liệu** để người dùng không bị mất dữ liệu đã điền.

---

## 4. Đặc Tả Giao Diện Người Dùng (UI / UX)

1. **Phương tiện (`vehicle_management_screen.dart`)**: Thẻ xe `pending` hiển thị nút Sửa (mở form điền sẵn) và nút Hủy (xác nhận trước khi gọi `cancelPendingVehicle`).
2. **Đặt tiện ích (`amenity_booking_screen.dart`)**: Nút "Đổi lịch" cho các booking tương lai. Bottom sheet chọn ngày/slot trống; đối với booking đã thanh toán, khóa trường số khách và thông báo giữ nguyên tiền cọc/phí.
3. **Chỉ số điện nước (`resident_meter_reading_screen.dart`)**: Thẻ pending có nút Sửa chỉ số (giữ ảnh cũ nếu không đổi) và nút Hủy phiếu.
4. **Liên kết căn hộ (`link_request_screen.dart`)**: Nút "Hủy yêu cầu này" giải phóng trạng thái chờ, đưa người dùng quay lại form nhập mã căn hộ.

---

## 5. Kế Hoạch Kiểm Thử Nghiệm Thu (Comprehensive Test Suite)

1. **Kiểm thử CSDL & RPC (PostgreSQL level)**:
   - **Deadlock Test**: Chạy đồng thời 2 session đổi lịch chéo nhau (Slot A $\rightarrow$ Slot B và Slot B $\rightarrow$ Slot A), xác nhận không phát sinh deadlock.
   - **Self-slot Test**: Đổi lịch sang chính slot hiện tại $\rightarrow$ thành công, không tự chặn mình.
   - **Waitlist Promotion Test**: Đổi lịch slot cũ $\rightarrow$ người tiếp theo trong hàng đợi được đôn sang `pending_payment` (nếu có phí) hoặc `confirmed` (nếu miễn phí).
   - **Vehicle Concurrency Test**: 2 session đồng thời chuyển sang xe máy khi căn hộ đã có 1 xe máy $\rightarrow$ chỉ 1 session thành công, session còn lại nhận lỗi vượt hạn mức.
   - **Vehicle Ownership Test**: Người cùng căn hộ (không phải người tạo và không phải BQL) thử hủy xe $\rightarrow$ bị từ chối.
   - **Link Request Re-request Test**: Hủy request căn hộ A $\rightarrow$ tạo lại request cho căn hộ A ngay lập tức $\rightarrow$ thành công.
2. **Kiểm thử Tích Hợp Flutter & UI**:
   - Unit test mockito/fake cho Repository.
   - Widget test cho các nút bấm Sửa/Hủy trên UI.
3. **Phân tích tĩnh**: `flutter analyze` đạt 0 warnings, 0 errors.
