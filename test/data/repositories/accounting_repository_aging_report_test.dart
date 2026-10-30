import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/financial_aging_report_model.dart';
import 'package:pka_home/data/repositories/accounting_repository.dart';

void main() {
  group('AccountingRepository - Financial Aging Report Tests', () {
    test('calculateAgingReportFallback computes correct stats from invoice maps', () {
      final repository = AccountingRepository();

      final invoices = [
        {
          'id': 'inv-1',
          'apartment_id': 'apt-1',
          'apartment_code': 'A0110',
          'total_amount': 2000000.0,
          'status': 'paid',
          'due_date': DateTime.now().subtract(const Duration(days: 10)).toIso8601String(),
          'period': '10/2026',
        },
        {
          'id': 'inv-2',
          'apartment_id': 'apt-1',
          'apartment_code': 'A0110',
          'total_amount': 1500000.0,
          'status': 'unpaid',
          'due_date': DateTime.now().subtract(const Duration(days: 20)).toIso8601String(),
          'period': '10/2026',
        },
        {
          'id': 'inv-3',
          'apartment_id': 'apt-2',
          'apartment_code': 'B0205',
          'total_amount': 3000000.0,
          'status': 'unpaid',
          'due_date': DateTime.now().subtract(const Duration(days: 45)).toIso8601String(),
          'period': '10/2026',
        },
        {
          'id': 'inv-4',
          'apartment_id': 'apt-3',
          'apartment_code': 'A0301',
          'total_amount': 4000000.0,
          'status': 'overdue',
          'due_date': DateTime.now().subtract(const Duration(days: 75)).toIso8601String(),
          'period': '10/2026',
        },
        {
          'id': 'inv-5',
          'apartment_id': 'apt-4',
          'apartment_code': 'B0401',
          'total_amount': 5000000.0,
          'status': 'overdue',
          'due_date': DateTime.now().subtract(const Duration(days: 100)).toIso8601String(),
          'period': '10/2026',
        },
      ];

      final report = repository.calculateAgingReportFallback(
        invoices: invoices,
        filterPeriod: '10/2026',
      );

      // Summary
      expect(report.summary.totalBilled, 15500000.0);
      expect(report.summary.actualCollected, 2000000.0);
      expect(report.summary.totalOutstanding, 13500000.0);
      expect(report.summary.totalInvoiceCount, 5);
      expect(report.summary.paidInvoiceCount, 1);
      expect(report.summary.unpaidInvoiceCount, 4);

      // 4 Aging Buckets
      expect(report.agingBuckets.amount0To30, 1500000.0);
      expect(report.agingBuckets.count0To30, 1);
      expect(report.agingBuckets.amount31To60, 3000000.0);
      expect(report.agingBuckets.count31To60, 1);
      expect(report.agingBuckets.amount61To90, 4000000.0);
      expect(report.agingBuckets.count61To90, 1);
      expect(report.agingBuckets.amountOver90, 5000000.0);
      expect(report.agingBuckets.countOver90, 1);

      // Debtors sorted by total debt descending
      expect(report.debtors.length, 4);
      expect(report.debtors[0].apartmentCode, 'B0401');
      expect(report.debtors[0].totalDebt, 5000000.0);
      expect(report.debtors[0].riskLevel, 'over_90');
      expect(report.debtors[0].isSevereRisk, isTrue);

      // Collection By Block
      expect(report.collectionByBlock.any((b) => b.blockName == 'A'), isTrue);
      expect(report.collectionByBlock.any((b) => b.blockName == 'B'), isTrue);
    });

    test('fetchAgingReport returns fallback when client is null', () async {
      final repository = AccountingRepository();
      final report = await repository.fetchAgingReport(period: '10/2026');
      expect(report, isA<FinancialAgingReportModel>());
    });
  });
}

