# Kế Hoạch Chuẩn Hóa Đợt 3: Trải Nghiệm Người Dùng, Đồng Bộ Hóa Thông Báo & Triage Sự Cố (P1/P2)

> **Mục tiêu:** Giải quyết triệt để các vấn đề UX, phân luồng thông báo đẩy, deep-linking thông báo, rà soát văn bản thương mại và phân loại sự cố tự động chuẩn mực.

---

## 1. Danh Sách Hạng Mục Triển Khai

| STT | Nhiệm Vụ | Mục Tiêu & Mô Tả Kỹ Thuật | Trạng Thái |
| :--- | :--- | :--- | :--- |
| **3.1** | **Khắc phục spam toast khi đổi căn hộ** | Trong `ResidentHomeScreen`, theo dõi `_lastNotifiedApartmentId`. Bỏ qua so sánh hóa đơn mới khi đổi căn hộ hoặc nạp dữ liệu lần đầu của căn hộ mới. | ✅ Hoàn thành 100% |
| **3.2** | **Gom luồng thông báo & Chống lặp thông báo** | Loại bỏ việc phát Notification Heads-up trùng lặp giữa các listener dữ liệu màn hình và dịch vụ thông báo trung tâm; chỉ phát notification cho sự kiện sau `_sessionStartTime`. | ✅ Hoàn thành 100% |
| **3.3** | **Điều hướng thông báo (Deep-linking)** | Thêm `rootNavigatorKey` cho `GoRouter`, cấu hình `getInitialMessage`, `onMessageOpenedApp` và truyền `onSelectNotificationRoute` trong `auth_provider.dart`. | ✅ Hoàn thành 100% |
| **3.4** | **Loại bỏ chuỗi "Demo Payment"** | Thay thế toàn bộ "Demo Payment" thành "Cổng thanh toán điện tử" hoặc "Cổng thanh toán trực tuyến" chuẩn nghiệp vụ trong handbook, booking và invoice. | ✅ Hoàn thành 100% |
| **3.5** | **Chuẩn hóa Triage từ khóa & Nút cứu hộ khẩn cấp** | Chuẩn hóa ranh giới từ vựng không dấu trong `IssueSmartTriageEngine`, bổ sung phím tắt gọi 114/115 khi có hỏa hoạn/kẹt người, đổi nhãn "Trợ lý AI" thành "Gợi ý tự động". | ✅ Hoàn thành 100% |
| **3.6** | **Kiểm thử & Xác minh hồi quy** | Viết unit/widget test cho logic chống spam toast, deep-linking route resolver, kiểm tra từ khóa triage không bị dính 'nóng' -> 'nổ', chạy `dart analyze lib test`. | ✅ Hoàn thành 100% |

---

## 2. Kế Hoạch Thực Hiện Chi Tiết Từng Bước

### Bước 1: Loại bỏ chuỗi "Demo Payment" (Task 3.4)
- Files:
  - `lib/features/management/screens/amenity_management_screen.dart`
  - `lib/features/resident/screens/amenity_booking_screen.dart`
  - `lib/features/resident/screens/resident_handbook_screen.dart`
  - `lib/features/resident/screens/resident_invoice_detail_screen.dart`

### Bước 2: Chuẩn hóa Triage Engine & Màn hình gửi phản ánh (Task 3.5)
- Files:
  - `lib/core/utils/issue_smart_triage_engine.dart`: Cải tiến kiểm tra từ nguyên vẹn với chuỗi tiếng Việt có dấu và không dấu; bổ sung số khẩn cấp 114, 115.
  - `lib/features/resident/screens/create_issue_screen.dart`: Bổ sung nút gọi 114 (Cứu hỏa) & 115 (Cấp cứu y tế) khi phát hiện nguy cơ cao; đổi nhãn thành "Gợi ý tự động".
  - `test/core/utils/issue_smart_triage_engine_test.dart`: Test kiểm tra không bị false-positive với 'bon cau bi tac, nong'.

### Bước 3: Đồng bộ thông báo & Điều hướng Deep-linking (Task 3.2 & 3.3)
- Files:
  - `lib/core/router/app_router.dart`: Thêm `rootNavigatorKey`.
  - `lib/core/services/push_notification_service.dart`: Cập nhật `_sessionStartTime`, xử lý `getInitialMessage` và `onMessageOpenedApp`.
  - `lib/data/providers/auth_provider.dart`: Cung cấp `onSelectNotificationRoute` cho `safeInitialize`.
  - Test: `test/core/services/push_notification_service_test.dart`.

### Bước 4: Khắc phục spam toast khi đổi căn hộ trong `ResidentHomeScreen` (Task 3.1)
- Files:
  - `lib/features/resident/screens/resident_home_screen.dart`:
    - Quản lý `_lastNotifiedApartmentId`.
    - Khi căn hộ thay đổi, ghi nhận ID mới mà không kích hoạt toast "Hóa đơn mới".
    - Không gọi `pushNotificationServiceProvider.showSystemNotification` trong các listener UI màn hình này để tránh duplicate với FCM / notification stream.
  - Test: `test/features/resident/resident_home_apartment_switch_test.dart`.

### Bước 5: Kiểm thử tĩnh và toàn bộ test suite (Task 3.6)
- Chạy `dart analyze lib test`.
- Chạy toàn bộ test suites của Đợt 1, Đợt 2 và Đợt 3.
- Cập nhật tài liệu roadmap và bàn giao.

