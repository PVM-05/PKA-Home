import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/audit_log_model.dart';

void main() {
  group('AuditLogModel Unit Tests', () {
    test('Khởi tạo và parse fromJson đầy đủ thông tin', () {
      final json = {
        'id': 'log-1',
        'building_id': 'b-1',
        'actor_id': 'user-1',
        'actor': {'full_name': 'Nguyen Van Admin'},
        'action': 'CONFIRM_PAYMENT',
        'entity_name': 'invoices',
        'entity_id': 'inv-123',
        'old_values': {'status': 'unpaid', 'total_amount': 2500000},
        'new_values': {'status': 'paid', 'total_amount': 2500000, 'payment_method': 'vietqr'},
        'details': {},
        'ip_address': '192.168.1.1',
        'created_at': '2026-10-29T10:00:00Z',
      };

      final model = AuditLogModel.fromJson(json);

      expect(model.id, 'log-1');
      expect(model.buildingId, 'b-1');
      expect(model.actorId, 'user-1');
      expect(model.actorName, 'Nguyen Van Admin');
      expect(model.action, 'CONFIRM_PAYMENT');
      expect(model.entityName, 'invoices');
      expect(model.entityId, 'inv-123');
      expect(model.oldValues?['status'], 'unpaid');
      expect(model.newValues?['status'], 'paid');
      expect(model.actionDisplayName, 'Xác nhận thu tiền hóa đơn');
      expect(model.category, 'invoice');
      expect(model.isFinancialAction, isTrue);
    });

    test('toJson xuất dữ liệu chuẩn xác', () {
      final model = AuditLogModel(
        id: 'log-2',
        actorId: 'user-2',
        action: 'UPDATE_VEHICLE_STATUS',
        entityName: 'vehicles',
        entityId: 'veh-99',
        oldValues: {'status': 'pending'},
        newValues: {'status': 'approved'},
        createdAt: DateTime.parse('2026-10-29T12:00:00Z'),
      );

      final map = model.toJson();
      expect(map['id'], 'log-2');
      expect(map['action'], 'UPDATE_VEHICLE_STATUS');
      expect(map['entity_name'], 'vehicles');
      expect(map['entity_id'], 'veh-99');
    });
  });
}
