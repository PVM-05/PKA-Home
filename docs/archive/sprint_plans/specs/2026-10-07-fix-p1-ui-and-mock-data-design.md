# Thiết Kế Chi Tiết: Khắc Phục Toàn Bộ Lỗi P1 Giao Diện UI, Mock Data, Xử Lý Lỗi và Quản Lý Trạng Thái

- **Ngày tạo:** 07/10/2026
- **Trạng thái:** Đã duyệt thiết kế
- **Phạm vi:** P1 (UI Integrity, Real Data Querying, Auth Security, Error Formatting, Dark Mode, Concurrency)
- **Các thành phần ảnh hưởng:**
  - `lib/features/management/widgets/resident_360_detail_sheet.dart`
  - `lib/features/resident/screens/resident_meter_reading_screen.dart`
  - `lib/features/management/screens/management_payment_transactions_screen.dart`
  - `lib/features/management/screens/management_invoice_detail_screen.dart`
  - `lib/data/repositories/management_repository.dart`
  - `lib/core/utils/error_formatter.dart` & `lib/core/utils/network_error_handler.dart`
  - `lib/data/providers/dashboard_providers.dart`
  - `lib/data/providers/auth_provider.dart`
  - Dark mode widgets (`resident_handbook_screen.dart`, `management_handbook_screen.dart`, `announcement_management_screen.dart`, `notification_card.dart`, `equipment_interruption_banner.dart`)

---

## 1. Bối cảnh & Vấn đề Cần Khắc Phục (P1)

1. **`Resident360DetailSheet` dùng dữ liệu giả (Hardcoded Mock Data):**
   - Hiện tại Tab Phương tiện hiển thị cứng `Honda Vision (Xe máy)`, Tab Hóa đơn hiển thị `1.480.000 đ`, Tab Dịch vụ hiển thị `Gói Gym Tháng`.
   - Cần truy vấn dữ liệu thực tế từ Supabase theo `apartment_id` và `user_id`.
2. **`ResidentMeterReadingScreen` dùng ảnh Unsplash giả & fallback số liệu giả:**
   - Khi quét OCR, gán cố định URL Unsplash tĩnh thay vì lưu trữ ảnh thực tế hoặc URL hợp lệ.
   - Khi `aptReadingsAsync` null (chưa có căn hộ), âm thầm fallback về `A0110`, `1250 kWh`, `80 m³` thay vì hiển thị thông báo lỗi / yêu cầu liên kết.
   - Chưa dùng `validateInvoicePeriod` cho ô nhập kỳ phí và chưa chặn gửi trùng kỳ đã nộp.
3. **Badge trạng thái giao dịch & Ghi nhận thanh toán:**
   - `ManagementPaymentTransactionsScreen`: Gắn huy hiệu "Thành công" xanh cho mọi giao dịch, kể cả `FAILED` và `CANCELLED`.
   - `ManagementInvoiceDetailScreen`: BQL bấm xác nhận đã thu tiền mặt / chuyển khoản chỉ cập nhật `status = 'paid'` mà không ghi bản ghi vào `payment_transactions`, dẫn đến lệch số liệu đối soát doanh thu.
4. **Nuốt lỗi & Phân mảnh bộ xử lý lỗi:**
   - `validateMonthlyBulkInvoices` bắt mọi ngoại lệ và trả về issue giả với `apartmentId: ''` thay vì ném lỗi để UI hiển thị.
   - Nhiều màn hình vẫn hiển thị lỗi thô `'Lỗi: $e'`. Hai hàm `formatErrorMessage` và `NetworkErrorHandler` hoạt động rời rạc.
5. **Số liệu tiến độ thu phí & Lỗ hổng Auth:**
   - `financialStatsProvider` cộng dồn tiền của tất cả các kỳ trong lịch sử thay vì kỳ tháng hiện tại.
   - `AuthNotifier` không hủy StreamSubscription `authStateChanges` khi dispose và không kiểm tra cờ `isLocked`.
   - `createApartment` chưa chuẩn hóa chữ hoa mã căn hộ (`code.trim().toUpperCase()`).
   - Một số widget bị vỡ Dark mode do sử dụng `Colors.white` cứng.

---

## 2. Kiến Trúc & Thiết Kế Giải Pháp Chi Tiết

### 2.1. Thay Thế Mock Data trong `Resident360DetailSheet`
- Bổ sung 3 provider hoặc truy vấn trực tiếp qua repository/client theo `apartmentId` và `resident.id`:
  - `residentVehiclesProvider(apartmentId)`: Lấy danh sách xe đã duyệt và chờ duyệt của căn hộ.
  - `residentInvoicesProvider(apartmentId)`: Lấy danh sách hóa đơn của căn hộ, sắp xếp theo ngày tạo mới nhất.
  - `residentServicesProvider(residentId)`: Lấy danh sách đặt tiện ích `amenity_bookings` của cư dân.
- Render danh sách thực tế với icon và badge tương ứng. Nếu danh sách rỗng, hiển thị empty state nhẹ nhàng: "Chưa có phương tiện đăng ký", "Chưa có hóa đơn", "Chưa sử dụng dịch vụ nào".

