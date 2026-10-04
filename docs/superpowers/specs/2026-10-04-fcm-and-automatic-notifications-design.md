# Thiết Kế Hệ Thống: FCM & Hệ Thống Thông Báo Tự Động (FCM & Automated Notifications)

## 1. Tổng Quan & Mục Tiêu

Hệ thống thông báo đẩy (Push Notifications) và tự động hóa cảnh báo vận hành là huyết mạch kết nối giữa Ban Quản Lý (BQL) và Cư dân tại chung cư PKA-Home. Thiết kế này tích hợp song song:
1. **Firebase Cloud Messaging (FCM)**: Đẩy thông báo tức thời cấp hệ điều hành (hiển thị trên màn hình khóa, thanh trạng thái, rung chuông) ngay cả khi ứng dụng bị đóng hoàn toàn (`kill app`) hoặc khóa màn hình.
2. **Supabase Realtime & Postgres Triggers**: Tự động hóa 100% việc tạo bản ghi thông báo khi có sự kiện vận hành (phát hành hóa đơn mới, bảo trì thiết bị gián đoạn dịch vụ, cập nhật trạng thái xử lý phản ánh sự cố), đồng thời đồng bộ tức thì vào "Trung tâm thông báo" (In-App Notification Center) khi ứng dụng đang mở.

---

## 2. Kiến Trúc Tổng Thể (Architecture Overview)

```
┌────────────────────────────────────────────────────────────────────────┐
│                        SUPABASE POSTGRESQL                             │
│                                                                        │
│  [invoices]  [building_equipments]  [issue_reports]                    │
│      │               │                    │                            │
│      ▼               ▼                    ▼                            │
│  (Trigger 1)     (Trigger 2)          (Trigger 3)                      │
│   Hóa đơn mới    Bảo trì gián đoạn    Cập nhật phản ánh                │
│      │               │                    │                            │
│      └───────────────┼────────────────────┘                            │
│                      ▼                                                 │
│             [public.notifications] ◄───────────────┐                  │
│                      │                             │                   │
│         Postgres CDC / Realtime Stream             │                   │
└──────────────────────┼─────────────────────────────┼───────────────────┘
                       │                             │
        (App đang mở / Foreground)                   │ Đăng ký token
                       │                             │ khi đăng nhập
                       ▼                             │
          ┌─────────────────────────┐                │
          │  FLUTTER CLIENT APP     │                │
          │  PushNotificationService├────────────────┘
          │  - Quản lý FCM Token    │
          │  - In-app Notification  │
          │  - Notification Center  │
          └────────────▲────────────┘
                       │
             (App tắt / Màn hình khóa)
                       │
          ┌────────────┴────────────┐
          │  FIREBASE CLOUD         │
          │  MESSAGING (FCM HTTP v1)│
          └─────────────────────────┘
```

---

## 3. Chi Tiết Tầng Cơ Sở Dữ Liệu (Database Triggers)

### 3.1. Bảng Dữ Liệu Liên Quan
- `public.user_fcm_tokens`: Lưu trữ cặp `(user_id, token, device_info, updated_at)`.
- `public.notifications`: Lưu trữ danh sách thông báo in-app (`user_id`, `apartment_id`, `title`, `body`, `type`, `payload`, `is_read`, `created_at`).

### 3.2. Ba Bộ Triggers Tự Động Hóa Nghiệp Vụ
1. **Trigger 1: Thông báo Hóa đơn mới (`trg_notify_on_new_invoice`)**:
   - Bảng: `public.invoices` (AFTER INSERT).
   - Điều kiện: `NEW.status = 'unpaid'`.
   - Hành động: Quét toàn bộ cư dân gắn với `NEW.apartment_id` qua `residents_apartments` $\rightarrow$ Thêm thông báo `type = 'new_invoice'`.
   - Nội dung: *"Hóa đơn mới kỳ [Kỳ] - Căn hộ [Mã phòng] vừa nhận được hóa đơn với tổng tiền [Tiền] đ. Hạn thanh toán: [Hạn]"*.

2. **Trigger 2: Thông báo Bảo trì thiết bị gián đoạn sinh hoạt (`trg_notify_on_equipment_maintenance`)**:
   - Bảng: `public.equipment_maintenance_tasks` (AFTER UPDATE / INSERT).
   - Điều kiện: `NEW.status = 'in_progress'` AND `NEW.affects_service = true`.
   - Hành động: 
     - Lấy thông tin thiết bị (`building_equipments`) để biết tòa nhà (`building`).
     - Quét toàn bộ cư dân thuộc tòa nhà đó (nếu là `'Toàn khu'` thì gửi toàn thể cư dân).
     - Thêm thông báo `type = 'equipment_maintenance'`.
   - Nội dung: *"Bảo trì thiết bị: [Tên thiết bị] tạm gián đoạn dịch vụ từ [Giờ bắt đầu] đến [Giờ kết thúc]. Ghi chú: [Lưu ý]"*.

