import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pka_home/core/utils/document_pdf_builder.dart';
import 'package:pka_home/data/models/apartment_model.dart';
import 'package:pka_home/data/models/invoice_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InvoiceModel sampleUnpaidInvoice;
  late InvoiceModel samplePaidInvoice;
  late List<Map<String, dynamic>> sampleItems;

  setUp(() {
    final apartment = ApartmentModel(
      id: 'apt-01',
      code: 'A0110',
      buildingCode: 'A',
      floorNumber: 1,
      area: 68.5,
      isEmpty: false,
    );

    sampleUnpaidInvoice = InvoiceModel(
      id: 'inv-12345678-unpaid',
      apartmentId: 'apt-01',
      period: '10/2026',
      dueDate: DateTime(2026, 11, 15),
      totalAmount: 1850000,
      status: 'unpaid',
      createdAt: DateTime(2026, 10, 25, 9, 30),
      apartment: apartment,
      paymentCode: 'INV202610A0110',
      einvoiceLookupCode: 'PKAINV98765432',
    );

    samplePaidInvoice = InvoiceModel(
      id: 'inv-87654321-paid',
      apartmentId: 'apt-01',
      period: '10/2026',
      dueDate: DateTime(2026, 11, 15),
      totalAmount: 1850000,
      paidAmount: 1850000,
      status: 'paid',
      createdAt: DateTime(2026, 10, 25, 9, 30),
      paidAt: DateTime(2026, 10, 28, 14, 25, 30),
      paymentMethod: 'VietQR Napas 247',
      transactionCode: 'TXN202610281425',
      receiptNumber: 'PT-202610-81425',
      einvoiceLookupCode: 'PKAINV98765432',
      apartment: apartment,
      paymentCode: 'INV202610A0110',
    );

    sampleItems = [
      {
        'fee_type': 'management',
        'unit_price': 10000,
        'quantity': 68.5,
        'subtotal': 685000,
      },
      {
        'fee_type': 'electricity',
        'unit_price': 3000,
        'quantity': 150,
        'subtotal': 450000,
      },
      {
        'fee_type': 'water',
        'unit_price': 15000,
        'quantity': 15,
        'subtotal': 225000,
      },
      {
        'fee_type': 'parking_motorbike',
        'unit_price': 120000,
        'quantity': 2,
        'subtotal': 240000,
      },
      {
        'fee_type': 'parking_car',
        'unit_price': 250000,
        'quantity': 1,
        'subtotal': 250000,
      },
    ];
  });

  bool isValidPdf(Uint8List bytes) {
    if (bytes.length < 5) return false;
    final header = String.fromCharCodes(bytes.sublist(0, 5));
    return header == '%PDF-';
  }

  group('DocumentPdfBuilder - TDD Unit Tests', () {
    test('1. buildInvoicePdfA4 generates valid A4 PDF for unpaid invoice', () async {
      final bytes = await DocumentPdfBuilder.buildInvoicePdfA4(
        invoice: sampleUnpaidInvoice,
        items: sampleItems,
      );

      expect(bytes, isA<Uint8List>());
      expect(bytes.isNotEmpty, isTrue);
      expect(isValidPdf(bytes), isTrue);
      expect(bytes.length, greaterThan(1000));
    });

    test('2. buildInvoicePdfA4 generates valid A4 PDF for paid invoice', () async {
      final bytes = await DocumentPdfBuilder.buildInvoicePdfA4(
        invoice: samplePaidInvoice,
        items: sampleItems,
      );

      expect(bytes, isA<Uint8List>());
      expect(bytes.isNotEmpty, isTrue);
      expect(isValidPdf(bytes), isTrue);
      expect(bytes.length, greaterThan(1000));
    });

    test('3. buildReceiptPdfA4 generates valid A4 receipt PDF with digital stamp for paid invoice', () async {
      final bytes = await DocumentPdfBuilder.buildReceiptPdfA4(
        invoice: samplePaidInvoice,
        items: sampleItems,
      );

      expect(bytes, isA<Uint8List>());
      expect(bytes.isNotEmpty, isTrue);
      expect(isValidPdf(bytes), isTrue);
      expect(bytes.length, greaterThan(1000));
    });

    test('4. buildReceiptPdf80mm generates valid 80mm thermal roll PDF', () async {
      final bytes = await DocumentPdfBuilder.buildReceiptPdf80mm(
        invoice: samplePaidInvoice,
        items: sampleItems,
      );

      expect(bytes, isA<Uint8List>());
      expect(bytes.isNotEmpty, isTrue);
      expect(isValidPdf(bytes), isTrue);
      expect(bytes.length, greaterThan(500));
    });

    test('5. handles empty items list and missing optional fields without crashing', () async {
      final bareInvoice = InvoiceModel(
        id: 'bare-inv',
        apartmentId: 'unknown-apt',
        period: '09/2026',
        dueDate: DateTime(2026, 10, 10),
        totalAmount: 0,
        status: 'unpaid',
        createdAt: DateTime(2026, 9, 1),
      );

      final invoiceBytes = await DocumentPdfBuilder.buildInvoicePdfA4(
        invoice: bareInvoice,
        items: [],
      );
      expect(isValidPdf(invoiceBytes), isTrue);

      final receiptBytes = await DocumentPdfBuilder.buildReceiptPdfA4(
        invoice: bareInvoice,
        items: [],
      );
      expect(isValidPdf(receiptBytes), isTrue);

      final rollBytes = await DocumentPdfBuilder.buildReceiptPdf80mm(
        invoice: bareInvoice,
        items: [],
      );
      expect(isValidPdf(rollBytes), isTrue);
    });

    test('6. supports custom fonts and safe fallback without throwing unhandled exceptions', () async {
      final customBaseFont = pw.Font.helvetica();
      final customBoldFont = pw.Font.helveticaBold();

      final bytes = await DocumentPdfBuilder.buildInvoicePdfA4(
        invoice: sampleUnpaidInvoice,
        items: sampleItems,
        baseFont: customBaseFont,
        boldFont: customBoldFont,
      );

      expect(isValidPdf(bytes), isTrue);
      expect(bytes.isNotEmpty, isTrue);
    });

    test('7. stripDiacritics safely strips accents and currency symbols', () {
      const input = 'BAN QUẢN LÝ CHUNG CƯ PKA-HOME 1.250.000 đ';
      final output = DocumentPdfBuilder.stripDiacritics(input);
      expect(output, equals('BAN QUAN LY CHUNG CU PKA-HOME 1.250.000 d'));
    });
  });
}
