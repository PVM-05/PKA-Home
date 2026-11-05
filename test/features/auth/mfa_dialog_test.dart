import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/features/auth/widgets/mfa_setup_dialog.dart';
import 'package:pka_home/features/auth/widgets/mfa_verification_dialog.dart';

void main() {
  group('MfaVerificationDialog Widget Tests', () {
    testWidgets('Hiển thị giao diện và xác thực mã TOTP thành công', (tester) async {
      bool verifyCalled = false;
      String? submittedCode;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => MfaVerificationDialog.show(
                  context,
                  onVerify: (code) async {
                    verifyCalled = true;
                    submittedCode = code;
                    return code == '654321';
                  },
                ),
                child: const Text('Mở Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Mở Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Xác thực hai yếu tố'), findsOneWidget);
      expect(find.text('Xác nhận'), findsOneWidget);

      // Thử bấm Xác nhận khi chưa nhập đủ 6 số
      await tester.enterText(find.byType(TextField), '123');
      await tester.tap(find.text('Xác nhận'));
      await tester.pumpAndSettle();
      expect(find.text('Vui lòng nhập đầy đủ 6 chữ số xác thực.'), findsOneWidget);
      expect(verifyCalled, isFalse);

      // Nhập đủ 6 số hợp lệ
      await tester.enterText(find.byType(TextField), '654321');
      await tester.tap(find.text('Xác nhận'));
      await tester.pumpAndSettle();

      expect(verifyCalled, isTrue);
      expect(submittedCode, '654321');
      // Dialog đã đóng
      expect(find.text('Xác thực hai yếu tố'), findsNothing);
    });

    testWidgets('Hiển thị thông báo lỗi khi mã TOTP không chính xác', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => MfaVerificationDialog.show(
                  context,
                  onVerify: (code) async => false, // Mã sai
                ),
                child: const Text('Mở Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Mở Dialog'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '000000');
      await tester.tap(find.text('Xác nhận'));
      await tester.pumpAndSettle();

      expect(find.text('Mã xác thực không chính xác hoặc đã hết hạn. Vui lòng thử lại.'), findsOneWidget);
      expect(find.text('Xác thực hai yếu tố'), findsOneWidget);
    });
  });

  group('MfaSetupDialog Widget Tests', () {
    testWidgets('Hiển thị mã bí mật và hoàn tất kích hoạt MFA', (tester) async {
      bool activateCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => MfaSetupDialog.show(
                  context,
                  secretKey: 'ABCD1234EFGH5678',
                  onActivate: (code) async {
                    activateCalled = true;
                    return code == '112233';
                  },
                ),
                child: const Text('Mở Setup Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Mở Setup Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Kích hoạt xác thực 2 yếu tố'), findsOneWidget);
      expect(find.text('ABCD1234EFGH5678'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '112233');
      await tester.tap(find.text('Hoàn tất kích hoạt'));
      await tester.pumpAndSettle();

      expect(activateCalled, isTrue);
      expect(find.text('Kích hoạt xác thực 2 yếu tố'), findsNothing);
    });
  });
}
