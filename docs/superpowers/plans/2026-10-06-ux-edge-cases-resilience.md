# Kế Hoạch Triển Khai: Tối Ưu UX & Xử Lý 8 Edge Cases (Hardening Phase)

- **Mục tiêu**: Thực hiện giai đoạn Hardening cuối cùng của PKA-Home, đảm bảo độ ổn định, chống trùng lặp dữ liệu, thông báo lỗi tiếng Việt thân thiện và bảo toàn 100% test suites.
- **Branch**: `feature/ux-edge-cases-resilience`

---

## Task 1: P0 Core Utility & Decoupling PaymentService
- [ ] Tạo branch `feature/ux-edge-cases-resilience` từ `main`.
- [ ] Xây dựng `NetworkErrorHandler` trong `lib/core/utils/network_error_handler.dart`.
  - Bắt các trường hợp: `SocketException`, `ClientException`, `TimeoutException`, `PostgrestException` (`08006`, `08001`, `23505`, `23503`).
- [ ] Viết bộ kiểm thử đơn vị `test/core/utils/network_error_handler_test.dart` kiểm tra tất cả các kiểu lỗi.
- [ ] Tách `PaymentService` khỏi Riverpod:
  - Bỏ tham số `WidgetRef ref` trong `PaymentService.pay()`.
  - Cập nhật `PaymentNotifier` / `UnifiedPaymentSheet` thực hiện `ref.invalidate(...)` cho:
    - `unpaidInvoicesCountProvider`
    - `residentInvoiceProvider`
    - `residentInvoiceDetailProvider`
    - `paymentTransactionsProvider`
    - `managementInvoiceProvider`
    - `myAmenityBookingsProvider`
- [ ] Chạy `dart analyze` và `flutter test`.

---

## Task 2: P0 Anti-Double-Click & Concurrent Booking (Mã 23505)
- [ ] Triển khai cờ `_isSubmitting`, vô hiệu hóa nút bấm và hiển thị spinner cho:
  - `lib/core/widgets/unified_payment_sheet.dart`
  - `lib/features/resident/screens/amenity_booking_screen.dart`
  - `lib/features/resident/screens/resident_meter_reading_screen.dart`
  - `lib/features/resident/widgets/vehicle_registration_sheet.dart`
  - `lib/features/resident/screens/invoice_detail_screen.dart`
- [ ] Xử lý bắt lỗi trùng lịch `23505` (`uq_active_amenity_slot`) trong `amenity_booking_repository.dart` và `amenity_booking_screen.dart`:
  - Thông báo: *"Khung giờ vừa được người khác đặt. Vui lòng chọn khung giờ khác."*
  - Tự động gọi `ref.invalidate(myAmenityBookingsProvider)` / làm mới slot trống.
- [ ] Viết widget test kiểm tra anti-double-click và bắt lỗi 23505.
- [ ] Chạy `dart analyze` và `flutter test`.

---

## Task 3: P1 Foreign Key Deletion Guard (Mã 23503) & Expired Session
- [ ] Bắt lỗi `23503` (Foreign key violation) trong các phương thức xóa tại:
  - `lib/data/repositories/management_repository.dart`
  - `lib/data/repositories/amenity_booking_repository.dart`
  - Thông báo thân thiện: *"Không thể xóa dữ liệu này vì đang được liên kết với dữ liệu khác trong hệ thống."*
- [ ] Xây dựng bộ bắt phiên làm việc hết hạn (Expired Session Guard):
  - Lắng nghe `onAuthStateChange` với cờ `_hasNavigatedToLogin` để điều hướng duy nhất 1 lần về `/login`.
  - Hiển thị thông báo: *"Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại để tiếp tục sử dụng."*
- [ ] Viết test cho bắt lỗi 23503 và Session Guard.
- [ ] Chạy `dart analyze` và `flutter test`.

---

## Task 4: P2 Meter Cutoff Warning & Toàn Diện Hệ Thống
- [ ] Thêm Banner cảnh báo trễ hạn chốt chỉ số (`DateTime.now().day > 25`) trên `resident_meter_reading_screen.dart`:
  - Hiển thị thông điệp cảnh báo màu vàng/cam không chặn thao tác gửi.
- [ ] Chạy kiểm thử toàn diện:
  - `dart analyze` (0 lỗi).
  - `flutter test` (227+ test pass).
- [ ] Merge branch `feature/ux-edge-cases-resilience` vào `main`.
- [ ] Cập nhật tài liệu kiểm thử và checklist hoàn tất.
