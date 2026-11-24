import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../../../core/theme/app_typography.dart';

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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: context.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onPrimary,
          ),
        ),
        elevation: 0,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      body: SafeArea(
        child: PdfPreview(
          canChangeOrientation: false,
          canDebug: false,
          pdfFileName: fileName,
          allowPrinting: true,
          allowSharing: true,
          canChangePageFormat: false,
          loadingWidget: Center(
            child: CircularProgressIndicator(
              color: colorScheme.primary,
            ),
          ),
          build: buildPdf,
        ),
      ),
    );
  }
}
