# Đặc Tả Kỹ Thuật: Tối Ưu UX & Xử Lý 8 Edge Cases Dự Án PKA-Home (Hardening Phase)

- **Ngày tạo**: 06/10/2026
- **Trạng thái**: Đã phê duyệt (Approved)
- **Mục tiêu**: Nâng cao độ bền vững (resilience), bảo vệ giao dịch, phòng chống lỗi tương tranh và tối ưu trải nghiệm người dùng trong các tình huống thực tế phục vụ bảo vệ đồ án tốt nghiệp.
- **Tiêu chí cốt lõi**:
  - Không thêm module nghiệp vụ mới; tập trung hoàn thiện độ tin cậy và xử lý ngoại lệ.
  - Tách bạch kiến trúc: Service/Repository thuần túy, Controller/UI quản lý `ref.invalidate`.
  - 100% tiếng Việt chuẩn mực, thông báo lỗi thân thiện, không để lộ raw exception ra UI.
  - Bảo toàn 227/227 tests pass và 0 cảnh báo `dart analyze`.

---

## 1. Phân Tích & Phân Bổ Kiến Trúc

### Sơ Đồ Kiến Trúc Luồng Thanh Toán & Invalidation Mới
```text
UI (UnifiedPaymentSheet / Screen)
 │
 ▼
Payment Controller / Notifier
 │
 ├── 1. Gọi PaymentService.pay(...) [Pure Dart / Không phụ thuộc Riverpod]
 │         │
 │         └── RPC: simulate_unified_payment (PostgreSQL)
 │
 └── 2. Khi result.success == true:
           ├── ref.invalidate(unpaidInvoicesCountProvider)
           ├── ref.invalidate(residentInvoiceProvider)
           ├── ref.invalidate(residentInvoiceDetailProvider)
           ├── ref.invalidate(paymentTransactionsProvider)
           ├── ref.invalidate(managementInvoiceProvider)
           └── ref.invalidate(myAmenityBookingsProvider)
```

---

## 2. Chi Tiết Các Hạng Mục Xử Lý Edge Case Theo Thứ Tự Ưu Tiên

### Nhóm 1: Ưu Tiên P0 (Tối Quan Trọng Cho Demo & Dữ Liệu)

#### 1.1. Network & Timeout Error Handler (`NetworkErrorHandler`)
- **Vị trí**: `lib/core/utils/network_error_handler.dart`
- **Chức năng**: Nhận mọi `Object error` và chuyển đổi thành thông điệp tiếng Việt lịch sự, dễ hiểu:
  - `SocketException` / `ClientException`: *"Không có kết nối mạng. Vui lòng kiểm tra Internet (Wifi/4G) và thử lại."*
  - `TimeoutException`: *"Kết nối máy chủ quá lâu. Vui lòng thử lại sau ít phút."*
  - `PostgrestException` (mã `08006`, `08001` - connection error): *"Không thể kết nối đến hệ thống. Vui lòng thử lại."*
  - `PostgrestException` (mã `23505` - unique violation): *"Dữ liệu đã tồn tại hoặc khung giờ vừa được người khác đăng ký."*
  - `PostgrestException` (mã `23503` - foreign key violation): *"Không thể xóa dữ liệu này vì đang được liên kết với dữ liệu khác trong hệ thống."*
  - Mặc định: *"Đã xảy ra lỗi không mong muốn. Vui lòng thử lại."*
- **Quy tắc**: Tuyệt đối không để lộ mã lỗi kỹ thuật hoặc cú pháp SQL cho cư dân/ban quản lý.

#### 1.2. Cơ Chế Chống Bấm 2 Lần (Anti-Double-Click / Button Guard)
- **Mục tiêu**: Ngăn chặn gửi request kép (double-tap) gây ra 2 giao dịch, 2 đơn đăng ký hoặc lỗi trùng mã.
- **Giải pháp**:
  - Quản lý biến cờ `_isSubmitting` (hoặc `_isProcessing`).
  - Khóa nút bấm tức thì (`onPressed: _isSubmitting ? null : _handleSubmit`).
  - Chuyển đổi nhãn nút bấm thành biểu tượng quay tải: `[ ◌ Đang xử lý... ]`.
- **Phạm vi áp dụng**:
  1. `UnifiedPaymentSheet`: Nút "Xác nhận thanh toán ngay".
  2. `AmenityBookingScreen`: Nút "Xác nhận đặt chỗ".
  3. `ResidentMeterReadingScreen`: Nút "Gửi chỉ số điện nước".
  4. `VehicleRegistrationSheet`: Nút "Gửi hồ sơ đăng ký xe".
  5. `InvoiceDetailScreen`: Nút "Thanh toán ngay".

#### 1.3. Lỗi Trùng Lịch Đặt Chỗ Tương Tranh (Concurrent Booking - Mã `23505`)
- **Tình huống**: 2 cư dân cùng mở app và bấm đặt cùng 1 khung giờ tiện ích (ví dụ Sân Tennis 18:00 - 19:30 ngày mai).
- **Hành vi**:
  - PostgreSQL trigger/index `uq_active_amenity_slot` chặn người đến sau bằng mã lỗi `23505`.
  - Repository/Screen bắt `PostgrestException` mã `23505`.
  - Hiển thị Dialog/SnackBar cảnh báo rõ ràng: *"Khung giờ này vừa được cư dân khác đặt trước. Vui lòng chọn khung giờ khác."*
  - Ngay lập tức gọi `ref.invalidate(amenityBookingsProvider)` để cập nhật danh sách slot đã kín, ngăn người dùng bấm lại vào khung giờ đó.

