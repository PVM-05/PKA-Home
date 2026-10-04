import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pka_home/data/repositories/auth_repository.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockGoTrueClient extends Mock implements GoTrueClient {}
class MockUserResponse extends Mock implements UserResponse {}
class MockAuthResponse extends Mock implements AuthResponse {}

void main() {
  late AuthRepository repository;
  late MockSupabaseClient mockClient;
  late MockGoTrueClient mockAuth;

  setUpAll(() {
    registerFallbackValue(UserAttributes(password: 'dummy'));
    registerFallbackValue(OtpType.recovery);
  });

  setUp(() {
    mockClient = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    when(() => mockClient.auth).thenReturn(mockAuth);
    repository = AuthRepository(mockClient);
  });

  group('AuthRepository updatePassword', () {
    test('updatePassword calls updateUser with new password', () async {
      final newPassword = 'newPassword123!';
      when(() => mockAuth.updateUser(any())).thenAnswer((_) async => MockUserResponse());

      await repository.updatePassword(newPassword);

      final captured = verify(() => mockAuth.updateUser(captureAny())).captured;
      final attrs = captured.first as UserAttributes;
      expect(attrs.password, newPassword);
    });

    test('updatePassword throws if updateUser fails', () async {
      when(() => mockAuth.updateUser(any())).thenThrow(const AuthException('Update failed'));

      expect(
        () => repository.updatePassword('newPassword123!'),
        throwsA(isA<AuthException>()),
      );
    });
  });

  group('AuthRepository OTP Password Reset', () {
    test('sendPasswordResetOtp calls resetPasswordForEmail', () async {
      when(() => mockAuth.resetPasswordForEmail('user@test.com'))
          .thenAnswer((_) async {});

      await repository.sendPasswordResetOtp('user@test.com');

      verify(() => mockAuth.resetPasswordForEmail('user@test.com')).called(1);
    });

    test('sendPasswordResetOtp handles 429 rate limit with friendly message', () async {
      when(() => mockAuth.resetPasswordForEmail('user@test.com'))
          .thenThrow(const AuthException('Too many requests', statusCode: '429'));

      expect(
        () => repository.sendPasswordResetOtp('user@test.com'),
        throwsA(predicate((e) => e.toString().contains('quá nhiều lần'))),
      );
    });

    test('verifyPasswordResetOtp calls verifyOTP with OtpType.recovery', () async {
      when(() => mockAuth.verifyOTP(
            email: 'user@test.com',
            token: '123456',
            type: OtpType.recovery,
          )).thenAnswer((_) async => MockAuthResponse());

      final res = await repository.verifyPasswordResetOtp(
        email: 'user@test.com',
        token: '123456',
      );

      expect(res, isNotNull);
      verify(() => mockAuth.verifyOTP(
            email: 'user@test.com',
            token: '123456',
            type: OtpType.recovery,
          )).called(1);
    });

    test('verifyPasswordResetOtp throws friendly message when expired or invalid', () async {
      when(() => mockAuth.verifyOTP(
            email: 'user@test.com',
            token: '000000',
            type: OtpType.recovery,
          )).thenThrow(const AuthException('Token has expired', code: 'otp_expired'));

      expect(
        () => repository.verifyPasswordResetOtp(
          email: 'user@test.com',
          token: '000000',
        ),
        throwsA(predicate((e) => e.toString().contains('hết hạn'))),
      );
    });
  });
}
