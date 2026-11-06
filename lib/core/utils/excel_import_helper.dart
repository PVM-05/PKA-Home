import 'dart:convert';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import '../../data/models/batch_import_model.dart';

class ExcelImportHelper {
  /// Regex chuẩn theo coding-rules.md: Block + Tầng 2 chữ số + Phòng 2 chữ số (VD: A0110, B0205)
  static final RegExp apartmentCodeRegex = RegExp(r'^[A-Za-z]+[0-9]{4}$');
  static final RegExp phoneRegex = RegExp(r'^(03|05|07|08|09)[0-9]{8}$');

  /// Chuẩn hóa mã phòng về định dạng chuẩn A0110 (Block + Tầng 2 chữ số + Phòng 2 chữ số)
  /// Ví dụ:
  /// - 'a0110' -> 'A0110'
  /// - 'A101'  -> 'A0101' (tự động thêm số 0 cho tầng 1 chữ số)
  /// - 'a110'  -> 'A0110'
  /// - 'b0205' -> 'B0205'
  /// - 'B-205' -> 'B0205'
  /// - 'A.01.10' -> 'A0110'
  static String normalizeApartmentCode(String raw) {
    var trimmed = raw.trim();
    if (trimmed.isEmpty) return '';

    // Loại bỏ các ký tự ngăn cách phổ biến như '-', '.', '_', khoảng trắng
    final cleaned = trimmed.replaceAll(RegExp(r'[\s\.\-_]+'), '');

    // 1. Kiểm tra mẫu: Block (chữ cái) + Tầng (1 hoặc 2 chữ số) + Phòng (2 chữ số)
    final match = RegExp(r'^([A-Za-z]+)(\d{1,2})(\d{2})$').firstMatch(cleaned);
    if (match != null) {
      final block = match.group(1)!.toUpperCase();
      final floor = match.group(2)!.padLeft(2, '0');
      final room = match.group(3)!;
      return '$block$floor$room';
    }

    // Nếu không khớp pattern phân tách trên, giữ nguyên dạng viết hoa để validator đánh giá
    return cleaned.toUpperCase();
  }

  // ==========================================
  // 1. CÁC HÀM TẠO FILE MẪU EXCEL (.XLSX)
  // ==========================================

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

  // ==========================================
  // 2. CÁC HÀM TẠO FILE MẪU CSV (.CSV)
  // ==========================================

  /// Tạo file mẫu CSV cho Nhập căn hộ (BOM UTF-8 để mở tiếng Việt chuẩn trên Excel Windows)
  static Uint8List generateApartmentCsvTemplate() {
    const csv = '\uFEFFMã Căn Hộ (*),Diện Tích (m2) (*),Trạng Thái Trống (Có/Không)\r\n'
        'A0110,68.5,Có\r\n'
        'B0205,85.0,Không\r\n';
    return Uint8List.fromList(utf8.encode(csv));
  }

  /// Tạo file mẫu CSV cho Nhập danh sách cư dân
  static Uint8List generateResidentCsvTemplate() {
    const csv = '\uFEFFMã Căn Hộ (*),Họ Và Tên (*),Số Điện Thoại (*),Vai Trò (Chủ hộ / Người thuê / Thành viên) (*),Email\r\n'
        'A0110,Nguyễn Văn An,0901234567,Chủ hộ,an.nguyen@example.com\r\n'
        'A0110,Trần Thị Bình,0912345678,Thành viên gia đình,\r\n'
        'B0205,Lê Văn Cường,0987654321,Người thuê,cuong.le@example.com\r\n';
    return Uint8List.fromList(utf8.encode(csv));
  }

  /// Tạo file mẫu CSV cho Nhập chỉ số điện nước
  static Uint8List generateMeterReadingCsvTemplate() {
    const csv = '\uFEFFMã Căn Hộ (*),Chỉ Số Điện (kWh) (*),Chỉ Số Nước (m3) (*),Kỳ Thu (YYYY-MM)\r\n'
        'A0110,150.5,24.0,2026-10\r\n'
        'B0205,210.0,31.5,2026-10\r\n';
    return Uint8List.fromList(utf8.encode(csv));
  }

