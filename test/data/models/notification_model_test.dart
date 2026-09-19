import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/notification_model.dart';

void main() {
  group('NotificationModel Tests', () {
    test('fromJson and toJson map fields accurately', () {
      final json = {
        'id': 'notif-123',
        'user_id': 'user-456',
        'apartment_id': 'apt-789',
        'title': 'Nhắc hạn thanh toán hóa đơn kỳ 09/2026',
        'body': 'Căn hộ A0110: Hóa đơn kỳ 09/2026 sẽ đến hạn thanh toán trong 3 ngày tới.',
        'type': 'invoice_due_reminder',
        'payload': {'invoice_id': 'inv-001', 'total_amount': 1500000},
        'is_read': false,
        'created_at': '2026-09-19T10:00:00.000Z',
      };

      final model = NotificationModel.fromJson(json);

      expect(model.id, equals('notif-123'));
      expect(model.userId, equals('user-456'));
      expect(model.apartmentId, equals('apt-789'));
      expect(model.title, equals('Nhắc hạn thanh toán hóa đơn kỳ 09/2026'));
      expect(model.type, equals('invoice_due_reminder'));
      expect(model.isRead, isFalse);
      expect(model.payload['invoice_id'], equals('inv-001'));

      final mappedJson = model.toJson();
      expect(mappedJson['id'], equals('notif-123'));
      expect(mappedJson['is_read'], isFalse);
    });

    test('copyWith produces modified instance with new values', () {
      final model = NotificationModel(
        id: 'notif-1',
        userId: 'user-1',
        title: 'Tiêu đề cũ',
        body: 'Nội dung cũ',
        createdAt: DateTime.now(),
        isRead: false,
      );

      final updated = model.copyWith(isRead: true, title: 'Tiêu đề mới');
      expect(updated.id, equals('notif-1'));
      expect(updated.isRead, isTrue);
      expect(updated.title, equals('Tiêu đề mới'));
      expect(model.isRead, isFalse); // Immutable original
    });
  });
}
