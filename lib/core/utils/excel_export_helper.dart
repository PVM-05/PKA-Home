import '../../data/models/financial_aging_report_model.dart';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/models/invoice_model.dart';
import '../../data/models/issue_model.dart';

class ExcelExportHelper {
  /// Mở hộp thoại chia sẻ/lưu file qua Share Sheet hệ điều hành
  static Future<void> shareFile(String filePath, {String? subject, String? text}) async {
    try {
      final xFile = XFile(filePath);
      await SharePlus.instance.share(
        ShareParams(
          files: [xFile],
          subject: subject,
          text: text,
        ),
      );
    } catch (_) {}
  }
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
          DoubleCellValue(invoice.totalAmount),
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

  /// Tạo bytes file Excel Báo cáo Tài chính & Phân tích Tuổi nợ (2 Sheets)
  static List<int>? generateAgingReportBytes(FinancialAgingReportModel report) {
    try {
      var excel = Excel.createExcel();

      // Sheet 1: Tổng Quan & Tuổi Nợ
      Sheet overviewSheet = excel['Tổng Quan & Tuổi Nợ'];
      excel.delete('Sheet1');

      final moneyFormat = NumberFormat('#,##0', 'vi_VN');
      final dateFormat = DateFormat('dd/MM/yyyy');

      overviewSheet.appendRow([
        TextCellValue('BÁO CÁO TÀI CHÍNH VÀ PHÂN TÍCH TUỔI NỢ CÔNG NỢ'),
      ]);
      overviewSheet.appendRow([
        TextCellValue('Thời gian xuất: ' + DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())),
      ]);
      overviewSheet.appendRow([
        TextCellValue('Kỳ đối soát: ' + (report.filterPeriod ?? 'Tất cả các kỳ')),
      ]);
      overviewSheet.appendRow([TextCellValue('')]);

      // Bảng Chỉ số tổng quan
      overviewSheet.appendRow([
        TextCellValue('CHỈ SỐ TÀI CHÍNH'),
        TextCellValue('GIÁ TRỊ'),
      ]);
      overviewSheet.appendRow([
        TextCellValue('Tổng doanh thu phát hành'),
        TextCellValue(moneyFormat.format(report.summary.totalBilled) + ' đ'),
      ]);
      overviewSheet.appendRow([
        TextCellValue('Doanh thu thực tế đã thu'),
        TextCellValue(moneyFormat.format(report.summary.actualCollected) + ' đ'),
      ]);
      overviewSheet.appendRow([
        TextCellValue('Tổng công nợ tồn đọng'),
        TextCellValue(moneyFormat.format(report.summary.totalOutstanding) + ' đ'),
      ]);
      overviewSheet.appendRow([
        TextCellValue('Tỷ lệ thu hồi công nợ'),
        TextCellValue('${report.summary.collectionRate}%'),
      ]);
      overviewSheet.appendRow([
        TextCellValue('Tổng số hóa đơn phát hành'),
        IntCellValue(report.summary.totalInvoiceCount),
      ]);
      overviewSheet.appendRow([
        TextCellValue('Số hóa đơn đã thanh toán'),
        IntCellValue(report.summary.paidInvoiceCount),
      ]);
      overviewSheet.appendRow([
        TextCellValue('Số hóa đơn chưa thanh toán'),
        IntCellValue(report.summary.unpaidInvoiceCount),
      ]);

      overviewSheet.appendRow([TextCellValue('')]);
      overviewSheet.appendRow([
        TextCellValue('PHÂN LOẠI 4 XÔ TUỔI NỢ (AGING BUCKETS)'),
        TextCellValue('SỐ LƯỢNG HÓA ĐƠN'),
        TextCellValue('SỐ TIỀN (VNĐ)'),
        TextCellValue('TỶ TRỌNG CÔNG NỢ'),
      ]);

      final totalDebt = report.agingBuckets.totalDebt > 0 ? report.agingBuckets.totalDebt : 1.0;

      overviewSheet.appendRow([
        TextCellValue('0 - 30 ngày (Trong hạn / Mới phát sinh)'),
        IntCellValue(report.agingBuckets.count0To30),
        TextCellValue(moneyFormat.format(report.agingBuckets.amount0To30) + ' đ'),
        TextCellValue('${((report.agingBuckets.amount0To30 / totalDebt) * 100).toStringAsFixed(1)}%'),
      ]);
      overviewSheet.appendRow([
        TextCellValue('31 - 60 ngày (Quá hạn mức 1 - Đôn đốc)'),
        IntCellValue(report.agingBuckets.count31To60),
        TextCellValue(moneyFormat.format(report.agingBuckets.amount31To60) + ' đ'),
        TextCellValue('${((report.agingBuckets.amount31To60 / totalDebt) * 100).toStringAsFixed(1)}%'),
      ]);
      overviewSheet.appendRow([
        TextCellValue('61 - 90 ngày (Quá hạn mức 2 - Cảnh báo dịch vụ)'),
        IntCellValue(report.agingBuckets.count61To90),
        TextCellValue(moneyFormat.format(report.agingBuckets.amount61To90) + ' đ'),
        TextCellValue('${((report.agingBuckets.amount61To90 / totalDebt) * 100).toStringAsFixed(1)}%'),
      ]);
      overviewSheet.appendRow([
        TextCellValue('> 90 ngày (Nợ xấu / Khó đòi)'),
        IntCellValue(report.agingBuckets.countOver90),
        TextCellValue(moneyFormat.format(report.agingBuckets.amountOver90) + ' đ'),
        TextCellValue('${((report.agingBuckets.amountOver90 / totalDebt) * 100).toStringAsFixed(1)}%'),
      ]);

      // Sheet 2: Danh Sách Căn Hộ Nợ
      Sheet debtorSheet = excel['Danh Sách Căn Hộ Nợ'];
      debtorSheet.appendRow([
        TextCellValue('STT'),
        TextCellValue('Mã Căn Hộ'),
        TextCellValue('Chủ Hộ / Người Đại Diện'),
        TextCellValue('Số Điện Thoại'),
        TextCellValue('Số Hóa Đơn Nợ'),
        TextCellValue('Ngày Đến Hạn Cũ Nhất'),
        TextCellValue('Số Ngày Quá Hạn'),
        TextCellValue('Mức Độ Rủi Ro'),
        TextCellValue('Tổng Tiền Nợ (VNĐ)'),
      ]);

      int index = 1;
      for (final debtor in report.debtors) {
        debtorSheet.appendRow([
          IntCellValue(index++),
          TextCellValue(debtor.apartmentCode),
          TextCellValue(debtor.ownerName),
          TextCellValue(debtor.ownerPhone),
          IntCellValue(debtor.unpaidInvoicesCount),
          TextCellValue(debtor.oldestDueDate != null ? dateFormat.format(debtor.oldestDueDate!) : '-'),
          IntCellValue(debtor.maxDaysOverdue),
          TextCellValue(debtor.riskLevelText),
          DoubleCellValue(debtor.totalDebt),
        ]);
      }

      return excel.save();
    } catch (_) {
      return null;
    }
  }

  /// Xuất Báo cáo Tài chính & Phân tích Tuổi nợ ra file .xlsx
  static Future<String?> exportAgingReport({
    required FinancialAgingReportModel report,
    String? period,
  }) async {
    try {
      final fileBytes = generateAgingReportBytes(report);
      if (fileBytes != null) {
        final directory = await getApplicationDocumentsDirectory();
        final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
        final safePeriod = (period ?? 'TatCa').replaceAll('/', '_');
        final filePath = '${directory.path}/BaoCaoTuoiNo_${safePeriod}_$timestamp.xlsx';

        File(filePath)
          ..createSync(recursive: true)
          ..writeAsBytesSync(fileBytes);

        return filePath;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
