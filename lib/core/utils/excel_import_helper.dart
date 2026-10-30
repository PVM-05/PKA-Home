import 'dart:typed_data';
import 'package:excel/excel.dart';
import '../../data/models/batch_import_model.dart';

class ExcelImportHelper {
  static final RegExp apartmentCodeRegex = RegExp(r'^[A-Za-z]+[0-9]{4}$');
  static final RegExp phoneRegex = RegExp(r'^(03|05|07|08|09)[0-9]{8}$');

  /// Tạo file mẫu Excel cho Nhập căn hộ
  static Uint8List generateApartmentTemplate() {
    final excel = Excel.createExcel();
    final sheet = excel['Mau_Nhap_Can_Ho'];
    excel.delete('Sheet1');

    sheet.appendRow([
      TextCellValue('Mã Căn Hộ (*)'),
      TextCellValue('Diện Tích (m2) (*)'),
      TextCellValue('Trạng Thái Trống (Có/Không)'),
    ]);

    sheet.appendRow([
      TextCellValue('A0110'),
      DoubleCellValue(68.5),
      TextCellValue('Có'),
    ]);
    sheet.appendRow([
      TextCellValue('B0205'),
      DoubleCellValue(85.0),
      TextCellValue('Không'),
    ]);

    return Uint8List.fromList(excel.save()!);
  }

  /// Tạo file mẫu Excel cho Nhập danh sách cư dân
  static Uint8List generateResidentTemplate() {
    final excel = Excel.createExcel();
    final sheet = excel['Mau_Nhap_Cu_Dan'];
    excel.delete('Sheet1');

    sheet.appendRow([
      TextCellValue('Mã Căn Hộ (*)'),
      TextCellValue('Họ Và Tên (*)'),
      TextCellValue('Số Điện Thoại (*)'),
      TextCellValue('Vai Trò (Chủ hộ / Người thuê / Thành viên) (*)'),
      TextCellValue('Email'),
    ]);

    sheet.appendRow([
      TextCellValue('A0110'),
      TextCellValue('Nguyễn Văn An'),
      TextCellValue('0901234567'),
      TextCellValue('Chủ hộ'),
      TextCellValue('an.nguyen@example.com'),
    ]);
    sheet.appendRow([
      TextCellValue('A0110'),
      TextCellValue('Trần Thị Bình'),
      TextCellValue('0912345678'),
      TextCellValue('Thành viên gia đình'),
      TextCellValue(''),
    ]);
    sheet.appendRow([
      TextCellValue('B0205'),
      TextCellValue('Lê Văn Cường'),
      TextCellValue('0987654321'),
      TextCellValue('Người thuê'),
      TextCellValue('cuong.le@example.com'),
    ]);

    return Uint8List.fromList(excel.save()!);
  }

  /// Tạo file mẫu Excel cho Nhập chỉ số điện nước
  static Uint8List generateMeterReadingTemplate() {
    final excel = Excel.createExcel();
    final sheet = excel['Mau_Nhap_Chi_So_Dien_Nuoc'];
    excel.delete('Sheet1');

    sheet.appendRow([
      TextCellValue('Mã Căn Hộ (*)'),
      TextCellValue('Chỉ Số Điện (kWh) (*)'),
      TextCellValue('Chỉ Số Nước (m3) (*)'),
      TextCellValue('Kỳ Thu (YYYY-MM)'),
    ]);

    sheet.appendRow([
      TextCellValue('A0110'),
      DoubleCellValue(150.5),
      DoubleCellValue(24.0),
      TextCellValue('2026-10'),
    ]);
    sheet.appendRow([
      TextCellValue('B0205'),
      DoubleCellValue(210.0),
      DoubleCellValue(31.5),
      TextCellValue('2026-10'),
    ]);

    return Uint8List.fromList(excel.save()!);
  }

