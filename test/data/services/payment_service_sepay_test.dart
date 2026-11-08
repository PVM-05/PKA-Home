import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/sepay_webhook_payload_model.dart';
import 'package:pka_home/data/services/payment_service.dart';

void main() {
  group('PaymentService SePay Tests', () {
    late PaymentService paymentService;

    setUp(() {
      paymentService = const PaymentService(isMockMode: true);
    });

    test('processSepayWebhook xử lý thành công giao dịch SePay khớp mã hóa đơn', () async {
      final payload = SepayWebhookPayloadModel(
        id: '92704',
        gateway: 'MBBank',
        accountNumber: '0388888888',
        content: 'INV2611A0110 thanh toan phi thang 11',
        transferType: 'in',
        transferAmount: 1500000.0,
      );

      final res = await paymentService.processSepayWebhook(payload, apiKey: 'TEST_KEY');

      expect(res['success'], isTrue);
      expect(res['status'], 'SUCCESS');
      expect(res['receipt_number'], startsWith('REC-'));
    });

    test('processSepayWebhook bỏ qua an toàn giao dịch tiền ra out', () async {
      final payload = SepayWebhookPayloadModel(
        id: '92705',
        gateway: 'Vietcombank',
        content: 'Rut tien mat',
        transferType: 'out',
        transferAmount: 2000000.0,
      );

      final res = await paymentService.processSepayWebhook(payload);

      expect(res['success'], isTrue);
      expect(res['status'], 'IGNORED_OUTGOING');
    });

    test('processSepayWebhook chuyển sang UNMATCHED khi không tìm thấy mã hóa đơn', () async {
      final payload = SepayWebhookPayloadModel(
        id: '92706',
        gateway: 'Techcombank',
        content: 'Chuyen tien khong ghi ro noi dung',
        transferType: 'in',
        transferAmount: 500000.0,
      );

      final res = await paymentService.processSepayWebhook(payload);

      expect(res['success'], isFalse);
      expect(res['status'], 'UNMATCHED');
    });
  });
}
