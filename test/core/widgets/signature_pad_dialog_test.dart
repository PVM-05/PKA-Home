import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/core/widgets/signature_pad_dialog.dart';

void main() {
  group('SignaturePadDialog Widget Tests', () {
    testWidgets('Hiển thị tiêu đề, nút xóa và nút xác nhận', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => const SignaturePadDialog(
                        title: 'Ký tên xác nhận',
                        signerRole: 'Ban Quản Lý',
                      ),
                    );
                  },
                  child: const Text('Mở chữ ký'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Mở chữ ký'));
      await tester.pumpAndSettle();

      expect(find.text('Ký tên xác nhận'), findsOneWidget);
      expect(find.text('Người ký: Ban Quản Lý'), findsOneWidget);
      expect(find.text('Ký lại'), findsOneWidget);
      expect(find.text('Đóng'), findsOneWidget);
      expect(find.text('Xác nhận ký'), findsOneWidget);
    });

    testWidgets('Có thể vẽ nét chữ ký và bấm Xác nhận ký', (tester) async {
      Uint8List? capturedSignature;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showDialog<Uint8List>(
                      context: context,
                      builder: (_) => SignaturePadDialog(
                        title: 'Ký nhận bàn giao',
                        signerRole: 'Cư dân',
                        customRasterizer: (strokes) async => Uint8List.fromList([1, 2, 3, 4]),
                        onSignatureSaved: (bytes) {
                          capturedSignature = bytes;
                        },
                      ),
                    );
                  },
                  child: const Text('Mở chữ ký'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Mở chữ ký'));
      await tester.pumpAndSettle();

      final canvasFinder = find.byKey(const Key('signature_pad_canvas'));
      expect(canvasFinder, findsOneWidget);

      final center = tester.getCenter(canvasFinder);
      final gesture = await tester.startGesture(center);
      await gesture.moveBy(const Offset(40, 30));
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.moveBy(const Offset(30, 20));
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.up();
      await tester.pumpAndSettle();

      // Bấm nút Xác nhận ký
      final confirmBtn = find.widgetWithText(ElevatedButton, 'Xác nhận ký');
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      expect(capturedSignature, isNotNull);
      expect(capturedSignature, Uint8List.fromList([1, 2, 3, 4]));
    });
  });
}
