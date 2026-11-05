import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/core/security/visitor_pass_token_service.dart';

void main() {
  group('VisitorPassTokenService', () {
    const testSecret = 'test-secret-salt-pka-landmark-2026';
    final now = DateTime(2026, 11, 5, 14, 0, 0);
    final expiresAt = now.add(const Duration(hours: 12));

    test('sinh token hợp lệ và verify thành công', () {
      final token = VisitorPassTokenService.generateSignedQrPayload(
        passCode: 'VP-202611-00001',
        issuedAt: now,
        expiresAt: expiresAt,
        nonce: 'nonce-123456',
        secretKey: testSecret,
      );

      expect(token.startsWith('PKAPASS.v1.'), isTrue);

      final result = VisitorPassTokenService.verifyAndParseQrPayload(
        token,
        now: now.add(const Duration(hours: 2)),
        secretKey: testSecret,
      );

      expect(result.isValid, isTrue);
      expect(result.isExpired, isFalse);
      expect(result.passCode, 'VP-202611-00001');
      expect(result.nonce, 'nonce-123456');
      expect(result.isLegacyFormat, isFalse);
      expect(result.errorMessage, isNull);
    });

    test('từ chối token đã quá hạn sử dụng (expired)', () {
      final token = VisitorPassTokenService.generateSignedQrPayload(
        passCode: 'VP-202611-00002',
        issuedAt: now,
        expiresAt: expiresAt,
        secretKey: testSecret,
      );

      // Giả lập thời gian hiện tại sau expiresAt 1 phút
      final pastDueTime = expiresAt.add(const Duration(minutes: 1));
      final result = VisitorPassTokenService.verifyAndParseQrPayload(
        token,
        now: pastDueTime,
        secretKey: testSecret,
      );

      expect(result.isValid, isFalse);
      expect(result.isExpired, isTrue);
      expect(result.passCode, 'VP-202611-00002');
      expect(result.errorMessage, contains('hết hạn'));
    });

    test('từ chối token bị can thiệp nội dung hoặc sai chữ ký HMAC', () {
      final validToken = VisitorPassTokenService.generateSignedQrPayload(
        passCode: 'VP-202611-00003',
        issuedAt: now,
        expiresAt: expiresAt,
        secretKey: testSecret,
      );

      // Thay đổi pass_code từ 00003 thành 99999
      final tamperedToken = validToken.replaceAll('VP-202611-00003', 'VP-202611-99999');

      final result = VisitorPassTokenService.verifyAndParseQrPayload(
        tamperedToken,
        now: now,
        secretKey: testSecret,
      );

      expect(result.isValid, isFalse);
      expect(result.errorMessage?.toLowerCase(), contains('chữ ký'));
    });

    test('nhận diện và tương thích ngược với mã vé legacy PKAPASS:code:random', () {
      const legacyPayload = 'PKAPASS:VP-202611-00005:a1b2c3d4';

      final result = VisitorPassTokenService.verifyAndParseQrPayload(
        legacyPayload,
        now: now,
        secretKey: testSecret,
      );

      expect(result.isValid, isTrue);
      expect(result.isLegacyFormat, isTrue);
      expect(result.passCode, 'VP-202611-00005');
      expect(result.errorMessage, isNull);
    });

    test('từ chối chuỗi QR rác không hợp lệ', () {
      final result = VisitorPassTokenService.verifyAndParseQrPayload(
        'INVALID_QR_STRING_XYZ',
        now: now,
      );

      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('không đúng định dạng'));
    });
  });
}
