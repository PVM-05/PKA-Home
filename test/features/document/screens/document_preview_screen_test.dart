import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pka_home/features/document/screens/document_preview_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('net.nfet.printing'),
      (MethodCall call) async {
        switch (call.method) {
          case 'printingInfo':
            return <String, dynamic>{
              'directPrint': true,
              'dynamicLayout': true,
              'canPrint': true,
              'canConvertHtml': false,
              'canListPrinters': true,
              'canRaster': false,
            };
          case 'sharePdf':
            return true;
          case 'printPdf':
            return 1;
          default:
            return null;
        }
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('net.nfet.printing'),
      null,
    );
  });

  Future<Uint8List> createSamplePdf(PdfPageFormat format) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: format,
        build: (context) => pw.Center(
          child: pw.Text('Document Preview Test'),
        ),
      ),
    );
    return pdf.save();
  }

  testWidgets('DocumentPreviewScreen hiển thị AppBar tiêu đề và widget PdfPreview', (tester) async {
    const testTitle = 'Biên lai điện tử A4 - Căn hộ A0110';
    const testFileName = 'bien_lai_A0110.pdf';

    await tester.pumpWidget(
      MaterialApp(
        home: DocumentPreviewScreen(
          title: testTitle,
          fileName: testFileName,
          buildPdf: createSamplePdf,
        ),
      ),
    );

    // Kiểm tra AppBar hiển thị đúng title
    expect(find.text(testTitle), findsOneWidget);

    // Kiểm tra widget PdfPreview tồn tại trong cây widget
    expect(find.byType(PdfPreview), findsOneWidget);
  });

  testWidgets('DocumentPreviewScreen cấu hình đầy đủ nút in ấn và chia sẻ mượt mà', (tester) async {
    const testTitle = 'Hóa đơn dịch vụ A4 - Tháng 10/2026';
    const testFileName = 'hoa_don_10_2026.pdf';

    await tester.pumpWidget(
      MaterialApp(
        home: DocumentPreviewScreen(
          title: testTitle,
          fileName: testFileName,
          buildPdf: createSamplePdf,
        ),
      ),
    );

    await tester.pump();

    final previewWidget = tester.widget<PdfPreview>(find.byType(PdfPreview));
    expect(previewWidget.allowPrinting, isTrue);
    expect(previewWidget.allowSharing, isTrue);
    expect(previewWidget.canChangeOrientation, isFalse);
    expect(previewWidget.canDebug, isFalse);
    expect(previewWidget.pdfFileName, equals(testFileName));
    expect(previewWidget.loadingWidget, isNotNull);
  });
}
