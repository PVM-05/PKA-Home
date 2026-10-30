import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:excel/excel.dart';
import 'package:pka_home/core/utils/excel_import_helper.dart';
import 'package:pka_home/data/models/batch_import_model.dart';

void main() {
  group('ExcelImportHelper Tests', () {
    test('generateApartmentTemplate creates valid excel bytes with headers and sample row', () {
      final bytes = ExcelImportHelper.generateApartmentTemplate();
      expect(bytes, isNotEmpty);

      final excel = Excel.decodeBytes(bytes);
      expect(excel.tables.isNotEmpty, isTrue);

      final sheet = excel.tables[excel.tables.keys.first]!;
      expect(sheet.maxRows, greaterThanOrEqualTo(2));

      // Header row
      final headers = sheet.rows[0].map((c) => c?.value?.toString() ?? '').toList();
      expect(headers[0], contains('Mã Căn Hộ'));
      expect(headers[1], contains('Diện Tích'));
    });

    test('parseAndValidateApartments succeeds on valid rows and reports row errors on invalid data', () {
      final excel = Excel.createExcel();
      final sheet = excel['Sheet1'];
      // Header
      sheet.appendRow([
        TextCellValue('Mã Căn Hộ'),
        TextCellValue('Diện Tích (m2)'),
        TextCellValue('Trạng Thái Trống'),
      ]);
      // Valid row 1
      sheet.appendRow([
        TextCellValue('A0110'),
        DoubleCellValue(68.5),
        TextCellValue('Có'),
      ]);
      // Invalid row 2 (Invalid format code)
      sheet.appendRow([
        TextCellValue('XYZ'),
        DoubleCellValue(70.0),
        TextCellValue('Không'),
      ]);
      // Invalid row 3 (Invalid negative area)
      sheet.appendRow([
        TextCellValue('B0205'),
        DoubleCellValue(-15.0),
        TextCellValue('Có'),
      ]);

      final bytes = Uint8List.fromList(excel.save()!);
      final result = ExcelImportHelper.parseAndValidateApartments(bytes);

      expect(result.totalRows, 3);
      expect(result.validCount, 1);
      expect(result.errorCount, 2);
      expect(result.validItems.first.code, 'A0110');
      expect(result.validItems.first.area, 68.5);
      expect(result.validItems.first.isEmpty, isTrue);

      final errors = result.rowErrors;
      expect(errors.any((e) => e.rowNumber == 3 && e.columnName.contains('Mã Căn Hộ')), isTrue);
      expect(errors.any((e) => e.rowNumber == 4 && e.columnName.contains('Diện Tích')), isTrue);
    });

    test('parseAndValidateResidents validates phone, role and apartment existence', () {
      final excel = Excel.createExcel();
      final sheet = excel['Sheet1'];
      sheet.appendRow([
        TextCellValue('Mã Căn Hộ'),
        TextCellValue('Họ Và Tên'),
        TextCellValue('Số Điện Thoại'),
        TextCellValue('Vai Trò'),
        TextCellValue('Email'),
      ]);
      // Valid row 1
      sheet.appendRow([
        TextCellValue('A0110'),
        TextCellValue('Nguyễn Văn An'),
        TextCellValue('0901234567'),
        TextCellValue('Chủ hộ'),
        TextCellValue('an@example.com'),
      ]);
      // Invalid row 2 (Phone invalid length)
      sheet.appendRow([
        TextCellValue('A0110'),
        TextCellValue('Trần Thị Bình'),
        TextCellValue('09012'),
        TextCellValue('Người thuê'),
        TextCellValue('binh@example.com'),
      ]);
      // Invalid row 3 (Apartment does not exist)
      sheet.appendRow([
        TextCellValue('C9999'),
        TextCellValue('Lê Văn Cường'),
        TextCellValue('0912345678'),
        TextCellValue('Cư dân'),
        TextCellValue(''),
      ]);

      final bytes = Uint8List.fromList(excel.save()!);
      final result = ExcelImportHelper.parseAndValidateResidents(
        bytes,
        existingApartmentCodes: {'A0110', 'B0205'},
      );

      expect(result.totalRows, 3);
      expect(result.validCount, 1);
      expect(result.errorCount, 2);
      expect(result.validItems.first.fullName, 'Nguyễn Văn An');
      expect(result.validItems.first.relationRole, 'owner');

      final errors = result.rowErrors;
      expect(errors.any((e) => e.rowNumber == 3 && e.columnName.contains('Số Điện Thoại')), isTrue);
      expect(errors.any((e) => e.rowNumber == 4 && e.columnName.contains('Mã Căn Hộ')), isTrue);
    });

    test('parseAndValidateMeterReadings validates non-negative readings and apartment codes', () {
      final excel = Excel.createExcel();
      final sheet = excel['Sheet1'];
      sheet.appendRow([
        TextCellValue('Mã Căn Hộ'),
        TextCellValue('Chỉ Số Điện (kWh)'),
        TextCellValue('Chỉ Số Nước (m3)'),
        TextCellValue('Kỳ Thu (YYYY-MM)'),
      ]);
      // Valid row
      sheet.appendRow([
        TextCellValue('A0110'),
        DoubleCellValue(145.2),
        DoubleCellValue(22.0),
        TextCellValue('2026-10'),
      ]);
      // Negative reading row
      sheet.appendRow([
        TextCellValue('A0110'),
        DoubleCellValue(-5.0),
        DoubleCellValue(10.0),
        TextCellValue('2026-10'),
      ]);

      final bytes = Uint8List.fromList(excel.save()!);
      final result = ExcelImportHelper.parseAndValidateMeterReadings(
        bytes,
        existingApartmentCodes: {'A0110'},
      );

      expect(result.totalRows, 2);
      expect(result.validCount, 1);
      expect(result.errorCount, 1);
      expect(result.validItems.first.electricReading, 145.2);
      expect(result.validItems.first.waterReading, 22.0);
      expect(result.rowErrors.first.columnName, contains('Chỉ Số Điện'));
    });

    test('exportErrorRows produces excel bytes containing error details', () {
      const errors = [
        BatchRowErrorModel(
          rowNumber: 2,
          columnName: 'Mã Căn Hộ',
          invalidValue: 'XYZ',
          errorMessage: 'Sai định dạng chuẩn',
        ),
      ];

      final bytes = ExcelImportHelper.exportErrorRows(errors);
      expect(bytes, isNotEmpty);

      final excel = Excel.decodeBytes(bytes);
      final sheet = excel.tables[excel.tables.keys.first]!;
      expect(sheet.maxRows, 2); // Header + 1 row
    });
  });
}
