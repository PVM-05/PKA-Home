import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/financial_aging_report_model.dart';
import 'package:pka_home/data/providers/financial_report_provider.dart';
import 'package:pka_home/features/management/screens/financial_report_screen.dart';

void main() {
  testWidgets('FinancialReportScreen displays KPI cards, aging buckets, and debtors list', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final mockReport = FinancialAgingReportModel(
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
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          financialAgingReportProvider.overrideWith((ref) async => mockReport),
        ],
        child: const MaterialApp(
          home: FinancialReportScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Tiêu đề App bar & nút xuất Excel
    expect(find.text('Báo cáo Tài chính & Tuổi nợ'), findsOneWidget);
    expect(find.byIcon(Icons.file_download_outlined), findsOneWidget);

    // 2. Thẻ KPI tổng quan
    expect(find.text('Tổng phát hành'), findsOneWidget);
    expect(find.text('Đã thu thực tế'), findsOneWidget);
    expect(find.text('Công nợ tồn đọng'), findsOneWidget);
    expect(find.text('Tỷ lệ thu hồi'), findsOneWidget);
    expect(find.text('70.0%'), findsOneWidget);

    // 3. Phân loại 4 xô tuổi nợ
    expect(find.text('0 - 30 ngày'), findsOneWidget);
    expect(find.text('31 - 60 ngày'), findsOneWidget);
    expect(find.text('61 - 90 ngày'), findsOneWidget);
    expect(find.text('> 90 ngày'), findsOneWidget);

    // 4. Danh sách con nợ & nút hành động
    expect(find.text('A0110'), findsOneWidget);
    expect(find.text('Nguyễn Văn A'), findsOneWidget);
    expect(find.text('Nhắc nợ'), findsOneWidget);
    expect(find.text('Sổ cái'), findsOneWidget);
  });
}
