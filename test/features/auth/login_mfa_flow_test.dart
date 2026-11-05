import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/core/security/mfa_service.dart';

void main() {
  group('Login MFA Flow Logic Tests', () {
    test('MfaService.isMfaEnrolled() phản ánh đúng trạng thái khi có statusChecker mock', () async {
      final activeMfaService = MfaService(
        statusChecker: () async => true,
        verifyHandler: (factorId, code) async => code == '123456',
      );

      final hasMfa = await activeMfaService.isMfaEnrolled();
      expect(hasMfa, isTrue);

      final isValid = await activeMfaService.verifyTotp(factorId: 'f-01', code: '123456');
      expect(isValid, isTrue);

      final isInvalid = await activeMfaService.verifyTotp(factorId: 'f-01', code: '000000');
      expect(isInvalid, isFalse);
    });

    test('MfaService ném ArgumentError nếu mã TOTP không đủ 6 chữ số', () async {
      final service = MfaService(
        verifyHandler: (factorId, code) async => true,
      );

      expect(
        () => service.verifyTotp(factorId: 'f-01', code: '123'),
        throwsArgumentError,
      );

      expect(
        () => service.verifyTotp(factorId: 'f-01', code: 'abcdef'),
        throwsArgumentError,
      );
    });

    test('Khi tài khoản không bật MFA, isMfaEnrolled trả về false', () async {
      final disabledMfaService = MfaService(
        statusChecker: () async => false,
      );

      final hasMfa = await disabledMfaService.isMfaEnrolled();
      expect(hasMfa, isFalse);
    });
  });
}

