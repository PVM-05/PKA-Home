import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/utils/excel_export_helper.dart';
import '../../core/utils/excel_import_helper.dart';
import '../models/batch_import_model.dart';
import '../repositories/batch_import_repository.dart';

final batchImportRepositoryProvider = Provider<BatchImportRepository>((ref) {
  return BatchImportRepository();
});

class BatchImportState {
  final BatchImportType selectedType;
  final String? selectedFileName;
  final Uint8List? fileBytes;
  final BatchImportResultModel? validationResult;
  final bool importOnlyValidRows;
  final bool isProcessing;
  final String? errorMessage;
  final String? successMessage;

  const BatchImportState({
    this.selectedType = BatchImportType.apartments,
    this.selectedFileName,
    this.fileBytes,
    this.validationResult,
    this.importOnlyValidRows = false,
    this.isProcessing = false,
    this.errorMessage,
    this.successMessage,
  });

  BatchImportState copyWith({
    BatchImportType? selectedType,
    String? selectedFileName,
    Uint8List? fileBytes,
    BatchImportResultModel? validationResult,
    bool? importOnlyValidRows,
    bool? isProcessing,
    String? errorMessage,
    String? successMessage,
    bool clearValidation = false,
    bool clearMessages = false,
    bool clearFile = false,
  }) {
    return BatchImportState(
      selectedType: selectedType ?? this.selectedType,
      selectedFileName: clearFile ? null : (selectedFileName ?? this.selectedFileName),
      fileBytes: clearFile ? null : (fileBytes ?? this.fileBytes),
      validationResult: clearValidation ? null : (validationResult ?? this.validationResult),
      importOnlyValidRows: importOnlyValidRows ?? this.importOnlyValidRows,
      isProcessing: isProcessing ?? this.isProcessing,
      errorMessage: clearMessages ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearMessages ? null : (successMessage ?? this.successMessage),
    );
  }
}

class BatchImportNotifier extends StateNotifier<BatchImportState> {
  final BatchImportRepository _repository;

  BatchImportNotifier(this._repository) : super(const BatchImportState());

  void selectType(BatchImportType type) {
    if (state.selectedType == type) return;
    state = state.copyWith(
      selectedType: type,
      clearFile: true,
      clearValidation: true,
      clearMessages: true,
      importOnlyValidRows: false,
    );
  }

  void toggleImportOnlyValidRows(bool val) {
    state = state.copyWith(importOnlyValidRows: val);
  }

  void reset() {
    state = state.copyWith(
      clearFile: true,
      clearValidation: true,
      clearMessages: true,
      importOnlyValidRows: false,
      isProcessing: false,
    );
  }

