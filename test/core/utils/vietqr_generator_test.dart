import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/core/utils/vietqr_generator.dart';

void main() {
  group('VietQrGenerator Tests', () {
    test('generates valid EMVCo Napas 247 QR string with proper TLV tags and CRC', () {
      final qrString = VietQrGenerator.generate(
        bankBin: '970418', // BIDV
        bankAccount: '1234567890',
        amount: 1500000,
        memo: 'PKA A0110 T10',
      );

      // Verify basic EMVCo format
      expect(qrString.startsWith('000201'), isTrue, reason: 'Payload format indicator');
      expect(qrString, contains('010212'), reason: 'Point of initiation method dynamic');
      expect(qrString, contains('A000000727'), reason: 'Napas AID');
      expect(qrString, contains('970418'), reason: 'Bank BIN');
      expect(qrString, contains('1234567890'), reason: 'Account number');
      expect(qrString, contains('5303704'), reason: 'Currency VND');
      expect(qrString, contains('54071500000'), reason: 'Amount 1,500,000');
      expect(qrString, contains('5802VN'), reason: 'Country code VN');
      expect(qrString, contains('PKA A0110 T10'), reason: 'Memo content');
      expect(qrString, contains('6304'), reason: 'CRC tag');

      // CRC must be 4 hex digits at the end
      final crcStr = qrString.substring(qrString.length - 4);
      expect(RegExp(r'^[0-9A-F]{4}$').hasMatch(crcStr), isTrue);
    });

    test('generates quick link URL fallback correctly', () {
      final url = VietQrGenerator.generateQuickLinkUrl(
        bankBin: '970418',
        bankAccount: '1234567890',
        amount: 250000,
        memo: 'PKA A0110',
        accountName: 'BQL PKA LANDMARK',
      );

      expect(url, contains('img.vietqr.io/image/970418-1234567890-compact2.png'));
      expect(url, contains('amount=250000'));
      expect(url, contains('addInfo=PKA%20A0110'));
    });
  });
}
