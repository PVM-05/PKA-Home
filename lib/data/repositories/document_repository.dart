import 'dart:typed_data';
import 'package:pdf/widgets.dart' as pw;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_config.dart';
import '../../core/utils/document_pdf_builder.dart';
import '../models/document_lookup_result_model.dart';
import '../models/invoice_model.dart';

/// Repository xử lý tra cứu, đối soát chứng từ điện tử và ủy quyền sinh PDF (Milestone C4)
class DocumentRepository {
  final SupabaseClient? _injectedClient;

  DocumentRepository({SupabaseClient? client}) : _injectedClient = client;

  SupabaseClient? get _client {
    if (_injectedClient != null) return _injectedClient;
    try {
      return SupabaseConfig.client;
    } catch (_) {
      return null;
    }
  }

  /// Tra cứu tính xác thực của Hóa đơn hoặc Biên lai điện tử qua RPC `verify_document_lookup`
  Future<DocumentLookupResultModel> verifyLookupCode(String lookupCode) async {
    final cleanCode = lookupCode.trim().toUpperCase();

    if (cleanCode.isEmpty) {
      return DocumentLookupResultModel.invalid(
        'Mã tra cứu không được để trống',
        lookupCode: '',
      );
    }

    final client = _client;
    if (client == null) {
      return DocumentLookupResultModel.invalid(
        'Chưa kết nối cơ sở dữ liệu hoặc máy chủ quản lý',
        lookupCode: cleanCode,
      );
    }

    try {
      final response = await client.rpc(
        'verify_document_lookup',
        params: {'p_lookup_code': cleanCode},
      );

      if (response == null || response is! Map<String, dynamic>) {
        return DocumentLookupResultModel.invalid(
          'Dữ liệu phản hồi từ máy chủ không hợp lệ',
          lookupCode: cleanCode,
        );
      }

      return DocumentLookupResultModel.fromJson(response);
    } catch (e) {
      return DocumentLookupResultModel.invalid(
        'Đã xảy ra lỗi khi tra cứu chứng từ: $e',
        lookupCode: cleanCode,
      );
    }
  }

  /// Sinh file PDF mẫu A4 Hóa đơn thu phí dịch vụ
  Future<Uint8List> generateInvoicePdf({
    required InvoiceModel invoice,
    required List<Map<String, dynamic>> items,
    String buildingName = DocumentPdfBuilder.defaultBuildingName,
    String buildingAddress = DocumentPdfBuilder.defaultBuildingAddress,
    String hotline = DocumentPdfBuilder.defaultHotline,
    String bankBin = DocumentPdfBuilder.defaultBankBin,
    String bankName = DocumentPdfBuilder.defaultBankName,
    String bankAccount = DocumentPdfBuilder.defaultBankAccount,
    String? accountName,
    pw.Font? baseFont,
    pw.Font? boldFont,
  }) {
    return DocumentPdfBuilder.buildInvoicePdfA4(
      invoice: invoice,
      items: items,
      buildingName: buildingName,
      buildingAddress: buildingAddress,
      hotline: hotline,
      bankBin: bankBin,
      bankName: bankName,
      bankAccount: bankAccount,
      accountName: accountName,
      baseFont: baseFont,
      boldFont: boldFont,
    );
  }

  /// Sinh file PDF mẫu A4 Biên lai thu tiền điện tử kèm mộc số
  Future<Uint8List> generateReceiptPdfA4({
    required InvoiceModel invoice,
    required List<Map<String, dynamic>> items,
    String buildingName = DocumentPdfBuilder.defaultBuildingName,
    String buildingAddress = DocumentPdfBuilder.defaultBuildingAddress,
    String hotline = DocumentPdfBuilder.defaultHotline,
    pw.Font? baseFont,
    pw.Font? boldFont,
  }) {
    return DocumentPdfBuilder.buildReceiptPdfA4(
      invoice: invoice,
      items: items,
      buildingName: buildingName,
      buildingAddress: buildingAddress,
      hotline: hotline,
      baseFont: baseFont,
      boldFont: boldFont,
    );
  }

  /// Sinh file PDF mẫu in nhiệt cuộn 80mm tại quầy
  Future<Uint8List> generateReceiptPdf80mm({
    required InvoiceModel invoice,
    required List<Map<String, dynamic>> items,
    String buildingName = DocumentPdfBuilder.defaultBuildingName,
    String hotline = DocumentPdfBuilder.defaultHotline,
    pw.Font? baseFont,
    pw.Font? boldFont,
  }) {
    return DocumentPdfBuilder.buildReceiptPdf80mm(
      invoice: invoice,
      items: items,
      buildingName: buildingName,
      hotline: hotline,
      baseFont: baseFont,
      boldFont: boldFont,
    );
  }
}
