# Thiết Kế Kỹ Thuật: Cơ Chế Sửa Sai và Hủy Yêu Cầu Đang Chờ Duyệt (Gói 1)

> **Mục tiêu**: Cung cấp cơ chế sửa sai và hủy an toàn cho cư dân đối với 4 nhóm yêu cầu nghiệp vụ đang chờ duyệt (`pending`), đảm bảo tính toàn vẹn dữ liệu, chống Race Condition ở cấp CSDL, bảo vệ lịch sử tài chính và kiểm toán.
> **Ngày lập**: 2026-10-24
> **Nhánh thực hiện**: `main`

---

## 1. Bối Cảnh & Vấn Đề (Problem Statement)
Hiện tại trên PKA-Home, một số luồng nghiệp vụ khi cư dân nhập nhầm thông tin hoặc đổi ý thì rơi vào trạng thái bế tắc:
1. **Phương tiện**: Cư dân đăng ký sai biển số hoặc loại xe nhưng không thể sửa, phương thức `deleteVehicle` hiện tại xóa trực tiếp qua ID mà không kiểm tra trạng thái và quyền sở hữu chặt chẽ.
2. **Đặt tiện ích**: Chưa có cơ chế đổi ngày/giờ cho lượt đặt trong tương lai; việc đổi slot nếu không kiểm soát đồng bộ sẽ gây xung đột slot (overbooking) hoặc sai lệch doanh thu / tiền cọc.
3. **Chỉ số điện nước**: Chưa có cơ chế cho cư dân sửa số liệu hoặc hủy phiếu gửi đang `pending`. Giá trị ảnh minh chứng cần có quy tắc cập nhật rõ ràng để tránh vô tình ghi đè `null`.
4. **Liên kết căn hộ**: Cư dân nhập nhầm mã căn hộ bị kẹt ở trạng thái `pending` và không thể gửi lại yêu cầu mới do ràng buộc `UNIQUE(user_id, apartment_id)` và `uq_apartment_link_requests_user_pending`.

---

## 2. Kiến Trúc Cơ Sở Dữ Liệu & Atomic RPCs

### 2.1. File Migration
`supabase/migrations/20261024_04_pending_requests_correction_and_reschedule.sql`

### 2.2. Chi Tiết Các RPCs

#### A. Phân Hệ Phương Tiện (Vehicles)
1. **`cancel_pending_vehicle(p_vehicle_id UUID)`**:
   - **Mục đích**: Hủy an toàn bản ghi đăng ký phương tiện đang chờ duyệt.
   - **Xác thực quyền**: `v_user_id = auth.uid()`. Người gọi phải là người tạo bản ghi (`user_id` / `registered_by`), hoặc là thành viên cùng căn hộ (`residents_apartments`), hoặc là nhân sự BQL (`public.is_staff()`).
   - **Kiểm tra trạng thái nguyên tử**:
     ```sql
     UPDATE public.vehicles
     SET status = 'cancelled', updated_at = NOW()
     WHERE id = p_vehicle_id AND status = 'pending';
     ```
     Nếu `ROW_COUNT = 0`: Bắn lỗi `'Không tìm thấy phương tiện đang chờ duyệt hoặc bạn không có quyền hủy.'`.

2. **`update_pending_vehicle(p_vehicle_id UUID, p_license_plate VARCHAR, p_vehicle_type VARCHAR, p_brand_model VARCHAR)`**:
   - **Khóa chống Race Condition**: Khóa advisory lock theo căn hộ:
     `PERFORM pg_advisory_xact_lock(hashtext('vehicle_limit_' || v_apt_id::text));`
   - **Kiểm tra giới hạn 2 xe máy**:
     Nếu `p_vehicle_type = 'motorbike'`, đếm số xe máy đang hoạt động của căn hộ (`status IN ('pending', 'approved') AND id <> p_vehicle_id`). Nếu $\ge 2$, từ chối kèm lỗi rõ ràng.
   - **Cập nhật đồng bộ**:
     Cập nhật cả `license_plate` và `plate_number` thành biển số viết hoa đã cắt khoảng trắng thừa; cập nhật `vehicle_type`, `brand_model`, `updated_at = NOW()`.
     Chỉ cập nhật khi `status = 'pending'`.

