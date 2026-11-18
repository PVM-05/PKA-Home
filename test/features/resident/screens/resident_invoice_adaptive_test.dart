import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivona/data/models/invoice_model.dart';
import 'package:vivona/data/providers/resident_invoice_provider.dart';
import 'package:vivona/features/resident/screens/resident_invoice_screen.dart';

void main() {
  final testInvoice = InvoiceModel(
    id: 'inv-test-1',
    apartmentId: 'apt-1',
    period: '11/2026',
    dueDate: DateTime(2026, 11, 25),
    totalAmount: 1500000.0,
    status: 'unpaid',
    createdAt: DateTime(2026, 11, 1),
  );

  Widget createWidgetUnderTest() {
    return ProviderScope(
      overrides: [
        residentInvoiceProvider.overrideWith((ref) => [testInvoice]),
        residentInvoiceDetailProvider('inv-test-1').overrideWith(
          (ref) => Future.value([
            {
              'fee_type': 'management',
              'unit_price': 1000000.0,
              'quantity': 1,
              'subtotal': 1000000.0,
            },
          ]),
        ),
      ],
      child: const MaterialApp(
        home: ResidentInvoiceScreen(),
      ),
    );
  }

  group('ResidentInvoiceScreen Adaptive Tests', () {
    testWidgets('renders single pane list on mobile viewport (390dp)', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Hóa Đơn & Thanh Toán'), findsOneWidget);
      expect(find.text('Kỳ 11/2026'), findsOneWidget);
      // Trên mobile không hiển thị placeholder chọn bên phải
      expect(find.text('Chưa chọn mục nào'), findsNothing);
    });

    testWidgets('renders master-detail split layout on desktop viewport (1200dp)', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Kỳ 11/2026'), findsOneWidget);

      // Nhấp chọn hóa đơn ở cột Master bên trái
      await tester.tap(find.text('Kỳ 11/2026'));
      await tester.pumpAndSettle();

      // Cột Detail bên phải hiển thị chi tiết hóa đơn
      expect(find.textContaining('11/2026'), findsAtLeastNWidgets(1));
    });
  });
}

