import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/notification_model.dart';

void main() {
  group('NotificationModel Phase E1 Tests', () {
    test('Khởi tạo NotificationModel có buildingId và các helper getters', () {
      final notif = NotificationModel(
        id: 'notif-1',
        buildingId: 'bld-1',
        userId: 'usr-1',
        apartmentId: 'apt-1',
        title: 'Nhắc nợ',
        body: 'Hóa đơn quá hạn',
        type: 'invoice_overdue',
        createdAt: DateTime(2026, 10, 28),
      );

      expect(notif.buildingId, equals('bld-1'));
      expect(notif.isInvoiceReminder, isTrue);
      expect(notif.isAnnouncement, isFalse);
      expect(notif.typeDisplayName, equals('Hóa đơn'));
    });

    test('NotificationModel.fromJson và toJson tương thích hoàn toàn', () {
      final json = {
        'id': 'notif-2',
        'building_id': 'bld-99',
        'user_id': 'usr-2',
        'apartment_id': 'apt-2',
        'title': 'Thông báo bảo trì',
        'body': 'Bảo trì thang máy',
        'type': 'equipment_maintenance',
        'payload': {'code': 'TM01'},
        'is_read': true,
        'created_at': '2026-10-28T10:00:00.000Z',
      };

      final model = NotificationModel.fromJson(json);
      expect(model.buildingId, equals('bld-99'));
      expect(model.isRead, isTrue);
      expect(model.typeDisplayName, equals('Bảo trì'));

      final outJson = model.toJson();
      expect(outJson['building_id'], equals('bld-99'));
    });
  });
}
