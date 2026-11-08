import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/core/theme/app_theme.dart';
import 'package:pka_home/features/auth/screens/login_screen.dart';

void main() {
  Widget buildTestApp({required double width, required double height}) {
    return ProviderScope(
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: MediaQueryData(size: Size(width, height)),
          child: const LoginScreen(),
        ),
      ),
    );
  }

  group('LoginScreen Impeccable Responsive Tests', () {
    testWidgets('renders desktop Split-Screen layout at width 1200dp', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp(width: 1200, height: 900));
      await tester.pumpAndSettle();

      // Should display brand showcase elements
      expect(find.textContaining('PKA'), findsWidgets);
      expect(find.text('Thư điện tử'), findsOneWidget);
      expect(find.text('Mật khẩu'), findsOneWidget);
      expect(find.text('Đăng nhập'), findsOneWidget);
      expect(find.text('Kích hoạt tài khoản lần đầu'), findsOneWidget);
    });

    testWidgets('renders mobile centered layout at width 360dp without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp(width: 360, height: 640));
      await tester.pumpAndSettle();

      expect(find.text('Thư điện tử'), findsOneWidget);
      expect(find.text('Mật khẩu'), findsOneWidget);
      expect(find.text('Đăng nhập'), findsOneWidget);
      // No RenderFlex overflow exception
      expect(tester.takeException(), isNull);
    });
  });
}
