import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../data/models/invoice_model.dart';
import 'invoice_fee_helper.dart';
import 'vietnamese_currency_text_formatter.dart';
import 'vietqr_generator.dart';

/// Helper lưu trữ thông tin Theme và khả năng hỗ trợ Unicode của font
class _PdfContext {
  final pw.ThemeData theme;
  final bool isUnicode;

  const _PdfContext({
    required this.theme,
    required this.isUnicode,
  });

  /// Chuyển đổi chuỗi text an toàn tùy thuộc vào font có hỗ trợ Unicode hay không
  String t(String text) {
    if (isUnicode) return text;
    return DocumentPdfBuilder.stripDiacritics(text);
  }

  /// Định dạng tiền tệ tự động thích ứng với font
  String formatCurrency(num amount) {
    return t(VietnameseCurrencyTextFormatter.format(amount));
  }
}

/// Engine dựng tài liệu PDF vector cho Hóa đơn & Biên lai (PKA-Home)
/// Hỗ trợ chuẩn A4 Hóa đơn, A4 Biên lai điện tử và Phiếu in nhiệt cuộn 80mm
class DocumentPdfBuilder {
  static const String defaultBuildingName = 'BAN QUẢN LÝ CHUNG CƯ PKA-HOME';
  static const String defaultBuildingAddress = 'Khu Đô Thị Sáng Tạo PKA, TP. Hà Nội';
  static const String defaultHotline = '1900 8888 - 0987 654 321';
  static const String defaultBankBin = '';
  static const String defaultBankName = '';
  static const String defaultBankAccount = '';
  static const String defaultAccountName = '';
  static const String defaultLookupBaseUrl = 'https://pka-home.vn/tra-cuu';

  /// Khởi tạo theme PDF với font Roboto Unicode hoặc fallback sang Helvetica
  static Future<_PdfContext> _getPdfTheme({
    pw.Font? baseFont,
    pw.Font? boldFont,
  }) async {
    if (baseFont != null) {
      final isUnicode = _isUnicodeSupported(baseFont);
      return _PdfContext(
        theme: pw.ThemeData.withFont(
          base: baseFont,
          bold: boldFont ?? baseFont,
          italic: baseFont,
        ),
        isUnicode: isUnicode,
      );
    }

    try {
      final robotoRegular = await PdfGoogleFonts.robotoRegular();
      final robotoBold = await PdfGoogleFonts.robotoBold();
      final robotoItalic = await PdfGoogleFonts.robotoItalic();

      final isUnicode = _isUnicodeSupported(robotoRegular);

      return _PdfContext(
        theme: pw.ThemeData.withFont(
          base: robotoRegular,
          bold: robotoBold,
          italic: robotoItalic,
        ),
        isUnicode: isUnicode,
      );
    } catch (_) {
      // Fallback an toàn khi offline hoặc trong môi trường test không có mạng
      return _PdfContext(
        theme: pw.ThemeData.withFont(
          base: pw.Font.helvetica(),
          bold: pw.Font.helveticaBold(),
          italic: pw.Font.helveticaOblique(),
        ),
        isUnicode: false,
      );
    }
  }

  static bool _isUnicodeSupported(pw.Font font) {
    final name = font.fontName.toLowerCase();
    if (name.contains('helvetica') ||
        name.contains('courier') ||
        name.contains('times') ||
        name.contains('symbol') ||
        name.contains('zapfdingbats')) {
      return false;
    }
    return true;
  }