#### B. Phân Hệ Đặt Tiện Ích (Amenity Bookings)
1. **`reschedule_amenity_booking(p_booking_id UUID, p_new_date DATE, p_new_time_slot VARCHAR, p_new_guests_count INT, p_new_notes TEXT)`**:
   - **Quy ước khóa đồng bộ**:
     Khóa slot cũ và slot mới theo cùng một quy ước hash với `book_amenity_slot`:
     ```sql
     PERFORM pg_advisory_xact_lock(hashtext(v_amenity_id::text || '_' || v_old_date::text || '_' || v_old_slot));
     PERFORM pg_advisory_xact_lock(hashtext(v_amenity_id::text || '_' || p_new_date::text || '_' || p_new_time_slot));
     ```
   - **Kiểm tra điều kiện tiên quyết**:
     - Quyền sở hữu: `booked_by = auth.uid()` hoặc `public.is_staff()`.
     - Trạng thái hiện tại: `status IN ('confirmed', 'pending_payment', 'waitlist')`.
     - Lịch cũ chưa diễn ra: So sánh thời điểm bắt đầu của slot cũ với `(now() AT TIME ZONE 'Asia/Ho_Chi_Minh')`.
     - Slot mới hợp lệ: `p_new_date >= (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date`, thời gian bắt đầu slot mới ở tương lai nếu cùng ngày, không nằm trong `amenity_maintenance_windows`.
   - **Chính sách tài chính & Số khách**:
     - Nếu booking cũ đã `confirmed` (đã thanh toán): Giữ nguyên số tiền phí & tiền cọc đã đóng; **bắt buộc giữ nguyên `guests_count`** (không cho phép thay đổi làm phát sinh chênh lệch tài chính ngoài luồng). Booking ở slot mới tiếp tục giữ `status = 'confirmed'`.
     - Nếu booking cũ là `pending_payment` hoặc miễn phí: Cho phép cập nhật `guests_count` (trong khoảng $1 \le \text{guests} \le \text{max\_capacity}$). Tính lại phí theo số khách mới nếu là tiện ích dùng chung (`shared`).
   - **Kiểm tra sức chứa slot mới**:
     - Tiện ích độc quyền (`exclusive`): Slot mới không có booking nào có `status IN ('confirmed', 'pending_payment')`.
     - Tiện ích dùng chung (`shared`): Tổng số khách đã xác nhận tại slot mới + `guests_count` mới $\le \text{max\_capacity}$.
   - **Cập nhật & Đôn hàng đợi nguyên tử**:
     - Cập nhật dòng booking hiện tại sang `booking_date = p_new_date`, `time_slot = p_new_time_slot`, `updated_at = NOW()`.
     - Đôn người trong hàng đợi: Tìm booking có `status = 'waitlist'` sớm nhất của slot cũ `(v_amenity_id, v_old_date, v_old_slot)`, tự động đôn lên `confirmed` (nếu miễn phí) hoặc `pending_payment`.

#### C. Phân Hệ Chỉ Số Điện Nước (Meter Readings)
1. **`update_pending_meter_reading(p_submission_id UUID, p_electric_reading NUMERIC, p_water_reading NUMERIC, p_electric_image_url TEXT, p_water_image_url TEXT, p_clear_electric_image BOOLEAN, p_clear_water_image BOOLEAN)`**:
   - Ràng buộc: `p_electric_reading >= 0` và `p_water_reading >= 0`.
   - Quyền: Người gửi (`submitted_by = auth.uid()`) hoặc nhân viên có thẩm quyền (`public.is_staff()`).
   - Quy tắc ảnh:
     - Nếu `p_clear_electric_image = true`: Set `electric_image_url = NULL`.
     - Ngược lại nếu `p_electric_image_url IS NOT NULL`: Cập nhật link ảnh mới.
     - Ngược lại (`p_electric_image_url IS NULL` và `clear = false`): Giữ nguyên ảnh cũ (`COALESCE`).
   - Cập nhật nguyên tử: `WHERE id = p_submission_id AND status = 'pending'`.

2. **`cancel_pending_meter_reading(p_submission_id UUID)`**:
   - Chuyển `status = 'cancelled'`, `updated_at = NOW()` khi `id = p_submission_id AND status = 'pending'`.
   - Mở rộng check constraint bảng `meter_reading_submissions`: `status IN ('pending', 'approved', 'rejected', 'cancelled')`.

#### D. Phân Hệ Liên Kết Căn Hộ (Apartment Link Requests)
1. **Lược đồ & Constraints**:
   - Mở rộng enum: `ALTER TYPE public.link_request_status ADD VALUE IF NOT EXISTS 'cancelled';`.
   - Xóa constraint cứng `UNIQUE(user_id, apartment_id)` cũ.
   - Thay bằng Partial Unique Index:
     `CREATE UNIQUE INDEX IF NOT EXISTS uq_link_requests_active ON public.apartment_link_requests(user_id, apartment_id) WHERE status IN ('pending', 'approved');`.
2. **`cancel_apartment_link_request(p_request_id UUID)`**:
   - Cập nhật `status = 'cancelled'::public.link_request_status`, `updated_at = NOW()` với điều kiện `id = p_request_id AND user_id = auth.uid() AND status = 'pending'::public.link_request_status`.
   - Cho phép cư dân nhập và gửi ngay yêu cầu liên kết mới mà không bị xung đột.

---

## 3. Đặc Tả Tầng Repository (Flutter)

### 3.1. `VehicleRepository`
- `updatePendingVehicle({required String vehicleId, required String licensePlate, required String vehicleType, String? brandModel})`: Gọi RPC `update_pending_vehicle`.
- `cancelPendingVehicle(String vehicleId)`: Gọi RPC `cancel_pending_vehicle`.

