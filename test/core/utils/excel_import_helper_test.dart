import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:excel/excel.dart';
import 'package:pka_home/core/utils/excel_import_helper.dart';
import 'package:pka_home/data/models/batch_import_model.dart';

void main() {
  group('ExcelImportHelper Tests', () {
    test('normalizeApartmentCode correctly standardizes variations to A0110 format', () {
      // Đúng chuẩn viết hoa
      expect(ExcelImportHelper.normalizeApartmentCode('A0110'), 'A0110');
      // Viết thường -> viết hoa
      expect(ExcelImportHelper.normalizeApartmentCode('a0110'), 'A0110');
      // Dạng cũ 3 chữ số (tầng 1 chữ số) -> tự động thêm 0 thành 2 chữ số
      expect(ExcelImportHelper.normalizeApartmentCode('A101'), 'A0101');
      expect(ExcelImportHelper.normalizeApartmentCode('a110'), 'A0110');
      expect(ExcelImportHelper.normalizeApartmentCode('b205'), 'B0205');
      // Dấu gạch nối hoặc dấu chấm
      expect(ExcelImportHelper.normalizeApartmentCode('B-205'), 'B0205');
      expect(ExcelImportHelper.normalizeApartmentCode('A.01.10'), 'A0110');
      expect(ExcelImportHelper.normalizeApartmentCode(' a 01 10 '), 'A0110');
      // Rỗng hoặc sai cấu trúc
      expect(ExcelImportHelper.normalizeApartmentCode(''), '');
      expect(ExcelImportHelper.normalizeApartmentCode('XYZ'), 'XYZ');
    });

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

    test('generateApartmentCsvTemplate creates UTF-8 BOM csv bytes with headers', () {
      final bytes = ExcelImportHelper.generateApartmentCsvTemplate();
      expect(bytes, isNotEmpty);

      // Kiểm tra 3 byte UTF-8 BOM [0xEF, 0xBB, 0xBF]
      expect(bytes.length, greaterThanOrEqualTo(3));
      expect(bytes[0], 0xEF);
      expect(bytes[1], 0xBB);
      expect(bytes[2], 0xBF);

      final text = utf8.decode(bytes);
      expect(text, contains('Mã Căn Hộ (*)'));
      expect(text, contains('Diện Tích (m2) (*)'));
      expect(text, contains('A0110,68.5,Có'));
    });

    test('generateResidentCsvTemplate and generateMeterReadingCsvTemplate create valid csv bytes', () {
      final resBytes = ExcelImportHelper.generateResidentCsvTemplate();
      final resText = utf8.decode(resBytes);
      expect(resText, contains('Họ Và Tên (*)'));
      expect(resText, contains('0901234567'));

      final meterBytes = ExcelImportHelper.generateMeterReadingCsvTemplate();
      final meterText = utf8.decode(meterBytes);
      expect(meterText, contains('Chỉ Số Điện (kWh) (*)'));
      expect(meterText, contains('150.5'));
    });

    test('parseAndValidateApartments succeeds on valid Excel rows and normalizes codes', () {
      final excel = Excel.createExcel();
      final sheet = excel['Sheet1'];
      // Header
      sheet.appendRow([
        TextCellValue('Mã Căn Hộ'),
        TextCellValue('Diện Tích (m2)'),
        TextCellValue('Trạng Thái Trống'),
      ]);
      // Valid row 1: A0110
      sheet.appendRow([
        TextCellValue('A0110'),
        DoubleCellValue(68.5),
        TextCellValue('Có'),
      ]);
      // Valid row 2: a101 (sẽ tự chuẩn hóa thành A0101)
      sheet.appendRow([
        TextCellValue('a101'),
        DoubleCellValue(72.0),
        TextCellValue('Không'),
      ]);
      // Invalid row 3 (Invalid format code)
      sheet.appendRow([
        TextCellValue('XYZ'),
        DoubleCellValue(70.0),
        TextCellValue('Không'),
      ]);
      // Invalid row 4 (Invalid negative area)
      sheet.appendRow([
        TextCellValue('B0205'),
        DoubleCellValue(-15.0),
        TextCellValue('Có'),
      ]);

      final bytes = Uint8List.fromList(excel.save()!);
      final result = ExcelImportHelper.parseAndValidateApartments(bytes);

      expect(result.totalRows, 4);
      expect(result.validCount, 2);
      expect(result.errorCount, 2);
      expect(result.validItems[0].code, 'A0110');
      expect(result.validItems[0].area, 68.5);
      expect(result.validItems[0].isEmpty, isTrue);
      expect(result.validItems[1].code, 'A0101');
      expect(result.validItems[1].area, 72.0);
      expect(result.validItems[1].isEmpty, isFalse);

      final errors = result.rowErrors;
      expect(errors.any((e) => e.rowNumber == 4 && e.columnName.contains('Mã Căn Hộ')), isTrue);
      expect(errors.any((e) => e.rowNumber == 5 && e.columnName.contains('Diện Tích')), isTrue);
    });

    test('parseAndValidateApartments correctly parses CSV bytes', () {
      const csvContent =
          'Mã Căn Hộ,Diện Tích,Trạng Thái Trống\r\n'
          'a0110,65.5,Có\r\n'
          'B205,80.0,Không\r\n'
          'SAI_DINH_DANG,50.0,Có\r\n';

      final bytes = Uint8List.fromList(utf8.encode(csvContent));
      final result = ExcelImportHelper.parseAndValidateApartments(bytes, fileName: 'data.csv');

      expect(result.totalRows, 3);
      expect(result.validCount, 2);
      expect(result.errorCount, 1);
      expect(result.validItems[0].code, 'A0110');
      expect(result.validItems[0].area, 65.5);
      expect(result.validItems[1].code, 'B0205');
      expect(result.validItems[1].isEmpty, isFalse);
      expect(result.rowErrors.first.columnName, contains('Mã Căn Hộ'));
    });

    test('parseAndValidateResidents parses CSV bytes with role normalization and checks', () {
      const csvContent =
          'Mã Căn Hộ,Họ Và Tên,Số Điện Thoại,Vai Trò,Email\r\n'
          'a0110,Nguyễn Văn An,0901234567,Chủ hộ,an@test.com\r\n'
          'b0205,Trần Thị Bình,0987654321,Người thuê,binh@test.com\r\n'
          'A0110,Lê Văn Lỗi,01234,Chủ hộ,\r\n';

      final bytes = Uint8List.fromList(utf8.encode(csvContent));
      final result = ExcelImportHelper.parseAndValidateResidents(
        bytes,
        fileName: 'residents.csv',
        existingApartmentCodes: {'A0110', 'B0205'},
      );

      expect(result.totalRows, 3);
      expect(result.validCount, 2);
      expect(result.errorCount, 1);
      expect(result.validItems[0].apartmentCode, 'A0110');
      expect(result.validItems[0].relationRole, 'owner');
      expect(result.validItems[1].apartmentCode, 'B0205');
      expect(result.validItems[1].relationRole, 'tenant');
      expect(result.rowErrors.first.columnName, contains('Số Điện Thoại'));
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

    test('exportErrorRowsCsv produces valid csv bytes containing error details', () {
      const errors = [
        BatchRowErrorModel(
          rowNumber: 2,
          columnName: 'Mã Căn Hộ',
          invalidValue: 'XYZ',
          errorMessage: 'Sai định dạng chuẩn',
        ),
      ];

      final bytes = ExcelImportHelper.exportErrorRowsCsv(errors);
      expect(bytes, isNotEmpty);
      expect(bytes[0], 0xEF);
      expect(bytes[1], 0xBB);
      expect(bytes[2], 0xBF);

      final text = utf8.decode(bytes);
      expect(text, contains('Dòng,Cột Bị Lỗi'));
      expect(text, contains('2,Mã Căn Hộ,XYZ,Sai định dạng chuẩn'));
    });
  });
}
