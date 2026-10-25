# Kế Hoạch Triển Khai: Đặt Chỗ Tiện Ích Chặt Chẽ, Chống Đặt Trùng, Hủy & Cho Phép Đặt Lại

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Triển khai cơ chế đặt chỗ tiện ích chặt chẽ từ tầng Database đến UI Resident & Admin: chống đặt trùng lịch trong cùng khung giờ, cho phép cư dân hủy lịch ngay tại Tab chọn giờ lẫn Tab lịch của tôi, và sau khi hủy có thể đặt lại ngay lập tức; cho phép Admin hủy/từ chối lịch ở mọi trạng thái active.

**Architecture:** Database áp dụng Partial Unique Index trên `(amenity_id, booking_date, time_slot, booked_by)` cho trạng thái active và cập nhật RPC `book_amenity_slot` kèm `cancel_amenity_booking`; Tầng Flutter UI cập nhật `AmenityBookingScreen` và `AmenityManagementScreen` với tính năng hủy lịch tương tác mượt mà, realtime invalidation provider.

**Tech Stack:** PostgreSQL / Supabase, Flutter, Dart, Riverpod (`StateNotifierProvider` / `AsyncNotifierProvider`).

## Global Constraints
- Toàn bộ text UI, nhãn, thông báo lỗi phải bằng 100% tiếng Việt chuẩn mực.
- Tuyệt đối không hardcode mã màu rời rạc trong widget (tuân thủ `AppTheme` và `AppStatusColors`).
- Không tạo branch/worktree phụ, toàn bộ commit trực tiếp vào nhánh `main`.
- Đảm bảo atomic transactions, fail-closed và xử lý đôn waitlist tự động.

---

### Task 1: Database Migration - Ràng Buộc Đặt Trùng & Cập Nhật RPC Đặt/Hủy Lịch

**Files:**
- Create: `supabase/migrations/20261026_02_strict_amenity_booking_rules.sql`
- Test: `scratch/test_strict_amenity_booking_lifecycle.py`

**Interfaces:**
- Consumes: Bảng `public.amenity_bookings`, `public.building_amenities`, `public.payment_transactions`
- Produces:
  - Partial Unique Index: `uq_amenity_bookings_active_user_slot`
  - RPC: `book_amenity_slot(UUID, DATE, VARCHAR, INT, UUID, BOOLEAN, TEXT)`
  - RPC: `cancel_amenity_booking(UUID)`

- [ ] **Step 1: Viết migration SQL**
Tạo file `supabase/migrations/20261026_02_strict_amenity_booking_rules.sql` gồm:
1. Tạo Partial Unique Index trên `amenity_bookings`:
```sql
CREATE UNIQUE INDEX IF NOT EXISTS uq_amenity_bookings_active_user_slot
ON public.amenity_bookings (amenity_id, booking_date, time_slot, booked_by)
WHERE status IN ('confirmed', 'pending_payment', 'waitlist', 'pending');
```
2. Cập nhật `book_amenity_slot`:
- Kiểm tra nếu `auth.uid()` đã có booking active cho `(amenity_id, booking_date, time_slot)` thì bắn lỗi tiếng Việt: `'Bạn đã có lượt đặt trong khung giờ này. Vui lòng hủy lịch hiện tại trước nếu muốn đặt lại.'`
- Kiểm tra sức chứa, tính phí và cọc chuẩn xác.
3. Cập nhật `cancel_amenity_booking`:
- Hủy các giao dịch chờ (`payment_transactions.status = 'CANCELLED'`).
- Chuyển `amenity_bookings.status = 'cancelled'`.
- Kích hoạt trigger đôn người tiếp theo trong danh sách chờ lên.

- [ ] **Step 2: Viết script test chu trình DB**
Tạo file `scratch/test_strict_amenity_booking_lifecycle.py` kết nối trực tiếp PostgreSQL:
1. Đặt 1 slot tiện ích -> Thành công.
2. Cố tình đặt lại cùng slot bởi cùng 1 user -> Bị từ chối với thông báo chặn đặt trùng.
3. Hủy lịch slot đó bằng `cancel_amenity_booking` -> Thành công.
4. Đặt lại slot đó ngay sau khi hủy -> Thành công!
5. Dọn dẹp dữ liệu test.

- [ ] **Step 3: Chạy migration và thực thi script test DB**
Chạy python script để apply migration và chạy test, xác nhận PASS 100%.

- [ ] **Step 4: Commit task 1**
```bash
git add supabase/migrations/20261026_02_strict_amenity_booking_rules.sql
git commit -m "feat(amenity): enforce unique active slot booking and cancel-rebook cycle in db"
```

---

### Task 2: Cải Tiến Giao Diện Cư Dân (Resident UI) - Hủy & Đặt Lại Trực Tiếp

**Files:**
- Modify: `lib/features/resident/screens/amenity_booking_screen.dart`

**Interfaces:**
- Consumes: `ref.read(amenityBookingRepositoryProvider).cancelBooking(bookingId)`
- Produces:
  - Nút hủy nhanh trên thẻ khung giờ đã đặt (`Icons.cancel_outlined`).
  - Thanh tác vụ dưới chuyển thành nút đỏ "Hủy lịch đã đặt" khi người dùng chạm vào slot mình đã đặt.
  - Tự động làm mới dữ liệu và giải phóng slot ngay lập tức để người dùng có thể đặt lại.

