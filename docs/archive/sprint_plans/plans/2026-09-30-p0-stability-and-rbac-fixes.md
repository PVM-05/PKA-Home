# Kế Hoạch Triển Khai: Khắc Phục Điểm Nghẽn P0 (Ổn Định Ứng Dụng, RBAC & Luồng Liên Kết Căn Hộ)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Khắc phục triệt để 3 lỗi P0 (Crash / Locale tiếng Việt tại main, Lỗ hổng fail-open & lối vào UI ủy quyền tại BQL, và Kẹt luồng liên kết căn hộ khi danh mục rỗng).

**Architecture:** Tận dụng Single Source of Truth `AppPermissions` và Riverpod providers (`activeDelegationsProvider`, `availableApartmentsProvider`) để bảo đảm bảo mật fail-closed và trải nghiệm người dùng liền mạch không ngõ cụt.

**Tech Stack:** Flutter, Riverpod, intl, flutter_localizations, timeago.

## Global Constraints
- Tuân thủ quy tắc 100% tiếng Việt trong `design-rules.md`.
- Bảo đảm quy tắc fail-closed (mặc định không có quyền `?? false`).
- Chạy toàn bộ test suite và không làm hỏng các test hiện có.

---

### Task 1: Quốc tế hóa và cấu hình Root (`pubspec.yaml`, `lib/main.dart`)

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/main.dart`
- Test: `test/widget_test.dart` hoặc kiểm thử toàn bộ test suite

**Interfaces:**
- Consumes: `initializeDateFormatting('vi', null)`, `GlobalMaterialLocalizations`, `GlobalWidgetsLocalizations`, `GlobalCupertinoLocalizations`, `timeago.setLocaleMessages`
- Produces: Môi trường ngày giờ, DatePicker, DateRangePicker, Timeago và FontScaler chuẩn tiếng Việt toàn app

- [ ] **Step 1: Cập nhật dependencies trong `pubspec.yaml`**
Thêm `flutter_localizations: sdk: flutter` vào khối dependencies.

- [ ] **Step 2: Cập nhật `lib/main.dart`**
Khởi tạo ngôn ngữ trước `runApp`, bổ sung cấu hình `localizationsDelegates`, `supportedLocales`, `locale`, và chuẩn hóa `textScaler: MediaQuery.of(context).textScaler.scale(fontScale)`.

- [ ] **Step 3: Chạy static analysis & test**
Chạy `flutter test` để xác nhận ứng dụng biên dịch và chạy kiểm thử không có lỗi.

- [ ] **Step 4: Commit thay đổi**
`git commit -m "fix(core): khoi tao quoc te hoa tieng viet va chuan hoa scale chu tai main"`

---

### Task 2: Bảo vệ quyền BQL & UI ủy quyền tạm thời (`lib/features/management/screens/management_home_screen.dart`)

**Files:**
- Modify: `lib/features/management/screens/management_home_screen.dart`
- Create / Modify Test: `test/features/management/management_home_rbac_test.dart`

**Interfaces:**
- Consumes: `activeDelegationsProvider`, `AppPermissions.invoiceManagement`, `AppPermissions.issueManagement`
- Produces: Quyền truy cập Tab và Quick Action BQL bảo mật (fail-closed) và nhận diện ủy quyền

- [ ] **Step 1: Viết test cho hiển thị tab theo ủy quyền**
Viết widget test xác nhận: khi user có role resident nhưng có ủy quyền accountant trong `activeDelegationsProvider`, tab "Hóa đơn" sẽ xuất hiện.

- [ ] **Step 2: Cập nhật logic trong `management_home_screen.dart`**
Sửa `isAdmin = currentUser?.isAdmin ?? false;`. Đọc `activeDelegationsProvider` và dùng `AppPermissions.invoiceManagement.allows(...)`, `AppPermissions.issueManagement.allows(...)` để hiển thị Tab và Quick Actions.

- [ ] **Step 3: Chạy test xác nhận thành công**
Chạy `flutter test test/features/management/management_home_rbac_test.dart`

- [ ] **Step 4: Commit thay đổi**
`git commit -m "fix(management): chan lo hong fail-open va tich hop uy quyen cho tab bql"`

---

### Task 3: Cải tiến trải nghiệm và fallback màn liên kết căn hộ (`lib/features/resident/screens/link_request_screen.dart`)

**Files:**
- Modify: `lib/features/resident/screens/link_request_screen.dart`
- Create / Modify Test: `test/features/resident/link_request_fallback_test.dart`

**Interfaces:**
- Consumes: `availableApartmentsProvider`, `validateApartmentCode`
- Produces: UI liên kết căn hộ không bao giờ bị kẹt khi danh mục rỗng hoặc gặp sự cố

- [ ] **Step 1: Viết test cho trường hợp danh mục căn hộ rỗng**
Viết widget test mô phỏng `availableApartmentsProvider` trả về `[]`, kiểm tra xem ô `TextFormField` (mã căn hộ) và nút "Gửi yêu cầu" có xuất hiện và cho phép nhập mã không.

- [ ] **Step 2: Cập nhật giao diện `link_request_screen.dart`**
Thêm chế độ nhập thủ công, khi `apartments.isEmpty` thì hiển thị Card thông báo kèm ngay bên dưới là trường nhập mã căn hộ thủ công và nút toggle chuyển đổi.

- [ ] **Step 3: Chạy test xác nhận thành công**
Chạy `flutter test test/features/resident/link_request_fallback_test.dart`

- [ ] **Step 4: Commit thay đổi**
`git commit -m "fix(resident): bo sung form nhap ma thu cong khi danh muc can ho rong"`
