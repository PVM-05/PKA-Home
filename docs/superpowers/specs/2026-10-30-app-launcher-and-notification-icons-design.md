# Tài Liệu Thiết Kế: App Launcher Icon & Notification Icon (PKA-Home)

- **Ngày lập:** 30/10/2026
- **Trạng thái:** Đã phê duyệt (Approved)
- **Tác giả:** Antigravity AI Assistant & PKA-Home Engineering Team

---

## 1. Mục Tiêu & Bối Cảnh

Ứng dụng **PKA-Home** hiện đang sử dụng biểu tượng mặc định của Flutter (`ic_launcher.png`) và chưa có biểu tượng thông báo riêng (`ic_notification`), dẫn đến:
1. Nhận diện thương hiệu chưa chuyên nghiệp trên màn hình chính của thiết bị cư dân và ban quản lý.
2. Trên Android thanh trạng thái (status bar), các thông báo biến động số dư, nhắc tiền phòng và duyệt xe bị hiển thị thành một khối vuông màu trắng đục do Android yêu cầu biểu tượng thông báo bắt buộc phải là định dạng đơn sắc (monochrome trắng trên nền trong suốt).

Mục tiêu của tài liệu này là thiết kế và triển khai trọn bộ:
- **App Launcher Icon**: Chuẩn Modern Minimalist kết hợp Adaptive Icon (Android 8.0 - 14+) và iOS.
- **Notification Small Icon**: Biểu tượng chuông + mái nhà đơn sắc chuẩn Android Status Bar.

---

## 2. Thông Số Thiết Kế Chi Tiết

### 2.1. App Launcher Icon
- **Chủ đề tạo hình:** Mái nhà kết hợp tòa chung cư cao tầng hiện đại vươn lên, các khối ô cửa sổ tượng trưng cho các căn hộ số hóa.
- **Màu sắc thương hiệu:**
  - Nền (`background`): Gradient chuyển từ Xanh dương đậm (`#1E3A8A`) sang Xanh thương hiệu PKA (`#1E88E5`).
  - Họa tiết (`foreground`): Trắng (`#FFFFFF`) kết hợp viền ánh xanh Cyan (`#03A9F4`).
- **Quy chuẩn kỹ thuật:**
  - Master Canvas: `1024 x 1024 px` PNG 32-bit (ARGB).
  - Vùng an toàn Adaptive Icon (Safe Zone): Họa tiết chính nằm gọn trong đường kính 66dp (~680px ở canvas 1024) để không bị xén cạnh khi Android hiển thị dạng squircle, circle hay teardrop.

### 2.2. Notification Icon (`ic_notification`)
- **Chủ đề tạo hình:** Biểu tượng Chuông thông báo kết hợp đường viền mái nhà (Bell + Home roofline).
- **Quy chuẩn Android Status Bar:**
  - 100% màu trắng tinh (`#FFFFFF`), kênh Alpha trong suốt (`#00000000`).
  - Xuất ra đầy đủ các độ phân giải:
    - `drawable-mdpi`: 24 x 24 px
    - `drawable-hdpi`: 36 x 36 px
    - `drawable-xhdpi`: 48 x 48 px
    - `drawable-xxhdpi`: 72 x 72 px
    - `drawable-xxxhdpi`: 96 x 96 px
    - XML Vector Drawable: `android/app/src/main/res/drawable/ic_notification.xml`

---

## 3. Kiến Trúc Tích Hợp & File Liên Quan

1. **Master Assets:**
   - `assets/icons/app_icon.png` (Icon đầy đủ nền và biểu tượng, dùng cho iOS và Android legacy).
   - `assets/icons/app_icon_foreground.png` (Họa tiết trong suốt dùng cho Android Adaptive Icon).
   - `assets/icons/notification_icon.png` (Monochrome master).

2. **Cấu hình `pubspec.yaml` (`flutter_launcher_icons`):**
   ```yaml
   dev_dependencies:
     flutter_launcher_icons: ^0.14.3

   flutter_launcher_icons:
     android: "launcher_icon"
     ios: true
     image_path: "assets/icons/app_icon.png"
     adaptive_icon_background: "#1E88E5"
     adaptive_icon_foreground: "assets/icons/app_icon_foreground.png"
     min_sdk_android: 21
   ```

3. **Cấu hình Hệ thống Android:**
   - `android/app/src/main/AndroidManifest.xml`:
     ```xml
     <meta-data
         android:name="com.google.firebase.messaging.default_notification_icon"
         android:resource="@drawable/ic_notification" />
     ```
   - `lib/core/services/push_notification_service.dart`:
     Cập nhật `AndroidInitializationSettings('@drawable/ic_notification')` và fallback icon notification sang `@drawable/ic_notification`.

---

## 4. Kịch Bản Kiểm Thử & Tiêu Chí Nghiệm Thu (Acceptance Criteria)

1. **Tiêu chí 1 (Launcher Icon):**
   - Lệnh `flutter pub run flutter_launcher_icons` tạo thành công toàn bộ mipmap (`mipmap-mdpi` đến `mipmap-xxxhdpi`) và iOS asset catalog.
   - Ứng dụng khi build lên thiết bị hiển thị icon PKA-Home màu xanh nổi bật, sắc nét, không bị méo tỉ lệ.

2. **Tiêu chí 2 (Notification Icon):**
   - Đầy đủ file `ic_notification.png` trong các thư mục `android/app/src/main/res/drawable-*` và vector `ic_notification.xml`.
   - Thông báo đẩy cục bộ (Local notifications) và thông báo Firebase (FCM) hiển thị icon chuông mái nhà sắc nét trên thanh trạng thái Android, không bị hiện tượng ô vuông trắng (white box).

3. **Tiêu chí 3 (Quality Gate):**
   - `dart analyze` đạt 0 lỗi.
   - `flutter test` đạt 100% pass (646+ tests).
   - `flutter build apk --debug` hoàn thành thành công không có lỗi tài nguyên drawable.