  /// Mở hộp thoại chọn file Excel/CSV và phân tích thẩm định dữ liệu
  Future<void> pickAndParseFile({required String buildingId}) async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
      );

      if (files.isEmpty) return;

      final file = files.first;
      final bytes = await file.readAsBytes();

      if (bytes.isEmpty) {
        state = state.copyWith(
          errorMessage: 'Không thể đọc nội dung file đã chọn',
          clearMessages: false,
        );
        return;
      }

      await parseBytes(bytes: bytes, fileName: file.name, buildingId: buildingId);
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Lỗi khi đọc file: $e',
      );
    }
  }

  /// Phân tích thẩm định bytes trực tiếp (hỗ trợ cả chọn file và test)
  Future<void> parseBytes({
    required Uint8List bytes,
    required String fileName,
    required String buildingId,
  }) async {
    state = state.copyWith(
      isProcessing: true,
      clearMessages: true,
    );

    try {
      Set<String>? existingCodes;
      if (state.selectedType != BatchImportType.apartments) {
        existingCodes = await _repository.fetchExistingApartmentCodes(buildingId);
      }

      BatchImportResultModel validationResult;
      switch (state.selectedType) {
        case BatchImportType.apartments:
          validationResult = ExcelImportHelper.parseAndValidateApartments(
            bytes,
            fileName: fileName,
          );
          break;
        case BatchImportType.residents:
          validationResult = ExcelImportHelper.parseAndValidateResidents(
            bytes,
            fileName: fileName,
            existingApartmentCodes: existingCodes,
          );
          break;
        case BatchImportType.meterReadings:
          validationResult = ExcelImportHelper.parseAndValidateMeterReadings(
            bytes,
            fileName: fileName,
            existingApartmentCodes: existingCodes,
          );
          break;
      }

      state = state.copyWith(
        selectedFileName: fileName,
        fileBytes: bytes,
        validationResult: validationResult,
        isProcessing: false,
        clearMessages: true,
      );
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        errorMessage: 'Lỗi khi kiểm tra dữ liệu: $e',
      );
    }
  }

  /// Thực thi nạp dữ liệu vào cơ sở dữ liệu qua Repository & RPC
  Future<bool> executeImport({required String buildingId}) async {
    final validation = state.validationResult;
    if (validation == null || !validation.hasValidItems) {
      state = state.copyWith(
        errorMessage: 'Không có dòng dữ liệu hợp lệ nào để nạp vào hệ thống',
      );
      return false;
    }

    if (validation.hasErrors && !state.importOnlyValidRows) {
      state = state.copyWith(
        errorMessage:
            'Tập tin chứa ${validation.errorCount} dòng bị lỗi. Vui lòng bật "Chỉ nạp các dòng hợp lệ" hoặc sửa lại file trước khi nạp.',
      );
      return false;
    }

    state = state.copyWith(
      isProcessing: true,
      clearMessages: true,
    );

    try {
      Map<String, dynamic> response;
      switch (state.selectedType) {
        case BatchImportType.apartments:
          final items = validation.validItems.cast<ApartmentImportItem>();
          response = await _repository.importApartments(
            buildingId: buildingId,
            apartments: items,
          );
          break;

        case BatchImportType.residents:
          final items = validation.validItems.cast<ResidentImportItem>();
          response = await _repository.importResidents(
            buildingId: buildingId,
            residents: items,
          );
          break;

        case BatchImportType.meterReadings:
          final items = validation.validItems.cast<MeterReadingImportItem>();
          response = await _repository.importMeterReadings(
            buildingId: buildingId,
            readings: items,
          );
          break;
      }

      final isSuccess = response['success'] == true;
      final msg = response['message']?.toString() ??
          (isSuccess ? 'Đã nạp dữ liệu thành công' : 'Đã xảy ra sự cố khi nạp');

      if (isSuccess) {
        state = state.copyWith(
          isProcessing: false,
          successMessage: msg,
          clearValidation: true,
          clearFile: true,
        );
        return true;
      } else {
        state = state.copyWith(
          isProcessing: false,
          errorMessage: msg,
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        errorMessage: 'Lỗi khi gọi máy chủ: $e',
      );
      return false;
    }
  }

  /// Tải file mẫu Excel và chia sẻ
  Future<String?> downloadTemplate(BatchImportType type) async {
    try {
      Uint8List bytes;
      switch (type) {
        case BatchImportType.apartments:
          bytes = ExcelImportHelper.generateApartmentTemplate();
          break;
        case BatchImportType.residents:
          bytes = ExcelImportHelper.generateResidentTemplate();
          break;
        case BatchImportType.meterReadings:
          bytes = ExcelImportHelper.generateMeterReadingTemplate();
          break;
      }

      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd').format(DateTime.now());
      final filePath = '${dir.path}/${type.fileNamePrefix}_$timestamp.xlsx';

      final file = File(filePath);
      await file.create(recursive: true);
      await file.writeAsBytes(bytes);

      await ExcelExportHelper.shareFile(
        filePath,
        subject: 'Mẫu nhập liệu ${type.label} (Excel)',
        text: 'File mẫu nhập liệu Excel cho ${type.label}',
      );

      return filePath;
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Lỗi khi tạo file mẫu Excel: $e',
      );
      return null;
    }
  }

  /// Tải file mẫu CSV và chia sẻ
  Future<String?> downloadCsvTemplate(BatchImportType type) async {
    try {
      Uint8List bytes;
      switch (type) {
        case BatchImportType.apartments:
          bytes = ExcelImportHelper.generateApartmentCsvTemplate();
          break;
        case BatchImportType.residents:
          bytes = ExcelImportHelper.generateResidentCsvTemplate();
          break;
        case BatchImportType.meterReadings:
          bytes = ExcelImportHelper.generateMeterReadingCsvTemplate();
          break;
      }

      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd').format(DateTime.now());
      final filePath = '${dir.path}/${type.fileNamePrefix}_$timestamp.csv';

      final file = File(filePath);
      await file.create(recursive: true);
      await file.writeAsBytes(bytes);

      await ExcelExportHelper.shareFile(
        filePath,
        subject: 'Mẫu nhập liệu ${type.label} (CSV)',
        text: 'File mẫu nhập liệu CSV cho ${type.label}',
      );

      return filePath;
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Lỗi khi tạo file mẫu CSV: $e',
      );
      return null;
    }
  }

  /// Xuất danh sách dòng lỗi ra file Excel để người dùng xem và sửa
  Future<String?> exportErrorRows() async {
    final validation = state.validationResult;
    if (validation == null || !validation.hasErrors) return null;

    try {
      final bytes = ExcelImportHelper.exportErrorRows(validation.rowErrors);
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filePath = '${dir.path}/Danh_Sach_Loi_Nhap_${state.selectedType.label}_$timestamp.xlsx';

      final file = File(filePath);
      await file.create(recursive: true);
      await file.writeAsBytes(bytes);

      await ExcelExportHelper.shareFile(
        filePath,
        subject: 'Danh sách dòng lỗi nhập ${state.selectedType.label} (Excel)',
        text: 'Tập tin danh sách dòng bị lỗi kèm giải thích nguyên nhân',
      );

      return filePath;
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Lỗi khi xuất file lỗi: $e',
      );
      return null;
    }
  }

  /// Xuất danh sách dòng lỗi ra file CSV
  Future<String?> exportErrorRowsCsv() async {
    final validation = state.validationResult;
    if (validation == null || !validation.hasErrors) return null;

    try {
      final bytes = ExcelImportHelper.exportErrorRowsCsv(validation.rowErrors);
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filePath = '${dir.path}/Danh_Sach_Loi_Nhap_${state.selectedType.label}_$timestamp.csv';

      final file = File(filePath);
      await file.create(recursive: true);
      await file.writeAsBytes(bytes);

      await ExcelExportHelper.shareFile(
        filePath,
        subject: 'Danh sách dòng lỗi nhập ${state.selectedType.label} (CSV)',
        text: 'Tập tin danh sách dòng bị lỗi dạng CSV',
      );

      return filePath;
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Lỗi khi xuất file lỗi CSV: $e',
      );
      return null;
    }
  }
}

final batchImportProvider =
    StateNotifierProvider<BatchImportNotifier, BatchImportState>((ref) {
  final repo = ref.watch(batchImportRepositoryProvider);
  return BatchImportNotifier(repo);
});
