import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/core/theme/app_theme.dart';
import 'package:pka_home/features/auth/screens/forgot_password_screen.dart';

void main() {
  Widget buildTestApp({
    required double width,
    required double height,
    double textScale = 1.0,
  }) {
    return ProviderScope(
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, height),
            textScaler: TextScaler.linear(textScale),
          ),
          child: const ForgotPasswordScreen(),
        ),
      ),
    );
  }

  group('ForgotPasswordScreen Impeccable Responsive Tests', () {
    testWidgets('renders safely on 320dp narrow mobile with 1.3x text zoom without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp(width: 320, height: 600, textScale: 1.3));
      await tester.pumpAndSettle();

      expect(find.text('Quên mật khẩu'), findsOneWidget);
      expect(find.text('Khôi phục mật khẩu'), findsOneWidget);
      expect(find.text('Gửi mã xác thực'), findsOneWidget);
      expect(find.text('Quay lại đăng nhập'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('renders desktop Web layout at 1200dp width without overflow', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp(width: 1200, height: 800));
      await tester.pumpAndSettle();

      expect(find.text('Khôi phục mật khẩu'), findsOneWidget);
      expect(find.text('Gửi mã xác thực'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

