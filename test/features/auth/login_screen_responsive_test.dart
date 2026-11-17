import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivona/core/theme/app_theme.dart';
import 'package:vivona/features/auth/screens/login_screen.dart';

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

    testWidgets('renders desktop safely on low-height viewport (1024dp x 580dp) without vertical overflow', (tester) async {
      tester.view.physicalSize = const Size(1024, 580);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp(width: 1024, height: 580));
      await tester.pumpAndSettle();

      expect(find.textContaining('PKA'), findsWidgets);
      expect(find.text('Đăng nhập'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders mobile centered layout at width 320dp with 1.3x text scale without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp(width: 320, height: 600, textScale: 1.3));
      await tester.pumpAndSettle();

      expect(find.text('Thư điện tử'), findsOneWidget);
      expect(find.text('Mật khẩu'), findsOneWidget);
      expect(find.text('Đăng nhập'), findsOneWidget);
      expect(find.text('Kích hoạt tài khoản lần đầu'), findsOneWidget);
      // No RenderFlex overflow exception
      expect(tester.takeException(), isNull);
    });
  });
}
