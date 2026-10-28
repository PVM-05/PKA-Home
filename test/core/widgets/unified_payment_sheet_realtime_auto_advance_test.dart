import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pka_home/core/widgets/unified_payment_sheet.dart';
import 'package:pka_home/data/models/building_model.dart';
import 'package:pka_home/data/models/invoice_model.dart';
import 'package:pka_home/data/providers/building_provider.dart';
import 'package:pka_home/data/providers/resident_invoice_provider.dart';
import 'package:pka_home/data/services/payment_service.dart';

void main() {
  testWidgets('UnifiedPaymentSheet auto-advances to success when invoice is paid via Realtime', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final testBuilding = BuildingModel(
      id: 'b-001',
      organizationId: 'org-001',
      name: 'PKA Landmark 1',
      code: 'PKAL',
      bankBin: '970418',
      bankName: 'BIDV',
      bankAccountNumber: '9876543210',
      bankAccountName: 'BQL PKA LANDMARK 1',
    );

    final unpaidInvoice = InvoiceModel(
      id: 'inv-realtime-101',
      apartmentId: 'apt-01',
      period: '10/2026',
      dueDate: DateTime(2026, 11, 5),
      totalAmount: 1850000,
      status: 'unpaid',
      createdAt: DateTime(2026, 10, 20),
      paymentCode: 'INV2610A0110',
    );

    final invoicesNotifier = StateProvider<List<InvoiceModel>>((ref) => [unpaidInvoice]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeBuildingProvider.overrideWith((ref) => Future.value(testBuilding)),
          residentInvoiceProvider.overrideWith((ref) => Future.value(ref.watch(invoicesNotifier))),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: UnifiedPaymentSheet(
              type: PaymentType.invoice,
              referenceId: 'inv-realtime-101',
              title: 'Thanh toán hóa đơn kỳ 10/2026',
              referenceCode: 'INV2610A0110',
              amount: 1850000,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Initial State: Confirmation screen with QR and payment info
    expect(find.text('Thanh toán hóa đơn kỳ 10/2026'), findsOneWidget);
    expect(find.text('INV2610A0110'), findsOneWidget);
    expect(find.text('Chuyển khoản VietQR (Napas 247)'), findsOneWidget);
    expect(find.text('Sao chép STK'), findsOneWidget);
    expect(find.text('Sao chép Nội dung'), findsOneWidget);
    expect(find.text('Sao chép Số tiền'), findsOneWidget);

    // 2. Simulate Webhook receiving bank transfer -> Invoice status updated to 'paid' via Realtime
    final paidInvoice = InvoiceModel(
      id: 'inv-realtime-101',
      apartmentId: 'apt-01',
      period: '10/2026',
      dueDate: DateTime(2026, 11, 5),
      totalAmount: 1850000,
      paidAmount: 1850000,
      status: 'paid',
      createdAt: DateTime(2026, 10, 20),
      paidAt: DateTime(2026, 10, 29, 0, 50),
      receiptNumber: 'REC-20261029-RT0001',
      paymentCode: 'INV2610A0110',
      transactionCode: 'TXN-BANK-1729988776655',
    );

    final container = ProviderScope.containerOf(tester.element(find.byType(UnifiedPaymentSheet)));
    container.read(invoicesNotifier.notifier).state = [paidInvoice];

    await tester.pump();
    await tester.pumpAndSettle();

    // 3. Verified: Sheet automatically advanced to Success step without user clicking simulation
    expect(find.text('Thanh toán thành công'), findsOneWidget);
    expect(find.text('REC-20261029-RT0001'), findsOneWidget);
    expect(find.text('Chuyển khoản VietQR (Napas 247)'), findsOneWidget);
    expect(find.text('HOÀN TẤT'), findsOneWidget);
  });
}
