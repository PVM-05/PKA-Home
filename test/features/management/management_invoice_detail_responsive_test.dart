import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/apartment_model.dart';
import 'package:pka_home/data/models/invoice_model.dart';
import 'package:pka_home/data/providers/invoice_items_provider.dart';
import 'package:pka_home/features/management/screens/management_invoice_detail_screen.dart';

void main() {
  final apt = ApartmentModel(
    id: 'apt-01',
    code: 'A0110',
    buildingCode: 'A',
    floorNumber: 1,
    area: 75.0,
    isEmpty: false,
  );

  final samplePaidInvoice = InvoiceModel(
    id: 'inv-paid-001',
    apartmentId: 'apt-01',
    period: '11/2026',
    dueDate: DateTime(2026, 11, 15),
    totalAmount: 18500000.0,
    paidAmount: 18500000.0,
    status: 'paid',
    createdAt: DateTime(2026, 11, 1),
    paidAt: DateTime(2026, 11, 10, 14, 30),
    paymentMethod: 'VietQR Napas 247',
    transactionCode: 'TXN-PAID-01',
    receiptNumber: 'PT-202611-001',
    einvoiceLookupCode: 'PKAINV12345678',
    apartment: apt,
  );

  final samplePendingInvoice = InvoiceModel(
    id: 'inv-pending-002',
    apartmentId: 'apt-01',
    period: '11/2026',
    dueDate: DateTime(2026, 11, 15),
    totalAmount: 3250000.0,
    status: 'pending_confirmation',
    createdAt: DateTime(2026, 11, 1),
    paymentMethod: 'CASH',
    apartment: apt,
  );

  final sampleInvoiceItems = <Map<String, dynamic>>[
    {
      'id': 'item-1',
      'fee_type': 'management',
      'unit_price': 850000.0,
      'quantity': 1,
      'subtotal': 850000.0,
    },
    {
      'id': 'item-2',
      'fee_type': 'electricity',
      'unit_price': 1500000.0,
      'quantity': 1,
      'subtotal': 1500000.0,
    },
    {
      'id': 'item-3',
      'fee_type': 'water',
      'unit_price': 900000.0,
      'quantity': 1,
      'subtotal': 900000.0,
    },
  ];

  Widget createWidget({required InvoiceModel invoice}) {
    return ProviderScope(
      overrides: [
        invoiceDetailProvider(invoice.id).overrideWith(
          (ref) async => sampleInvoiceItems,
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: ManagementInvoiceDetailScreen(invoice: invoice),
      ),
    );
  }

  group('ManagementInvoiceDetailScreen Responsive & Impeccable Tests', () {
    testWidgets('renders desktop workstation split-screen at 1200dp width without overflow', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidget(invoice: samplePaidInvoice));
      await tester.pumpAndSettle();

      expect(find.text('Chi tiết Hóa đơn 11/2026'), findsOneWidget);
      expect(find.text('TỔNG CỘNG'), findsOneWidget);
      expect(find.text('Đã thanh toán'), findsOneWidget);
      expect(find.text('CHI TIẾT CÁC KHOẢN PHÍ'), findsOneWidget);
      expect(find.text('XEM BIÊN LAI THU TIỀN'), findsOneWidget);
    });

    testWidgets('renders narrow mobile 320dp with 1.3x text zoom without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      await tester.pumpWidget(createWidget(invoice: samplePendingInvoice));
      await tester.pumpAndSettle();

      expect(find.text('Chi tiết Hóa đơn 11/2026'), findsOneWidget);
      expect(find.text('Chờ xác nhận'), findsOneWidget);
      expect(find.text('CHI TIẾT CÁC KHOẢN PHÍ'), findsOneWidget);
      expect(find.textContaining('XÁC NHẬN ĐÃ THU'), findsOneWidget);
    });
  });
}

