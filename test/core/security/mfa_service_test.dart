import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/core/security/mfa_service.dart';

void main() {
  group('MfaService Tests', () {
    late MfaService service;

    setUp(() {
      service = MfaService(
        statusChecker: () async => true,
        enrollHandler: () async => const MfaEnrollData(
          factorId: 'factor-123',
          secret: 'JBSWY3DPEHPK3PXP',
          qrCodeUri: 'otpauth://totp/PKA-Home:admin@pka.vn?secret=JBSWY3DPEHPK3PXP',
        ),
        verifyHandler: (factorId, code) async => code == '123456',
        unenrollHandler: (factorId) async {},
      );
    });

    test('isMfaEnrolled trả về trạng thái MFA của người dùng', () async {
      final enrolled = await service.isMfaEnrolled();
      expect(enrolled, isTrue);
    });

    test('enrollTotp trả về factorId và mã bí mật secret key', () async {
      final enrollData = await service.enrollTotp();
      expect(enrollData.factorId, 'factor-123');
      expect(enrollData.secret, 'JBSWY3DPEHPK3PXP');
      expect(enrollData.qrCodeUri, contains('otpauth://totp/'));
    });

    test('verifyTotp trả về true khi mã khớp và false khi mã sai', () async {
      final valid = await service.verifyTotp(factorId: 'factor-123', code: '123456');
      expect(valid, isTrue);

      final invalid = await service.verifyTotp(factorId: 'factor-123', code: '000000');
      expect(invalid, isFalse);
    });

    test('verifyTotp ném lỗi nếu mã không đủ 6 chữ số', () async {
      expect(
        () => service.verifyTotp(factorId: 'factor-123', code: '123'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
