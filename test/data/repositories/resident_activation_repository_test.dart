import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/repositories/resident_activation_repository.dart';

void main() {
  group('ResidentActivationRepository Tests', () {
    test('verifyActivationCode mockFallback handles matching codes', () async {
      final repo = ResidentActivationRepository();

      final successRes = await repo.verifyActivationCode(
        phone: '0901234567',
        activationCode: 'ACT-123456',
      );
      expect(successRes['success'], isTrue);
      expect(successRes['full_name'], 'Nguyễn Văn An');
      expect(successRes['apartment_code'], 'A0110');
      expect(successRes['otp_hint'], '123456');

      final failRes = await repo.verifyActivationCode(
        phone: '0901234567',
        activationCode: '12',
      );
      expect(failRes['success'], isFalse);
    });

    test('verifyActivationOtp validates mock OTP code', () async {
      final repo = ResidentActivationRepository();

      final successOtp = await repo.verifyActivationOtp(
        phone: '0901234567',
        activationCode: 'ACT-123456',
        otpCode: '123456',
      );
      expect(successOtp['success'], isTrue);

      final failOtp = await repo.verifyActivationOtp(
        phone: '0901234567',
        activationCode: 'ACT-123456',
        otpCode: '999999',
      );
      expect(failOtp['success'], isFalse);
    });

    test('completeActivation succeeds with valid payload', () async {
      final repo = ResidentActivationRepository();

      final res = await repo.completeActivation(
        phone: '0901234567',
        activationCode: 'ACT-123456',
        otpCode: '123456',
        authUserId: 'user-auth-uuid',
      );

      expect(res['success'], isTrue);
      expect(res['user_id'], 'user-auth-uuid');
    });

    test('generateActivationCodes returns positive count in mock', () async {
      final repo = ResidentActivationRepository();
      final res = await repo.generateActivationCodes(buildingId: 'b-1');

      expect(res['success'], isTrue);
      expect(res['generated_count'], greaterThan(0));
    });

    test('fetchBuildingActivationList returns list of activation records', () async {
      final repo = ResidentActivationRepository();
      final list = await repo.fetchBuildingActivationList('b-1');

      expect(list, isNotEmpty);
      expect(list.any((a) => a.fullName == 'Nguyễn Văn An'), isTrue);
    });
  });
}

