import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pka_home/data/repositories/auth_repository.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockGoTrueClient extends Mock implements GoTrueClient {}
class MockUserResponse extends Mock implements UserResponse {}

void main() {
  late AuthRepository repository;
  late MockSupabaseClient mockClient;
  late MockGoTrueClient mockAuth;

  setUpAll(() {
    registerFallbackValue(UserAttributes(password: 'dummy'));
  });

  setUp(() {
    mockClient = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    when(() => mockClient.auth).thenReturn(mockAuth);
    repository = AuthRepository(mockClient);
  });

  group('AuthRepository updatePassword', () {
    test('updatePassword calls updateUser with new password', () async {
      // Arrange
      final newPassword = 'newPassword123!';
      when(() => mockAuth.updateUser(any())).thenAnswer((_) async => MockUserResponse());

      // Act
      await repository.updatePassword(newPassword);

      // Assert
      final captured = verify(() => mockAuth.updateUser(captureAny())).captured;
      final attrs = captured.first as UserAttributes;
      expect(attrs.password, newPassword);
    });

    test('updatePassword throws if updateUser fails', () async {
      // Arrange
      when(() => mockAuth.updateUser(any())).thenThrow(AuthException('Update failed'));

      // Act & Assert
      expect(
        () => repository.updatePassword('newPassword123!'),
        throwsA(isA<AuthException>()),
      );
    });
  });
}
