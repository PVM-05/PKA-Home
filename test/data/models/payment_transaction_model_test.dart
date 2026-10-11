import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/payment_transaction_model.dart';

void main() {
  group('PaymentTransactionModel Tests', () {
    test('deserialize JSON giao dịch thành công chính xác', () {
      final json = {
        'id': 'tx-001',
        'invoice_id': 'inv-101',
        'user_id': 'user-1',
        'apartment_id': 'apt-01',
        'amount': 500000.0,
        'payment_method': 'DEMO',
        'status': 'SUCCESS',
        'transaction_code': 'PAY-20261005-00125',
        'failure_reason': null,
        'created_at': '2026-10-05T20:00:00Z',
      };

      final model = PaymentTransactionModel.fromJson(json);

      expect(model.id, 'tx-001');
      expect(model.invoiceId, 'inv-101');
      expect(model.userId, 'user-1');
      expect(model.apartmentId, 'apt-01');
      expect(model.amount, 500000.0);
      expect(model.paymentMethod, 'DEMO');
      expect(model.status, 'SUCCESS');
      expect(model.isSuccess, isTrue);
      expect(model.isFailed, isFalse);
      expect(model.isCancelled, isFalse);
      expect(model.transactionCode, 'PAY-20261005-00125');
      expect(model.statusDisplayName, 'Thành công');
      expect(model.failureReason, isNull);

      final outJson = model.toJson();
      expect(outJson['transaction_code'], 'PAY-20261005-00125');
      expect(outJson['status'], 'SUCCESS');
    });

    test('deserialize JSON giao dịch thất bại', () {
      final json = {
        'id': 'tx-002',
        'invoice_id': 'inv-101',
        'user_id': 'user-1',
        'apartment_id': 'apt-01',
        'amount': 500000.0,
        'payment_method': 'DEMO',
        'status': 'FAILED',
        'transaction_code': 'PAY-20261005-00126',
        'failure_reason': 'Giao dịch bị từ chối bởi cổng thanh toán mô phỏng (Demo).',
        'created_at': '2026-10-05T20:05:00Z',
      };

      final model = PaymentTransactionModel.fromJson(json);

      expect(model.isSuccess, isFalse);
      expect(model.isFailed, isTrue);
      expect(model.statusDisplayName, 'Thất bại');
      expect(model.failureReason, contains('từ chối'));
    });

    test('deserialize JSON giao dịch PENDING (chờ xác nhận)', () {
      final json = {
        'id': 'tx-003',
        'invoice_id': 'inv-101',
        'user_id': 'user-1',
        'apartment_id': 'apt-01',
        'amount': 500000.0,
        'payment_method': 'bank_transfer',
        'status': 'PENDING',
        'transaction_code': 'PENDING-INV-20261011-AB12',
        'failure_reason': null,
        'confirmed_by': 'staff-01',
        'confirmed_at': '2026-10-11T20:30:00Z',
        'created_at': '2026-10-11T20:00:00Z',
      };

      final model = PaymentTransactionModel.fromJson(json);

      expect(model.isPending, isTrue);
      expect(model.isSuccess, isFalse);
      expect(model.isFailed, isFalse);
      expect(model.statusDisplayName, 'Chờ xác nhận');
      expect(model.transactionCode, 'PENDING-INV-20261011-AB12');
      expect(model.confirmedBy, 'staff-01');
      expect(model.confirmedAt, isNotNull);
    });

    test('fallback an toàn khi thiếu status không mặc định là SUCCESS', () {
      final json = {
        'id': 'tx-004',
        'apartment_id': 'apt-01',
        'amount': 150000.0,
        'payment_method': 'CASH',
        'transaction_code': 'TX-FALLBACK',
      };

      final model = PaymentTransactionModel.fromJson(json);

      expect(model.status, 'PENDING');
      expect(model.isPending, isTrue);
      expect(model.isSuccess, isFalse);
      expect(model.statusDisplayName, 'Chờ xác nhận');
    });
  });
}

