# Tài Liệu Thiết Kế: Quy Trình Đặt Chỗ, Chống Đặt Trùng & Hủy Lịch Tiện Ích

## 1. Mục Tiêu & Yêu Cầu
- **Chống đặt trùng (Strict Constraint)**: Mỗi cư dân chỉ được có duy nhất 1 lượt đặt đang hoạt động (`confirmed`, `pending_payment`, `waitlist`, `pending`) cho cùng 1 khung giờ (`amenity_id`, `booking_date`, `time_slot`).
- **Khả năng hủy và đặt lại (Cancel & Re-book)**: Khi cư dân đã đặt một khung giờ, họ có quyền hủy lịch này. Khi lịch đã chuyển sang trạng thái `cancelled`, khung giờ được giải phóng và cư dân có thể đặt lại.
- **Trải nghiệm người dùng thuận tiện (UX)**:
  - Cư dân có thể hủy trực tiếp tại Tab "Chọn Khung Giờ" (thanh dưới đổi sang nút "Hủy lịch đã đặt" khi bấm vào slot của mình) hoặc tại Tab "Lịch Đã Đặt".
  - Ban quản lý (Admin) có quyền hủy/từ chối lịch ở mọi trạng thái active (`confirmed`, `pending_payment`, `waitlist`).
- **An toàn giao dịch (Atomic Database Level)**: Sử dụng Partial Unique Index và RPC atomic `book_amenity_slot`, `cancel_amenity_booking` để ngăn ngừa race conditions.

---

## 2. Thiết Kế Cơ Sở Dữ Liệu (Supabase / PostgreSQL)

### 2.1. Ràng Buộc Đặt Trùng (Partial Unique Index)
Tạo Partial Unique Index trên bảng `public.amenity_bookings`:
```sql
CREATE UNIQUE INDEX IF NOT EXISTS uq_amenity_bookings_active_user_slot
ON public.amenity_bookings (amenity_id, booking_date, time_slot, booked_by)
WHERE status IN ('confirmed', 'pending_payment', 'waitlist', 'pending');
```
*Ý nghĩa:* Ràng buộc này đảm bảo một người dùng (`booked_by`) không thể tồn tại nhiều hơn một dòng ở trạng thái active trong cùng một khung giờ. Khi dòng đó chuyển sang `'cancelled'`, index không còn áp dụng và người dùng có thể tạo một booking mới cho khung giờ đó.

### 2.2. Nâng Cấp RPC `book_amenity_slot`
Bổ sung kiểm tra tường minh trước khi thực hiện logic đặt chỗ:
```sql
IF EXISTS (
    SELECT 1 FROM public.amenity_bookings
    WHERE amenity_id = p_amenity_id
      AND booking_date = p_booking_date
      AND time_slot = p_time_slot
      AND booked_by = auth.uid()
      AND status IN ('confirmed', 'pending_payment', 'waitlist', 'pending')
) THEN
    RAISE EXCEPTION 'Bạn đã có lượt đặt trong khung giờ này. Vui lòng hủy lịch hiện tại trước nếu muốn đặt lại.';
END IF;
```

### 2.3. Tối Ưu Hóa RPC `cancel_amenity_booking`
- Xác thực quyền: Người dùng sở hữu lượt đặt (`booked_by = auth.uid()`) HOẶC ban quản lý (`is_staff_or_management()`).
- Tự động hủy các bản ghi giao dịch chờ thanh toán (`payment_transactions.status = 'CANCELLED'`).
- Cập nhật trạng thái `amenity_bookings.status = 'cancelled'`.
- Kích hoạt trigger `trg_amenity_booking_cancellation` để tự động xét duyệt cư dân tiếp theo trong danh sách chờ (`waitlist`) đôn lên `confirmed`.

---

## 3. Thiết Kế Giao Diện Cư Dân (Resident UI)

### 3.1. Tab "Chọn Khung Giờ" (`_buildBookingTab`)
- **Hiển thị thẻ khung giờ**:
  - Khi `myBookingInSlot != null`:
    - Thẻ có nền xanh nhạt, viền xanh, hiển thị nhãn `"Lịch của bạn (Trạng thái)"`.
    - Thêm nút icon nhỏ màu đỏ `Icons.cancel_outlined` ở góc thẻ để cho phép hủy nhanh ngay tại danh sách.
- **Thanh tác vụ bên dưới**:
  - Nếu cư dân đang chọn khung giờ mà mình ĐÃ đặt (`_selectedSlot == myBookingInSlot.timeSlot`):
    - Đổi màu nút sang đỏ (`AppTheme.error`).
    - Icon: `Icons.cancel_outlined`.
    - Nhãn nút: `"Hủy lịch khung giờ $_selectedSlot"`.
    - Khi bấm: Mở hộp thoại `_confirmCancelBooking(myBookingInSlot)`.
  - Nếu cư dân chọn khung giờ trống:
    - Hiển thị nút "Đặt lịch khung giờ..." màu xanh/tím bình thường.
- **Sau khi hủy lịch**:
  - Gọi RPC hủy -> Làm mới `amenityBookingsForDateProvider` và `myAmenityBookingsProvider`.
  - Thẻ slot chuyển từ màu xanh "Lịch của bạn" về trạng thái khả dụng.
  - Thanh nút chuyển về "Đặt lịch" cho phép cư dân đặt lại ngay lập tức nếu muốn.

### 3.2. Tab "Lịch Đã Đặt" (`_buildMyBookingsTab`)
- Hiển thị nút "Hủy lịch này" cho tất cả các trạng thái `confirmed`, `pending_payment`, `waitlist`.
- Hộp thoại xác nhận ghi rõ hậu quả (nhường chỗ cho waitlist nếu đã xác nhận, hoặc rút khỏi hàng chờ).

---

## 4. Thiết Kế Giao Diện Ban Quản Lý (Admin UI)

### 4.1. Màn Hình Quản Lý Lịch Đặt (`AmenityManagementScreen`)
- Trong Tab "Duyệt Lịch Đặt Chỗ":
  - Hiển thị nút **"Từ chối / Hủy lịch"** cho:
    1. Lịch chờ thanh toán (`b.isPendingPayment`).
    2. Lịch đã xác nhận (`b.isConfirmed`).
    3. Lịch trong danh sách chờ (`b.isWaitlist`).
  - Hộp thoại `_showRejectBookingDialog`:
    - Cho phép Admin nhập lý do (tùy chọn).
    - Gọi repository `cancelBooking(b.id)`.
    - Thông báo SnackBar thành công và tự động reload danh sách.

---

## 5. Kế Hoạch Xác Minh (Verification & Testing)
1. **Kiểm thử Database**:
   - Chạy script python mô phỏng đầy đủ vòng đời:
     - Tạo 1 booking -> Thành công.
     - Tạo booking thứ 2 cùng slot bởi cùng 1 user -> Bị chặn với lỗi chuẩn xác.
     - Gọi `cancel_amenity_booking` -> Thành công chuyển `cancelled`.
     - Tạo lại booking cho slot vừa hủy -> Thành công!
     - Admin hủy booking -> Thành công.
2. **Kiểm thử Frontend**:
   - `dart analyze` để đảm bảo không có bất kỳ warning/error nào.
   - Chạy `flutter test` các test suite liên quan đến tiện ích.
