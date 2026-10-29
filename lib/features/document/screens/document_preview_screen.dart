import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../../../core/theme/app_theme.dart';

/// Màn hình xem trước chứng từ PDF tích hợp xem trực quan,
/// in ấn (Wifi/AirPrint), lưu file và chia sẻ qua Zalo/Email.
class DocumentPreviewScreen extends StatelessWidget {
  final String title;
  final Future<Uint8List> Function(PdfPageFormat format) buildPdf;
  final String fileName;

  const DocumentPreviewScreen({
    super.key,
    required this.title,
    required this.buildPdf,
    required this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        elevation: 0,
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: PdfPreview(
          canChangeOrientation: false,
          canDebug: false,
          pdfFileName: fileName,
          allowPrinting: true,
          allowSharing: true,
          canChangePageFormat: false,
          loadingWidget: const Center(
            child: CircularProgressIndicator(
              color: AppTheme.primary,
            ),
          ),
          build: buildPdf,
        ),
      ),
    );
  }
}
