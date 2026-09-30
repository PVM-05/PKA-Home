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

    test('generateBqlInvoiceQrUrl uses default BQL account correctly with clean memo', () {
      final url = VietQrHelper.generateBqlInvoiceQrUrl(
        apartmentCode: 'A0110',
        period: '09/2026',
        amount: 1250000.0,
      );

      expect(url, startsWith('https://img.vietqr.io/image/MB-0987654321-compact2.png'));
      expect(url, contains('amount=1250000'));
      // Nội dung không chứa ký tự gạch chéo %2F, thay bằng T09-2026
      expect(url, contains('addInfo=A0110%20T09-2026'));
    });

    test('buildTransferMemo creates concise and standard memo format without slashes', () {
      final memo = VietQrHelper.buildTransferMemo('A0110', '10/2026');
      expect(memo, 'A0110 T10-2026');

      final memoAlreadyT = VietQrHelper.buildTransferMemo('B0202', 'T11-2026');
      expect(memoAlreadyT, 'B0202 T11-2026');
    });
  });
}
