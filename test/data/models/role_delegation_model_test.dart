import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/role_delegation_model.dart';

void main() {
  group('RoleDelegationModel Tests', () {
    test('fromJson and toJson parse data correctly', () {
      final now = DateTime.now();
      final startsAt = now.subtract(const Duration(hours: 1));
      final endsAt = now.add(const Duration(days: 2));

      final json = {
        'id': 'del-123',
        'delegator_id': 'user-admin',
        'delegator': {'full_name': 'Admin Quan Tri'},
        'delegate_id': 'user-tech',
        'delegate': {'full_name': 'Ky Thuat Vien A'},
        'delegated_role': 'accountant',
        'starts_at': startsAt.toUtc().toIso8601String(),
        'ends_at': endsAt.toUtc().toIso8601String(),
        'note': 'Uy quyen xu ly hoa don dot 1',
        'created_at': startsAt.toUtc().toIso8601String(),
      };

      final model = RoleDelegationModel.fromJson(json);

      expect(model.id, equals('del-123'));
      expect(model.delegatorId, equals('user-admin'));
      expect(model.delegatorName, equals('Admin Quan Tri'));
      expect(model.delegateId, equals('user-tech'));
      expect(model.delegateName, equals('Ky Thuat Vien A'));
      expect(model.delegatedRole, equals('accountant'));
      expect(model.roleDisplayName, equals('Kế toán'));
      expect(model.note, equals('Uy quyen xu ly hoa don dot 1'));

      expect(model.isActive, isTrue);
      expect(model.isExpired, isFalse);
      expect(model.isUpcoming, isFalse);

      final toJson = model.toJson();
      expect(toJson['id'], equals('del-123'));
      expect(toJson['delegator_id'], equals('user-admin'));
      expect(toJson['delegate_id'], equals('user-tech'));
      expect(toJson['delegated_role'], equals('accountant'));
    });

    test('isActiveAt correctly evaluates active status for past, present, and future', () {
      final startsAt = DateTime(2026, 9, 1, 8, 0);
      final endsAt = DateTime(2026, 9, 5, 18, 0);

      final model = RoleDelegationModel(
        id: 'del-1',
        delegatorId: 'admin-id',
        delegateId: 'staff-id',
        delegatedRole: 'technician',
        startsAt: startsAt,
        endsAt: endsAt,
        createdAt: startsAt,
      );

      expect(model.roleDisplayName, equals('Kỹ thuật viên'));
      // Trước ngày bắt đầu
      expect(model.isActiveAt(DateTime(2026, 9, 1, 7, 59)), isFalse);
      // Trong khoảng thời gian hiệu lực
      expect(model.isActiveAt(DateTime(2026, 9, 3, 12, 0)), isTrue);
      // Sau ngày kết thúc
      expect(model.isActiveAt(DateTime(2026, 9, 5, 18, 1)), isFalse);
    });
  });
}
