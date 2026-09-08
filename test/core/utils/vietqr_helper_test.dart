import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/core/utils/vietqr_helper.dart';

void main() {
  group('VietQrHelper Tests', () {
    test('generateQrUrl creates a valid VietQR QuickLink URL with custom params', () {
      final url = VietQrHelper.generateQrUrl(
        bankId: 'MB',
        accountNo: '0987654321',
        amount: 500000,
        memo: 'PKA-101 Thang 09-2026',
        accountName: 'BQL PKA HOME',
      );

      expect(url, startsWith('https://img.vietqr.io/image/MB-0987654321-compact2.png'));
      expect(url, contains('amount=500000'));
      expect(url, contains('accountName=BQL%20PKA%20HOME'));
      expect(url, contains('addInfo=PKA-101%20Thang%2009-2026'));
    });

    test('generateBqlInvoiceQrUrl uses default BQL account correctly', () {
      final url = VietQrHelper.generateBqlInvoiceQrUrl(
        apartmentCode: 'A0110',
        period: '09/2026',
        amount: 1250000.0,
      );

      expect(url, startsWith('https://img.vietqr.io/image/MB-0987654321-compact2.png'));
      expect(url, contains('amount=1250000'));
      expect(url, contains('addInfo=A0110%2009%2F2026'));
    });

    test('buildTransferMemo creates concise and standard memo format', () {
      final memo = VietQrHelper.buildTransferMemo('B502', '10/2026');
      expect(memo, 'B502 10/2026');
    });
  });
}