- [ ] **Step 1: Cập nhật thẻ khung giờ tại `_buildBookingTab`**
Trong vòng lặp render các khung giờ:
- Khi `myBookingInSlot != null`:
  - Thêm nút icon nhỏ màu đỏ `IconButton(icon: Icon(Icons.cancel_outlined, color: Colors.red), onPressed: () => _confirmCancelBooking(myBookingInSlot))` trên thẻ hoặc cạnh badge "Lịch của bạn".
  - Khi bấm thẻ: `_selectedSlot = slot`, `_isWaitlistSelection = false`.

- [ ] **Step 2: Cập nhật thanh tác vụ đặt lịch dưới đáy màn hình**
- Kiểm tra xem slot đang chọn có thuộc về người dùng không:
```dart
final mySelectedBooking = existingBookings.where((b) {
  final isMyId = (b.bookedBy != null && b.bookedBy == userId) || b.isMyBooking;
  return b.timeSlot == _selectedSlot && isMyId && (b.isConfirmed || b.isPendingPayment || b.isWaitlist);
}).firstOrNull;
```
- Nếu `mySelectedBooking != null`:
  - Nút dưới đổi thành màu đỏ (`AppTheme.error`):
    - Icon: `Icons.cancel_outlined`.
    - Label: `'Hủy lịch khung giờ $_selectedSlot'`.
    - OnPressed: Mở `_confirmCancelBooking(mySelectedBooking)`.
- Sau khi hủy thành công trong `_confirmCancelBooking`:
  - Reset `_selectedSlot = null` (hoặc giữ nguyên nếu slot trống).
  - Invalidate `amenityBookingsForDateProvider` và `myAmenityBookingsProvider`.
  - Hiển thị SnackBar thông báo: "Đã hủy lịch thành công. Bạn có thể đặt lại khung giờ này nếu muốn."

- [ ] **Step 3: Cập nhật Tab "Lịch Đã Đặt" (`_buildMyBookingsTab`)**
- Đảm bảo hiển thị nút "Hủy lịch này" cho các trạng thái `confirmed`, `pending_payment`, `waitlist`.

- [ ] **Step 4: Kiểm tra Static Analysis & Commit**
```bash
flutter analyze lib/features/resident/screens/amenity_booking_screen.dart
git add lib/features/resident/screens/amenity_booking_screen.dart
git commit -m "feat(resident): add quick cancellation and re-booking support in amenity booking tab"
```

---

### Task 3: Cải Tiến Giao Diện Quản Lý (Admin UI) - Hủy & Từ Chối Toàn Diện

**Files:**
- Modify: `lib/features/management/screens/amenity_management_screen.dart`

**Interfaces:**
- Consumes: `allAmenityBookingsProvider`, `amenityBookingRepositoryProvider.cancelBooking(id)`
- Produces: Quyền hủy/từ chối lịch đặt tiện ích cho Admin ở cả 3 trạng thái: `confirmed`, `pending_payment`, `waitlist`.

- [ ] **Step 1: Bổ sung nút Hủy lịch / Từ chối cho trạng thái Waitlist và Pending Payment**
Trong `_buildBookingApprovalCard`:
- Cập nhật điều kiện hiển thị nút từ chối / hủy:
  - Nếu `b.isWaitlist`: Bổ sung nút `OutlinedButton.icon(icon: Icon(Icons.cancel_outlined), label: Text('Từ chối / Hủy'), onPressed: () => _showRejectBookingDialog(b))`.
  - Đảm bảo `_showRejectBookingDialog` xử lý hủy thành công, hiển thị snackbar tiếng Việt và invalidate các provider quản lý.

- [ ] **Step 2: Kiểm tra Static Analysis & Commit**
```bash
flutter analyze lib/features/management/screens/amenity_management_screen.dart
git add lib/features/management/screens/amenity_management_screen.dart
git commit -m "feat(management): allow admin to cancel or reject waitlist and active amenity bookings"
```

---

### Task 4: Kiểm Thử Tích Hợp & Xác Minh Toàn Diện

**Files:**
- Test: `test/features/resident/amenity_booking_strict_test.dart` (hoặc test tương đương)
- Script: `scratch/verify_all_amenity_flows.py`

- [ ] **Step 1: Viết và chạy kịch bản kiểm thử Flutter**
Chạy `flutter test test/integration/amenity_responsive_and_workflow_test.dart` hoặc bổ sung test kiểm tra UI action.

- [ ] **Step 2: Chạy kiểm thử luồng tổng thể qua DB script**
Mô phỏng cả luồng user và admin:
1. User 1 đặt slot -> OK.
2. User 1 cố tình đặt lại slot -> FAIL (chặn chuẩn).
3. User 1 hủy slot -> OK.
4. User 1 đặt lại slot đó -> OK.
5. Admin hủy slot của User 1 -> OK.

- [ ] **Step 3: Chạy Dart Analyze toàn dự án**
Chạy `dart analyze lib/features/resident/screens/amenity_booking_screen.dart lib/features/management/screens/amenity_management_screen.dart`.

- [ ] **Step 4: Commit và tổng kết**
```bash
git add .
git commit -m "test(amenity): verify strict booking cancellation and rebooking workflows"
```
