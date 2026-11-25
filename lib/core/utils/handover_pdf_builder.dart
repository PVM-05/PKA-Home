import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../data/models/apartment_handover_model.dart';
import '../../data/models/handover_item_model.dart';
import 'vietnamese_currency_text_formatter.dart';

/// Helper lưu trữ thông tin Theme và khả năng hỗ trợ Unicode của font
class _HandoverPdfContext {
  final pw.ThemeData theme;
  final bool isUnicode;

  const _HandoverPdfContext({required this.theme, required this.isUnicode});

  /// Chuyển đổi chuỗi text an toàn tùy thuộc vào font có hỗ trợ Unicode hay không
  String t(String text) {
    if (isUnicode) return text;
    return HandoverPdfBuilder.stripDiacritics(text);
  }

  /// Định dạng tiền tệ tự động thích ứng với font
  String formatCurrency(num? amount) {
    if (amount == null) return t('0 đ');
    return t(VietnameseCurrencyTextFormatter.format(amount));
  }

  /// Định dạng ngày tháng
  String formatDate(DateTime? date) {
    if (date == null) return t('Chưa xác định');
    return DateFormat('dd/MM/yyyy').format(date);
  }
}

/// Bộ máy dựng tài liệu PDF vector cho Biên bản bàn giao & kiểm kê tài sản (Vivona)
/// Tuân thủ chuẩn in A4 B2B SaaS, pháp lý bàn giao căn hộ chung cư / căn hộ dịch vụ
class HandoverPdfBuilder {
  static const String defaultBuildingName = 'BAN QUẢN LÝ TÒA NHÀ VIVONA';
  static const String defaultLookupBaseUrl = 'https://vivona.vn/tra-cuu/bien-ban';

