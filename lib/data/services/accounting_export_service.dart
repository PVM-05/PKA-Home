import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/invoice_model.dart';

/// Dịch vụ xuất dữ liệu đối soát kế toán và danh sách hóa đơn theo chuẩn Excel (.xlsx)
class AccountingExportService {
  /// Sinh dữ liệu byte file Excel đối soát kế toán
  Uint8List generateExcelBytes({
    required List<InvoiceModel> invoices,
    required String buildingName,
    required String period,
  }) {
    final excel = Excel.createExcel();
    const sheetName = 'Báo cáo đối soát';
    final sheet = excel[sheetName];

    // Xóa sheet mặc định nếu có
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    final formatDate = DateFormat('dd/MM/yyyy');
    final formatDateTime = DateFormat('dd/MM/yyyy HH:mm');

    // Header bảng tính
    sheet.appendRow([
      TextCellValue('STT'),
      TextCellValue('Mã Căn Hộ'),
      TextCellValue('Tầng'),
      TextCellValue('Diện Tích (m2)'),
      TextCellValue('Kỳ Phí'),
      TextCellValue('Hạn Thanh Toán'),
      TextCellValue('Tổng Tiền (VND)'),
      TextCellValue('Trạng Thái'),
      TextCellValue('Hình Thức Thanh Toán'),
      TextCellValue('Mã Giao Dịch'),
      TextCellValue('Số Biên Lai'),
      TextCellValue('Thời Gian Thu Tiền'),
    ]);

    for (int i = 0; i < invoices.length; i++) {
      final inv = invoices[i];

      String statusText;
      switch (inv.status) {
        case 'paid':
          statusText = 'Đã thanh toán';
          break;
        case 'pending_confirmation':
          statusText = 'Chờ BQL xác nhận';
          break;
        case 'unpaid':
        default:
          statusText = 'Chưa thanh toán';
          break;
      }

      String paymentMethodText = '';
      if (inv.paymentMethod != null) {
        final pm = inv.paymentMethod!.toLowerCase();
        if (pm.contains('cash') || pm.contains('tiền mặt')) {
          paymentMethodText = 'Tiền mặt';
        } else if (pm.contains('bank') || pm.contains('transfer') || pm.contains('vietqr')) {
          paymentMethodText = 'Chuyển khoản VietQR';
        } else {
          paymentMethodText = inv.paymentMethod!;
        }
      }

      sheet.appendRow([
        IntCellValue(i + 1),
        TextCellValue(inv.apartment?.code ?? ''),
        IntCellValue(inv.apartment?.floorNumber ?? 1),
        DoubleCellValue(inv.apartment?.area ?? 0.0),
        TextCellValue(inv.period),
        TextCellValue(formatDate.format(inv.dueDate)),
        DoubleCellValue(inv.totalAmount),
        TextCellValue(statusText),
        TextCellValue(paymentMethodText),
        TextCellValue(inv.transactionCode ?? ''),
        TextCellValue(inv.status == 'paid' ? inv.displayReceiptNumber : ''),
        TextCellValue(inv.paidAt != null ? formatDateTime.format(inv.paidAt!) : ''),
      ]);
    }

    final bytes = excel.save();
    return Uint8List.fromList(bytes ?? []);
  }

  /// Xuất file Excel và gọi popup chia sẻ / lưu trữ trên thiết bị
  Future<String?> exportAndShare({
    required List<InvoiceModel> invoices,
    required String buildingName,
    required String period,
  }) async {
    final bytes = generateExcelBytes(
      invoices: invoices,
      buildingName: buildingName,
      period: period,
    );

    final tempDir = await getTemporaryDirectory();
    final sanitizedPeriod = period.replaceAll('/', '_');
    final fileName = 'Bao_cao_doi_soat_${sanitizedPeriod}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    final filePath = '${tempDir.path}/$fileName';
    final file = File(filePath);
    await file.writeAsBytes(bytes);

    await Share.shareXFiles(
      [XFile(filePath)],
      text: 'Báo cáo đối soát kế toán $buildingName - Kỳ $period',
    );

    return filePath;
  }
}
