# Kế Hoạch Triển Khai: FCM & Hệ Thống Thông Báo Tự Động (FCM & Automated Notifications)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tích hợp Firebase Cloud Messaging (FCM) và xây dựng hệ thống thông báo tự động 100% từ Database Triggers cho mọi biến động quan trọng: phát hành hóa đơn mới, bảo trì thiết bị gián đoạn sinh hoạt, và cập nhật tiến độ xử lý phản ánh sự cố.

**Architecture:** Kiến trúc Hybrid kết hợp Supabase PostgreSQL Triggers (tự động tạo thông báo in-app realtime) và `PushNotificationService` (quản lý đăng ký Device Token lên `user_fcm_tokens`, lắng nghe thông báo Foreground/Background, điều hướng thông minh).

**Tech Stack:** Flutter (Dart 3.x), Riverpod, GoRouter, Firebase Core, Firebase Messaging, Supabase Database, RLS, Triggers.

## Global Constraints

- **Language:** 100% Tiếng Việt chuẩn mực trên mọi màn hình, tiêu đề thông báo, nội dung cảnh báo.
- **Fail-safe / Graceful Degradation:** Tích hợp Firebase an toàn, bọc trong try-catch và kiểm tra nền tảng để không gây crash app khi chạy trên môi trường test, Windows desktop, hoặc thiết bị chưa có Google Play Services.
- **TDD:** Kiểm thử độc lập từng tầng; bảo đảm toàn bộ 162/162 test cases hiện có tiếp tục PASS 100%.

---

### Task 1: Cấu Hình Gradle Android & Cài Đặt Thư Viện Firebase

**Files:**
- Modify: `android/settings.gradle.kts`
- Modify: `android/app/build.gradle.kts`
- Modify: `pubspec.yaml`

**Interfaces & Configurations:**
- Thêm plugin `com.google.gms.google-services:4.4.2` vào `android/settings.gradle.kts`.
- Apply plugin `id("com.google.gms.google-services")` vào `android/app/build.gradle.kts`.
- Thêm `firebase_core: ^3.12.0` và `firebase_messaging: ^15.2.0` vào `pubspec.yaml`.

- [ ] **Step 1: Cập nhật `android/settings.gradle.kts` thêm plugin Google Services**
- [ ] **Step 2: Cập nhật `android/app/build.gradle.kts` apply plugin Google Services**
- [ ] **Step 3: Cập nhật `pubspec.yaml` thêm `firebase_core` và `firebase_messaging`**
- [ ] **Step 4: Chạy `flutter pub get` để tải dependencies**
- [ ] **Step 5: Commit vào git**

```bash
git add android/ pubspec.yaml pubspec.lock
git commit -m "chore(deps): tích hợp thư viện firebase core, firebase messaging và cấu hình gradle"
```

---

### Task 2: Migration Database Triggers Thông Báo Tự Động (`20261004_03_automatic_notifications_triggers.sql`)

**Files:**
- Create: `supabase/migrations/20261004_03_automatic_notifications_triggers.sql`

**Interfaces:**
- Trigger 1: `trg_notify_on_equipment_maintenance` trên `public.equipment_maintenance_tasks`:
  - Kích hoạt khi task có `affects_service = true` chuyển `status = 'in_progress'`.
  - Quét danh sách cư dân thuộc tòa nhà của thiết bị đó (hoặc toàn khu nếu tòa nhà là 'Toàn khu').
  - Tạo bản ghi `notifications` loại `equipment_maintenance`.
- Trigger 2: `trg_notify_on_issue_status_change` trên `public.issue_reports`:
  - Kích hoạt khi `status` chuyển sang `in_progress` hoặc `resolved`, gửi thông báo cho `reporter_id`.
  - Kích hoạt khi có phân công kỹ thuật viên `assigned_staff_id`, gửi thông báo cho nhân viên đó.

- [ ] **Step 1: Tạo file migration `supabase/migrations/20261004_03_automatic_notifications_triggers.sql`**
- [ ] **Step 2: Kiểm tra cấu trúc trigger và policies**
- [ ] **Step 3: Commit migration vào git**

```bash
git add supabase/migrations/20261004_03_automatic_notifications_triggers.sql
git commit -m "feat(db): bổ sung triggers tự động tạo thông báo bảo trì thiết bị và cập nhật sự cố"
```

---

### Task 3: Xây Dựng `PushNotificationService` & Unit Tests

**Files:**
- Create: `lib/core/services/push_notification_service.dart`
- Create: `test/core/services/push_notification_service_test.dart`