  // ==========================================
  // 3. PARSER & VALIDATOR (HỖ TRỢ CẢ EXCEL VÀ CSV)
  // ==========================================

  /// Phân tích và thẩm định dữ liệu Căn hộ từ bytes (hỗ trợ .xlsx, .xls, .csv)
  static BatchImportResultModel<ApartmentImportItem> parseAndValidateApartments(
    Uint8List bytes, {
    String? fileName,
  }) {
    if (_isCsv(bytes, fileName)) {
      return _parseAndValidateApartmentsFromCsv(bytes);
    }

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

      final rawCode = _cellToString(row.elementAtOrNull(0));
      final areaVal = _cellToDouble(row.elementAtOrNull(1));
      final rawEmpty = _cellToString(row.elementAtOrNull(2)).toLowerCase();

      // Chuẩn hóa mã căn hộ
      final normalizedCode = normalizeApartmentCode(rawCode);

      // Thẩm định Mã căn hộ
      if (rawCode.isEmpty) {
        rowErrors.add(
          BatchRowErrorModel(
            rowNumber: rowNumber,
            columnName: 'Mã Căn Hộ',
            invalidValue: rawCode,
            errorMessage: 'Mã căn hộ không được để trống',
          ),
        );
        rowHasError = true;
      } else if (!apartmentCodeRegex.hasMatch(normalizedCode)) {
        rowErrors.add(
          BatchRowErrorModel(
            rowNumber: rowNumber,
            columnName: 'Mã Căn Hộ',
            invalidValue: rawCode,
            errorMessage:
                'Mã căn hộ không đúng định dạng chuẩn A0110 (Block + Tầng 2 chữ số + Phòng 2 chữ số, VD: A0110, B0205)',
          ),
        );
        rowHasError = true;
      }

      // Thẩm định Diện tích
      if (areaVal == null || areaVal <= 0) {
        rowErrors.add(
          BatchRowErrorModel(
            rowNumber: rowNumber,
            columnName: 'Diện Tích',
            invalidValue: _cellToString(row.elementAtOrNull(1)),
            errorMessage: 'Diện tích phải là số lớn hơn 0 m²',
          ),
        );
        rowHasError = true;
      }

      if (!rowHasError) {
        final isEmptyApartment =
            rawEmpty.isEmpty ||
            rawEmpty == 'có' ||
            rawEmpty == 'co' ||
            rawEmpty == 'true' ||
            rawEmpty == '1';

        validItems.add(
          ApartmentImportItem(
            code: normalizedCode,
            area: areaVal!,
            isEmpty: isEmptyApartment,
          ),
        );
      }
    }

