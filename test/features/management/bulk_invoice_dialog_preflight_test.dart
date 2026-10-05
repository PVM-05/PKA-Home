import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pka_home/data/models/bulk_invoice_validation_model.dart';
import 'package:pka_home/data/providers/management_provider.dart';
import 'package:pka_home/data/repositories/management_repository.dart';
import 'package:pka_home/features/management/widgets/bulk_invoice_dialog.dart';

class MockManagementRepository implements ManagementRepository {
  bool validateCalled = false;
  bool generateCalled = false;

  @override
  Future<BulkInvoiceValidationModel> validateMonthlyBulkInvoices({
    required String period,
    double mgmtRate = 10000,
    double electricRate = 3500,
    double waterRate = 18000,
  }) async {
    validateCalled = true;
    return BulkInvoiceValidationModel(
      period: period,
      totalScanned: 280,
      validCount: 270,
      missingCount: 8,
      invalidCount: 2,
      alreadyInvoicedCount: 0,
      totalEstimatedAmount: 395000000.0,
      validItems: [
        ValidApartmentBillingItem(
          apartmentId: 'apt-1',
          apartmentCode: 'A0110',
          area: 75.0,
          electricUsage: 140.0,
          waterUsage: 11.0,
          estimatedTotal: 1480000.0,
        ),
      ],
      issues: [
        BulkInvoiceIssueItem(
          apartmentId: 'apt-2',
          apartmentCode: 'A0105',
          type: 'missing_data',
          message: 'Chưa có chỉ số nước tháng 10/2026',
        ),
        BulkInvoiceIssueItem(
          apartmentId: 'apt-3',
          apartmentCode: 'A0203',
          type: 'invalid_reading',
          message: 'Chỉ số điện mới nhỏ hơn chỉ số cũ',
        ),
      ],
    );
  }

  @override
  Future<Map<String, dynamic>> generateValidBulkInvoices({
    required String period,
    required DateTime dueDate,
    double mgmtRate = 10000,
    double electricRate = 3500,
    double waterRate = 18000,
    List<String>? targetApartmentIds,
  }) async {
    generateCalled = true;
    return {
      'success': true,
      'period': period,
      'invoices_created': 270,
      'total_amount': 395000000.0,
      'skipped_count': 10,
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('BulkInvoiceDialog hoat dong dung quy trinh 2 buoc: Thiet lap -> Kiem tra du lieu -> Tao hoa don', (tester) async {
    final mockRepo = MockManagementRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          managementRepositoryProvider.overrideWithValue(mockRepo),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: BulkInvoiceDialog(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Kiem tra Step 1 (Thiet lap)
    expect(find.text('Tạo hóa đơn hàng loạt'), findsOneWidget);
    expect(find.text('Kỳ hóa đơn *'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Kiểm tra dữ liệu'), findsOneWidget);

    // 2. Bam Kiem tra du lieu de chay Dry-Run
    final checkButton = find.widgetWithText(ElevatedButton, 'Kiểm tra dữ liệu');
    await tester.tap(checkButton);
    await tester.pumpAndSettle();

    expect(mockRepo.validateCalled, isTrue);

    // 3. Kiem tra Step 2 (Ket qua tien kiem tra)
    expect(find.text('Kết Quả Tiền Kiểm Tra'), findsOneWidget);
    expect(find.text('270 Hợp lệ'), findsOneWidget);
    expect(find.text('8 Thiếu số'), findsOneWidget);
    expect(find.text('2 Bất thường'), findsOneWidget);

    // Kiem tra nut hanh dong
    expect(find.text('Quay lại chỉnh sửa'), findsOneWidget);
    final createButton = find.widgetWithText(ElevatedButton, 'Tạo 270 hóa đơn hợp lệ');
    expect(createButton, findsOneWidget);

    // 4. Bam Tao 270 hoa don hop le
    await tester.tap(createButton);
    await tester.pumpAndSettle();

    expect(mockRepo.generateCalled, isTrue);
  });
}