### 3.2. `AmenityBookingRepository`
- `rescheduleBooking({required String bookingId, required DateTime newDate, required String newTimeSlot, int? newGuestsCount, String? newNotes})`: Gọi RPC `reschedule_amenity_booking`.

### 3.3. `MeterReadingRepository`
- `updatePendingSubmission({required String submissionId, required double electricReading, required double waterReading, String? electricImageUrl, String? waterImageUrl, bool clearElectricImage = false, bool clearWaterImage = false})`: Gọi RPC `update_pending_meter_reading`.
- `cancelPendingSubmission(String submissionId)`: Gọi RPC `cancel_pending_meter_reading`.

### 3.4. `LinkRequestNotifier`
- `cancelPendingRequest(String requestId)`: Gọi RPC `cancel_apartment_link_request`, sau đó gọi `checkStatus()` để giao diện lập tức chuyển về màn hình nhập mã căn hộ.

---

## 4. Đặc Tả Giao Diện Người Dùng (UI / UX)

### 4.1. Màn hình Quản Lý Phương Tiện (`vehicle_management_screen.dart`)
- Với các thẻ xe có `status == 'pending'`: Hiển thị icon Chỉnh sửa (`Icons.edit_outlined`) và icon Hủy (`Icons.delete_outline`).
- Bấm Sửa: Mở Dialog nạp sẵn biển số, loại xe, hãng xe. Tự động viết hoa biển số, có nút Lưu (loading spinner khi đang submit).
- Bấm Hủy: Hiển thị Dialog xác nhận `"Bạn có chắc chắn muốn hủy đăng ký phương tiện này không?"`.
- Khi thành công: Làm mới danh sách xe (`ref.invalidate(residentVehiclesProvider)`), đóng dialog, hiện SnackBar xanh.

### 4.2. Màn hình Đặt Tiện Ích (`amenity_booking_screen.dart`)
- Trong tab "Lịch sử đặt", với các booking tương lai có `status IN ('confirmed', 'pending_payment', 'waitlist')`: Hiển thị nút "Đổi lịch" (`Icons.calendar_month_outlined`).
- Mở BottomSheet Đổi lịch:
  - Chọn ngày mới (không cho chọn ngày quá khứ).
  - Chọn khung giờ mới từ danh sách slot khả dụng.
  - Đối với booking đã `confirmed`: Ẩn/khóa trường số khách kèm chú thích *"Số lượng khách được giữ cố định theo thanh toán ban đầu"*.
  - Nút xác nhận đổi lịch: Gọi RPC `reschedule_amenity_booking`.
  - Khi thành công: Refresh danh sách đặt chỗ, hiển thị SnackBar thành công.

### 4.3. Màn hình Gửi Chỉ Số Điện Nước (`resident_meter_reading_screen.dart`)
- Với các phiếu có `status == 'pending'`: Hiển thị nút "Sửa chỉ số" và "Hủy phiếu".
- Form sửa: Điền sẵn số điện và số nước. Hiển thị thumbnail ảnh cũ, có nút "Đổi ảnh" và nút "Xóa ảnh". Nếu người dùng không chạm vào ảnh, giữ nguyên link ảnh cũ.
- Khi hủy: Xác nhận rõ ràng, chuyển trạng thái `cancelled`.

### 4.4. Màn hình Yêu Cầu Liên Kết Căn Hộ (`link_request_screen.dart`)
- Khi ở trạng thái `LinkStatus.pending`: Hiển thị nút "Hủy yêu cầu này" nổi bật.
- Bấm Hủy: Xác nhận qua AlertDialog, gọi `cancelPendingRequest()`. Trạng thái màn hình chuyển ngay về form ban đầu để cư dân nhập lại mã phòng.

---

## 5. Chiến Lược Kiểm Thử (Testing & Quality Assurance)

1. **Unit Test CSDL & Repository**:
   - Sửa xe: Test xe `pending` thành công; test xe `approved` bắn lỗi; test đổi sang xe máy khi đã có 2 xe máy active bắn lỗi.
   - Hủy xe: Test hủy xe `pending` thành công; test hủy xe của người khác bắn lỗi.
   - Đổi lịch tiện ích: Test đổi sang slot trống thành công; test đổi sang slot đã đầy hoặc trùng bảo trì bị từ chối; test tự động đôn Waitlist cho slot cũ.
   - Chỉ số điện nước: Test sửa số âm bắn lỗi; test giữ nguyên ảnh cũ thành công; test xóa ảnh thành công; test sửa trên phiếu đã duyệt bị chặn.
   - Hủy liên kết: Test hủy request `pending` thành công và gửi ngay request mới cho cùng căn hộ thành công.
2. **Kiểm tra tĩnh**: `flutter analyze` đạt 0 warnings, 0 errors.
3. **Quy tắc Git**: Commit và push trực tiếp lên nhánh `main`.
