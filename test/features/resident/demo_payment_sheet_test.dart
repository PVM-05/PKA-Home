import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pka_home/data/models/invoice_model.dart';
import 'package:pka_home/data/models/apartment_model.dart';
import 'package:pka_home/features/resident/screens/resident_invoice_detail_screen.dart';

import 'package:pka_home/data/providers/resident_invoice_provider.dart';

void main() {
  testWidgets('ResidentInvoiceDetailScreen mở Cổng thanh toán mô phỏng Demo Payment', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final invoice = InvoiceModel(
      id: 'inv-test-1',
      apartmentId: 'apt-01',
      period: '10/2026',
      dueDate: DateTime(2026, 10, 15),
      totalAmount: 500000.0,
      status: 'unpaid',
      createdAt: DateTime(2026, 10, 1),
      apartment: ApartmentModel(
        id: 'apt-01',
        code: 'A0110',
        buildingCode: 'A',
        floorNumber: 1,
        area: 75.0,
        isEmpty: false,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          residentInvoiceDetailProvider('inv-test-1').overrideWith(
            (ref) async => [
              {
                'id': 'item-1',
                'fee_type': 'Phí quản lý',
                'unit_price': 500000.0,
                'quantity': 1,
                'subtotal': 500000.0,
              }
            ],
          ),
        ],
        child: MaterialApp(
          home: ResidentInvoiceDetailScreen(invoice: invoice),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Nút THANH TOÁN NGAY hiển thị
    final payBtn = find.text('THANH TOÁN NGAY');
    expect(payBtn, findsOneWidget);

    // Bấm nút THANH TOÁN NGAY
    await tester.tap(payBtn);
    await tester.pumpAndSettle();

    // Mở Bottom Sheet Cổng thanh toán điện tử
    expect(find.text('CỔNG THANH TOÁN ĐIỆN TỬ'), findsOneWidget);
    expect(find.text('Demo Payment (Sandbox)'), findsOneWidget);

    // Nút TIẾN HÀNH THANH TOÁN
    final proceedBtn = find.text('TIẾN HÀNH THANH TOÁN');
    expect(proceedBtn, findsOneWidget);

    // Bấm TIẾN HÀNH THANH TOÁN -> Mở dialog chọn kịch bản
    await tester.tap(proceedBtn);
    await tester.pumpAndSettle();

    expect(find.text('Xác Nhận Thanh Toán'), findsOneWidget);
    expect(find.text('Thanh toán thành công (Mô phỏng)'), findsOneWidget);
    expect(find.text('Thanh toán thất bại (Mô phỏng)'), findsOneWidget);
  });
}
