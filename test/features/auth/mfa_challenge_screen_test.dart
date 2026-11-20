import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivona/core/security/mfa_service.dart';
import 'package:vivona/core/theme/app_theme.dart';
import 'package:vivona/data/models/user_model.dart';
import 'package:vivona/data/providers/auth_provider.dart';
import 'package:vivona/features/auth/screens/mfa_challenge_screen.dart';

class _FakeAuthNotifier extends StateNotifier<AsyncValue<UserModel?>> implements AuthNotifier {
  _FakeAuthNotifier(UserModel user) : super(AsyncValue.data(user));

  @override
  void clearMfaChallenge() {}

  @override
  Future<void> logout() async {
    state = const AsyncValue.data(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('MfaChallengeScreen Security Gate Tests', () {
    testWidgets('renders TOTP challenge form with title, input, and action buttons', (tester) async {
      final mockMfaService = MfaService(
        statusChecker: () async => true,
        verifyHandler: (factorId, code) async => code == '123456',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(
              (ref) => _FakeAuthNotifier(
                UserModel(id: 'admin-01', fullName: 'Ban Quản Trị', role: 'admin'),
              ),
            ),
            mfaServiceProvider.overrideWithValue(mockMfaService),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const MfaChallengeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Tiêu đề và biểu tượng an ninh
      expect(find.text('Xác thực hai bước'), findsOneWidget);
      expect(find.byIcon(Icons.security_rounded), findsOneWidget);

      // 2. Ô nhập mã OTP 6 số
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('000000'), findsOneWidget);

      // 3. Các nút xác nhận và đăng xuất
      expect(find.widgetWithText(ElevatedButton, 'Xác nhận đăng nhập'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Đăng xuất / Đổi tài khoản'), findsOneWidget);
    });

    testWidgets('validates 6-digit length before calling verify', (tester) async {
      final mockMfaService = MfaService(
        statusChecker: () async => true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(
              (ref) => _FakeAuthNotifier(
                UserModel(id: 'admin-01', fullName: 'Ban Quản Trị', role: 'admin'),
              ),
            ),
            mfaServiceProvider.overrideWithValue(mockMfaService),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const MfaChallengeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Bấm xác nhận khi chưa nhập đủ 6 số
      await tester.tap(find.widgetWithText(ElevatedButton, 'Xác nhận đăng nhập'));
      await tester.pumpAndSettle();

      expect(find.text('Vui lòng nhập đầy đủ 6 chữ số mã xác thực.'), findsOneWidget);
    });
  });
}

