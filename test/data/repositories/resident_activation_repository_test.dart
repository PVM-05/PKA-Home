import 'package:flutter_test/flutter_test.dart';
import 'package:vivona/core/utils/guard_helper.dart';
import 'package:vivona/data/repositories/resident_activation_repository.dart';

void main() {
  group('ResidentActivationRepository Tests (Fail-Closed)', () {
    late ResidentActivationRepository repository;

    setUp(() {
      repository = ResidentActivationRepository();
    });

    test('generateActivationCodes throws AppException when Supabase is unavailable', () async {
      expect(
        () => repository.generateActivationCodes(buildingId: 'bld-01'),
        throwsA(isA<AppException>()),
      );
    });

    test('verifyActivationCode throws AppException when Supabase is unavailable', () async {
      expect(
        () => repository.verifyActivationCode(phone: '0901234567', activationCode: 'ACT-123456'),
        throwsA(isA<AppException>()),
      );
    });

    test('verifyActivationOtp throws AppException when Supabase is unavailable', () async {
      expect(
        () => repository.verifyActivationOtp(
          phone: '0901234567',
          activationCode: 'ACT-123456',
          otpCode: '123456',
        ),
        throwsA(isA<AppException>()),
      );
    });

    test('completeActivation throws AppException when Supabase is unavailable', () async {
      expect(
        () => repository.completeActivation(
          phone: '0901234567',
          activationCode: 'ACT-123456',
          otpCode: '123456',
          authUserId: 'user-01',
        ),
        throwsA(isA<AppException>()),
      );
    });

    test('regenerateActivationCode throws AppException when Supabase is unavailable', () async {
      expect(
        () => repository.regenerateActivationCode(userId: 'user-01'),
        throwsA(isA<AppException>()),
      );
    });

    test('revokeActivation throws AppException when Supabase is unavailable', () async {
      expect(
        () => repository.revokeActivation(activationId: 'act-01'),
        throwsA(isA<AppException>()),
      );
    });

    test('fetchBuildingActivationList throws AppException when Supabase is unavailable', () async {
      expect(
        () => repository.fetchBuildingActivationList('bld-01'),
        throwsA(isA<AppException>()),
      );
    });
  });
}
