# Kế Hoạch Triển Khai: App Launcher Icon & Notification Icon (PKA-Home)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tạo trọn bộ App Launcher Icon (Adaptive Icon chuẩn Android & iOS) và Notification Small Icon (Monochrome Bell + House chuẩn Android Status Bar) cho PKA-Home, loại bỏ hoàn toàn icon mặc định của Flutter và lỗi khối vuông trắng khi nhận thông báo.

**Architecture:** Sử dụng pipeline tự động hóa: sinh master image assets chuẩn tỷ lệ 1024x1024 (`app_icon.png`, `app_icon_foreground.png`), sinh monochrome notification drawables (`ic_notification.png` & vector XML), chạy `flutter_launcher_icons` để tạo toàn bộ mipmaps, và cập nhật `AndroidManifest.xml` cùng `PushNotificationService`.

**Tech Stack:** Dart, Flutter, `flutter_launcher_icons: ^0.14.3`, Android Vector/Drawable Resources, `flutter_local_notifications`.

## Global Constraints
- Tuân thủ quy tắc git: Toàn bộ commit trực tiếp vào nhánh `main`.
- 100% tiếng Việt tự nhiên trên UI, không dùng emoji.
- Màu sắc thương hiệu chuẩn: Primary `#1E88E5`, Secondary `#03A9F4`, Dark Blue `#1E3A8A`.
- Không làm suy giảm số lượng test: Duy trì 100% pass toàn bộ 646+ tests.
- `dart analyze` phải đạt 0 issue.

---

### Task 1: Thiết Kế & Tạo Master Assets Độ Phân Giải Cao (1024x1024)

**Files:**
- Create: `assets/icons/app_icon.png` (Master launcher icon 1024x1024)
- Create: `assets/icons/app_icon_foreground.png` (Adaptive foreground 1024x1024)
- Create: `assets/icons/notification_icon.png` (Monochrome white on transparent 512x512)

**Interfaces:**
- Consumes: Brand palette (`#1E88E5`, `#03A9F4`, `#1E3A8A`, `#FFFFFF`)
- Produces: PNG files trong `assets/icons/` dùng làm nguồn cho `flutter_launcher_icons` và drawable resizers.

- [x] **Step 1:** Viết script generator hoặc vẽ đồ họa vector chất lượng cao kết xuất ra `assets/icons/app_icon.png` (gradient background + stylized high-rise residential building + smart home roofline).
- [x] **Step 2:** Kết xuất `assets/icons/app_icon_foreground.png` với kích thước 1024x1024 trong suốt, họa tiết chính nằm trong safe zone (đường kính ~680px).
- [x] **Step 3:** Kết xuất `assets/icons/notification_icon.png` hình chuông lồng mái nhà đơn sắc trắng trên nền trong suốt.
- [x] **Step 4:** Kiểm tra sự tồn tại và tính hợp lệ của các file ảnh qua PowerShell test.
- [x] **Step 5:** Commit task 1 vào `main`.

---

### Task 2: Cấu Hình & Chạy `flutter_launcher_icons` Tạo Mipmaps Android & iOS

**Files:**
- Modify: `pubspec.yaml` (Thêm `flutter_launcher_icons: ^0.14.3` vào `dev_dependencies` và khối cấu hình)
- Generate: `android/app/src/main/res/mipmap-*/ic_launcher.png`
- Generate: `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml`
- Generate: `ios/Runner/Assets.xcassets/AppIcon.appiconset/*`

**Interfaces:**
- Consumes: `assets/icons/app_icon.png` & `assets/icons/app_icon_foreground.png`
- Produces: Full density icon mipmaps cho Android & iOS.

- [x] **Step 1:** Thêm `flutter_launcher_icons: ^0.14.3` và cấu hình `flutter_launcher_icons` vào `pubspec.yaml`.
- [x] **Step 2:** Chạy `flutter pub get`.
- [x] **Step 3:** Chạy `dart run flutter_launcher_icons` để tự động cập nhật toàn bộ icon launcher.
- [x] **Step 4:** Xác minh các file mipmap và adaptive XML đã được cập nhật thành công trong `android/app/src/main/res/`.
- [x] **Step 5:** Commit task 2 vào `main`.

---

### Task 3: Tạo Bộ Android Notification Drawables (`ic_notification`)

**Files:**
- Create: `android/app/src/main/res/drawable/ic_notification.xml` (Vector Drawable)
- Create: `android/app/src/main/res/drawable-mdpi/ic_notification.png` (24x24)
- Create: `android/app/src/main/res/drawable-hdpi/ic_notification.png` (36x36)
- Create: `android/app/src/main/res/drawable-xhdpi/ic_notification.png` (48x48)
- Create: `android/app/src/main/res/drawable-xxhdpi/ic_notification.png` (72x72)
- Create: `android/app/src/main/res/drawable-xxxhdpi/ic_notification.png` (96x96)

**Interfaces:**
- Consumes: Vector path / master notification icon (White Bell + Home).
- Produces: Chuẩn Android status bar notification drawables.

- [x] **Step 1:** Tạo file vector XML `android/app/src/main/res/drawable/ic_notification.xml` với path chuông thông báo kết hợp mái nhà PKA màu trắng.
- [x] **Step 2:** Sinh các file PNG bitmap tương ứng ở 5 mức mật độ (`mdpi` 24px, `hdpi` 36px, `xhdpi` 48px, `xxhdpi` 72px, `xxxhdpi` 96px).
- [x] **Step 3:** Viết unit/integration test kiểm tra sự tồn tại và tính hợp lệ của tất cả các file resource drawable.
- [x] **Step 4:** Commit task 3 vào `main`.

---

### Task 4: Tích Hợp `ic_notification` Vào Hệ Thống Thông Báo (FCM & Local)

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `lib/core/services/push_notification_service.dart`
- Test: `test/core/services/push_notification_service_realtime_test.dart` (hoặc test tương ứng)

**Interfaces:**
- Consumes: `@drawable/ic_notification`
- Produces: Thông báo hệ thống Android tự động sử dụng icon `ic_notification` chuẩn.

- [x] **Step 1:** Cập nhật `AndroidManifest.xml` đổi `default_notification_icon` từ `@mipmap/ic_launcher` thành `@drawable/ic_notification`.
- [x] **Step 2:** Cập nhật `push_notification_service.dart` đổi cấu hình `AndroidInitializationSettings` và default notification icon sang `@drawable/ic_notification`.
- [x] **Step 3:** Chạy các unit test liên quan đến notification service để kiểm tra cấu hình.
- [x] **Step 4:** Commit task 4 vào `main`.

---

### Task 5: Quality Gate & Verification Toàn Diện

**Files:**
- Verify: Toàn bộ codebase

- [x] **Step 1:** Chạy `dart analyze` đảm bảo 0 issues.
- [x] **Step 2:** Chạy `flutter test` đảm bảo 100% tests pass (646+ tests).
- [x] **Step 3:** Chạy `flutter build apk --debug` để xác minh Android Asset Packaging Tool (AAPT2) biên dịch toàn bộ icon và drawable thành công, không có lỗi tài nguyên.
- [x] **Step 4:** Báo cáo hoàn tất và bàn giao cho người dùng.

