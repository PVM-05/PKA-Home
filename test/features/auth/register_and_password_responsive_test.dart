import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/core/theme/app_theme.dart';
import 'package:pka_home/features/auth/screens/register_screen.dart';
import 'package:pka_home/features/auth/screens/change_password_screen.dart';

void main() {
  Widget buildTestWidget({
    required Widget screen,
    required Size screenSize,
    double textScale = 1.0,
  }) {
    return ProviderScope(
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: MediaQueryData(
            size: screenSize,
            textScaler: TextScaler.linear(textScale),
          ),
          child: screen,
        ),
      ),
    );
  }

  group('Register & ChangePassword Responsive & Anti-RenderFlex Tests', () {
    testWidgets('RegisterScreen renders safely on 320dp mobile with 1.3x text zoom', (tester) async {
      tester.view.physicalSize = const Size(320 * 2, 600 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestWidget(
          screen: const RegisterScreen(),
          screenSize: const Size(320, 600),
          textScale: 1.3,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Tạo tài khoản'), findsOneWidget);
      expect(find.text('Họ và tên'), findsOneWidget);
      expect(find.text('Đăng ký'), findsOneWidget);
    });

    testWidgets('RegisterScreen renders centered on 1200dp desktop width', (tester) async {
      tester.view.physicalSize = const Size(1200 * 2, 800 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestWidget(
          screen: const RegisterScreen(),
          screenSize: const Size(1200, 800),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Tạo tài khoản'), findsOneWidget);
    });

    testWidgets('ChangePasswordScreen renders safely on 320dp mobile with 1.3x text zoom', (tester) async {
      tester.view.physicalSize = const Size(320 * 2, 600 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestWidget(
          screen: const ChangePasswordScreen(),
          screenSize: const Size(320, 600),
          textScale: 1.3,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Đổi mật khẩu'), findsOneWidget);
      expect(find.text('Mật khẩu mới'), findsOneWidget);
      expect(find.text('Cập nhật mật khẩu'), findsOneWidget);
    });

    testWidgets('ChangePasswordScreen renders centered on 1200dp desktop width', (tester) async {
      tester.view.physicalSize = const Size(1200 * 2, 800 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestWidget(
          screen: const ChangePasswordScreen(),
          screenSize: const Size(1200, 800),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Đổi mật khẩu'), findsOneWidget);
    });
  });
}