  /// Loại bỏ dấu tiếng Việt khi phải dùng font Type 1 (Helvetica) để tránh crash
  static String stripDiacritics(String str) {
    var result = str;
    result = result.replaceAll('★', '*');
    result = result.replaceAll('₫', 'd');
    result = result.replaceAll('đ', 'd');
    result = result.replaceAll('Đ', 'D');
    result = result.replaceAll(RegExp(r'[àáạảãâầấậẩẫăằắặẳẵ]'), 'a');
    result = result.replaceAll(RegExp(r'[ÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴ]'), 'A');
    result = result.replaceAll(RegExp(r'[èéẹẻẽêềếệểễ]'), 'e');
    result = result.replaceAll(RegExp(r'[ÈÉẸẺẼÊỀẾỆỂỄ]'), 'E');
    result = result.replaceAll(RegExp(r'[ìíịỉĩ]'), 'i');
    result = result.replaceAll(RegExp(r'[ÌÍỊỈĨ]'), 'I');
    result = result.replaceAll(RegExp(r'[òóọỏõôồốộổỗơờớợởỡ]'), 'o');
    result = result.replaceAll(RegExp(r'[ÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠ]'), 'O');
    result = result.replaceAll(RegExp(r'[ùúụủũưừứựửữ]'), 'u');
    result = result.replaceAll(RegExp(r'[ÙÚỤỦŨƯỪỨỰỬỮ]'), 'U');
    result = result.replaceAll(RegExp(r'[ỳýỵỷỹ]'), 'y');
    result = result.replaceAll(RegExp(r'[ỲÝỴỶỸ]'), 'Y');
    return result;
  }