  /// Phân tích và thẩm định dữ liệu Căn hộ từ bytes Excel
  static BatchImportResultModel<ApartmentImportItem> parseAndValidateApartments(
    Uint8List bytes,
  ) {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) {
      return const BatchImportResultModel(
        totalRows: 0,
        validItems: [],
        rowErrors: [],
      );
    }

    final sheet = excel.tables[excel.tables.keys.first]!;
    final validItems = <ApartmentImportItem>[];
    final rowErrors = <BatchRowErrorModel>[];
    int processedDataRows = 0;

    // Bỏ qua dòng tiêu đề index 0
    for (int i = 1; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      if (_isRowEmpty(row)) continue;

      processedDataRows++;
      final rowNumber = i + 1;
      bool rowHasError = false;

      final rawCode = _cellToString(row.elementAtOrNull(0)).toUpperCase();
      final areaVal = _cellToDouble(row.elementAtOrNull(1));
      final rawEmpty = _cellToString(row.elementAtOrNull(2)).toLowerCase();

      // Thẩm định Mã căn hộ
      if (rawCode.isEmpty) {
        rowErrors.add(BatchRowErrorModel(
          rowNumber: rowNumber,
          columnName: 'Mã Căn Hộ',
          invalidValue: rawCode,
          errorMessage: 'Mã căn hộ không được để trống',
        ));
        rowHasError = true;
      } else if (!apartmentCodeRegex.hasMatch(rawCode)) {
        rowErrors.add(BatchRowErrorModel(
          rowNumber: rowNumber,
          columnName: 'Mã Căn Hộ',
          invalidValue: rawCode,
          errorMessage: 'Mã căn hộ không đúng định dạng chuẩn (VD: A0110, B0205)',
        ));
        rowHasError = true;
      }

      // Thẩm định Diện tích
      if (areaVal == null || areaVal <= 0) {
        rowErrors.add(BatchRowErrorModel(
          rowNumber: rowNumber,
          columnName: 'Diện Tích',
          invalidValue: _cellToString(row.elementAtOrNull(1)),
          errorMessage: 'Diện tích phải là số lớn hơn 0 m²',
        ));
        rowHasError = true;
      }

      if (!rowHasError) {
        final isEmptyApartment = rawEmpty.isEmpty ||
            rawEmpty == 'có' ||
            rawEmpty == 'co' ||
            rawEmpty == 'true' ||
            rawEmpty == '1';

        validItems.add(ApartmentImportItem(
          code: rawCode,
          area: areaVal!,
          isEmpty: isEmptyApartment,
        ));
      }
    }

