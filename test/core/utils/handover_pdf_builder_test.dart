import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pka_home/core/utils/handover_pdf_builder.dart';
import 'package:pka_home/data/models/apartment_handover_model.dart';
import 'package:pka_home/data/models/handover_item_model.dart';

void main() {
  group('HandoverPdfBuilder Tests', () {
    test('buildHandoverReportPdf sinh byte data PDF hợp lệ', () async {
      final handover = ApartmentHandoverModel(
        id: 'ho-01',
        apartmentId: 'apt-01',
        buildingId: 'bld-01',
        residentId: 'res-01',
        handoverType: 'move_out',
        reportCode: 'HO-202611-00001',
        handoverDate: DateTime(2026, 11, 7),
        conductedBy: 'staff-01',
        initialElectricityReading: 1540.0,
        initialWaterReading: 85.0,
        depositHeld: 10000000.0,
        totalDeduction: 1200000.0,
        depositRefund: 8800000.0,
        status: 'confirmed',
        lookupCode: 'HK-98A1B2C3D4',
        apartmentCode: 'A0110',
        residentName: 'Nguyễn Văn An',
        staffName: 'Trần Kỹ Thuật',
      );

      final items = [
        const HandoverItemModel(
          id: 'item-01',
          handoverId: 'ho-01',
          itemName: 'Điều hòa Daikin 1.5HP',
          roomArea: 'bedroom',
          quantity: 1,
          condition: 'good',
        ),
        const HandoverItemModel(
          id: 'item-02',
          handoverId: 'ho-01',
          itemName: 'Mặt bàn trà phòng khách',
          roomArea: 'living_room',
          quantity: 1,
          condition: 'damaged',
          repairCost: 500000.0,
          note: 'Vết xước sâu',
        ),
      ];

      final pdfBytes = await HandoverPdfBuilder.buildHandoverReportPdf(
        handover: handover,
        items: items,
        buildingName: 'Chung cư PKA-Home Thăng Long',
        baseFont: pw.Font.helvetica(),
        boldFont: pw.Font.helveticaBold(),
      );

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.isNotEmpty, isTrue);

      // Kiểm tra magic number chuẩn của file PDF: %PDF- (0x25, 0x50, 0x44, 0x46, 0x2D)
      expect(pdfBytes.sublist(0, 5), Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2D]));
    });
  });
}