  // ===========================================================================
  // 1. MẪU A4: HÓA ĐƠN THU PHÍ DỊCH VỤ
  // ===========================================================================
  static Future<Uint8List> buildInvoicePdfA4({
    required InvoiceModel invoice,
    required List<Map<String, dynamic>> items,
    String buildingName = defaultBuildingName,
    String buildingAddress = defaultBuildingAddress,
    String hotline = defaultHotline,
    String bankBin = defaultBankBin,
    String bankName = defaultBankName,
    String bankAccount = defaultBankAccount,
    String? accountName,
    pw.Font? baseFont,
    pw.Font? boldFont,
  }) async {
    final ctx = await _getPdfTheme(baseFont: baseFont, boldFont: boldFont);
    final pdf = pw.Document(theme: ctx.theme);

    final isPaid = invoice.status.toLowerCase() == 'paid';
    final aptCode = invoice.apartment?.code ?? invoice.apartmentId;
    final primaryColor = PdfColor.fromHex('#1E3A8A'); // Deep Navy Blue
    final totalWords = VietnameseCurrencyTextFormatter.toWords(invoice.totalAmount);
    final lookupCode = invoice.displayLookupCode;
    final paymentCode = invoice.effectivePaymentCode;

    // QR Data
    final String qrData;
    final String qrLabel;
    if (isPaid) {
      qrData = '$defaultLookupBaseUrl?code=$lookupCode';
      qrLabel = 'Quét mã tra cứu chứng từ gốc';
    } else {
      qrData = VietQrGenerator.generate(
        bankBin: bankBin,
        bankAccount: bankAccount,
        amount: invoice.totalAmount,
        memo: paymentCode,
        accountName: accountName ?? defaultAccountName,
      );
      qrLabel = 'Quét VietQR để thanh toán 24/7';
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context pageCtx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header Ban Quản Lý
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          ctx.t(buildingName),
                          style: pw.TextStyle(
                            fontSize: 13,
                            fontWeight: pw.FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          ctx.t('Địa chỉ: $buildingAddress'),
                          style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
                        ),
                        pw.Text(
                          ctx.t('Hotline: $hotline'),
                          style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
                        ),
                      ],
                    ),
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: primaryColor, width: 1),
                      borderRadius: pw.BorderRadius.circular(6),
                      color: PdfColor.fromHex('#F0F9FF'),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          ctx.t('MÃ TRA CỨU: $lookupCode'),
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          ctx.t('Mã thanh toán: $paymentCode'),
                          style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 14),
              pw.Divider(color: PdfColors.grey400, thickness: 0.8),
              pw.SizedBox(height: 10),

              // Tiêu đề Hóa đơn
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      ctx.t('THÔNG BÁO THU PHÍ DỊCH VỤ / HÓA ĐƠN'),
                      style: pw.TextStyle(
                        fontSize: 17,
                        fontWeight: pw.FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      ctx.t('Kỳ thanh toán: Tháng ${invoice.period}'),
                      style: pw.TextStyle(
                        fontSize: 10.5,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey800,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),

              // Bảng thông tin căn hộ
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F8FAFC'),
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildInfoLine(ctx, 'Căn hộ:', aptCode, isBold: true),
                        pw.SizedBox(height: 4),
                        _buildInfoLine(
                          ctx,
                          'Ngày phát hành:',
                          DateFormat('dd/MM/yyyy').format(invoice.createdAt),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildInfoLine(
                          ctx,
                          'Hạn nộp phí:',
                          DateFormat('dd/MM/yyyy').format(invoice.dueDate),
                          valueColor: PdfColor.fromHex('#DC2626'),
                          isBold: true,
                        ),
                        pw.SizedBox(height: 4),
                        _buildInfoLine(
                          ctx,
                          'Trạng thái:',
                          _resolveInvoiceStatusText(ctx, invoice.status),
                          valueColor: isPaid
                              ? PdfColor.fromHex('#16A34A')
                              : PdfColor.fromHex('#DC2626'),
                          isBold: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),

              // Bảng chi tiết các mục phí
              _buildItemsTable(ctx, items),
              pw.SizedBox(height: 10),

              // Dòng Tổng Cộng
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F1F5F9'),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      ctx.t('TỔNG TIỀN PHẢI THANH TOÁN:'),
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      ctx.formatCurrency(invoice.totalAmount),
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 4),
                child: pw.Text(
                  ctx.t('Bằng chữ: $totalWords'),
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontStyle: pw.FontStyle.italic,
                    color: PdfColors.grey800,
                  ),
                ),
              ),
              pw.SizedBox(height: 16),

              // Phần Hướng Dẫn & QR Code
              pw.Expanded(
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Thông tin tài khoản BQL
                    pw.Expanded(
                      flex: 3,
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(10),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey300),
                          borderRadius: pw.BorderRadius.circular(6),
                          color: PdfColor.fromHex('#FAFAFA'),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              ctx.t('HƯỚNG DẪN THANH TOÁN CHUYỂN KHOẢN'),
                              style: pw.TextStyle(
                                fontSize: 9.5,
                                fontWeight: pw.FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                            pw.SizedBox(height: 6),
                            _buildBankRow(ctx, 'Ngân hàng:', bankName),
                            _buildBankRow(ctx, 'Số tài khoản:', bankAccount, isBold: true),
                            _buildBankRow(
                              ctx,
                              'Chủ tài khoản:',
                              accountName ?? defaultAccountName,
                            ),
                            _buildBankRow(
                              ctx,
                              'Nội dung CK:',
                              paymentCode,
                              isBold: true,
                              color: PdfColor.fromHex('#DC2626'),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              ctx.t('* Vui lòng giữ nguyên nội dung chuyển khoản để hệ thống tự động gạch nợ sau 30 giây.'),
                              style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
                            ),
                          ],
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 14),
                    // Khu vực QR Code
                    pw.Expanded(
                      flex: 2,
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(8),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey300),
                          borderRadius: pw.BorderRadius.circular(6),
                        ),
                        child: pw.Column(
                          mainAxisAlignment: pw.MainAxisAlignment.center,
                          children: [
                            pw.BarcodeWidget(
                              barcode: pw.Barcode.qrCode(),
                              data: qrData,
                              width: 85,
                              height: 85,
                            ),
                            pw.SizedBox(height: 6),
                            pw.Text(
                              ctx.t(qrLabel),
                              textAlign: pw.TextAlign.center,
                              style: pw.TextStyle(
                                fontSize: 7.5,
                                fontWeight: pw.FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Footer chân trang
              pw.Divider(color: PdfColors.grey300, thickness: 0.5),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    ctx.t('Chứng từ điện tử tạo từ Hệ thống Quản trị PKA-Home | Tra cứu: $defaultLookupBaseUrl'),
                    style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
                  ),
                  pw.Text(
                    ctx.t('Trang 1/1'),
                    style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // ===========================================================================
  // 2. MẪU A4: BIÊN LAI THU TIỀN ĐIỆN TỬ (BẢN GỐC) KÈM CON DẤU MỘC SỐ
  // ===========================================================================
  static Future<Uint8List> buildReceiptPdfA4({
    required InvoiceModel invoice,
    required List<Map<String, dynamic>> items,
    String buildingName = defaultBuildingName,
    String buildingAddress = defaultBuildingAddress,
    String hotline = defaultHotline,
    pw.Font? baseFont,
    pw.Font? boldFont,
  }) async {
    final ctx = await _getPdfTheme(baseFont: baseFont, boldFont: boldFont);
    final pdf = pw.Document(theme: ctx.theme);

    final aptCode = invoice.apartment?.code ?? invoice.apartmentId;
    final primaryColor = PdfColor.fromHex('#065F46'); // Deep Forest Green
    final stampColor = PdfColor.fromHex('#B91C1C'); // Deep Official Red
    final paidAmount = invoice.paidAmount ?? invoice.totalAmount;
    final paidWords = VietnameseCurrencyTextFormatter.toWords(paidAmount);
    final receiptNum = invoice.displayReceiptNumber;
    final lookupCode = invoice.displayLookupCode;
    final paidAtStr = invoice.paidAt != null
        ? DateFormat('dd/MM/yyyy HH:mm:ss').format(invoice.paidAt!)
        : DateFormat('dd/MM/yyyy HH:mm:ss').format(invoice.createdAt);

    final lookupUrl = '$defaultLookupBaseUrl?code=$lookupCode';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context pageCtx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header Ban Quản Lý
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          ctx.t(buildingName),
                          style: pw.TextStyle(
                            fontSize: 13,
                            fontWeight: pw.FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          ctx.t('Địa chỉ: $buildingAddress'),
                          style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
                        ),
                        pw.Text(
                          ctx.t('Hotline hỗ trợ: $hotline'),
                          style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
                        ),
                      ],
                    ),
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: primaryColor, width: 1),
                      borderRadius: pw.BorderRadius.circular(6),
                      color: PdfColor.fromHex('#ECFDF5'),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          ctx.t('SỐ BIÊN LAI: $receiptNum'),
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          ctx.t('Mã tra cứu: $lookupCode'),
                          style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 14),
              pw.Divider(color: PdfColors.grey400, thickness: 0.8),
              pw.SizedBox(height: 10),

              // Tiêu đề Biên lai
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      ctx.t('BIÊN LAI THU TIỀN ĐIỆN TỬ (BẢN GỐC)'),
                      style: pw.TextStyle(
                        fontSize: 17,
                        fontWeight: pw.FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      ctx.t('Kỳ thu phí dịch vụ: Tháng ${invoice.period}'),
                      style: pw.TextStyle(
                        fontSize: 10.5,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey800,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),

              // Bảng thông tin người nộp & giao dịch
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F8FAFC'),
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildInfoLine(ctx, 'Căn hộ nộp phí:', aptCode, isBold: true),
                        pw.SizedBox(height: 4),
                        _buildInfoLine(
                          ctx,
                          'Hình thức thanh toán:',
                          invoice.paymentMethod ?? 'Chuyển khoản VietQR',
                        ),
                        pw.SizedBox(height: 4),
                        _buildInfoLine(
                          ctx,
                          'Thời gian thu tiền:',
                          paidAtStr,
                          isBold: true,
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildInfoLine(
                          ctx,
                          'Mã đối soát / GD:',
                          invoice.transactionCode ?? 'TXN-$lookupCode',
                          isBold: true,
                        ),
                        pw.SizedBox(height: 4),
                        _buildInfoLine(
                          ctx,
                          'Trạng thái thu:',
                          'ĐÃ THU ĐỦ TIỀN',
                          valueColor: PdfColor.fromHex('#16A34A'),
                          isBold: true,
                        ),
                        pw.SizedBox(height: 4),
                        _buildInfoLine(
                          ctx,
                          'Kênh ghi nhận:',
                          'Hệ thống tự động Napas 247',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),

              // Bảng chi tiết các khoản thu
              _buildItemsTable(ctx, items),
              pw.SizedBox(height: 10),

              // Dòng Tổng Cộng Đã Thu
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#ECFDF5'),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      ctx.t('TỔNG SỐ TIỀN ĐÃ THU:'),
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      ctx.formatCurrency(paidAmount),
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 4),
                child: pw.Text(
                  ctx.t('Bằng chữ: $paidWords'),
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontStyle: pw.FontStyle.italic,
                    color: PdfColors.grey800,
                  ),
                ),
              ),
              pw.SizedBox(height: 16),

              // Khu Vực Chữ Ký & Con Dấu Mộc Số Điện Tử
              pw.Expanded(
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    // Bên trái: Người nộp tiền & QR Tra cứu
                    pw.Expanded(
                      flex: 3,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Text(
                            ctx.t('NGƯỜI NỘP TIỀN'),
                            style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.Text(
                            ctx.t('(Đã ký số xác nhận nộp tiền)'),
                            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
                          ),
                          pw.SizedBox(height: 10),
                          pw.BarcodeWidget(
                            barcode: pw.Barcode.qrCode(),
                            data: lookupUrl,
                            width: 65,
                            height: 65,
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            ctx.t('Quét mã kiểm tra tính hợp lệ biên lai'),
                            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 20),
                    // Bên phải: Đại diện BQL & Con dấu mộc số vector
                    pw.Expanded(
                      flex: 4,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Text(
                            ctx.t('ĐẠI DIỆN BAN QUẢN LÝ TÒA NHÀ'),
                            style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.Text(
                            ctx.t('(Xác nhận hệ thống)'),
                            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
                          ),
                          pw.SizedBox(height: 6),

                          // Con dấu mộc số điện tử vector chuẩn
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: pw.BoxDecoration(
                              border: pw.Border.all(color: stampColor, width: 2),
                              borderRadius: pw.BorderRadius.circular(8),
                              color: PdfColor.fromHex('#FEF2F2'),
                            ),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.center,
                              children: [
                                pw.Text(
                                  ctx.t('★ BAN QUẢN LÝ CHUNG CƯ PKA-HOME ★'),
                                  style: pw.TextStyle(
                                    fontSize: 8,
                                    fontWeight: pw.FontWeight.bold,
                                    color: stampColor,
                                  ),
                                ),
                                pw.SizedBox(height: 2),
                                pw.Container(
                                  height: 0.8,
                                  color: stampColor,
                                  width: 140,
                                ),
                                pw.SizedBox(height: 3),
                                pw.Text(
                                  ctx.t('*** ĐÃ THU TIỀN ***'),
                                  style: pw.TextStyle(
                                    fontSize: 11,
                                    fontWeight: pw.FontWeight.bold,
                                    color: stampColor,
                                  ),
                                ),
                                pw.SizedBox(height: 3),
                                pw.Text(
                                  ctx.t('Ký số: HỆ THỐNG TÀI CHÍNH PKA-HOME'),
                                  style: pw.TextStyle(fontSize: 6.8, color: stampColor),
                                ),
                                pw.Text(
                                  ctx.t('Thời gian ký: $paidAtStr'),
                                  style: pw.TextStyle(fontSize: 6.8, color: stampColor),
                                ),
                                pw.Text(
                                  ctx.t('Mã chứng từ: $lookupCode'),
                                  style: pw.TextStyle(fontSize: 6.8, color: stampColor),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Footer chân trang
              pw.Divider(color: PdfColors.grey300, thickness: 0.5),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    ctx.t('Biên lai điện tử có giá trị pháp lý theo Nghị định 123/2020/NĐ-CP | Tra cứu: $defaultLookupBaseUrl'),
                    style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
                  ),
                  pw.Text(
                    ctx.t('Trang 1/1'),
                    style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // ===========================================================================
  // 3. MẪU 80MM: PHIẾU IN NHIỆT CUỘN TẠI QUẦY (ROLL 80MM)
  // ===========================================================================
  static Future<Uint8List> buildReceiptPdf80mm({
    required InvoiceModel invoice,
    required List<Map<String, dynamic>> items,
    String buildingName = defaultBuildingName,
    String hotline = defaultHotline,
    pw.Font? baseFont,
    pw.Font? boldFont,
  }) async {
    final ctx = await _getPdfTheme(baseFont: baseFont, boldFont: boldFont);
    final pdf = pw.Document(theme: ctx.theme);

    final aptCode = invoice.apartment?.code ?? invoice.apartmentId;
    final paidAmount = invoice.paidAmount ?? invoice.totalAmount;
    final paidWords = VietnameseCurrencyTextFormatter.toWords(paidAmount);
    final receiptNum = invoice.displayReceiptNumber;
    final lookupCode = invoice.displayLookupCode;
    final paidAtStr = invoice.paidAt != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(invoice.paidAt!)
        : DateFormat('dd/MM/yyyy HH:mm').format(invoice.createdAt);
    final lookupUrl = '$defaultLookupBaseUrl?code=$lookupCode';

    // 80mm roll format với margin hẹp 4mm
    const roll80Format = PdfPageFormat(
      80 * PdfPageFormat.mm,
      double.infinity,
      marginAll: 4 * PdfPageFormat.mm,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: roll80Format,
        build: (pw.Context pageCtx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Header Quầy Thu Ngân
              pw.Text(
                ctx.t(buildingName),
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                ctx.t('Hotline: $hotline'),
                style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
              ),
              pw.SizedBox(height: 4),
              pw.Divider(thickness: 0.5),

              // Tiêu đề phiếu
              pw.Text(
                ctx.t('PHIẾU THU TIỀN DỊCH VỤ'),
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                ctx.t('(Biên lai quầy in nhiệt)'),
                style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
              ),
              pw.SizedBox(height: 6),

              // Thông tin căn hộ & thời gian
              pw.Container(
                alignment: pw.Alignment.centerLeft,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildRollLine(ctx, 'Số phiếu:', receiptNum),
                    _buildRollLine(ctx, 'Căn hộ:', aptCode, isBold: true),
                    _buildRollLine(ctx, 'Kỳ phí:', 'Tháng ${invoice.period}'),
                    _buildRollLine(ctx, 'Thời gian:', paidAtStr),
                    _buildRollLine(
                      ctx,
                      'Hình thức:',
                      invoice.paymentMethod ?? 'Tiền mặt / POS',
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Divider(thickness: 0.5),

              // Danh sách khoản mục dạng thu gọn cho khổ 80mm
              if (items.isEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4),
                  child: pw.Text(
                    ctx.t('Thu phí dịch vụ trọn gói'),
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                )
              else
                pw.Column(
                  children: items.map((item) {
                    final rawFeeType = item['fee_type'] as String?;
                    final feeName = InvoiceFeeHelper.getFeeName(rawFeeType);
                    final unit = InvoiceFeeHelper.getFeeUnit(rawFeeType).trim();
                    final qty = item['quantity'] ?? 1;
                    final unitPrice = item['unit_price'] ?? 0;
                    final subtotal = item['subtotal'] ?? 0;

                    return pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Expanded(
                                child: pw.Text(
                                  ctx.t(feeName),
                                  style: pw.TextStyle(
                                    fontSize: 8,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                              ),
                              pw.Text(
                                ctx.formatCurrency(subtotal),
                                style: pw.TextStyle(
                                  fontSize: 8,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          pw.Text(
                            '${ctx.formatCurrency(unitPrice)} x $qty $unit',
                            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),

              pw.Divider(thickness: 0.5),

              // Tổng cộng
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    ctx.t('TỔNG THU:'),
                    style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    ctx.formatCurrency(paidAmount),
                    style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                ctx.t('Bằng chữ: $paidWords'),
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 7,
                  fontStyle: pw.FontStyle.italic,
                  color: PdfColors.grey800,
                ),
              ),
              pw.SizedBox(height: 6),

              // Xác nhận đã thu
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.black, width: 1),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  ctx.t('*** ĐÃ THU ĐỦ TIỀN ***'),
                  style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 6),

              // QR Tra cứu ở đáy phiếu
              pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: lookupUrl,
                width: 52,
                height: 52,
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                ctx.t('Mã tra cứu: $lookupCode'),
                style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                ctx.t('Quét mã để tra cứu chứng từ gốc'),
                style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                ctx.t('Cảm ơn Quý cư dân!'),
                style: pw.TextStyle(
                  fontSize: 7.5,
                  fontWeight: pw.FontWeight.bold,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
              pw.SizedBox(height: 6),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // ===========================================================================
  // PRIVATE HELPER WIDGETS
  // ===========================================================================

  static pw.Widget _buildInfoLine(
    _PdfContext ctx,
    String label,
    String value, {
    bool isBold = false,
    PdfColor? valueColor,
  }) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Text(
          ctx.t(label),
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
        pw.SizedBox(width: 4),
        pw.Text(
          ctx.t(value),
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: valueColor ?? PdfColors.black,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildBankRow(
    _PdfContext ctx,
    String label,
    String value, {
    bool isBold = false,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 75,
            child: pw.Text(
              ctx.t(label),
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              ctx.t(value),
              style: pw.TextStyle(
                fontSize: 8.5,
                fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: color ?? PdfColors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildRollLine(
    _PdfContext ctx,
    String label,
    String value, {
    bool isBold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            ctx.t(label),
            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
          ),
          pw.Text(
            ctx.t(value),
            style: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  static String _resolveInvoiceStatusText(_PdfContext ctx, String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return ctx.t('ĐÃ THANH TOÁN');
      case 'unpaid':
        return ctx.t('CHƯA THANH TOÁN');
      case 'overdue':
        return ctx.t('QUÁ HẠN THANH TOÁN');
      case 'pending_confirmation':
        return ctx.t('CHỜ XÁC NHẬN');
      case 'cancelled':
        return ctx.t('ĐÃ HỦY');
      default:
        return ctx.t(status.toUpperCase());
    }
  }

  static pw.Widget _buildItemsTable(
    _PdfContext ctx,
    List<Map<String, dynamic>> items,
  ) {
    if (items.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        alignment: pw.Alignment.center,
        child: pw.Text(
          ctx.t('(Không có chi tiết từng khoản mục hoặc hóa đơn trọn gói)'),
          style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600),
        ),
      );
    }

    final rows = <pw.TableRow>[
      // Table Header
      pw.TableRow(
        decoration: pw.BoxDecoration(color: PdfColor.fromHex('#F1F5F9')),
        children: [
          _buildTableCell(ctx.t('STT'), isHeader: true, align: pw.TextAlign.center),
          _buildTableCell(ctx.t('Khoản mục dịch vụ'), isHeader: true),
          _buildTableCell(ctx.t('ĐVT'), isHeader: true, align: pw.TextAlign.center),
          _buildTableCell(ctx.t('Số lượng'), isHeader: true, align: pw.TextAlign.right),
          _buildTableCell(ctx.t('Đơn giá (đ)'), isHeader: true, align: pw.TextAlign.right),
          _buildTableCell(ctx.t('Thành tiền (đ)'), isHeader: true, align: pw.TextAlign.right),
        ],
      ),
    ];

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final rawFeeType = item['fee_type'] as String?;
      final feeName = InvoiceFeeHelper.getFeeName(rawFeeType);
      final unit = InvoiceFeeHelper.getFeeUnit(rawFeeType).trim();
      final qty = item['quantity'] ?? 1;
      final unitPrice = item['unit_price'] ?? 0;
      final subtotal = item['subtotal'] ?? 0;

      final qtyStr = (qty is num && qty == qty.roundToDouble())
          ? qty.toInt().toString()
          : qty.toString();

      rows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: (i % 2 == 1) ? PdfColor.fromHex('#F8FAFC') : PdfColors.white,
          ),
          children: [
            _buildTableCell('${i + 1}', align: pw.TextAlign.center),
            _buildTableCell(ctx.t(feeName)),
            _buildTableCell(ctx.t(unit.isEmpty ? '-' : unit), align: pw.TextAlign.center),
            _buildTableCell(qtyStr, align: pw.TextAlign.right),
            _buildTableCell(
              ctx.formatCurrency(unitPrice),
              align: pw.TextAlign.right,
            ),
            _buildTableCell(
              ctx.formatCurrency(subtotal),
              align: pw.TextAlign.right,
              isBold: true,
            ),
          ],
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(28),
        1: pw.FlexColumnWidth(4),
        2: pw.FlexColumnWidth(1.5),
        3: pw.FlexColumnWidth(1.8),
        4: pw.FlexColumnWidth(2.6),
        5: pw.FlexColumnWidth(2.8),
      },
      children: rows,
    );
  }

  static pw.Widget _buildTableCell(
    String text, {
    bool isHeader = false,
    bool isBold = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4.5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: isHeader ? 8.5 : 8,
          fontWeight: (isHeader || isBold) ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.black : PdfColors.grey900,
        ),
      ),
    );
  }
}
