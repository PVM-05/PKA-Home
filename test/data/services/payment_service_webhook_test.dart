import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/services/payment_service.dart';

class MockWebhookPaymentService extends PaymentService {
  Map<String, dynamic>? lastPayload;

  @override
  Future<Map<String, dynamic>> processBankPaymentWebhook(Map<String, dynamic> payload) async {
    lastPayload = payload;
    final gatewayTxId = payload['gateway_transaction_id'] ?? payload['transaction_id'];
    if (gatewayTxId == null || gatewayTxId == '') {
      throw Exception('Webhook payload thiếu thông tin mã giao dịch ngân hàng');
    }
    return {
      'success': true,
      'status': 'SUCCESS',
      'invoice_id': 'inv-123',
      'receipt_number': 'REC-20261029-AABBCC',
      'message': 'Gạch nợ hóa đơn thành công.',
    };
  }
}

void main() {
  group('PaymentService Webhook Tests', () {
    test('processBankPaymentWebhook forwards payload and returns receipt response', () async {
      final service = MockWebhookPaymentService();
      final payload = {
        'gateway_transaction_id': 'TXN_MB_987654321',
        'amount': 1500000,
        'content': 'Thanh toan tien nha INV2610A0110',
      };

      final response = await service.processBankPaymentWebhook(payload);

      expect(service.lastPayload, equals(payload));
      expect(response['success'], isTrue);
      expect(response['status'], equals('SUCCESS'));
      expect(response['receipt_number'], equals('REC-20261029-AABBCC'));
    });
  });
}