    return BatchImportResultModel<ApartmentImportItem>(
      totalRows: processedDataRows,
      validItems: validItems,
      rowErrors: rowErrors,
    );
  }

  /// Phân tích và thẩm định dữ liệu Cư dân từ bytes Excel
  static BatchImportResultModel<ResidentImportItem> parseAndValidateResidents(
    Uint8List bytes, {
    Set<String>? existingApartmentCodes,
  }) {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) {
      return const BatchImportResultModel(
        totalRows: 0,
        validItems: [],
        rowErrors: [],
      );
    }

    final sheet = excel.tables[excel.tables.keys.first]!;
    final validItems = <ResidentImportItem>[];
    final rowErrors = <BatchRowErrorModel>[];
    int processedDataRows = 0;

    for (int i = 1; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      if (_isRowEmpty(row)) continue;

      processedDataRows++;
      final rowNumber = i + 1;
      bool rowHasError = false;

      final rawCode = _cellToString(row.elementAtOrNull(0)).toUpperCase();
      final rawName = _cellToString(row.elementAtOrNull(1));
      final rawPhone = _cellToString(row.elementAtOrNull(2)).replaceAll(' ', '').replaceAll('.', '');
      final rawRole = _cellToString(row.elementAtOrNull(3));
      final rawEmail = _cellToString(row.elementAtOrNull(4));

      // Thẩm định Mã căn hộ
      if (rawCode.isEmpty) {
        rowErrors.add(BatchRowErrorModel(
          rowNumber: rowNumber,
          columnName: 'Mã Căn Hộ',
          invalidValue: rawCode,
          errorMessage: 'Mã căn hộ không được để trống',
        ));
        rowHasError = true;
      } else if (existingApartmentCodes != null &&
          !existingApartmentCodes.contains(rawCode)) {
        rowErrors.add(BatchRowErrorModel(
          rowNumber: rowNumber,
          columnName: 'Mã Căn Hộ',
          invalidValue: rawCode,
          errorMessage: 'Căn hộ "$rawCode" không tồn tại trong hệ thống',
        ));
        rowHasError = true;
      }

      // Thẩm định Họ và tên
      if (rawName.isEmpty) {
        rowErrors.add(BatchRowErrorModel(
          rowNumber: rowNumber,
          columnName: 'Họ Và Tên',
          invalidValue: rawName,
          errorMessage: 'Họ và tên không được để trống',
        ));
        rowHasError = true;
      }

      // Thẩm định Số điện thoại
      if (rawPhone.isEmpty) {
        rowErrors.add(BatchRowErrorModel(
          rowNumber: rowNumber,
          columnName: 'Số Điện Thoại',
          invalidValue: rawPhone,
          errorMessage: 'Số điện thoại không được để trống',
        ));
        rowHasError = true;
      } else if (!phoneRegex.hasMatch(rawPhone)) {
        rowErrors.add(BatchRowErrorModel(
          rowNumber: rowNumber,
          columnName: 'Số Điện Thoại',
          invalidValue: rawPhone,
          errorMessage: 'Số điện thoại phải gồm 10 chữ số đúng định dạng Việt Nam (VD: 0901234567)',
        ));
        rowHasError = true;
      }

      if (!rowHasError) {
        final normalizedRole = _normalizeRelationRole(rawRole);
        validItems.add(ResidentImportItem(
          apartmentCode: rawCode,
          fullName: rawName,
          phone: rawPhone,
          relationRole: normalizedRole,
          email: rawEmail.isNotEmpty ? rawEmail : null,
        ));
      }
    }

    return BatchImportResultModel<ResidentImportItem>(
      totalRows: processedDataRows,
      validItems: validItems,
      rowErrors: rowErrors,
    );
  }

  /// Phân tích và thẩm định dữ liệu Chỉ số điện nước từ bytes Excel
  static BatchImportResultModel<MeterReadingImportItem> parseAndValidateMeterReadings(
    Uint8List bytes, {
    Set<String>? existingApartmentCodes,
  }) {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) {
      return const BatchImportResultModel(
        totalRows: 0,
        validItems: [],
        rowErrors: [],
      );
    }

    final sheet = excel.tables[excel.tables.keys.first]!;
    final validItems = <MeterReadingImportItem>[];
    final rowErrors = <BatchRowErrorModel>[];
    int processedDataRows = 0;

    for (int i = 1; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      if (_isRowEmpty(row)) continue;

      processedDataRows++;
      final rowNumber = i + 1;
      bool rowHasError = false;

      final rawCode = _cellToString(row.elementAtOrNull(0)).toUpperCase();
      final electricVal = _cellToDouble(row.elementAtOrNull(1));
      final waterVal = _cellToDouble(row.elementAtOrNull(2));
      final rawPeriod = _cellToString(row.elementAtOrNull(3));

      // Thẩm định Mã căn hộ
      if (rawCode.isEmpty) {
        rowErrors.add(BatchRowErrorModel(
          rowNumber: rowNumber,
          columnName: 'Mã Căn Hộ',
          invalidValue: rawCode,
          errorMessage: 'Mã căn hộ không được để trống',
        ));
        rowHasError = true;
      } else if (existingApartmentCodes != null &&
          !existingApartmentCodes.contains(rawCode)) {
        rowErrors.add(BatchRowErrorModel(
          rowNumber: rowNumber,
          columnName: 'Mã Căn Hộ',
          invalidValue: rawCode,
          errorMessage: 'Căn hộ "$rawCode" không tồn tại trong hệ thống',
        ));
        rowHasError = true;
      }

      // Thẩm định Chỉ số điện
      if (electricVal == null || electricVal < 0) {
        rowErrors.add(BatchRowErrorModel(
          rowNumber: rowNumber,
          columnName: 'Chỉ Số Điện',
          invalidValue: _cellToString(row.elementAtOrNull(1)),
          errorMessage: 'Chỉ số điện phải là số không âm (≥ 0)',
        ));
        rowHasError = true;
      }

      // Thẩm định Chỉ số nước
      if (waterVal == null || waterVal < 0) {
        rowErrors.add(BatchRowErrorModel(
          rowNumber: rowNumber,
          columnName: 'Chỉ Số Nước',
          invalidValue: _cellToString(row.elementAtOrNull(2)),
          errorMessage: 'Chỉ số nước phải là số không âm (≥ 0)',
        ));
        rowHasError = true;
      }

      if (!rowHasError) {
        validItems.add(MeterReadingImportItem(
          apartmentCode: rawCode,
          electricReading: electricVal!,
          waterReading: waterVal!,
          period: rawPeriod.isNotEmpty ? rawPeriod : null,
        ));
      }
    }

    return BatchImportResultModel<MeterReadingImportItem>(
      totalRows: processedDataRows,
      validItems: validItems,
      rowErrors: rowErrors,
    );
  }

  /// Xuất danh sách dòng bị lỗi ra file Excel để BQL sửa và nạp lại
  static Uint8List exportErrorRows(List<BatchRowErrorModel> errors) {
    final excel = Excel.createExcel();
    final sheet = excel['Danh_Sach_Loi'];
    excel.delete('Sheet1');

    sheet.appendRow([
      TextCellValue('Dòng'),
      TextCellValue('Cột Bị Lỗi'),
      TextCellValue('Giá Trị Không Hợp Lệ'),
      TextCellValue('Nguyên Nhân Lỗi'),
    ]);

    for (final err in errors) {
      sheet.appendRow([
        IntCellValue(err.rowNumber),
        TextCellValue(err.columnName),
        TextCellValue(err.invalidValue),
        TextCellValue(err.errorMessage),
      ]);
    }

    return Uint8List.fromList(excel.save()!);
  }

  // --- CÁC HÀM TIỆN ÍCH NỘI BỘ ---

  static bool _isRowEmpty(List<Data?> row) {
    if (row.isEmpty) return true;
    for (final cell in row) {
      if (cell != null && cell.value != null && _cellToString(cell).isNotEmpty) {
        return false;
      }
    }
    return true;
  }

  static String _cellToString(Data? cell) {
    if (cell == null || cell.value == null) return '';
    final val = cell.value!;
    if (val is TextCellValue) {
      return val.value.text?.trim() ?? val.value.toString().trim();
    }
    if (val is IntCellValue) return val.value.toString().trim();
    if (val is DoubleCellValue) return val.value.toString().trim();
    if (val is DateCellValue || val is DateTimeCellValue) return val.toString().trim();
    if (val is BoolCellValue) return val.value ? 'true' : 'false';
    return val.toString().trim();
  }

  static double? _cellToDouble(Data? cell) {
    if (cell == null || cell.value == null) return null;
    final val = cell.value!;
    if (val is DoubleCellValue) return val.value;
    if (val is IntCellValue) return val.value.toDouble();
    final str = _cellToString(cell).replaceAll(',', '.').replaceAll(' ', '');
    return double.tryParse(str);
  }

  static String _normalizeRelationRole(String rawRole) {
    final lower = rawRole.toLowerCase().trim();
    if (lower.contains('chủ hộ') || lower.contains('chu ho') || lower == 'owner') {
      return 'owner';
    }
    if (lower.contains('người thuê') || lower.contains('nguoi thue') || lower == 'tenant') {
      return 'tenant';
    }
    if (lower.contains('thành viên') ||
        lower.contains('thanh vien') ||
        lower.contains('family')) {
      return 'family_member';
    }
    return 'resident';
  }
}
