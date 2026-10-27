import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pka_home/core/widgets/electronic_receipt_sheet.dart';
import 'package:pka_home/data/models/invoice_model.dart';
import 'package:pka_home/data/models/apartment_model.dart';
import 'package:pka_home/data/models/building_model.dart';
import 'package:pka_home/data/providers/building_provider.dart';

void main() {
  group('ElectronicReceiptSheet Tests', () {
    final sampleInvoice = InvoiceModel(
      id: 'inv-receipt-001',
      apartmentId: 'apt-001',
      period: '10/2026',
      dueDate: DateTime(2026, 10, 25),
      totalAmount: 1500000,
      status: 'paid',
      createdAt: DateTime(2026, 10, 1),
      paidAt: DateTime(2026, 10, 15, 14, 30),
      paymentMethod: 'bank_transfer',
      transactionCode: 'TXN-20261015-0987',
      apartment: ApartmentModel(
        id: 'apt-001',
        code: 'A0110',
        buildingCode: 'A',
        floorNumber: 1,
        area: 72.5,
      ),
    );

    testWidgets('renders electronic receipt with standard Vietnamese fields and currency words', (tester) async {
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
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeBuildingProvider.overrideWith((ref) => Future.value(testBuilding)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ElectronicReceiptSheet(
                invoice: sampleInvoice,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check title and header
      expect(find.text('BIÊN LAI THU TIỀN ĐIỆN TỬ'), findsOneWidget);
      expect(find.textContaining('PT-'), findsOneWidget);

      // Check unit code and period
      expect(find.textContaining('A0110'), findsWidgets);
      expect(find.textContaining('10/2026'), findsWidgets);

      // Check amount and Vietnamese words
      expect(find.textContaining('1.500.000'), findsWidgets);
      expect(find.textContaining('Một triệu năm trăm nghìn đồng chẵn'), findsOneWidget);

      // Check payment status stamp
      expect(find.text('ĐÃ THU TIỀN'), findsOneWidget);

      // Check share button
      expect(find.text('Chia sẻ biên lai'), findsOneWidget);
    });
  });
}
