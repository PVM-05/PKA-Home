import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/apartment_model.dart';
import 'package:pka_home/data/models/invoice_model.dart';
import 'package:pka_home/data/services/accounting_export_service.dart';

void main() {
  group('AccountingExportService Tests', () {
    final sampleInvoices = [
      InvoiceModel(
        id: 'inv-001',
        apartmentId: 'apt-001',
        period: '10/2026',
        dueDate: DateTime(2026, 10, 25),
        totalAmount: 1500000,
        status: 'paid',
        createdAt: DateTime(2026, 10, 1),
        paidAt: DateTime(2026, 10, 15, 14, 30),
        paymentMethod: 'bank_transfer',
        transactionCode: 'TXN-001',
        receiptNumber: 'PT-202610-00001',
        einvoiceLookupCode: 'EINV0001',
        apartment: ApartmentModel(
          id: 'apt-001',
          code: 'A0110',
          buildingCode: 'A',
          floorNumber: 1,
          area: 72.5,
        ),
      ),
      InvoiceModel(
        id: 'inv-002',
        apartmentId: 'apt-002',
        period: '10/2026',
        dueDate: DateTime(2026, 10, 25),
        totalAmount: 850000,
        status: 'unpaid',
        createdAt: DateTime(2026, 10, 1),
        apartment: ApartmentModel(
          id: 'apt-002',
          code: 'A0201',
          buildingCode: 'A',
          floorNumber: 2,
          area: 55.0,
        ),
      ),
    ];

    test('generates valid Excel bytes with correct headers and rows', () {
      final service = AccountingExportService();
      final bytes = service.generateExcelBytes(
        invoices: sampleInvoices,
        buildingName: 'PKA Landmark 1',
        period: '10/2026',
      );

      expect(bytes, isNotEmpty);

      // Decode generated Excel to verify structure
      final excel = Excel.decodeBytes(bytes);
      expect(excel.tables.keys, contains('Báo cáo đối soát'));

      final sheet = excel.tables['Báo cáo đối soát']!;
      expect(sheet.maxRows, greaterThanOrEqualTo(3)); // Header + 2 data rows

      // Verify row 0 contains headers
      final headers = sheet.rows[0].map((cell) => cell?.value?.toString() ?? '').toList();
      expect(headers.any((h) => h.contains('Mã Căn Hộ')), isTrue);
      expect(headers.any((h) => h.contains('Tổng Tiền')), isTrue);
      expect(headers.any((h) => h.contains('Trạng Thái')), isTrue);

      // Verify row 1 contains A0110 data
      final row1 = sheet.rows[1].map((cell) => cell?.value?.toString() ?? '').toList();
      expect(row1.any((c) => c.contains('A0110')), isTrue);
      expect(row1.any((c) => c.contains('Đã thanh toán')), isTrue);

      // Verify row 2 contains A0201 data
      final row2 = sheet.rows[2].map((cell) => cell?.value?.toString() ?? '').toList();
      expect(row2.any((c) => c.contains('A0201')), isTrue);
      expect(row2.any((c) => c.contains('Chưa thanh toán')), isTrue);
    });
  });
}
