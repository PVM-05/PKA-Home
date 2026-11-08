import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/core/theme/app_theme.dart';
import 'package:pka_home/core/widgets/app_card.dart';
import 'package:pka_home/data/models/apartment_model.dart';
import 'package:pka_home/data/models/invoice_model.dart';
import 'package:pka_home/data/providers/resident_invoice_provider.dart';
import 'package:pka_home/features/resident/screens/resident_invoice_detail_screen.dart';

void main() {
  final sampleApartment = ApartmentModel(
    id: 'apt-01',
    code: 'A0110',
    buildingCode: 'A',
    floorNumber: 1,
    area: 75.0,
    isEmpty: false,
  );

  final testInvoice = InvoiceModel(
    id: 'inv-test-detail-1',
    apartmentId: 'apt-01',
    period: '11/2026',
    dueDate: DateTime.now().add(const Duration(days: 7)),
    totalAmount: 45000000.0, // 45 triệu VNĐ
    status: 'unpaid',
    createdAt: DateTime(2026, 11, 1),
    apartment: sampleApartment,
  );

  final mockItems = <Map<String, dynamic>>[
    {
      'fee_type': 'management',
      'unit_price': 10000.0,
      'quantity': 75,
      'subtotal': 750000.0,
      'note': 'Phí quản lý vận hành tháng 11',
    },
    {
      'fee_type': 'electricity',
      'unit_price': 3000.0,
      'quantity': 350,
      'subtotal': 1250000.0,
      'note': 'Chỉ số điện sinh hoạt',
    },
    {
      'fee_type': 'water',
      'unit_price': 15000.0,
      'quantity': 25,
      'subtotal': 375000.0,
      'note': 'Nước sinh hoạt',
    },
  ];

  Widget buildTestApp({
    required double width,
    required double height,
    double textScaleFactor = 1.0,
  }) {
    return ProviderScope(
      overrides: [
        residentInvoiceProvider.overrideWith(
          (ref) async => [testInvoice],
        ),
        residentInvoiceDetailProvider('inv-test-detail-1').overrideWith(
          (ref) async => mockItems,
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, height),
            textScaler: TextScaler.linear(textScaleFactor),
          ),
          child: ResidentInvoiceDetailScreen(invoice: testInvoice),
        ),
      ),
    );
  }

  group('ResidentInvoiceDetailScreen Responsive & Impeccable Tests', () {
    testWidgets('renders desktop/tablet layout at 1000dp width without overflow', (tester) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp(width: 1000, height: 800));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Chi tiết hóa đơn 11/2026'), findsOneWidget);
      expect(find.text('THANH TOÁN NGAY'), findsOneWidget);
    });

    testWidgets('renders narrow mobile 320dp width with 45M amount without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp(width: 320, height: 640));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('THANH TOÁN NGAY'), findsOneWidget);
    });

    testWidgets('renders narrow mobile 320dp with 1.3x text scale without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp(
        width: 320,
        height: 700,
        textScaleFactor: 1.3,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('THANH TOÁN NGAY'), findsOneWidget);
    });
  });
}
