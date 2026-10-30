import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/core/utils/excel_export_helper.dart';
import 'package:pka_home/data/models/financial_aging_report_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ExcelExportHelper - Aging Report Export Tests', () {
    final sampleReport = FinancialAgingReportModel(
      filterPeriod: '10/2026',
      summary: const FinancialAgingSummaryModel(
        totalBilled: 50000000.0,
        actualCollected: 35000000.0,
        totalOutstanding: 15000000.0,
        totalInvoiceCount: 50,
        paidInvoiceCount: 35,
        unpaidInvoiceCount: 15,
        collectionRate: 70.0,
      ),
      agingBuckets: const DebtAgingBucketModel(
        amount0To30: 8000000.0,
        count0To30: 8,
        amount31To60: 4000000.0,
        count31To60: 4,
        amount61To90: 2000000.0,
        count61To90: 2,
        amountOver90: 1000000.0,
        countOver90: 1,
      ),
      collectionByBlock: const [
        BlockCollectionRateModel(
          blockName: 'A',
          blockBilled: 30000000.0,
          blockCollected: 24000000.0,
          blockOutstanding: 6000000.0,
          collectionRate: 80.0,
        ),
      ],
      debtors: [
        DebtorApartmentModel(
          apartmentId: 'apt-01',
          apartmentCode: 'A0110',
          ownerName: 'Nguyễn Văn A',
          ownerPhone: '0901234567',
          totalDebt: 5000000.0,
          maxDaysOverdue: 95,
          unpaidInvoicesCount: 3,
          oldestDueDate: DateTime(2026, 7, 25),
          riskLevel: 'over_90',
        ),
        DebtorApartmentModel(
          apartmentId: 'apt-02',
          apartmentCode: 'B0205',
          ownerName: 'Trần Thị B',
          ownerPhone: '0912345678',
          totalDebt: 2500000.0,
          maxDaysOverdue: 45,
          unpaidInvoicesCount: 1,
          oldestDueDate: DateTime(2026, 9, 15),
          riskLevel: '31_60',
        ),
      ],
    );

    test('generateAgingReportBytes produces valid Excel with 2 sheets and correct tables', () {
      final bytes = ExcelExportHelper.generateAgingReportBytes(sampleReport);
      expect(bytes, isNotNull);
      expect(bytes!.isNotEmpty, isTrue);

      final excel = Excel.decodeBytes(bytes);
      expect(excel.tables.containsKey('Tổng Quan & Tuổi Nợ'), isTrue);
      expect(excel.tables.containsKey('Danh Sách Căn Hộ Nợ'), isTrue);

      final overviewSheet = excel.tables['Tổng Quan & Tuổi Nợ']!;
      expect(overviewSheet.rows.isNotEmpty, isTrue);

      final debtorSheet = excel.tables['Danh Sách Căn Hộ Nợ']!;
      expect(debtorSheet.rows.length, greaterThanOrEqualTo(3)); // header + 2 debtors
    });
  });
}

