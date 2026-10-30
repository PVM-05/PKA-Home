import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/financial_aging_report_model.dart';

void main() {
  group('Financial Aging Report Model Tests', () {
    final sampleJson = {
      'generated_at': '2026-10-30T10:00:00.000Z',
      'filter_building_id': 'b-1234',
      'filter_period': '10/2026',
      'summary': {
        'total_billed': 50000000.0,
        'actual_collected': 35000000.0,
        'total_outstanding': 15000000.0,
        'total_invoice_count': 50,
        'paid_invoice_count': 35,
        'unpaid_invoice_count': 15,
        'collection_rate': 70.0,
      },
      'aging_buckets': {
        'bucket_0_30': {'amount': 8000000.0, 'count': 8},
        'bucket_31_60': {'amount': 4000000.0, 'count': 4},
        'bucket_61_90': {'amount': 2000000.0, 'count': 2},
        'bucket_over_90': {'amount': 1000000.0, 'count': 1},
      },
      'collection_by_block': [
        {
          'block_name': 'A',
          'block_billed': 30000000.0,
          'block_collected': 24000000.0,
          'block_outstanding': 6000000.0,
          'collection_rate': 80.0,
        },
        {
          'block_name': 'B',
          'block_billed': 20000000.0,
          'block_collected': 11000000.0,
          'block_outstanding': 9000000.0,
          'collection_rate': 55.0,
        }
      ],
      'debtors': [
        {
          'apartment_id': 'apt-01',
          'apartment_code': 'A0110',
          'owner_name': 'Nguyễn Văn A',
          'owner_phone': '0901234567',
          'total_debt': 5000000.0,
          'max_days_overdue': 95,
          'unpaid_invoices_count': 3,
          'oldest_due_date': '2026-07-25T00:00:00.000Z',
          'risk_level': 'over_90',
        },
        {
          'apartment_id': 'apt-02',
          'apartment_code': 'B0205',
          'owner_name': 'Trần Thị B',
          'owner_phone': '0912345678',
          'total_debt': 2500000.0,
          'max_days_overdue': 45,
          'unpaid_invoices_count': 1,
          'oldest_due_date': '2026-09-15T00:00:00.000Z',
          'risk_level': '31_60',
        }
      ]
    };

    test('FinancialAgingReportModel parses from JSON correctly', () {
      final report = FinancialAgingReportModel.fromJson(sampleJson);

      expect(report.filterBuildingId, 'b-1234');
      expect(report.filterPeriod, '10/2026');
      expect(report.summary.totalBilled, 50000000.0);
      expect(report.summary.actualCollected, 35000000.0);
      expect(report.summary.totalOutstanding, 15000000.0);
      expect(report.summary.collectionRate, 70.0);

      // Buckets
      expect(report.agingBuckets.amount0To30, 8000000.0);
      expect(report.agingBuckets.count0To30, 8);
      expect(report.agingBuckets.amount31To60, 4000000.0);
      expect(report.agingBuckets.count31To60, 4);
      expect(report.agingBuckets.amount61To90, 2000000.0);
      expect(report.agingBuckets.count61To90, 2);
      expect(report.agingBuckets.amountOver90, 1000000.0);
      expect(report.agingBuckets.countOver90, 1);
      expect(report.agingBuckets.totalDebt, 15000000.0);

      // Block Collection Rates
      expect(report.collectionByBlock.length, 2);
      expect(report.collectionByBlock[0].blockName, 'A');
      expect(report.collectionByBlock[0].collectionRate, 80.0);
      expect(report.collectionByBlock[1].blockName, 'B');
      expect(report.collectionByBlock[1].collectionRate, 55.0);

      // Debtors
      expect(report.debtors.length, 2);
      expect(report.debtors[0].apartmentCode, 'A0110');
      expect(report.debtors[0].riskLevel, 'over_90');
      expect(report.debtors[0].isSevereRisk, isTrue);
      expect(report.debtors[0].riskLevelText, 'Quá hạn >90 ngày (Nợ xấu)');
      expect(report.debtors[1].apartmentCode, 'B0205');
      expect(report.debtors[1].riskLevel, '31_60');
      expect(report.debtors[1].isSevereRisk, isFalse);
      expect(report.debtors[1].riskLevelText, 'Quá hạn 31-60 ngày');
    });

    test('FinancialAgingReportModel handles empty/null json gracefully', () {
      final report = FinancialAgingReportModel.fromJson({});
      expect(report.summary.totalBilled, 0.0);
      expect(report.summary.actualCollected, 0.0);
      expect(report.summary.totalOutstanding, 0.0);
      expect(report.summary.collectionRate, 0.0);
      expect(report.agingBuckets.totalDebt, 0.0);
      expect(report.collectionByBlock, isEmpty);
      expect(report.debtors, isEmpty);
    });

    test('toJson produces expected structure', () {
      final report = FinancialAgingReportModel.fromJson(sampleJson);
      final json = report.toJson();
      expect(json['filter_period'], '10/2026');
      expect(json['summary']['total_billed'], 50000000.0);
      expect(json['aging_buckets']['bucket_0_30']['amount'], 8000000.0);
      expect(json['debtors'].length, 2);
    });
  });
}
