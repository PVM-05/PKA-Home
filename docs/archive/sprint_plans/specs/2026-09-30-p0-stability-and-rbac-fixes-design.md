# Thiết Kế Chi Tiết: Khắc Phục Các Điểm Nghẽn P0 (Ổn Định Ứng Dụng, RBAC & Luồng Liên Kết Căn Hộ)

- **Ngày tạo:** 30/09/2026
- **Trạng thái:** Đã duyệt thiết kế
- **Phạm vi:** P0 (Crash prevention, Localization, UI Authorization, Fallback UX)

---

## 1. Bối cảnh & Vấn đề

Trong quá trình rà soát chất lượng phục vụ cho phiên bản phát hành/demo, hệ thống ghi nhận 3 vấn đề nghiêm trọng thuộc mức độ P0:
1. **P0-3 (Nguy cơ Crash & Đa ngôn ngữ bị thiếu):**
   - Định dạng ngày tháng tiếng Việt `DateFormat('EEE', 'vi')` chưa được nạp biểu tượng qua `initializeDateFormatting('vi')`, gây lỗi runtime hoặc fallback sai.
   - Các DatePicker/DateRangePicker chưa cấu hình `flutter_localizations` nên hiển thị tiếng Anh, vi phạm tiêu chuẩn 100% tiếng Việt của dự án.
   - Thư viện `timeago` chỉ cấu hình locale tiếng Việt cục bộ ở màn hình Nhật ký, các màn khác bị rơi về tiếng Anh.
   - `textScaler` trong `MaterialApp.builder` ghi đè toàn bộ tỉ lệ phóng to văn bản của hệ điều hành.
2. **P0-5 (Lỗ hổng Fail-open & Thiếu lối vào cho Ủy quyền tạm thời tại BQL):**
   - `ManagementHomeScreen` gán `final isAdmin = currentUser?.isAdmin ?? true;` — nếu thông tin người dùng đang tải hoặc null thì mặc định cấp quyền Admin (lỗ hổng fail-open nghiêm trọng).
   - Thanh điều hướng (Tabs) và các nút thao tác nhanh (Quick Actions) chỉ kiểm tra vai trò cố định (`user.isAccountant`, `user.isTechnician`), bỏ qua các ủy quyền đang hoạt động từ `activeDelegationsProvider`. Người được ủy quyền hợp lệ bị chặn tầng giao diện.
3. **P0-6 (Kẹt luồng Liên kết Căn hộ khi Danh mục rỗng):**
   - Khi `availableApartmentsProvider` trả về danh sách rỗng hoặc lỗi, giao diện `LinkRequestScreen` thông báo "vui lòng nhập trực tiếp mã căn hộ ở ô bên dưới", nhưng ô nhập liệu lại không được render. Cư dân rơi vào ngõ cụt không thể gửi yêu cầu liên kết.

---

## 2. Kiến Trúc & Giải Pháp Chi Tiết

### 2.1. Cấu hình Root & Quốc tế hóa (`pubspec.yaml`, `lib/main.dart`)
- **Phụ thuộc:** Bổ sung `flutter_localizations` với `sdk: flutter` vào `pubspec.yaml`.
- **Khởi tạo tiền điều kiện trong `main()`:**
  - `await initializeDateFormatting('vi', null);` từ `package:intl/date_symbol_data_local.dart`.
  - `timeago.setLocaleMessages('vi', timeago.ViMessages());` để áp dụng toàn cầu cho mọi widget dùng relative time.
- **Cấu hình `MaterialApp.router`:**
  - Thêm `localizationsDelegates`:
    - `GlobalMaterialLocalizations.delegate`
    - `GlobalWidgetsLocalizations.delegate`
    - `GlobalCupertinoLocalizations.delegate`
  - Thêm `supportedLocales`: `const [Locale('vi', 'VN'), Locale('en', 'US')]`
  - Thiết lập mặc định `locale: const Locale('vi', 'VN')`
  - Tinh chỉnh `textScaler`: Sử dụng `MediaQuery.of(context).textScaler.scale(fontScale)` để nhân với tỷ lệ cài đặt trên máy người dùng, tránh phá vỡ trợ năng của OS.

### 2.2. Bảo Mật UI & Phân Quyền Ủy Quyền (`lib/features/management/screens/management_home_screen.dart`)
- **Khắc phục Fail-open:**
  - Sửa `final isAdmin = currentUser?.isAdmin ?? false;`. Mặc định từ chối quyền (Fail-closed).
- **Tích hợp `AppPermissions` và `activeDelegationsProvider`:**
  - Lấy danh sách vai trò đang được ủy quyền:
    ```dart
    final activeDelegations = ref.watch(activeDelegationsProvider).valueOrNull ?? [];
    ```
  - Tính toán quyền hạn thông qua Single Source of Truth `AppPermissions`:
    - `canManageInvoices`: Cho phép hiển thị Tab Hóa đơn & Quick Action lập hóa đơn nếu là Admin, Kế toán, hoặc có ủy quyền Kế toán.
    - `canManageIssues`: Cho phép hiển thị Tab Phản ánh & Quick Action xử lý sự cố nếu là Admin, Kỹ thuật viên, hoặc có ủy quyền Kỹ thuật viên.
  - Cập nhật linh hoạt danh sách `tabs` dựa trên quyền hạn thực tế.

### 2.3. Cải Tiến Luồng Liên Kết Căn Hộ (`lib/features/resident/screens/link_request_screen.dart`)
- **Khắc phục ngõ cụt khi danh mục rỗng:**
  - Khi danh sách trả về từ `availableApartmentsProvider` rỗng (`apartments.isEmpty`) hoặc gặp lỗi:
    - Hiển thị thông báo hướng dẫn rõ ràng.
    - Render ngay bên dưới ô nhập `TextFormField` cho phép nhập trực tiếp mã phòng (ví dụ: `A0110`).
- **Thêm tính năng chủ động:**
  - Cho phép người dùng linh hoạt bấm nút "Nhập mã trực tiếp" thay vì buộc phải chọn qua 3 dropdown Tòa - Tầng - Phòng nếu đã nhớ sẵn mã căn hộ của mình.
  - Áp dụng validator `validateApartmentCode` cho trường nhập thủ công.

---

## 3. Kế Hoạch Kiểm Thử (Testing & Verification)

1. **Unit & Widget Tests:**
   - Cập nhật / bổ sung test cho `ManagementHomeScreen` kiểm tra hiển thị tab khi có ủy quyền Kế toán / Kỹ thuật viên.
   - Bổ sung widget test cho `LinkRequestScreen` xác minh trường hợp danh sách căn hộ rỗng vẫn hiển thị ô nhập mã căn hộ và nút gửi hợp lệ.
2. **Kiểm thử tĩnh:**
   - Chạy `flutter test` đảm bảo 100% tests vượt qua không có hồi quy.
   - Chạy `dart analyze` để đảm bảo không phát sinh warning/error mới.
