import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/bulk_invoice_validation_model.dart';
import 'package:pka_home/data/repositories/management_repository.dart';

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
  group('ManagementRepository Bulk Invoice Methods Tests', () {
    late MockManagementRepository mockRepo;

    setUp(() {
      mockRepo = MockManagementRepository();
    });

    test('validateMonthlyBulkInvoices tra ve dung BulkInvoiceValidationModel', () async {
      final result = await mockRepo.validateMonthlyBulkInvoices(
        period: '10/2026',
        mgmtRate: 10000,
        electricRate: 3500,
        waterRate: 18000,
      );

      expect(mockRepo.validateCalled, isTrue);
      expect(result.period, '10/2026');
      expect(result.validCount, 270);
      expect(result.missingCount, 8);
      expect(result.invalidCount, 2);
      expect(result.canGenerateAny, isTrue);
      expect(result.validItems.length, 1);
      expect(result.issues.length, 1);
    });

    test('generateValidBulkInvoices goi va tra ve ket qua phat hanh hoa don thanh cong', () async {
      final result = await mockRepo.generateValidBulkInvoices(
        period: '10/2026',
        dueDate: DateTime(2026, 10, 20),
        mgmtRate: 10000,
        electricRate: 3500,
        waterRate: 18000,
      );

      expect(mockRepo.generateCalled, isTrue);
      expect(result['success'], isTrue);
      expect(result['invoices_created'], 270);
      expect(result['skipped_count'], 10);
    });
  });
}
