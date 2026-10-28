# Quy Chuẩn Kiểm Thử & Đảm Bảo Chất Lượng (QA & Testing)

> Toàn bộ quá trình phát triển PKA-Home tuân thủ nghiêm ngặt phương pháp **Test-Driven Development (TDD)**. Mỗi tính năng mới hoặc bản sửa lỗi (Bugfix) đều bắt buộc phải có kiểm thử tự động tương ứng trước khi đưa vào nhánh chính (`main`).

---

## 1. Tổng Quan Bộ Kiểm Thử Tự Động (Test Suite Metrics)

Hệ thống sở hữu bộ kiểm thử tự động toàn diện với hơn **489 bài kiểm thử đạt tỷ lệ 100% Pass**:

```text
[Unit Tests]        -> Kiểm thử logic nghiệp vụ thuần túy: Models, Validators, Utilities, Formatters.
[Provider Tests]    -> Kiểm thử quản lý trạng thái: AsyncNotifier, StreamProvider, Realtime Sync.
[Widget Tests]      -> Kiểm thử giao diện tương tác: Buttons, Dialogs, Preflight validation, Responsive.
[Integration Tests] -> Kiểm thử luồng nghiệp vụ end-to-end: Payment RPC, Migrations, Realtime Streams.
[Security Tests]    -> Kiểm thử xâm nhập & RLS: Chặn truy cập chéo, chống leo thang đặc quyền.
```

---

## 2. Các Phân Hệ Kiểm Thử Trọng Yếu

### 2.1. Kiểm Thử Bảo Mật & Độc Lập Dữ Liệu (RLS Security Suite)
- **Tập tin:** `test/integration/rls_security_test.dart`
- **Các kịch bản kiểm thử bắt buộc:**
  1. *RLS-01 & RLS-02:* Cư dân chỉ có thể SELECT dữ liệu hóa đơn gắn liền với `apartment_id` mà họ được phê duyệt liên kết.
  2. *RLS-03:* Cư dân không thể trực tiếp UPDATE trạng thái hóa đơn (`status = 'paid'`) thông qua PostgREST API.
  3. *RLS-04:* Kỹ thuật viên chỉ có thể cập nhật sự cố được phân công hoặc trong phạm vi cơ sở mình phụ trách.
  4. *RLS-05 (Chống leo thang đặc quyền):* Người dùng thông thường không thể tự sửa trường `role` của chính mình trong bảng `users` thành `'admin'` hoặc `'management'`.

### 2.2. Kiểm Thử Giao Dịch Tài Chính Nguyên Tử (Financial Integrity Suite)
- **Tập tin:** `test/integration/payment_workflow_migration_test.dart`
- **Kịch bản kiểm thử:**
  - Xác minh RPC `simulate_unified_payment` sử dụng cơ chế khóa dòng `FOR UPDATE` chống gửi kép (Double Spending).
  - Kiểm tra Idempotency: Khi giao dịch đang ở trạng thái `pending_confirmation`, không cho phép gửi thêm yêu cầu thanh toán trùng lặp.
  - Xác minh cột `subtotal` trong bảng `invoice_items` là Generated Column tự động tính toán.

### 2.3. Kiểm Thử Thông Báo Realtime & Database Triggers
- **Tập tin:**
  - `test/integration/notification_automation_triggers_migration_test.dart`
  - `test/core/services/push_notification_service_realtime_test.dart`
  - `test/data/providers/notification_realtime_sync_test.dart`
- **Kịch bản kiểm thử:**
  - Kiểm tra định nghĩa chuẩn của 4 Database Triggers trong file migration.
  - Kiểm thử `PushNotificationService` nhận gói tin CDC từ stream, lọc trùng lặp qua `_seenNotificationIds` và hiển thị Heads-up notification.
  - Kiểm thử vòng đời Riverpod: kích hoạt listener khi đăng nhập và hủy stream an toàn khi đăng xuất.

### 2.4. Kiểm Thử Giao Diện Co Giãn & Trợ Năng (Responsive & Accessibility Suite)
- **Tập tin:** `test/integration/ui_responsive_and_accessibility_test.dart`
- **Kịch bản kiểm thử:**
  - Chạy toàn bộ màn hình Dashboard, Căn hộ, Hóa đơn, Tiện ích trên các kích thước màn hình nhỏ hẹp (`360x640 dp`, `390x844 dp`).
  - Kiểm tra điều kiện: Tuyệt đối không phát sinh lỗi **RenderFlex overflowed**.
  - Kiểm tra thuộc tính tự động xuống dòng (Word-wrap) của các thẻ `AppCard` và `Wrap`.

---

## 3. Lệnh Kiểm Tra Chất Lượng Định Kỳ (Verification Commands)

Mỗi lần trước khi commit hoặc bàn giao phiên bản mới, bắt buộc thực thi 2 cổng kiểm soát chất lượng:

```bash
# 1. Phân tích tĩnh mã nguồn (Yêu cầu 0 cảnh báo, 0 lỗi linter)
dart analyze

# 2. Chạy toàn bộ 489+ bài kiểm thử tự động (Yêu cầu 100% Pass)
flutter test
```