    return BatchImportResultModel<ApartmentImportItem>(
      totalRows: processedDataRows,
      validItems: validItems,
      rowErrors: rowErrors,
    );
  }

  /// Phân tích và thẩm định dữ liệu Cư dân từ bytes (hỗ trợ .xlsx, .xls, .csv)
  static BatchImportResultModel<ResidentImportItem> parseAndValidateResidents(
    Uint8List bytes, {
    String? fileName,
    Set<String>? existingApartmentCodes,
  }) {
    if (_isCsv(bytes, fileName)) {
      return _parseAndValidateResidentsFromCsv(
        bytes,
        existingApartmentCodes: existingApartmentCodes,
      );
    }

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

      final rawCode = _cellToString(row.elementAtOrNull(0));
      final rawName = _cellToString(row.elementAtOrNull(1));
      final rawPhone = _cellToString(
        row.elementAtOrNull(2),
      ).replaceAll(' ', '').replaceAll('.', '');
      final rawRole = _cellToString(row.elementAtOrNull(3));
      final rawEmail = _cellToString(row.elementAtOrNull(4));

      final normalizedCode = normalizeApartmentCode(rawCode);

      // Thẩm định Mã căn hộ
      if (rawCode.isEmpty) {
        rowErrors.add(
          BatchRowErrorModel(
            rowNumber: rowNumber,
            columnName: 'Mã Căn Hộ',
            invalidValue: rawCode,
            errorMessage: 'Mã căn hộ không được để trống',
          ),
        );
        rowHasError = true;
      } else if (!apartmentCodeRegex.hasMatch(normalizedCode)) {
        rowErrors.add(
          BatchRowErrorModel(
            rowNumber: rowNumber,
            columnName: 'Mã Căn Hộ',
            invalidValue: rawCode,
            errorMessage:
                'Mã căn hộ không đúng định dạng chuẩn A0110 (Block + Tầng 2 chữ số + Phòng 2 chữ số, VD: A0110, B0205)',
          ),
        );
        rowHasError = true;
      } else if (existingApartmentCodes != null &&
          !existingApartmentCodes.contains(normalizedCode)) {
        rowErrors.add(
          BatchRowErrorModel(
            rowNumber: rowNumber,
            columnName: 'Mã Căn Hộ',
            invalidValue: rawCode,
            errorMessage: 'Căn hộ "$normalizedCode" không tồn tại trong hệ thống',
          ),
        );
        rowHasError = true;
      }

      // Thẩm định Họ và tên
      if (rawName.isEmpty) {
        rowErrors.add(
          BatchRowErrorModel(
            rowNumber: rowNumber,
            columnName: 'Họ Và Tên',
            invalidValue: rawName,
            errorMessage: 'Họ và tên không được để trống',
          ),
        );
        rowHasError = true;
      }

      // Thẩm định Số điện thoại
      if (rawPhone.isEmpty) {
        rowErrors.add(
          BatchRowErrorModel(
            rowNumber: rowNumber,
            columnName: 'Số Điện Thoại',
            invalidValue: rawPhone,
            errorMessage: 'Số điện thoại không được để trống',
          ),
        );
        rowHasError = true;
      } else if (!phoneRegex.hasMatch(rawPhone)) {
        rowErrors.add(
          BatchRowErrorModel(
            rowNumber: rowNumber,
            columnName: 'Số Điện Thoại',
            invalidValue: rawPhone,
            errorMessage:
                'Số điện thoại phải gồm 10 chữ số đúng định dạng Việt Nam (VD: 0901234567)',
          ),
        );
        rowHasError = true;
      }

      if (!rowHasError) {
        final normalizedRole = _normalizeRelationRole(rawRole);
        validItems.add(
          ResidentImportItem(
            apartmentCode: normalizedCode,
            fullName: rawName,
            phone: rawPhone,
            relationRole: normalizedRole,
            email: rawEmail.isNotEmpty ? rawEmail : null,
          ),
        );
      }
    }

    return BatchImportResultModel<ResidentImportItem>(
      totalRows: processedDataRows,
      validItems: validItems,
      rowErrors: rowErrors,
    );
  }

  /// Phân tích và thẩm định dữ liệu Chỉ số điện nước từ bytes (hỗ trợ .xlsx, .xls, .csv)
  static BatchImportResultModel<MeterReadingImportItem>
  parseAndValidateMeterReadings(
    Uint8List bytes, {
    String? fileName,
    Set<String>? existingApartmentCodes,
  }) {
    if (_isCsv(bytes, fileName)) {
      return _parseAndValidateMeterReadingsFromCsv(
        bytes,
        existingApartmentCodes: existingApartmentCodes,
      );
    }

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

      final rawCode = _cellToString(row.elementAtOrNull(0));
      final electricVal = _cellToDouble(row.elementAtOrNull(1));
      final waterVal = _cellToDouble(row.elementAtOrNull(2));
      final rawPeriod = _cellToString(row.elementAtOrNull(3));

      final normalizedCode = normalizeApartmentCode(rawCode);

      // Thẩm định Mã căn hộ
      if (rawCode.isEmpty) {
        rowErrors.add(
          BatchRowErrorModel(
            rowNumber: rowNumber,
            columnName: 'Mã Căn Hộ',
            invalidValue: rawCode,
            errorMessage: 'Mã căn hộ không được để trống',
          ),
        );
        rowHasError = true;
      } else if (!apartmentCodeRegex.hasMatch(normalizedCode)) {
        rowErrors.add(
          BatchRowErrorModel(
            rowNumber: rowNumber,
            columnName: 'Mã Căn Hộ',
            invalidValue: rawCode,
            errorMessage:
                'Mã căn hộ không đúng định dạng chuẩn A0110 (Block + Tầng 2 chữ số + Phòng 2 chữ số, VD: A0110, B0205)',
          ),
        );
        rowHasError = true;
      } else if (existingApartmentCodes != null &&
          !existingApartmentCodes.contains(normalizedCode)) {
        rowErrors.add(
          BatchRowErrorModel(
            rowNumber: rowNumber,
            columnName: 'Mã Căn Hộ',
            invalidValue: rawCode,
            errorMessage: 'Căn hộ "$normalizedCode" không tồn tại trong hệ thống',
          ),
        );
        rowHasError = true;
      }

      // Thẩm định Chỉ số điện
      if (electricVal == null || electricVal < 0) {
        rowErrors.add(
          BatchRowErrorModel(
            rowNumber: rowNumber,
            columnName: 'Chỉ Số Điện',
            invalidValue: _cellToString(row.elementAtOrNull(1)),
            errorMessage: 'Chỉ số điện phải là số không âm (≥ 0)',
          ),
        );
        rowHasError = true;
      }

      // Thẩm định Chỉ số nước
      if (waterVal == null || waterVal < 0) {
        rowErrors.add(
          BatchRowErrorModel(
            rowNumber: rowNumber,
            columnName: 'Chỉ Số Nước',
            invalidValue: _cellToString(row.elementAtOrNull(2)),
            errorMessage: 'Chỉ số nước phải là số không âm (≥ 0)',
          ),
        );
        rowHasError = true;
      }

      if (!rowHasError) {
        validItems.add(
          MeterReadingImportItem(
            apartmentCode: normalizedCode,
            electricReading: electricVal!,
            waterReading: waterVal!,
            period: rawPeriod.isNotEmpty ? rawPeriod : null,
          ),
        );
      }
    }

    return BatchImportResultModel<MeterReadingImportItem>(
      totalRows: processedDataRows,
      validItems: validItems,
      rowErrors: rowErrors,
    );
  }

  // ==========================================
  // 4. PARSER NỘI BỘ CHO CSV
  // ==========================================

  static BatchImportResultModel<ApartmentImportItem>
  _parseAndValidateApartmentsFromCsv(Uint8List bytes) {
    final rows = _parseCsvRows(bytes);
    if (rows.length <= 1) {
      return const BatchImportResultModel(
        totalRows: 0,
        validItems: [],
        rowErrors: [],
      );
    }

    final validItems = <ApartmentImportItem>[];
    final rowErrors = <BatchRowErrorModel>[];
    int processedDataRows = 0;

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty || row.every((c) => c.trim().isEmpty)) continue;

      processedDataRows++;
      final rowNumber = i + 1;
      bool rowHasError = false;

      final rawCode = row.isNotEmpty ? row[0].trim() : '';
      final rawArea = row.length > 1 ? row[1].trim() : '';
      final rawEmpty = row.length > 2 ? row[2].trim().toLowerCase() : '';

      final normalizedCode = normalizeApartmentCode(rawCode);
      final areaVal = double.tryParse(rawArea.replaceAll(',', '.').replaceAll(' ', ''));

      // Thẩm định Mã căn hộ
      if (rawCode.isEmpty) {
        rowErrors.add(
          BatchRowErrorModel(
            rowNumber: rowNumber,
            columnName: 'Mã Căn Hộ',
            invalidValue: rawCode,
            errorMessage: 'Mã căn hộ không được để trống',
          ),
        );
        rowHasError = true;
      } else if (!apartmentCodeRegex.hasMatch(normalizedCode)) {
        rowErrors.add(
          BatchRowErrorModel(
            rowNumber: rowNumber,
            columnName: 'Mã Căn Hộ',
            invalidValue: rawCode,
            errorMessage:
                'Mã căn hộ không đúng định dạng chuẩn A0110 (Block + Tầng 2 chữ số + Phòng 2 chữ số, VD: A0110, B0205)',
          ),
        );
        rowHasError = true;
      }

      // Thẩm định Diện tích
      if (areaVal == null || areaVal <= 0) {
        rowErrors.add(
          BatchRowErrorModel(
            rowNumber: rowNumber,
            columnName: 'Diện Tích',
            invalidValue: rawArea,
            errorMessage: 'Diện tích phải là số lớn hơn 0 m²',
          ),
        );
        rowHasError = true;
      }

      if (!rowHasError) {
        final isEmptyApartment =
            rawEmpty.isEmpty ||
            rawEmpty == 'có' ||
            rawEmpty == 'co' ||
            rawEmpty == 'true' ||
            rawEmpty == '1';

        validItems.add(
          ApartmentImportItem(
            code: normalizedCode,
            area: areaVal!,
            isEmpty: isEmptyApartment,
          ),
        );
      }
    }

    return BatchImportResultModel<ApartmentImportItem>(
      totalRows: processedDataRows,
      validItems: validItems,
      rowErrors: rowErrors,
    );
  }

  static BatchImportResultModel<ResidentImportItem>
  _parseAndValidateResidentsFromCsv(
    Uint8List bytes, {
    Set<String>? existingApartmentCodes,
  }) {
    final rows = _parseCsvRows(bytes);
    if (rows.length <= 1) {
      return const BatchImportResultModel(
        totalRows: 0,
        validItems: [],
        rowErrors: [],
      );
    }

    final validItems = <ResidentImportItem>[];
    final rowErrors = <BatchRowErrorModel>[];
    int processedDataRows = 0;

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty || row.every((c) => c.trim().isEmpty)) continue;

      processedDataRows++;
      final rowNumber = i + 1;
      bool rowHasError = false;

      final rawCode = row.isNotEmpty ? row[0].trim() : '';
      final rawName = row.length > 1 ? row[1].trim() : '';
      final rawPhone = row.length > 2
          ? row[2].replaceAll(' ', '').replaceAll('.', '').trim()
          : '';
      final rawRole = row.length > 3 ? row[3].trim() : '';
      final rawEmail = row.length > 4 ? row[4].trim() : '';

      final normalizedCode = normalizeApartmentCode(rawCode);

      // Thẩm định Mã căn hộ
      if (rawCode.isEmpty) {
        rowErrors.add(
          BatchRowErrorModel(
            rowNumber: rowNumber,
            columnName: 'Mã Căn Hộ',
            invalidValue: rawCode,
            errorMessage: 'Mã căn hộ không được để trống',
          ),
        );
        rowHasError = true;
      } else if (!apartmentCodeRegex.hasMatch(normalizedCode)) {
        rowErrors.add(
          BatchRowErrorModel(
            rowNumber: rowNumber,
            columnName: 'Mã Căn Hộ',
            invalidValue: rawCode,
            errorMessage:
                'Mã căn hộ không đúng định dạng chuẩn A0110 (Block + Tầng 2 chữ số + Phòng 2 chữ số, VD: A0110, B0205)',
          ),
        );
        rowHasError = true;
      } else if (existingApartmentCodes != null &&
          !existingApartmentCodes.contains(normalizedCode)) {
        rowErrors.add(
          BatchRowErrorModel(
            rowNumber: rowNumber,
            columnName: 'Mã Căn Hộ',
            invalidValue: rawCode,
            errorMessage: 'Căn hộ "$normalizedCode" không tồn tại trong hệ thống',
          ),
        );
        rowHasError = true;
      }

      // Thẩm định Họ và tên
      if (rawName.isEmpty) {
        rowErrors.add(
          BatchRowErrorModel(
            rowNumber: rowNumber,
            columnName: 'Họ Và Tên',
            invalidValue: rawName,
            errorMessage: 'Họ và tên không được để trống',
          ),
        );
        rowHasError = true;
      }

      // Thẩm định Số điện thoại
      if (rawPhone.isEmpty) {
        rowErrors.add(
          BatchRowErrorModel(
            rowNumber: rowNumber,
            columnName: 'Số Điện Thoại',
            invalidValue: rawPhone,
            errorMessage: 'Số điện thoại không được để trống',
          ),
        );
        rowHasError = true;
      } else if (!phoneRegex.hasMatch(rawPhone)) {
        rowErrors.add(
          BatchRowErrorModel(
            rowNumber: rowNumber,
            columnName: 'Số Điện Thoại',
            invalidValue: rawPhone,
            errorMessage:
                'Số điện thoại phải gồm 10 chữ số đúng định dạng Việt Nam (VD: 0901234567)',
          ),
        );
        rowHasError = true;
      }

      if (!rowHasError) {
        final normalizedRole = _normalizeRelationRole(rawRole);
        validItems.add(
          ResidentImportItem(
            apartmentCode: normalizedCode,
            fullName: rawName,
            phone: rawPhone,
            relationRole: normalizedRole,
            email: rawEmail.isNotEmpty ? rawEmail : null,
          ),
        );
      }
    }

    return BatchImportResultModel<ResidentImportItem>(
      totalRows: processedDataRows,
      validItems: validItems,
      rowErrors: rowErrors,
    );
  }

  static BatchImportResultModel<MeterReadingImportItem>
  _parseAndValidateMeterReadingsFromCsv(
    Uint8List bytes, {
    Set<String>? existingApartmentCodes,
  }) {
    final rows = _parseCsvRows(bytes);
    if (rows.length <= 1) {
      return const BatchImportResultModel(
        totalRows: 0,
        validItems: [],
        rowErrors: [],
      );
    }

    final validItems = <MeterReadingImportItem>[];
    final rowErrors = <BatchRowErrorModel>[];
    int processedDataRows = 0;

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty || row.every((c) => c.trim().isEmpty)) continue;

      processedDataRows++;
      final rowNumber = i + 1;
      bool rowHasError = false;

      final rawCode = row.isNotEmpty ? row[0].trim() : '';
      final rawElectric = row.length > 1 ? row[1].trim() : '';
      final rawWater = row.length > 2 ? row[2].trim() : '';
      final rawPeriod = row.length > 3 ? row[3].trim() : '';

      final normalizedCode = normalizeApartmentCode(rawCode);
      final electricVal = double.tryParse(rawElectric.replaceAll(',', '.').replaceAll(' ', ''));
      final waterVal = double.tryParse(rawWater.replaceAll(',', '.').replaceAll(' ', ''));

      // Thẩm định Mã căn hộ
      if (rawCode.isEmpty) {
        rowErrors.add(
          BatchRowErrorModel(
            rowNumber: rowNumber,
            columnName: 'Mã Căn Hộ',
            invalidValue: rawCode,
            errorMessage: 'Mã căn hộ không được để trống',
          ),
        );
        rowHasError = true;
      } else if (!apartmentCodeRegex.hasMatch(normalizedCode)) {
        rowErrors.add(
          BatchRowErrorModel(
            rowNumber: rowNumber,
            columnName: 'Mã Căn Hộ',
            invalidValue: rawCode,
            errorMessage:
                'Mã căn hộ không đúng định dạng chuẩn A0110 (Block + Tầng 2 chữ số + Phòng 2 chữ số, VD: A0110, B0205)',
          ),
        );
        rowHasError = true;
      } else if (existingApartmentCodes != null &&
          !existingApartmentCodes.contains(normalizedCode)) {
        rowErrors.add(
          BatchRowErrorModel(
            rowNumber: rowNumber,
            columnName: 'Mã Căn Hộ',
            invalidValue: rawCode,
            errorMessage: 'Căn hộ "$normalizedCode" không tồn tại trong hệ thống',
          ),
        );
        rowHasError = true;
      }

      // Thẩm định Chỉ số điện
      if (electricVal == null || electricVal < 0) {
        rowErrors.add(
          BatchRowErrorModel(
            rowNumber: rowNumber,
            columnName: 'Chỉ Số Điện',
            invalidValue: rawElectric,
            errorMessage: 'Chỉ số điện phải là số không âm (≥ 0)',
          ),
        );
        rowHasError = true;
      }

      // Thẩm định Chỉ số nước
      if (waterVal == null || waterVal < 0) {
        rowErrors.add(
          BatchRowErrorModel(
            rowNumber: rowNumber,
            columnName: 'Chỉ Số Nước',
            invalidValue: rawWater,
            errorMessage: 'Chỉ số nước phải là số không âm (≥ 0)',
          ),
        );
        rowHasError = true;
      }

      if (!rowHasError) {
        validItems.add(
          MeterReadingImportItem(
            apartmentCode: normalizedCode,
            electricReading: electricVal!,
            waterReading: waterVal!,
            period: rawPeriod.isNotEmpty ? rawPeriod : null,
          ),
        );
      }
    }

    return BatchImportResultModel<MeterReadingImportItem>(
      totalRows: processedDataRows,
      validItems: validItems,
      rowErrors: rowErrors,
    );
  }

  // ==========================================
  // 5. XUẤT FILE LỖI EXCEL & CSV
  // ==========================================

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

  /// Xuất danh sách dòng bị lỗi ra file CSV
  static Uint8List exportErrorRowsCsv(List<BatchRowErrorModel> errors) {
    final buffer = StringBuffer();
    buffer.writeln('\uFEFFDòng,Cột Bị Lỗi,Giá Trị Không Hợp Lệ,Nguyên Nhân Lỗi');
    for (final err in errors) {
      final sanitizedCol = _escapeCsv(err.columnName);
      final sanitizedVal = _escapeCsv(err.invalidValue);
      final sanitizedMsg = _escapeCsv(err.errorMessage);
      buffer.writeln('${err.rowNumber},$sanitizedCol,$sanitizedVal,$sanitizedMsg');
    }
    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }

  // --- CÁC HÀM TIỆN ÍCH NỘI BỘ ---

  static bool _isCsv(Uint8List bytes, String? fileName) {
    if (fileName != null && fileName.toLowerCase().endsWith('.csv')) {
      return true;
    }
    // Nhận diện qua byte signatures (Excel thường bắt đầu bằng PK.. cho zip/xlsx)
    if (bytes.length >= 2 && bytes[0] == 0x50 && bytes[1] == 0x4B) {
      return false; // ZIP/XLSX
    }
    // Nếu có UTF-8 BOM hoặc text có thể decode
    try {
      final decoded = utf8.decode(bytes, allowMalformed: false);
      return decoded.contains(',') || decoded.contains(';');
    } catch (_) {
      return false;
    }
  }

  static List<List<String>> _parseCsvRows(Uint8List bytes) {
    String text;
    try {
      text = utf8.decode(bytes);
    } catch (_) {
      text = utf8.decode(bytes, allowMalformed: true);
    }

    // Bỏ BOM nếu có
    if (text.startsWith('\uFEFF')) {
      text = text.substring(1);
    }

    final lines = text.split(RegExp(r'\r\n|\n|\r'));
    final result = <List<String>>[];

    // Tự động nhận diện dấu phân cách từ dòng đầu tiên
    String delimiter = ',';
    if (lines.isNotEmpty) {
      final firstLine = lines.first;
      final commaCount = ','.allMatches(firstLine).length;
      final semicolonCount = ';'.allMatches(firstLine).length;
      if (semicolonCount > commaCount) {
        delimiter = ';';
      }
    }

    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      result.add(_parseCsvLine(line, delimiter));
    }

    return result;
  }

  static List<String> _parseCsvLine(String line, String delimiter) {
    final values = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];

      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++; // Bỏ qua dấu nháy kép escape
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == delimiter && !inQuotes) {
        values.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    values.add(buffer.toString());
    return values;
  }

  static String _escapeCsv(String value) {
    if (value.contains(',') || value.contains(';') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  static bool _isRowEmpty(List<Data?> row) {
    if (row.isEmpty) return true;
    for (final cell in row) {
      if (cell != null &&
          cell.value != null &&
          _cellToString(cell).isNotEmpty) {
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
    if (val is DateCellValue || val is DateTimeCellValue) {
      return val.toString().trim();
    }
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
    if (lower.contains('chủ hộ') ||
        lower.contains('chu ho') ||
        lower == 'owner') {
      return 'owner';
    }
    if (lower.contains('người thuê') ||
        lower.contains('nguoi thue') ||
        lower == 'tenant') {
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
