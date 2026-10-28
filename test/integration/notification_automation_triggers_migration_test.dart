import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Notification Automation Triggers Migration Tests', () {
    const migrationPath = 'supabase/migrations/20261028_03_notification_automation_triggers.sql';

    test('Tập tin migration 20261028_03_notification_automation_triggers.sql phải tồn tại', () {
      final file = File(migrationPath);
      expect(file.existsSync(), isTrue, reason: 'Migration 20261028_03 chưa được tạo.');
    });

    test('Migration phải định nghĩa đầy đủ 4 Triggers tự động hóa thông báo', () {
      final content = File(migrationPath).readAsStringSync();

      // Trigger 1: Hóa đơn mới
      expect(content.contains('fn_notify_on_new_invoice'), isTrue);
      expect(content.contains('trg_notify_on_new_invoice'), isTrue);
      expect(content.contains('new_invoice'), isTrue);

      // Trigger 2: Tiến độ phản ánh sự cố
      expect(content.contains('fn_notify_on_issue_status_change'), isTrue);
      expect(content.contains('trg_notify_on_issue_status_change'), isTrue);
      expect(content.contains('issue_update'), isTrue);

      // Trigger 3: Phê duyệt liên kết căn hộ
      expect(content.contains('fn_notify_on_link_request_status'), isTrue);
      expect(content.contains('trg_notify_on_link_request_status'), isTrue);
      expect(content.contains('link_request'), isTrue);

      // Trigger 4: Xác nhận thanh toán thành công
      expect(content.contains('fn_notify_on_invoice_paid'), isTrue);
      expect(content.contains('trg_notify_on_invoice_paid'), isTrue);
      expect(content.contains('payment_success'), isTrue);
    });
  });
}