### 2.2. Khắc Phục Toàn Diện `ResidentMeterReadingScreen`
- **Ảnh công tơ:** Lưu trữ ảnh minh họa hợp lệ hoặc đường dẫn file thực tế, không dùng URL Unsplash bên ngoài.
- **Xử lý thiếu căn hộ:** Nếu `aptData == null`, hiển thị `AppStateView` hoặc thông báo "Bạn chưa liên kết với căn hộ nào để nộp chỉ số. Vui lòng gửi yêu cầu liên kết trước." kèm nút điều hướng đến màn hình liên kết căn hộ.
- **Validate kỳ phí:** Đặt `validator: validateInvoicePeriod` cho `_periodController`.
- **Chặn gửi trùng kỳ:** Kiểm tra `residentMeterReadingsProvider`: nếu kỳ nhập vào đã có trong danh sách chỉ số của căn hộ ở trạng thái `pending` hoặc `approved`, hiển thị cảnh báo đỏ và vô hiệu hóa nút gửi: "Kỳ phí này đã được gửi chỉ số trước đó."

### 2.3. Chuẩn Hóa Trạng Thái Giao Dịch & Ghi Nhận Thanh Toán
- **`ManagementPaymentTransactionsScreen`:**
  - Viết helper `_buildStatusBadge(String status)`:
    - `'SUCCESS'`: Màu `AppTheme.success`, text `'Thành công'`.
    - `'FAILED'`: Màu `AppTheme.error`, text `'Thất bại'`.
    - `'CANCELLED'`: Màu `AppTheme.textSecondary`, text `'Đã hủy'`.
- **`ManagementInvoiceDetailScreen`:**
  - Trong phương thức `_confirmPayment`:
    - Sau khi cập nhật hóa đơn `status = 'paid'`, gọi thêm phương thức ghi nhận giao dịch:
      ```dart
      await ref.read(managementRepositoryProvider).recordPaymentTransaction(
        invoiceId: invoice.id,
        apartmentId: invoice.apartment?.id,
        amount: invoice.totalAmount,
        paymentMethod: isPending ? 'bank_transfer' : 'cash',
        status: 'SUCCESS',
      );
      ```
    - Invalidate cả `invoicesProvider` và `paymentTransactionsProvider`.

### 2.4. Hợp Nhất Xử Lý Lỗi & Không Nuốt Lỗi
- **`ManagementRepository.validateMonthlyBulkInvoices`:**
  - Bỏ khối `catch` nuốt lỗi. Khi RPC lỗi, ném lỗi thật (`rethrow` hoặc `throw Exception(...)`) để `BulkInvoiceDialog` bắt và hiển thị thông báo lỗi mạng/hệ thống qua `formatErrorMessage(e)`.
- **Hợp nhất `formatErrorMessage` & `NetworkErrorHandler`:**
  - Chuẩn hóa `formatErrorMessage` để tận dụng toàn bộ logic của `NetworkErrorHandler`, đảm bảo trích xuất chính xác thông điệp tiếng Việt từ các lệnh `RAISE EXCEPTION` trong SQL và xử lý sạch sẽ mọi ngoại lệ `PostgrestException`, `SocketException`, `AuthException`.
  - Quét và thay thế toàn bộ chuỗi hiển thị `'Lỗi: $e'` thô trong `vehicle_approval_screen`, `bulk_invoice_dialog`, `resident_meter_reading_screen`, `equipment_management_screen`.

### 2.5. Tối Ưu Provider, Auth Security & Dark Mode
- **`financialStatsProvider`:**
  - Tính `paidTotal` và `unpaidTotal` trên danh sách `currentInvoices` (các hóa đơn thuộc kỳ hiện tại hoặc kỳ mới nhất có hóa đơn), đảm bảo tỷ lệ thu phí và tổng tiền phản ánh đúng tháng đang hiển thị.
- **`AuthNotifier`:**
  - Định nghĩa biến `StreamSubscription<AuthState>? _authSubscription;` và hủy trong `dispose()`.
  - Trong `_fetchUserInfo`:
    ```dart
    final userModel = UserModel.fromJson(data);
    if (userModel.isLocked) {
      await logout();
      state = AsyncValue.error('Tài khoản của bạn đã bị khóa. Vui lòng liên hệ Ban Quản Lý.', StackTrace.current);
      return;
    }
    state = AsyncValue.data(userModel);
    ```
- **Mã căn hộ trong `createApartment`:**
  - Sửa `code: code.trim().toUpperCase()`.
- **Sửa Dark mode:**
  - Thay `Colors.white` bằng `Theme.of(context).cardColor` hoặc `AppCard` trong `resident_handbook_screen.dart`, `management_handbook_screen.dart`, `announcement_management_screen.dart`, `notification_card.dart`, và `equipment_interruption_banner.dart`.

---

## 3. Kế Hoạch Xác Minh
- Viết Unit Tests & Widget Tests cho:
  - `Resident360DetailSheet`: hiển thị đúng danh sách thật và empty state.
  - `ManagementPaymentTransactionsScreen`: hiển thị đúng badge cho từng trạng thái.
  - `financialStatsProvider`: tính đúng tiền theo kỳ tháng hiện tại.
  - `AuthNotifier`: chặn tài khoản `isLocked == true`.
- Chạy `flutter test` và `flutter analyze` đảm bảo 100% pass và không có bất kỳ warning/lint nào.
