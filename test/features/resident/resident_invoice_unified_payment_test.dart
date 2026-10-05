import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pka_home/core/widgets/unified_payment_sheet.dart';
import 'package:pka_home/data/models/invoice_model.dart';
import 'package:pka_home/data/models/apartment_model.dart';
import 'package:pka_home/data/services/payment_service.dart';
import 'package:pka_home/data/providers/payment_provider.dart';
import 'package:pka_home/data/providers/resident_invoice_provider.dart';
import 'package:pka_home/features/resident/screens/resident_invoice_detail_screen.dart';

class MockPaymentService extends PaymentService {
  final PaymentResult result;
  MockPaymentService(this.result);

  @override
  Future<PaymentResult> pay({
    required WidgetRef ref,
    required PaymentType type,
    required String referenceId,
    String outcome = 'SUCCESS',
  }) async {
    return result;
  }
}

void main() {
  testWidgets('ResidentInvoiceDetailScreen mở UnifiedPaymentSheet khi bấm THANH TOÁN NGAY', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
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
      totalAmount: 1480000.0,
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

    final mockPaymentResult = PaymentResult(
      success: true,
      transactionCode: 'DEMO-20261005-0001',
      transactionId: 'tx-001',
      amount: 1480000.0,
      title: 'Hóa đơn tháng 10/2026',
      paidAt: DateTime(2026, 10, 5, 22, 35),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          paymentServiceProvider.overrideWithValue(MockPaymentService(mockPaymentResult)),
          residentInvoiceDetailProvider('inv-test-1').overrideWith(
            (ref) async => [
              {
                'id': 'item-1',
                'fee_type': 'Phí quản lý',
                'unit_price': 750000.0,
                'quantity': 1,
                'subtotal': 750000.0,
              },
              {
                'id': 'item-2',
                'fee_type': 'Tiền điện',
                'unit_price': 450000.0,
                'quantity': 1,
                'subtotal': 450000.0,
              },
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

    // Bấm THANH TOÁN NGAY
    await tester.tap(payBtn);
    await tester.pumpAndSettle();

    // Mở UnifiedPaymentSheet
    expect(find.text('Thanh toán hóa đơn'), findsOneWidget);
    expect(find.text('Demo Payment'), findsOneWidget);
    expect(find.descendant(of: find.byType(UnifiedPaymentSheet), matching: find.text('Phí quản lý')), findsOneWidget);

    // Bấm THANH TOÁN trong sheet
    await tester.tap(find.text('THANH TOÁN'));
    await tester.pump();
    expect(find.text('Đang xử lý giao dịch...'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();

    // Thành công
    expect(find.text('Thanh toán thành công'), findsOneWidget);
    expect(find.text('DEMO-20261005-0001'), findsOneWidget);
  });
}
