import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/services/payment_service.dart';

void main() {
  group('PaymentService VNPay Server-Side Flow Tests', () {
    test('createVnpayPaymentUrl trong chế độ mock trả về URL thanh toán VNPay hợp lệ', () async {
      const paymentService = PaymentService(isMockMode: true);

      final url = await paymentService.createVnpayPaymentUrl(
        invoiceId: 'inv-test-001',
      );

      expect(url, isNotNull);
      expect(url!.startsWith('https://sandbox.vnpayment.vn/paymentv2/vpcpay.html'), isTrue);
      final uri = Uri.parse(url);
      expect(uri.queryParameters['vnp_OrderType'], 'billpayment');
      expect(uri.queryParameters['vnp_Command'], 'pay');
      expect(uri.queryParameters['vnp_Version'], '2.1.0');
      expect(uri.queryParameters.containsKey('vnp_SecureHash'), isTrue);
    });

    test('createVnpayPaymentUrl hỗ trợ tham số invoiceId mà không đòi hỏi client hash secret', () async {
      const paymentService = PaymentService(isMockMode: true);

      final url = await paymentService.createVnpayPaymentUrl(
        invoiceId: 'inv-test-002',
        bankCode: 'NCB',
      );

      expect(url, isNotNull);
      expect(url, contains('sandbox.vnpayment.vn'));
    });

    test('createVnpayPaymentUrl trong chế độ thật (isMockMode: false) xử lý lỗi mạng an toàn và trả về null (Fail-Closed)', () async {
      // Khi không có phiên Supabase hợp lệ hoặc gặp sự cố mạng, hàm không được crash ứng dụng mà phải trả về null
      const paymentService = PaymentService(isMockMode: false);

      final url = await paymentService.createVnpayPaymentUrl(
        invoiceId: 'inv-network-error-001',
      );

      expect(url, isNull);
    });

    test('createVnpayPaymentUrl với invoice_id rỗng hoặc không tồn tại trả về null trong chế độ thật', () async {
      const paymentService = PaymentService(isMockMode: false);

      final url = await paymentService.createVnpayPaymentUrl(
        invoiceId: '',
      );

      expect(url, isNull);
    });
  });
}
