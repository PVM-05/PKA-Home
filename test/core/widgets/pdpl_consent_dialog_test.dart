import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pka_home/core/widgets/pdpl_consent_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PdplConsentManager Unit Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('hasConsented trả về false khi chưa lưu trạng thái', () async {
      final consented = await PdplConsentManager.hasConsented();
      expect(consented, isFalse);
    });

    test('saveConsent lưu trạng thái và con dấu thời gian thành công', () async {
      await PdplConsentManager.saveConsent();

      final consented = await PdplConsentManager.hasConsented();
      expect(consented, isTrue);

      final timestamp = await PdplConsentManager.getConsentTimestamp();
      expect(timestamp, isNotNull);
      expect(DateTime.tryParse(timestamp!), isNotNull);
    });

    test('revokeConsent rút lại trạng thái chấp thuận thành công', () async {
      await PdplConsentManager.saveConsent();
      expect(await PdplConsentManager.hasConsented(), isTrue);

      await PdplConsentManager.revokeConsent();
      expect(await PdplConsentManager.hasConsented(), isFalse);
      expect(await PdplConsentManager.getConsentTimestamp(), isNull);
    });
  });

  group('PdplConsentDialog Widget Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('Nút Xác nhận bị vô hiệu hóa khi chưa tick checkbox', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PdplConsentDialog(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bảo Vệ Dữ Liệu Cá Nhân'), findsOneWidget);
      expect(find.text('Căn cứ Luật 91/2025/QH15 & NĐ 356/2025/NĐ-CP'), findsOneWidget);

      final confirmBtn = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Xác nhận và Đồng ý'),
      );
      expect(confirmBtn.onPressed, isNull);

      // Tick checkbox
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      final activeConfirmBtn = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Xác nhận và Đồng ý'),
      );
      expect(activeConfirmBtn.onPressed, isNotNull);

      // Bấm xác nhận
      await tester.tap(find.widgetWithText(ElevatedButton, 'Xác nhận và Đồng ý'));
      await tester.pumpAndSettle();

      final consented = await PdplConsentManager.hasConsented();
      expect(consented, isTrue);
    });

    testWidgets('Chế độ review hiển thị nút Đóng', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PdplConsentDialog(isReviewMode: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Đóng'), findsOneWidget);
      expect(find.byType(Checkbox), findsNothing);
    });
  });
}