#### 1.4. Invalidation Trạng Thái Sau Khi Thanh Toán (Payment State Invalidation)
- **Tách coupling**: Xóa `WidgetRef` khỏi `PaymentService`. `PaymentService` chỉ nhận các tham số nghiệp vụ và trả về `PaymentResult`.
- **Bộ điều khiển (Notifier/UI Controller)**:
  - Khi thanh toán hóa đơn thành công:
    - `ref.invalidate(residentInvoiceProvider)`
    - `ref.invalidate(residentInvoiceDetailProvider(id))`
    - `ref.invalidate(unpaidInvoicesCountProvider)` -> Badge số hóa đơn chưa thanh toán trên Home giảm ngay lập tức.
    - `ref.invalidate(paymentTransactionsProvider)` -> Lịch sử thanh toán xuất hiện giao dịch mới tức thì.
    - `ref.invalidate(managementInvoiceProvider)` -> BQL nhìn thấy hóa đơn chuyển trạng thái Đã thanh toán.
  - Khi thanh toán cọc/dịch vụ tiện ích thành công:
    - `ref.invalidate(myAmenityBookingsProvider)`
    - `ref.invalidate(paymentTransactionsProvider)`

---

### Nhóm 2: Ưu Tiên P1 (Bảo Vệ Tính Toàn Vẹn Dữ Liệu & Phiên Làm Việc)

#### 2.1. Bảo Vệ Xóa Dữ Liệu Ràng Buộc Khóa Ngoại (Foreign Key - Mã `23503`)
- **Tình huống**: Quản trị viên bấm xóa căn hộ đang có cư dân, xóa tiện ích đang có lượt đặt chỗ, xóa thiết bị đang có bảo trì, hoặc xóa cư dân đang có hóa đơn.
- **Xử lý**:
  - Tại các Repository tầng Admin (`ApartmentRepository`, `UserRepository`, `AmenityBookingRepository`, `EquipmentRepository`):
  - Khối `catch (PostgrestException e)` kiểm tra `e.code == '23503'`.
  - Ném `AppException` hoặc trả về thông điệp thân thiện: *"Không thể xóa dữ liệu này vì đang được liên kết với dữ liệu khác."*
  - UI hiển thị cảnh báo màu cam/đỏ thân thiện thay vì crash hoặc hiện thông báo lỗi lạ.

#### 2.2. Xử Lý Hết Hạn Phiên Đăng Nhập (Expired Session & Single-Navigation Guard)
- **Tình huống**: Token hết hạn hoặc tài khoản bị đăng xuất ngầm từ máy chủ.
- **Xử lý**:
  - Lắng nghe `onAuthStateChange` trong `authStateProvider`.
  - Khi bắt được sự kiện `AuthChangeEvent.signedOut` hoặc token refresh lỗi:
    - Sử dụng biến cờ `_hasNavigatedToLogin` (Single-navigation guard) để tránh điều hướng lặp nhiều lần (redirect loop).
    - Xóa sạch state người dùng đang lưu trong cache.
    - Điều hướng về màn hình `/login`.
    - Hiển thị thông báo nhẹ nhàng: *"Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại để tiếp tục sử dụng."*

---

### Nhóm 3: Ưu Tiên P2 (Cảnh Báo Kỳ Hạn & Tối Ưu UX Nghiệp Vụ)

#### 3.1. Cảnh Báo Gửi Chỉ Số Trễ Hạn (Meter Cutoff Warning)
- **Quy định**: Hạn nộp chỉ số tự giác hàng tháng là từ ngày **20 đến ngày 25**.
- **Xử lý UX**:
  - Trong `ResidentMeterReadingScreen`, kiểm tra ngày hiện tại trong tháng (`DateTime.now().day`):
    - Nếu `day > 25`: Hiển thị Banner cảnh báo viền vàng/cam ở đầu màn hình:  
      *"Đã quá hạn chốt số tháng này (Hạn chót: ngày 25). Vui lòng gửi chỉ số sớm nhất có thể để tránh bị tạm tính theo mức trung bình."*
    - Không khóa cứng nút bấm (vẫn cho phép cư dân gửi bổ sung).

---

## 3. Kế Hoạch Kiểm Thử Tự Động & Tiêu Chí Nghiệm Thu (Acceptance Criteria)

1. **Unit & Widget Tests**:
   - Viết unit test cho `NetworkErrorHandler` kiểm tra toàn bộ các case lỗi (`SocketException`, `TimeoutException`, `PostgrestException` 23505, 23503, 08006).
   - Viết test mô phỏng nút bấm đang submitting: không cho phép kích hoạt callback lần 2.
   - Viết test cho luồng thanh toán: kiểm tra việc gọi đúng các invalidate providers khi thành công.
   - Viết test bắt lỗi 23505 khi đặt trùng lịch.
2. **Hệ thống hiện tại**:
   - Toàn bộ 227 tests hiện tại phải tiếp tục vượt qua 100%.
   - `dart analyze` tiếp tục đạt 0 warnings/errors.
