import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/services/payment_service.dart';

void main() {
  group('PaymentResult Model Contract Tests', () {
    test('PaymentResult.fromJson parses canonical server response properly', () {
      final json = {
        'success': true,
        'transaction_id': '11111111-2222-3333-4444-555555555555',
        'receipt_number': 'INV-20261027-ABC123',
        'message': 'Thanh toán hóa đơn thành công',
      };

      final result = PaymentResult.fromJson(json);

      expect(result.success, isTrue);
      expect(result.status, 'SUCCESS');
      expect(result.transactionId, '11111111-2222-3333-4444-555555555555');
      expect(result.transactionCode, 'INV-20261027-ABC123');
      expect(result.errorMessage, 'Thanh toán hóa đơn thành công');
      expect(result.isPending, isFalse);
    });

    test('PaymentResult.fromJson handles failure properly', () {
      final json = {
        'success': false,
        'transaction_id': '11111111-2222-3333-4444-555555555555',
        'message': 'Số dư không đủ',
      };

      final result = PaymentResult.fromJson(json);

      expect(result.success, isFalse);
      expect(result.status, 'FAILED');
      expect(result.errorMessage, 'Số dư không đủ');
    });

    test('PaymentResult.fromJson handles pending state properly', () {
      final json = {
        'success': true,
        'is_pending': true,
        'status': 'PENDING',
        'transaction_id': 'tx-123',
        'receipt_number': 'REC-123',
        'message': 'Chờ BQL xác nhận',
      };

      final result = PaymentResult.fromJson(json);

      expect(result.success, isTrue);
      expect(result.isPending, isTrue);
      expect(result.status, 'PENDING');
    });
  });
}
