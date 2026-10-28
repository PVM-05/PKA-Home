# Kế Hoạch Thực Thi: Giai Đoạn E2 - Triggers Tự Động Hóa Thông Báo CSDL & Realtime Dispatcher

> **Mục tiêu:** Tự động hóa hoàn toàn luồng thông báo trong PKA-Home: Khi có sự kiện nghiệp vụ (phát hành hóa đơn, cập nhật phản ánh sự cố, phê duyệt liên kết căn hộ, thanh toán thành công), Postgres Triggers tự động sinh bản ghi thông báo và chuyển tới Client qua Supabase Realtime CDC để hiển thị Heads-up notification tức thì.  
> **Nguyên tắc:** Commit trực tiếp vào `main`, TDD (Test-Driven Development), giữ 483+ tests pass 100%, 0 issues linter.

---

## Danh Sách Tasks

### Task 1: Database Migration `20261028_03_notification_automation_triggers.sql`
- [ ] Viết test `test/integration/notification_automation_triggers_migration_test.dart`
- [ ] Xác nhận test fail khi chưa có file migration
- [ ] Tạo file migration `supabase/migrations/20261028_03_notification_automation_triggers.sql`:
  - Trigger 1: `trg_notify_on_new_invoice` (Tự động thông báo khi có hóa đơn mới)
  - Trigger 2: `trg_notify_on_issue_status_change` (Tự động thông báo khi tiếp nhận/xử lý/hoàn tất phản ánh)
  - Trigger 3: `trg_notify_on_link_request_status` (Tự động thông báo khi duyệt/từ chối liên kết căn hộ)
  - Trigger 4: `trg_notify_on_invoice_paid` (Tự động gửi thông báo xác nhận thanh toán/biên lai thành công)
- [ ] Chạy test để xác nhận PASS
- [ ] Commit migration

### Task 2: Realtime In-App Notification Stream trong `NotificationRepository`
- [ ] Viết test `test/data/repositories/notification_realtime_stream_test.dart`
- [ ] Triển khai hàm `subscribeUserNotifications(String userId)` trong `NotificationRepository`
- [ ] Tích hợp vào `PushNotificationService` để tự động phát Heads-up notification (`showSystemNotification`)
- [ ] Chạy test để xác nhận PASS
- [ ] Commit Repository & Service

### Task 3: Kích Hoạt Realtime Dispatcher Trong `auth_provider.dart` & Cập Nhật Badge
- [ ] Viết test `test/data/providers/notification_realtime_sync_test.dart`
- [ ] Cập nhật `fcmTokenSyncProvider` / `userNotificationSyncProvider` trong `auth_provider.dart`
- [ ] Đảm bảo tự động hủy subscription khi đăng xuất (Clean cleanup)
- [ ] Chạy test để xác nhận PASS
- [ ] Commit Providers

### Task 4: Kiểm Thử Toàn Diện & Verification Gate
- [ ] Chạy `dart analyze` (0 issues)
- [ ] Chạy `flutter test` (toàn bộ tests pass 100%)
- [ ] Commit tổng kết Giai đoạn E2 lên `main`
