import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivona/core/theme/app_theme.dart';
import 'package:vivona/data/providers/resident_activation_provider.dart';
import 'package:vivona/data/repositories/resident_activation_repository.dart';
import 'package:vivona/features/auth/screens/resident_activation_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestApp({required double width, required double height, double textScale = 1.0}) {
    return ProviderScope(
      overrides: [
        residentActivationRepositoryProvider.overrideWithValue(
          ResidentActivationRepository(),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, height),
            textScaler: TextScaler.linear(textScale),
          ),
          child: const ResidentActivationScreen(),
        ),
      ),
    );
  }

  group('ResidentActivationScreen Impeccable Responsive Tests', () {
    testWidgets('renders safely on 320dp narrow mobile with 1.3x text zoom without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp(width: 320, height: 600, textScale: 1.3));
      await tester.pumpAndSettle();

      expect(find.text('Kích Hoạt Tài Khoản'), findsOneWidget);
      expect(find.text('Kích hoạt lần đầu'), findsOneWidget);
      expect(find.text('Mã mời'), findsOneWidget);
      expect(find.text('Xác thực'), findsOneWidget);
      expect(find.text('Mật khẩu'), findsOneWidget);
      expect(find.text('Hoàn tất'), findsOneWidget);

      // Verify no RenderFlex overflow
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders desktop Split-Screen layout with Hero Showcase at 1200dp width', (tester) async {
      tester.view.physicalSize = const Size(1200, 850);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp(width: 1200, height: 850));
      await tester.pumpAndSettle();

      // Verify Hero content on Desktop
      expect(find.textContaining('Không Gian Sống Thông Minh'), findsOneWidget);
      expect(find.textContaining('Định danh & Sở hữu căn hộ chuẩn xác'), findsOneWidget);
      expect(find.text('Kích hoạt lần đầu'), findsOneWidget);
      expect(find.text('Số điện thoại cư dân (*)'), findsOneWidget);

      // Verify no overflow
      expect(tester.takeException(), isNull);
    });
  });
}
