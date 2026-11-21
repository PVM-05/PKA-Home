import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivona/core/theme/app_theme.dart';
import 'package:vivona/core/widgets/app_qr_scanner_sheet.dart';

void main() {
  group('AppQrScannerSheet Tests', () {
    testWidgets('hiển thị tiêu đề, nút đóng, nút chuyển chế độ nhập tay', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: AppQrScannerSheet(
              title: 'Quét vé khách vào/ra',
              hintText: 'Căn chỉnh mã QR vé khách trong khung hình',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Quét vé khách vào/ra'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.byIcon(Icons.qr_code_scanner_rounded), findsOneWidget);
    });

    testWidgets('chế độ nhập tay: nhập mã và bấm xác nhận trả về kết quả chính xác', (tester) async {
      String? result;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    result = await AppQrScannerSheet.show(
                      context,
                      title: 'Soát vé khách',
                      manualInputHint: 'VD: VP-202611-00001',
                    );
                  },
                  child: const Text('Mở Scanner'),
                );
              },
            ),
          ),
        ),
      );

      // Mở Sheet
      await tester.tap(find.text('Mở Scanner'));
      await tester.pumpAndSettle();

      expect(find.text('Soát vé khách'), findsOneWidget);

      // Nếu đang ở Camera mode, bấm icon chuyển sang manual mode nếu có
      final manualToggle = find.byTooltip('Nhập mã tay');
      if (manualToggle.evaluate().isNotEmpty) {
        await tester.tap(manualToggle);
        await tester.pumpAndSettle();
      }

      // Kiểm tra ô nhập mã thủ công
      expect(find.text('Nhập mã vé / mã xác thực thủ công:'), findsOneWidget);

      // Nhập mã
      await tester.enterText(find.byType(TextField), 'VP-202611-99999');
      await tester.pump();

      // Bấm Xác nhận mã
      await tester.tap(find.text('Xác nhận mã'));
      await tester.pumpAndSettle();

      // Sheet đã đóng và trả về mã chính xác
      expect(result, 'VP-202611-99999');
      expect(find.text('Soát vé khách'), findsNothing);
    });
  });
}

