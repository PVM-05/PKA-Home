import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/core/services/vnpay_service.dart';

void main() {
  group('VnpayService Unit Tests', () {
    const testTmnCode = 'TESTTMN01';
    const testHashSecret = 'RAZYKXM450NWHAUZGUP81RSTGJDDU09W';
    final testDateTime = DateTime(2026, 11, 14, 21, 30, 0);

    test('createPaymentUrl sinh URL VNPay chuẩn xác và có chữ ký HMAC-SHA512', () {
      final paymentUrl = VnpayService.createPaymentUrl(
        tmnCode: testTmnCode,
        hashSecret: testHashSecret,
        amount: 500000.0,
        txnRef: 'INV2611A0110',
        orderInfo: 'Thanh toan hoa don A0110',
        returnUrl: 'https://pka-home.web.app/payment-result',
        ipAddress: '127.0.0.1',
        createDate: testDateTime,
        isSandbox: true,
      );

      final uri = Uri.parse(paymentUrl);

      expect(uri.host, 'sandbox.vnpayment.vn');
      expect(uri.path, '/paymentv2/vpcpay.html');
      expect(uri.queryParameters['vnp_Version'], '2.1.0');
      expect(uri.queryParameters['vnp_Command'], 'pay');
      expect(uri.queryParameters['vnp_TmnCode'], testTmnCode);
      expect(uri.queryParameters['vnp_Amount'], '50000000'); // 500000 * 100
      expect(uri.queryParameters['vnp_CurrCode'], 'VND');
      expect(uri.queryParameters['vnp_TxnRef'], 'INV2611A0110');
      expect(uri.queryParameters['vnp_OrderInfo'], 'Thanh toan hoa don A0110');
      expect(uri.queryParameters['vnp_ReturnUrl'], 'https://pka-home.web.app/payment-result');
      expect(uri.queryParameters['vnp_IpAddr'], '127.0.0.1');
      expect(uri.queryParameters['vnp_CreateDate'], '20261114213000');
      expect(uri.queryParameters['vnp_Locale'], 'vn');
      expect(uri.queryParameters['vnp_OrderType'], 'other');

      final secureHash = uri.queryParameters['vnp_SecureHash'];
      expect(secureHash, isNotNull);
      expect(secureHash!.length, 128); // SHA-512 hex string length is 128 chars
    });

    test('verifyChecksum xác thực tính toàn vẹn của dữ liệu trả về từ VNPay', () {
      final paymentUrl = VnpayService.createPaymentUrl(
        tmnCode: testTmnCode,
        hashSecret: testHashSecret,
        amount: 250000.0,
        txnRef: 'INV2611B0205',
        orderInfo: 'Thanh toan phi dich vu',
        returnUrl: 'https://pka-home.web.app/payment-result',
        createDate: testDateTime,
      );

      final uri = Uri.parse(paymentUrl);
      final params = Map<String, String>.from(uri.queryParameters);

      // Thêm các tham số mô phỏng khi VNPay redirect về ReturnUrl
      params['vnp_ResponseCode'] = '00';
      params['vnp_TransactionNo'] = '14592031';
      params['vnp_TransactionStatus'] = '00';

      // Tính lại chữ ký hợp lệ có thêm tham số mới
      final validSign = VnpayService.generateChecksum(params, testHashSecret);
      params['vnp_SecureHash'] = validSign;

      // 1. Chữ ký chuẩn -> true
      expect(VnpayService.verifyChecksum(params, testHashSecret), isTrue);

      // 2. Kẻ gian cố tình sửa số tiền -> false
      final tamperedParams = Map<String, String>.from(params);
      tamperedParams['vnp_Amount'] = '1000';
      expect(VnpayService.verifyChecksum(tamperedParams, testHashSecret), isFalse);

      // 3. Sai mã bí mật hashSecret -> false
      expect(VnpayService.verifyChecksum(params, 'WRONG_SECRET_KEY'), isFalse);
    });

    test('getVnpayResponseDescription trả về thông báo lỗi tiếng Việt chuẩn xác theo mã VNPay', () {
      expect(VnpayService.getResponseDescription('00'), 'Giao dịch thành công');
      expect(VnpayService.getResponseDescription('07'), contains('nghi ngờ gian lận'));
      expect(VnpayService.getResponseDescription('09'), contains('chưa đăng ký dịch vụ InternetBanking'));
      expect(VnpayService.getResponseDescription('10'), contains('xác thực thông tin thẻ/tài khoản không đúng quá 3 lần'));
      expect(VnpayService.getResponseDescription('11'), contains('hết hạn chờ thanh toán'));
      expect(VnpayService.getResponseDescription('24'), contains('khách hàng hủy giao dịch'));
      expect(VnpayService.getResponseDescription('51'), contains('Tài khoản của quý khách không đủ số dư'));
      expect(VnpayService.getResponseDescription('99'), contains('Lỗi không xác định'));
    });
  });
}