  /// Khởi tạo theme PDF với font Roboto Unicode hoặc fallback sang Helvetica
  static Future<_HandoverPdfContext> _getPdfTheme({
    pw.Font? baseFont,
    pw.Font? boldFont,
  }) async {
    if (baseFont != null) {
      final isUnicode = _isUnicodeSupported(baseFont);
      return _HandoverPdfContext(
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

      return _HandoverPdfContext(
        theme: pw.ThemeData.withFont(
          base: robotoRegular,
          bold: robotoBold,
          italic: robotoItalic,
        ),
        isUnicode: isUnicode,
      );
    } catch (_) {
      // Fallback an toàn khi offline hoặc trong môi trường test không có mạng
      return _HandoverPdfContext(
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

  /// Loại bỏ dấu tiếng Việt khi phải dùng font Type 1 (Helvetica) để tránh lỗi render
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

  /// Dựng toàn bộ tài liệu PDF Biên bản bàn giao & kiểm kê hiện trạng căn hộ
  static Future<Uint8List> buildHandoverReportPdf({
    required ApartmentHandoverModel handover,
    required List<HandoverItemModel> items,
    String? buildingName,
    Uint8List? staffSignatureBytes,
    Uint8List? residentSignatureBytes,
    pw.Font? baseFont,
    pw.Font? boldFont,
  }) async {
    final ctx = await _getPdfTheme(baseFont: baseFont, boldFont: boldFont);
    final pdf = pw.Document(theme: ctx.theme);

    final resolvedBuilding = buildingName ?? defaultBuildingName;
    final isMoveIn = handover.handoverType == 'move_in';
    final typeTitle = isMoveIn ? 'BÀN GIAO NHẬN NHÀ' : 'BÀN GIAO TRẢ NHÀ';
    final primaryColor = PdfColor.fromHex('#1E3A8A');
    final secondaryColor = PdfColor.fromHex('#047857');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 36),
        header: (pw.Context pageCtx) => _buildHeader(ctx, resolvedBuilding, handover, typeTitle, primaryColor),
        footer: (pw.Context pageCtx) => _buildFooter(ctx, pageCtx, handover),
        build: (pw.Context pageCtx) => [
          pw.SizedBox(height: 12),
          _buildInfoSection(ctx, handover),
          pw.SizedBox(height: 14),
          _buildMeterAndDepositSection(ctx, handover, secondaryColor),
          pw.SizedBox(height: 16),
          _buildItemsTable(ctx, items, primaryColor),
          pw.SizedBox(height: 16),
          _buildNotesSection(ctx, handover),
          pw.SizedBox(height: 24),
          _buildSignatureSection(ctx, handover, staffSignatureBytes, residentSignatureBytes),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildHeader(
    _HandoverPdfContext ctx,
    String buildingName,
    ApartmentHandoverModel handover,
    String typeTitle,
    PdfColor primaryColor,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  ctx.t(buildingName.toUpperCase()),
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
                ),
                pw.Text(
                  ctx.t('HỆ THỐNG VẬN HÀNH VIVONA SAAS'),
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  ctx.t('CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM'),
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  ctx.t('Độc lập - Tự do - Hạnh phúc'),
                  style: const pw.TextStyle(fontSize: 8, decoration: pw.TextDecoration.underline),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          ctx.t('BIÊN BẢN BÀN GIAO & KIỂM KÊ TÀI SẢN CĂN HỘ'),
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: primaryColor),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          ctx.t(typeTitle),
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text(
              ctx.t('Mã biên bản: ${handover.reportCode}   |   Ngày lập: ${ctx.formatDate(handover.handoverDate)}'),
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          ],
        ),
        pw.Divider(thickness: 1, color: primaryColor),
      ],
    );
  }

  static pw.Widget _buildInfoSection(_HandoverPdfContext ctx, ApartmentHandoverModel handover) {
    final statusText = switch (handover.status) {
      'confirmed' => 'Đã xác nhận & ký kết số',
      'pending_resident' => 'Chờ cư dân đối soát & ký',
      'disputed' => 'Đang có khiếu nại hiện trạng',
      'cancelled' => 'Đã hủy bỏ',
      _ => 'Bản nháp kiểm kê',
    };

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.RichText(
                  text: pw.TextSpan(
                    children: [
                      pw.TextSpan(text: ctx.t('Căn hộ / Phòng: '), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      pw.TextSpan(text: ctx.t(handover.apartmentCode ?? handover.apartmentId), style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
              ),
              pw.Expanded(
                child: pw.RichText(
                  text: pw.TextSpan(
                    children: [
                      pw.TextSpan(text: ctx.t('Trạng thái: '), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      pw.TextSpan(text: ctx.t(statusText), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.RichText(
                  text: pw.TextSpan(
                    children: [
                      pw.TextSpan(text: ctx.t('Đại diện BQL kiểm kê: '), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      pw.TextSpan(text: ctx.t(handover.staffName ?? handover.conductedBy), style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
              ),
              pw.Expanded(
                child: pw.RichText(
                  text: pw.TextSpan(
                    children: [
                      pw.TextSpan(text: ctx.t('Bên nhận/Bàn giao: '), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      pw.TextSpan(text: ctx.t(handover.residentName ?? handover.residentId ?? 'Chưa xác định'), style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (handover.lookupCode.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.RichText(
              text: pw.TextSpan(
                children: [
                  pw.TextSpan(text: ctx.t('Mã tra cứu bảo mật: '), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  pw.TextSpan(text: handover.lookupCode, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _buildMeterAndDepositSection(
    _HandoverPdfContext ctx,
    ApartmentHandoverModel handover,
    PdfColor secondaryColor,
  ) {
    final elec = handover.initialElectricityReading;
    final water = handover.initialWaterReading;
    final deposit = handover.depositHeld;
    final deduction = handover.totalDeduction;
    final refund = handover.depositRefund;

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            ctx.t('I. CHỈ SỐ KỸ THUẬT & TÀI CHÍNH BÀN GIAO'),
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: secondaryColor),
          ),
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                ctx.t('Chỉ số đồng hồ điện: ${elec.toStringAsFixed(1)} kWh'),
                style: const pw.TextStyle(fontSize: 9),
              ),
              pw.Text(
                ctx.t('Chỉ số đồng hồ nước: ${water.toStringAsFixed(1)} m³'),
                style: const pw.TextStyle(fontSize: 9),
              ),
            ],
          ),
          if (handover.handoverType == 'move_out' || deposit > 0) ...[
            pw.SizedBox(height: 6),
            pw.Divider(thickness: 0.5, color: PdfColors.grey300),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(ctx.t('Tiền đặt cọc giữ chỗ:'), style: const pw.TextStyle(fontSize: 9)),
                pw.Text(ctx.formatCurrency(deposit), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              ],
            ),
            pw.SizedBox(height: 2),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(ctx.t('Khấu trừ đền bù / sửa chữa hư hỏng:'), style: const pw.TextStyle(fontSize: 9, color: PdfColors.red700)),
                pw.Text('- ${ctx.formatCurrency(deduction)}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.red700)),
              ],
            ),
            pw.SizedBox(height: 2),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(ctx.t('Số tiền cọc thực trả hoàn lại:'), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: secondaryColor)),
                pw.Text(ctx.formatCurrency(refund), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: secondaryColor)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _buildItemsTable(
    _HandoverPdfContext ctx,
    List<HandoverItemModel> items,
    PdfColor primaryColor,
  ) {
    String formatRoom(String room) {
      return switch (room) {
        'living_room' => 'Khách',
        'bedroom' => 'Ngủ',
        'kitchen' => 'Bếp',
        'bathroom' => 'VS',
        'balcony' => 'Ban công',
        _ => room,
      };
    }

    String formatCondition(String cond) {
      return switch (cond) {
        'good' => 'Tốt',
        'normal_wear' => 'Hao mòn',
        'damaged' => 'Hư hỏng',
        'missing' => 'Thất lạc',
        _ => cond,
      };
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          ctx.t('II. DANH MỤC KIỂM KÊ TRANG THIẾT BỊ NỘI THẤT'),
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: primaryColor),
        ),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: const {
            0: pw.FixedColumnWidth(24),  // STT
            1: pw.FixedColumnWidth(55),  // Khu vực
            2: pw.FlexColumnWidth(3),   // Tên thiết bị
            3: pw.FixedColumnWidth(28),  // SL
            4: pw.FixedColumnWidth(55),  // Tình trạng
            5: pw.FixedColumnWidth(70),  // Khấu trừ
            6: pw.FlexColumnWidth(2),   // Ghi chú
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _buildTableHeaderCell(ctx, 'STT'),
                _buildTableHeaderCell(ctx, 'Khu vực'),
                _buildTableHeaderCell(ctx, 'Tên thiết bị / Hạng mục'),
                _buildTableHeaderCell(ctx, 'SL'),
                _buildTableHeaderCell(ctx, 'Hiện trạng'),
                _buildTableHeaderCell(ctx, 'Bồi thường'),
                _buildTableHeaderCell(ctx, 'Ghi chú'),
              ],
            ),
            if (items.isEmpty)
              pw.TableRow(
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    alignment: pw.Alignment.center,
                    child: pw.Text(ctx.t('Không có hạng mục nào được ghi nhận'), style: const pw.TextStyle(fontSize: 8)),
                  ),
                  for (int i = 0; i < 6; i++) pw.Container(),
                ],
              )
            else
              for (int i = 0; i < items.length; i++) ...[
                pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: i % 2 == 1 ? PdfColors.grey50 : PdfColors.white,
                  ),
                  children: [
                    _buildTableCell(ctx, '${i + 1}', align: pw.Alignment.center),
                    _buildTableCell(ctx, formatRoom(items[i].roomArea)),
                    _buildTableCell(ctx, items[i].itemName, isBold: true),
                    _buildTableCell(ctx, '${items[i].quantity}', align: pw.Alignment.center),
                    _buildTableCell(ctx, formatCondition(items[i].condition), align: pw.Alignment.center),
                    _buildTableCell(
                      ctx,
                      items[i].repairCost > 0 ? ctx.formatCurrency(items[i].repairCost) : '-',
                      align: pw.Alignment.centerRight,
                    ),
                    _buildTableCell(ctx, items[i].note ?? '-'),
                  ],
                ),
              ],
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildTableHeaderCell(_HandoverPdfContext ctx, String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      alignment: pw.Alignment.center,
      child: pw.Text(
        ctx.t(text),
        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900),
      ),
    );
  }

  static pw.Widget _buildTableCell(
    _HandoverPdfContext ctx,
    String text, {
    pw.Alignment align = pw.Alignment.centerLeft,
    bool isBold = false,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      alignment: align,
      child: pw.Text(
        ctx.t(text),
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static pw.Widget _buildNotesSection(_HandoverPdfContext ctx, ApartmentHandoverModel handover) {
    final hasStaffNotes = handover.staffNotes != null && handover.staffNotes!.trim().isNotEmpty;
    final hasResidentNotes = handover.residentNotes != null && handover.residentNotes!.trim().isNotEmpty;

    if (!hasStaffNotes && !hasResidentNotes) {
      return pw.SizedBox.shrink();
    }

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            ctx.t('Ý kiến / Cam kết bổ sung:'),
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
          if (hasStaffNotes) ...[
            pw.SizedBox(height: 2),
            pw.Text(
              ctx.t('Ghi chú BQL: ${handover.staffNotes!}'),
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800),
            ),
          ],
          if (hasResidentNotes) ...[
            pw.SizedBox(height: 2),
            pw.Text(
              ctx.t('Ý kiến cư dân: ${handover.residentNotes!}'),
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800),
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _buildSignatureSection(
    _HandoverPdfContext ctx,
    ApartmentHandoverModel handover,
    Uint8List? staffSignatureBytes,
    Uint8List? residentSignatureBytes,
  ) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Bên Đại diện BQL
        pw.Expanded(
          child: pw.Column(
            children: [
              pw.Text(
                ctx.t('ĐẠI DIỆN BAN QUẢN LÝ'),
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                ctx.t('(Ký điện tử & Ghi rõ họ tên)'),
                style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
              ),
              pw.SizedBox(height: 8),
              if (staffSignatureBytes != null)
                pw.Container(
                  height: 40,
                  child: pw.Image(pw.MemoryImage(staffSignatureBytes)),
                )
              else if (handover.staffSignatureUrl != null && handover.staffSignatureUrl!.isNotEmpty)
                pw.Container(
                  height: 40,
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    ctx.t('[ĐÃ KÝ ĐIỆN TỬ]'),
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800),
                  ),
                )
              else
                pw.SizedBox(height: 40),
              pw.SizedBox(height: 6),
              pw.Text(
                ctx.t(handover.staffName ?? handover.conductedBy),
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
        ),
        // Bên Cư dân
        pw.Expanded(
          child: pw.Column(
            children: [
              pw.Text(
                ctx.t('ĐẠI DIỆN CƯ DÂN / KHÁCH THUÊ'),
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                ctx.t('(Ký điện tử & Ghi rõ họ tên)'),
                style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
              ),
              pw.SizedBox(height: 8),
              if (residentSignatureBytes != null)
                pw.Container(
                  height: 40,
                  child: pw.Image(pw.MemoryImage(residentSignatureBytes)),
                )
              else if (handover.residentSignatureUrl != null && handover.residentSignatureUrl!.isNotEmpty)
                pw.Container(
                  height: 40,
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    ctx.t('[ĐÃ XÁC NHẬN KÝ SỐ]'),
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.green800),
                  ),
                )
              else
                pw.SizedBox(height: 40),
              pw.SizedBox(height: 6),
              pw.Text(
                ctx.t(handover.residentName ?? handover.residentId ?? 'Chưa xác nhận'),
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildFooter(
    _HandoverPdfContext ctx,
    pw.Context pageCtx,
    ApartmentHandoverModel handover,
  ) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Column(
        children: [
          pw.Divider(thickness: 0.5, color: PdfColors.grey400),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                ctx.t('Biên bản điện tử có giá trị pháp lý nội bộ tòa nhà. Tra cứu tại: $defaultLookupBaseUrl'),
                style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
              ),
              pw.Text(
                'Trang ${pageCtx.pageNumber} / ${pageCtx.pagesCount}',
                style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
