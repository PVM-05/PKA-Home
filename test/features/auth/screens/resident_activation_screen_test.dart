import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pka_home/data/providers/resident_activation_provider.dart';
import 'package:pka_home/data/repositories/resident_activation_repository.dart';
import 'package:pka_home/features/auth/screens/resident_activation_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  Widget buildTestWidget() {
    return ProviderScope(
      overrides: [
        residentActivationRepositoryProvider.overrideWithValue(
          ResidentActivationRepository(),
        ),
      ],
      child: const MaterialApp(
        home: ResidentActivationScreen(),
      ),
    );
  }

  group('ResidentActivationScreen Widget Tests', () {
    testWidgets('renders step 1 with phone and activation code inputs', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Kích Hoạt Tài Khoản'), findsOneWidget);
      expect(find.text('Kích hoạt lần đầu'), findsOneWidget);
      expect(find.text('Số điện thoại cư dân (*)'), findsOneWidget);
      expect(find.text('Mã kích hoạt (*)'), findsOneWidget);
      expect(find.text('Tiếp tục xác thực OTP'), findsOneWidget);
      expect(find.text('Chưa có mã kích hoạt? Liên hệ BQL'), findsOneWidget);
    });

    testWidgets('full flow from step 1 to step 4 completed', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // 1. Nhập SĐT & Mã kích hoạt
      await tester.enterText(
        find.widgetWithText(TextField, 'Số điện thoại cư dân (*)'),
        '0901234567',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Mã kích hoạt (*)'),
        'ACT-123456',
      );
      await tester.tap(find.text('Tiếp tục xác thực OTP'));
      await tester.pumpAndSettle();

      // 2. Chuyển sang Bước 2: Nhập OTP
      expect(find.textContaining('Chào mừng, Nguyễn Văn An!'), findsOneWidget);
      expect(find.textContaining('Hồ sơ gắn liền Căn hộ A0110'), findsOneWidget);
      expect(find.text('Mã xác thực OTP'), findsOneWidget);

      await tester.tap(find.text('Xác thực OTP & Thiết lập mật khẩu'));
      await tester.pumpAndSettle();

      // 3. Chuyển sang Bước 3: Đặt mật khẩu & Điều khoản
      expect(find.text('Thiết lập mật khẩu đăng nhập'), findsOneWidget);
      expect(find.text('Mật khẩu mới (tối thiểu 6 ký tự) (*)'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Mật khẩu mới (tối thiểu 6 ký tự) (*)'),
        'Password123!',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Xác nhận lại mật khẩu (*)'),
        'Password123!',
      );

      // Tick checkbox điều khoản
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      // Bấm Hoàn tất kích hoạt
      await tester.ensureVisible(find.text('Hoàn tất kích hoạt'));
      await tester.tap(find.text('Hoàn tất kích hoạt'));
      await tester.pumpAndSettle();

      // 4. Bước 4: Chúc mừng thành công
      expect(find.text('Kích Hoạt Thành Công!'), findsOneWidget);
      expect(find.textContaining('Nguyễn Văn An'), findsWidgets);
      expect(find.text('Bắt đầu trải nghiệm ngay'), findsOneWidget);
    });
  });
}
