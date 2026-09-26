import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../../data/models/invoice_model.dart';
import '../../data/models/issue_model.dart';

class ExcelExportHelper {
  /// Xuất danh sách Hóa đơn ra file .xlsx
  static Future<String?> exportInvoices(List<InvoiceModel> invoices) async {
    try {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Danh Sách Hóa Đơn'];
      excel.delete('Sheet1'); // Remove default sheet
      
      // Header
      sheetObject.appendRow([
        TextCellValue('Mã Căn Hộ'),
        TextCellValue('Kỳ Thu'),
        TextCellValue('Tổng Tiền (VNĐ)'),
        TextCellValue('Trạng Thái'),
        TextCellValue('Hạn Thanh Toán'),
      ]);

      final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '');
      final dateFormat = DateFormat('dd/MM/yyyy');

      for (var invoice in invoices) {
        String statusText = '';
        switch(invoice.status) {
          case 'paid': statusText = 'Đã thanh toán'; break;
          case 'unpaid': statusText = 'Chưa thanh toán'; break;
          case 'pending_confirmation': statusText = 'Chờ xác nhận'; break;
          case 'overdue': statusText = 'Quá hạn'; break;
          default: statusText = invoice.status;
        }

        sheetObject.appendRow([
          TextCellValue(invoice.apartment?.code ?? ''),
          TextCellValue(invoice.period),
          TextCellValue(currencyFormat.format(invoice.totalAmount)),
          TextCellValue(statusText),
          TextCellValue(dateFormat.format(invoice.dueDate)),
        ]);
      }

      var fileBytes = excel.save();
      
      if (fileBytes != null) {
        final directory = await getApplicationDocumentsDirectory();
        final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
        final filePath = '${directory.path}/HoaDon_$timestamp.xlsx';
        
        File(filePath)
          ..createSync(recursive: true)
          ..writeAsBytesSync(fileBytes);
          
        return filePath;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Xuất danh sách Sự cố & Phản ánh ra file .xlsx
  static Future<String?> exportIssues(List<IssueModel> issues) async {
    try {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Báo Cáo Sự Cố'];
      excel.delete('Sheet1'); // Remove default sheet

      // Header
      sheetObject.appendRow([
        TextCellValue('Mã Sự Cố'),
        TextCellValue('Căn Hộ'),
        TextCellValue('Người Báo Cáo'),
        TextCellValue('Nội Dung Sự Cố'),
        TextCellValue('Mức Độ Ưu Tiên'),
        TextCellValue('Trạng Thái'),
        TextCellValue('Nhân Viên Xử Lý'),
        TextCellValue('Thời Gian Tiếp Nhận'),
        TextCellValue('Cập Nhật Lần Cuối'),
      ]);

      final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

      for (var issue in issues) {
        String statusText = '';
        switch (issue.status) {
          case 'pending':
            statusText = 'Chờ tiếp nhận';
            break;
          case 'in_progress':
            statusText = 'Đang xử lý';
            break;
          case 'resolved':
            statusText = 'Đã giải quyết';
            break;
          default:
            statusText = issue.status;
        }

        String priorityText = '';
        switch (issue.priority) {
          case 'high':
            priorityText = 'Cao (Khẩn cấp)';
            break;
          case 'medium':
            priorityText = 'Trung bình';
            break;
          case 'low':
            priorityText = 'Thấp';
            break;
          default:
            priorityText = issue.priority;
        }

        final shortId = issue.id.length > 8 ? issue.id.substring(0, 8).toUpperCase() : issue.id;

        sheetObject.appendRow([
          TextCellValue(shortId),
          TextCellValue(issue.apartment?.code ?? ''),
          TextCellValue(issue.reporter?.fullName ?? 'Cư dân'),
          TextCellValue(issue.description),
          TextCellValue(priorityText),
          TextCellValue(statusText),
          TextCellValue(issue.assignedStaff?.fullName ?? 'Chưa phân công'),
          TextCellValue(dateFormat.format(issue.createdAt.toLocal())),
          TextCellValue(issue.updatedAt != null ? dateFormat.format(issue.updatedAt!.toLocal()) : '-'),
        ]);
      }

      var fileBytes = excel.save();

      if (fileBytes != null) {
        final directory = await getApplicationDocumentsDirectory();
        final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
        final filePath = '${directory.path}/BaoCaoSuCo_$timestamp.xlsx';

        File(filePath)
          ..createSync(recursive: true)
          ..writeAsBytesSync(fileBytes);

        return filePath;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
