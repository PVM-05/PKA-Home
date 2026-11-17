import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivona/core/theme/app_theme.dart';
import 'package:vivona/data/models/apartment_model.dart';
import 'package:vivona/data/models/invoice_model.dart';
import 'package:vivona/data/providers/resident_invoice_provider.dart';
import 'package:vivona/features/resident/screens/resident_invoice_screen.dart';

void main() {
  final sampleApartment = ApartmentModel(
    id: 'apt-01',
    code: 'A0110',
    buildingCode: 'A',
    floorNumber: 1,
    area: 70.0,
    isEmpty: false,
  );

  final unpaidInvoice = InvoiceModel(
    id: 'inv-unpaid-1',
    apartmentId: 'apt-01',
    period: '11/2026',
    dueDate: DateTime.now().add(const Duration(days: 5)),
    totalAmount: 1850000.0,
    status: 'unpaid',
    createdAt: DateTime(2026, 11, 1),
    apartment: sampleApartment,
  );

  final overdueInvoice = InvoiceModel(
    id: 'inv-overdue-1',
    apartmentId: 'apt-01',
    period: '10/2026',
    dueDate: DateTime.now().subtract(const Duration(days: 3)),
    totalAmount: 12500000.0, // Số tiền lớn 12.5 triệu
    status: 'unpaid',
    createdAt: DateTime(2026, 10, 1),
    apartment: sampleApartment,
  );

  final paidInvoice = InvoiceModel(
    id: 'inv-paid-1',
    apartmentId: 'apt-01',
    period: '09/2026',
    dueDate: DateTime(2026, 9, 15),
    totalAmount: 2100000.0,
    status: 'paid',
    createdAt: DateTime(2026, 9, 1),
    apartment: sampleApartment,
  );

  Widget buildTestApp({
    required double width,
    required double height,
    double textScaleFactor = 1.0,
    List<InvoiceModel> invoices = const [],
  }) {
    return ProviderScope(
      overrides: [
        residentInvoiceProvider.overrideWith((ref) => invoices),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, height),
            textScaler: TextScaler.linear(textScaleFactor),
          ),
          child: const ResidentInvoiceScreen(),
        ),
      ),
    );
  }

  group('ResidentInvoiceScreen Responsive & Impeccable Tests', () {
    testWidgets('renders desktop/tablet layout at 1000dp width cleanly without overflow', (tester) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp(
        width: 1000,
        height: 800,
        invoices: [unpaidInvoice, overdueInvoice, paidInvoice],
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
      expect(find.text('Hóa Đơn & Thanh Toán'), findsOneWidget);
      expect(find.text('Cần thanh toán'), findsOneWidget);
      expect(find.text('Kỳ 11/2026'), findsOneWidget);
    });

    testWidgets('renders narrow mobile 320dp width with overdue & large amount without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp(
        width: 320,
        height: 640,
        invoices: [unpaidInvoice, overdueInvoice],
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
      expect(find.text('Kỳ 10/2026'), findsOneWidget);
      expect(find.textContaining('Quá hạn'), findsOneWidget);
    });

    testWidgets('renders narrow mobile 320dp with 1.3x text scale without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp(
        width: 320,
        height: 700,
        textScaleFactor: 1.3,
        invoices: [unpaidInvoice, overdueInvoice],
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
      expect(find.text('Hóa Đơn & Thanh Toán'), findsOneWidget);
    });

    testWidgets('switches to paid history tab smoothly', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp(
        width: 390,
        height: 844,
        invoices: [unpaidInvoice, paidInvoice],
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Lịch sử đã đóng'), findsOneWidget);
      await tester.tap(find.text('Lịch sử đã đóng'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Kỳ 09/2026'), findsOneWidget);
      expect(find.text('Đã thanh toán'), findsOneWidget);
    });
  });
}

