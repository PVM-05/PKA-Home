import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vivona/core/theme/app_theme.dart';
import 'package:vivona/data/models/user_model.dart';
import 'package:vivona/features/resident/widgets/resident_onboarding_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testResident = UserModel(
    id: 'resident-onboarding-001',
    fullName: 'Lê Hoàng Nam',
    phone: '0912345678',
    role: 'resident',
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('ResidentOnboardingDialog hiển thị đúng thông tin chào mừng cư dân và 4 trụ cột tiện ích', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () => ResidentOnboardingDialog.checkAndShow(ctx, testResident),
                child: const Text('Mở Onboarding'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Mở Onboarding'));
    await tester.pumpAndSettle();

    // Xác nhận tiêu đề và huy hiệu
    expect(find.text('Chào mừng Lê Hoàng Nam!'), findsOneWidget);
    expect(find.text('CƯ DÂN VIVONA'), findsOneWidget);

    // Xác nhận 4 trụ cột tiện ích
    expect(find.text('Hóa đơn & VietQR tức thì'), findsOneWidget);
    expect(find.text('Báo cáo sự cố 24/7'), findsOneWidget);
    expect(find.text('Chỉ số điện nước AI'), findsOneWidget);
    expect(find.text('Cẩm nang & Tiện ích tòa nhà'), findsOneWidget);

    // Xác nhận nút bấm bắt đầu
    expect(find.text('BẮT ĐẦU TRẢI NGHIỆM'), findsOneWidget);

    // Nhấn nút hoàn tất onboarding
    await tester.tap(find.text('BẮT ĐẦU TRẢI NGHIỆM'));
    await tester.pumpAndSettle();

    // Dialog phải đóng lại
    expect(find.text('Chào mừng Lê Hoàng Nam!'), findsNothing);

    // SharedPreferences phải lưu flag đã xem
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('has_seen_resident_onboarding_resident-onboarding-001'), isTrue);
  });

  testWidgets('ResidentOnboardingDialog không mở lại nếu cư dân đã từng xem', (tester) async {
    SharedPreferences.setMockInitialValues({
      'has_seen_resident_onboarding_resident-onboarding-001': true,
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () => ResidentOnboardingDialog.checkAndShow(ctx, testResident),
                child: const Text('Mở Onboarding'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Mở Onboarding'));
    await tester.pumpAndSettle();

    // Không được hiển thị dialog vì đã xem rồi
    expect(find.text('Chào mừng Lê Hoàng Nam!'), findsNothing);
  });
}

