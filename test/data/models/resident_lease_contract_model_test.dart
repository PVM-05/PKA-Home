import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/resident_lease_contract_model.dart';

void main() {
  group('ResidentLeaseContractModel Tests', () {
    final now = DateTime(2026, 10, 30);
    final json = {
      'id': 'contract-01',
      'user_id': 'user-01',
      'apartment_id': 'apt-01',
      'full_name': 'Nguyen Van A',
      'phone': '0901234567',
      'relation_role': 'tenant',
      'status': 'active',
      'start_date': '2026-01-01',
      'end_date': '2027-01-01',
      'deposit_amount': 10000000.0,
      'contract_number': 'HD-2026/A0110-01',
      'note': 'Hợp đồng thuê 1 năm có cọc',
      'created_at': now.toIso8601String(),
    };

    test('fromJson parses data correctly', () {
      final model = ResidentLeaseContractModel.fromJson(json);

      expect(model.id, 'contract-01');
      expect(model.userId, 'user-01');
      expect(model.apartmentId, 'apt-01');
      expect(model.fullName, 'Nguyen Van A');
      expect(model.phone, '0901234567');
      expect(model.relationRole, 'tenant');
      expect(model.status, 'active');
      expect(model.depositAmount, 10000000.0);
      expect(model.contractNumber, 'HD-2026/A0110-01');
      expect(model.note, 'Hợp đồng thuê 1 năm có cọc');
      expect(model.isActive, isTrue);
    });

    test('Display helpers format correctly in Vietnamese', () {
      final model = ResidentLeaseContractModel.fromJson(json);

      expect(model.displayRole, 'Người thuê');
      expect(model.displayStatus, 'Đang lưu trú');
      expect(model.formattedDeposit, contains('10.000.000'));
      expect(model.formattedStartDate, '01/01/2026');
      expect(model.formattedEndDate, '01/01/2027');
    });

    test('Display helpers handle null end date and terminated status', () {
      final jsonTerminated = Map<String, dynamic>.from(json)
        ..['status'] = 'terminated'
        ..['end_date'] = null
        ..['relation_role'] = 'owner';

      final model = ResidentLeaseContractModel.fromJson(jsonTerminated);
      expect(model.displayRole, 'Chủ hộ');
      expect(model.displayStatus, 'Đã kết thúc');
      expect(model.formattedEndDate, 'Không xác định');
      expect(model.isActive, isFalse);
    });
  });
}