**Interfaces:**
- `PushNotificationService`:
  - `initialize({required String userId}) -> Future<void>`: Xin quyền `requestPermission()`, lấy `getToken()`, lưu vào `user_fcm_tokens`, lắng nghe `onTokenRefresh`.
  - `setupForegroundNotificationHandler(BuildContext context) -> void`: Lắng nghe `FirebaseMessaging.onMessage` để hiển thị SnackBar/Toast thông báo nổi.
  - `handleNotificationTap(RemoteMessage message, BuildContext context) -> void`: Điều hướng theo `type`:
    - `new_invoice`, `invoice_due_reminder` $\rightarrow$ `/resident/invoices`
    - `equipment_maintenance` $\rightarrow$ `/resident/handbook` hoặc Home
    - `issue_update` $\rightarrow$ `/resident/issues`
  - Fallback an toàn khi Firebase chưa khả dụng trên môi trường test.

- [ ] **Step 1: Viết unit tests kiểm tra logic của `PushNotificationService` trong `test/core/services/push_notification_service_test.dart`**
- [ ] **Step 2: Hiện thực `PushNotificationService` trong `lib/core/services/push_notification_service.dart`**
- [ ] **Step 3: Chạy test xác nhận PASS**
- [ ] **Step 4: Commit vào git**

```bash
git add lib/core/services/push_notification_service.dart test/core/services/
git commit -m "feat(service): tạo PushNotificationService quản lý FCM token và xử lý thông báo"
```

---

### Task 4: Tích Hợp Khởi Tạo & Đăng Ký Token (`main.dart` & `auth_provider.dart`)

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/data/providers/auth_provider.dart`

**Interfaces:**
- `main.dart`:
  - Khởi tạo `Firebase.initializeApp()` an toàn trong khối `try-catch`.
- `auth_provider.dart`:
  - Khi người dùng đăng nhập thành công (`UserModel` có dữ liệu), tự động kích hoạt đăng ký Device Token vào `user_fcm_tokens`.

- [ ] **Step 1: Cập nhật `main.dart` khởi tạo Firebase an toàn**
- [ ] **Step 2: Cập nhật lắng nghe đăng nhập để gọi `PushNotificationService.initialize(user.id)`**
- [ ] **Step 3: Chạy tests hiện có đảm bảo không bị ảnh hưởng**
- [ ] **Step 4: Commit vào git**

```bash
git add lib/main.dart lib/data/providers/
git commit -m "feat(auth): tích hợp tự động đăng ký FCM token khi người dùng đăng nhập"
```

---

### Task 5: Nâng Cấp Giao Diện Trung Tâm Thông Báo (`NotificationCenterScreen`)

**Files:**
- Modify: `lib/features/resident/screens/notification_center_screen.dart`
- Create: `test/features/resident/notification_center_screen_test.dart`

**Interfaces:**
- Bổ sung biểu tượng và màu sắc nhận diện cho các loại thông báo mới:
  - `equipment_maintenance`: Icon `Icons.build_circle_outlined`, màu cam cảnh báo, hiển thị nhãn "Bảo trì thiết bị".
  - `issue_update`: Icon `Icons.support_agent_outlined`, màu xanh thông tin, hiển thị nhãn "Xử lý sự cố".
- Xử lý điều hướng khi cư dân bấm vào từng thẻ thông báo.

- [ ] **Step 1: Viết widget test kiểm tra hiển thị các loại thông báo mới trong `test/features/resident/notification_center_screen_test.dart`**
- [ ] **Step 2: Cập nhật `NotificationCenterScreen` hỗ trợ `equipment_maintenance` và `issue_update`**
- [ ] **Step 3: Chạy test xác nhận PASS**
- [ ] **Step 4: Commit vào git**

```bash
git add lib/features/resident/screens/notification_center_screen.dart test/features/resident/
git commit -m "feat(ui): nâng cấp trung tâm thông báo hỗ trợ bảo trì thiết bị và cập nhật phản ánh"
```

---

### Task 6: Kiểm Thử Toàn Diện, Phân Tích Tĩnh & Tích Hợp Nhánh (Verification)

**Files:**
- Toàn bộ codebase liên quan

- [ ] **Step 1: Chạy `dart analyze` đảm bảo 0 issues**
- [ ] **Step 2: Chạy toàn bộ test suite `flutter test` đảm bảo 100% test cases pass**
- [ ] **Step 3: Báo cáo kết quả và tích hợp nhánh hoàn tất**
