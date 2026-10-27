import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/maintenance_fund_transaction_model.dart';

void main() {
  group('MaintenanceFundTransactionModel Tests', () {
    test('fromJson and toJson parse accurately', () {
      final json = {
        'id': 'tx-001',
        'building_id': 'bld-001',
        'fund_id': 'fund-001',
        'voucher_number': 'PT-202610-00001',
        'transaction_type': 'INCOME',
        'category': 'MAINTENANCE_FEE',
        'amount': 5000000.0,
        'balance_after': 2505000000.0,
        'reference_type': 'INVOICE',
        'reference_id': 'inv-123',
        'recipient_or_payer': 'Nguyễn Văn A - Căn A0110',
        'description': 'Thu kinh phí bảo trì đợt 1',
        'created_by': 'usr-admin',
        'created_at': '2026-10-27T10:00:00Z',
      };

      final model = MaintenanceFundTransactionModel.fromJson(json);

      expect(model.id, 'tx-001');
      expect(model.buildingId, 'bld-001');
      expect(model.fundId, 'fund-001');
      expect(model.voucherNumber, 'PT-202610-00001');
      expect(model.isIncome, isTrue);
      expect(model.isExpense, isFalse);
      expect(model.typeDisplayName, 'Thu quỹ');
      expect(model.amount, 5000000.0);
      expect(model.balanceAfter, 2505000000.0);
      expect(model.categoryDisplayName, 'Thu phí bảo trì');
      expect(model.recipientOrPayer, 'Nguyễn Văn A - Căn A0110');
      expect(model.description, 'Thu kinh phí bảo trì đợt 1');

      final serialized = model.toJson();
      expect(serialized['voucher_number'], 'PT-202610-00001');
      expect(serialized['transaction_type'], 'INCOME');
    });

    test('expense model attributes check', () {
      final json = {
        'id': 'tx-002',
        'building_id': 'bld-001',
        'fund_id': 'fund-001',
        'voucher_number': 'PC-202610-00001',
        'transaction_type': 'EXPENSE',
        'category': 'EQUIPMENT_REPAIR',
        'amount': 12000000.0,
        'balance_after': 2493000000.0,
        'reference_type': 'EQUIPMENT_TASK',
        'reference_id': 'eq-task-001',
        'recipient_or_payer': 'Công ty Thang máy Otis',
        'description': 'Bảo dưỡng thay thế cáp thang máy Tòa A',
        'created_at': '2026-10-27T11:00:00Z',
      };

      final model = MaintenanceFundTransactionModel.fromJson(json);
      expect(model.isExpense, isTrue);
      expect(model.isIncome, isFalse);
      expect(model.typeDisplayName, 'Chi quỹ');
      expect(model.categoryDisplayName, 'Sửa chữa thiết bị');
    });
  });
}
