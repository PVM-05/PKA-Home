import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pka_home/data/models/apartment_model.dart';
import 'package:pka_home/data/models/invoice_model.dart';
import 'package:pka_home/data/providers/resident_invoice_provider.dart';
import 'package:pka_home/features/document/screens/document_preview_screen.dart';
import 'package:pka_home/features/resident/screens/resident_invoice_detail_screen.dart';
import 'package:pka_home/features/management/screens/management_invoice_detail_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InvoiceModel samplePaidInvoice;
  late InvoiceModel sampleUnpaidInvoice;
  late List<Map<String, dynamic>> sampleInvoiceItems;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('net.nfet.printing'),
      (MethodCall call) async {
        if (call.method == 'printingInfo') {
          return <String, dynamic>{
            'directPrint': true,
            'dynamicLayout': true,
            'canPrint': true,
            'canConvertHtml': false,
            'canListPrinters': true,
            'canRaster': false,
          };
        }
        return null;
      },
    );

    final apt = ApartmentModel(
      id: 'apt-01',
      code: 'A0110',
      buildingCode: 'A',
      floorNumber: 1,
      area: 75.0,
      isEmpty: false,
    );

    samplePaidInvoice = InvoiceModel(
      id: 'inv-paid-001',
      apartmentId: 'apt-01',
      period: '10/2026',
      dueDate: DateTime(2026, 10, 15),
      totalAmount: 1500000.0,
      paidAmount: 1500000.0,
      status: 'paid',
      createdAt: DateTime(2026, 10, 1),
      paidAt: DateTime(2026, 10, 10, 14, 30),
      paymentMethod: 'VietQR Napas 247',
      transactionCode: 'TXN-PAID-01',
      receiptNumber: 'PT-202610-001',
      einvoiceLookupCode: 'PKAINV12345678',
      apartment: apt,
    );

    sampleUnpaidInvoice = InvoiceModel(
      id: 'inv-unpaid-002',
      apartmentId: 'apt-01',
      period: '10/2026',
      dueDate: DateTime(2026, 10, 15),
      totalAmount: 1200000.0,
      status: 'unpaid',
      createdAt: DateTime(2026, 10, 1),
      apartment: apt,
    );

    sampleInvoiceItems = [
      {
        'id': 'item-1',
        'fee_type': 'Phí quản lý',
        'unit_price': 500000.0,
        'quantity': 1,
        'subtotal': 500000.0,
      },
      {
        'id': 'item-2',
        'fee_type': 'Tiền điện',
        'unit_price': 700000.0,
        'quantity': 1,
        'subtotal': 700000.0,
      },
    ];
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('net.nfet.printing'),
      null,
    );
  });

  group('Kiểm thử Xuất PDF trên ResidentInvoiceDetailScreen & ManagementInvoiceDetailScreen', () {
    testWidgets('Test case 1: ResidentInvoiceDetailScreen có nút xuất PDF trên AppBar', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            residentInvoiceDetailProvider(samplePaidInvoice.id).overrideWith(
              (ref) async => sampleInvoiceItems,
            ),
          ],
          child: MaterialApp(
            home: ResidentInvoiceDetailScreen(invoice: samplePaidInvoice),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Kiểm tra có icon PDF hoặc tooltip xuất PDF chứng từ trên AppBar
      final pdfButton = find.byTooltip('Xuất PDF chứng từ');
      expect(pdfButton, findsOneWidget);
      expect(find.byIcon(Icons.picture_as_pdf_outlined), findsOneWidget);
    });

    testWidgets('Test case 2: Nhấn nút xuất PDF trên hóa đơn đã thanh toán điều hướng sang DocumentPreviewScreen', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            residentInvoiceDetailProvider(samplePaidInvoice.id).overrideWith(
              (ref) async => sampleInvoiceItems,
            ),
          ],
          child: MaterialApp(
            home: ResidentInvoiceDetailScreen(invoice: samplePaidInvoice),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final pdfButton = find.byTooltip('Xuất PDF chứng từ');
      expect(pdfButton, findsOneWidget);

      await tester.tap(pdfButton);
      await tester.pumpAndSettle();

      // Phải điều hướng sang DocumentPreviewScreen
      expect(find.byType(DocumentPreviewScreen), findsOneWidget);
      expect(find.textContaining('Biên lai'), findsWidgets);
    });

    testWidgets('Test case 2b: Nhấn nút xuất PDF trên hóa đơn chưa thanh toán điều hướng sang DocumentPreviewScreen hóa đơn', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            residentInvoiceDetailProvider(sampleUnpaidInvoice.id).overrideWith(
              (ref) async => sampleInvoiceItems,
            ),
          ],
          child: MaterialApp(
            home: ResidentInvoiceDetailScreen(invoice: sampleUnpaidInvoice),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final pdfButton = find.byTooltip('Xuất PDF chứng từ');
      expect(pdfButton, findsOneWidget);

      await tester.tap(pdfButton);
      await tester.pumpAndSettle();

      expect(find.byType(DocumentPreviewScreen), findsOneWidget);
      expect(find.textContaining('Hóa đơn'), findsWidgets);
    });

    testWidgets('Test case 3: ManagementInvoiceDetailScreen có nút xuất PDF/In ấn mở bottom sheet 3 tùy chọn', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            invoiceDetailProvider(samplePaidInvoice.id).overrideWith(
              (ref) async => sampleInvoiceItems,
            ),
          ],
          child: MaterialApp(
            home: ManagementInvoiceDetailScreen(invoice: samplePaidInvoice),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tìm nút In / Xuất PDF trên AppBar
      final printButton = find.byTooltip('Xuất PDF / In chứng từ');
      expect(printButton, findsOneWidget);
      expect(find.byIcon(Icons.print_outlined), findsOneWidget);

      // Nhấn nút in
      await tester.tap(printButton);
      await tester.pumpAndSettle();

      // Modal bottom sheet hiển thị 3 lựa chọn
      expect(find.text('Hóa đơn dịch vụ (Khổ A4)'), findsOneWidget);
      expect(find.text('Biên lai thu tiền điện tử (Khổ A4)'), findsOneWidget);
      expect(find.text('Phiếu in nhiệt quầy thu ngân (Cuộn 80mm)'), findsOneWidget);

      // Thử bấm lựa chọn 1 (Hóa đơn A4) và kiểm tra điều hướng sang DocumentPreviewScreen
      await tester.tap(find.text('Hóa đơn dịch vụ (Khổ A4)'));
      await tester.pumpAndSettle();

      expect(find.byType(DocumentPreviewScreen), findsOneWidget);
      expect(find.textContaining('Hóa đơn'), findsWidgets);
    });
  });
}
