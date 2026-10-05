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
  });
}