3. **Trigger 3: Thông báo Tiến độ xử lý phản ánh sự cố (`trg_notify_on_issue_status_change`)**:
   - Bảng: `public.issue_reports` (AFTER UPDATE).
   - Điều kiện: Trạng thái thay đổi (`OLD.status IS DISTINCT FROM NEW.status`) hoặc được phân công (`OLD.assigned_staff_id IS DISTINCT FROM NEW.assigned_staff_id`).
   - Hành động:
     - Gửi thông báo cho người phản ánh (`NEW.reporter_id`):
       - Khi sang `in_progress`: *"Sự cố [Tiêu đề] đã được Ban Quản Lý tiếp nhận và đang tiến hành xử lý"*.
       - Khi sang `resolved`: *"Sự cố [Tiêu đề] đã được xử lý hoàn tất. Quý Cư dân vui lòng kiểm tra và đánh giá chất lượng dịch vụ"*.
     - Gửi thông báo cho kỹ thuật viên (`NEW.assigned_staff_id`) nếu có phân công mới.

---

## 4. Chi Tiết Tầng Client Flutter

### 4.1. Gradle & Dependencies
- `android/settings.gradle.kts`: Plugin `com.google.gms.google-services` phiên bản `4.4.2`.
- `android/app/build.gradle.kts`: Apply plugin `id("com.google.gms.google-services")`.
- `pubspec.yaml`:
  - `firebase_core: ^3.12.0`
  - `firebase_messaging: ^15.2.0`

### 4.2. Quản Lý Dịch Vụ: `PushNotificationService`
- **Khởi tạo An toàn (Safe Initialization)**:
  - Bọc trong `try-catch` kiểm tra `Firebase.initializeApp()`. Nếu chạy trên môi trường test (unit/widget test) hoặc nền tảng không hỗ trợ, tự động chuyển về chế độ Mock/In-App fallback, không bao giờ gây crash app.
- **Quyền thông báo (Permissions)**:
  - Gọi `requestPermission()` xin cấp quyền nhận thông báo (Notification Permission) theo chuẩn Android 13+ (POST_NOTIFICATIONS) và iOS.
- **Đăng ký Device Token**:
  - Lấy `token = await _fcm.getToken()`.
  - Tự động lưu lên Supabase qua `NotificationRepository.registerFcmToken()`.
  - Lắng nghe sự kiện `_fcm.onTokenRefresh` để cập nhật khi token thay đổi.
- **Xử lý Thông báo 3 trạng thái**:
  - **Foreground (App đang mở)**: `FirebaseMessaging.onMessage` $\rightarrow$ Hiển thị Toast/SnackBar thông báo nổi hoặc Banner thông báo trong app mà không làm gián đoạn người dùng.
  - **Background (App chạy ẩn/Khóa màn hình)**: `FirebaseMessaging.onBackgroundMessage` (top-level handler) $\rightarrow$ Hệ điều hành tự động hiển thị thanh thông báo.
  - **Terminated (Mở app từ thông báo)**: `getInitialMessage()` hoặc `onMessageOpenedApp` $\rightarrow$ Phân tích `message.data['type']` để điều hướng GoRouter trực tiếp đến màn hình chi tiết (Hóa đơn `/resident/invoices`, Sự cố `/resident/issues/:id`, Cẩm nang/Thiết bị).

---

## 5. Kịch Bản Kiểm Thử & Tiêu Chí Nghiệm Thu (Acceptance Criteria)

1. **Gradle Build Verification**:
   - `android/settings.gradle.kts` và `android/app/build.gradle.kts` cấu hình đúng chuẩn, biên dịch Android Gradle thành công không lỗi cú pháp.
2. **Database Triggers**:
   - Tạo hóa đơn mới $\rightarrow$ Kiểm tra bảng `notifications` xuất hiện bản ghi thông báo tương ứng cho cư dân căn hộ đó.
   - Chuyển task bảo trì sang `in_progress` kèm `affects_service = true` $\rightarrow$ Cư dân trong tòa nhà nhận được thông báo bảo trì.
   - Cập nhật trạng thái sự cố sang `in_progress` / `resolved` $\rightarrow$ Cư dân gửi phản ánh nhận được thông báo cập nhật.
3. **Flutter Token Registration & Foreground Handling**:
   - Khi cư dân đăng nhập $\rightarrow$ Token được ghi nhận vào `user_fcm_tokens`.
   - Khi có thông báo mới $\rightarrow$ Badge số đếm trên Header tăng lên, màn hình Notification Center hiển thị đúng nội dung.
4. **Code Quality**:
   - 0 lỗi `dart analyze`.
   - Toàn bộ unit/widget tests hiện có tiếp tục PASS 100%.
