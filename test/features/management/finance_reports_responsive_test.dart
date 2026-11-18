import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivona/data/models/building_model.dart';
import 'package:vivona/data/models/debt_risk_score_model.dart';
import 'package:vivona/data/models/financial_aging_report_model.dart';
import 'package:vivona/data/models/maintenance_fund_model.dart';
import 'package:vivona/data/models/maintenance_fund_transaction_model.dart';
import 'package:vivona/data/models/user_model.dart';
import 'package:vivona/data/providers/auth_provider.dart';
import 'package:vivona/data/providers/building_provider.dart';
import 'package:vivona/data/providers/debt_prediction_provider.dart';
import 'package:vivona/data/providers/financial_report_provider.dart';
import 'package:vivona/data/providers/maintenance_fund_provider.dart';
import 'package:vivona/features/management/screens/financial_report_screen.dart';
import 'package:vivona/features/management/screens/maintenance_fund_ledger_screen.dart';

class _FakeAuthNotifier extends StateNotifier<AsyncValue<UserModel?>> implements AuthNotifier {
  _FakeAuthNotifier(UserModel user) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final mockReport = FinancialAgingReportModel(
    filterPeriod: '10/2026',
    filterBuildingId: 'bld-01',
    summary: const FinancialAgingSummaryModel(
      totalBilled: 125000000.0,
      actualCollected: 95000000.0,
      totalOutstanding: 30000000.0,
      totalInvoiceCount: 80,
      paidInvoiceCount: 60,
      unpaidInvoiceCount: 20,
      collectionRate: 76.0,
    ),
    agingBuckets: const DebtAgingBucketModel(
      amount0To30: 15000000.0,
      count0To30: 10,
      amount31To60: 8000000.0,
      count31To60: 5,
      amount61To90: 4000000.0,
      count61To90: 3,
      amountOver90: 3000000.0,
      countOver90: 2,
    ),
    collectionByBlock: const [
      BlockCollectionRateModel(
        blockName: 'A',
        blockBilled: 75000000.0,
        blockCollected: 60000000.0,
        blockOutstanding: 15000000.0,
        collectionRate: 80.0,
      ),
      BlockCollectionRateModel(
        blockName: 'B',
        blockBilled: 50000000.0,
        blockCollected: 35000000.0,
        blockOutstanding: 15000000.0,
        collectionRate: 70.0,
      ),
    ],
    debtors: [
      DebtorApartmentModel(
        apartmentId: 'apt-01',
        apartmentCode: 'A0110',
        ownerName: 'Nguyễn Văn A Rất Dài Để Kiểm Tra Tràn Khung Màn Hình Hẹp',
        ownerPhone: '0901234567',
        totalDebt: 18500000.0,
        maxDaysOverdue: 105,
        unpaidInvoicesCount: 4,
        oldestDueDate: DateTime(2026, 7, 15),
        riskLevel: 'over_90',
      ),
      DebtorApartmentModel(
        apartmentId: 'apt-02',
        apartmentCode: 'B0205',
        ownerName: 'Trần Thị B',
        ownerPhone: '0912345678',
        totalDebt: 3200000.0,
        maxDaysOverdue: 25,
        unpaidInvoicesCount: 1,
        oldestDueDate: DateTime(2026, 10, 5),
        riskLevel: '0_30',
      ),
    ],
  );

  const mockRadar = DebtRadarDataModel(
    buildingId: 'bld-01',
    kpi: DebtRadarKpiModel(
      totalAtRiskApartments: 2,
      highRiskCount: 1,
      mediumRiskCount: 1,
      lowRiskCount: 0,
      totalOverdueDebt: 21700000.0,
      highRiskDebt: 18500000.0,
    ),
    apartments: [],
  );

  final mockFund = MaintenanceFundModel(
    id: 'f-1',
    totalBalance: 2450000000.0,
    annualInterestEarned: 127400000.0,
    interestRatePercent: 5.2,
    collectedPercent: 98.5,
    bankName: 'BIDV Chi nhánh Hà Thành',
    bankAccountNumber: '1240000898989',
  );

  final mockTxs = [
    MaintenanceFundTransactionModel(
      id: 'tx-1',
      buildingId: 'bld-01',
      fundId: 'f-1',
      voucherNumber: 'PT-202610-00001',
      transactionType: 'INCOME',
      category: 'MAINTENANCE_FEE',
      amount: 5000000.0,
      balanceAfter: 2450000000.0,
      recipientOrPayer: 'Cư dân Căn A0110 - Nguyễn Văn A',
      description: 'Thu phí bảo trì 2% đợt bàn giao nhà chính thức',
      createdAt: DateTime(2026, 10, 27, 9, 0),
    ),
    MaintenanceFundTransactionModel(
      id: 'tx-2',
      buildingId: 'bld-01',
      fundId: 'f-1',
      voucherNumber: 'PC-202610-00002',
      transactionType: 'EXPENSE',
      category: 'EQUIPMENT_REPAIR',
      amount: 12000000.0,
      balanceAfter: 2438000000.0,
      recipientOrPayer: 'Công ty Cổ phần Thang máy Schindler Việt Nam',
      description: 'Bảo dưỡng định kỳ hệ thống thang máy block A',
      createdAt: DateTime(2026, 10, 28, 14, 30),
    ),
  ];

  final mockBuilding = BuildingModel(
    id: 'bld-01',
    organizationId: 'org-01',
    name: 'Tòa Central Park Tower',
    code: 'CPT',
    address: 'Hà Nội',
    totalFloors: 25,
    totalUnits: 200,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  group('FinancialReportScreen Responsive Tests', () {
    testWidgets('Mobile 320dp x 600dp (Zoom 1.3x) render an toan khong loi overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(
              (ref) => _FakeAuthNotifier(
                UserModel(id: 'admin-01', fullName: 'BQL', role: 'admin'),
              ),
            ),
            financialAgingReportProvider.overrideWith((ref) async => mockReport),
            buildingDebtRadarProvider.overrideWith((ref, arg) async => mockRadar),
            filteredDebtRiskApartmentsProvider.overrideWith((ref, arg) => []),
          ],
          child: const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(320, 600),
                textScaler: TextScaler.linear(1.3),
              ),
              child: FinancialReportScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Báo cáo Tài chính & Tuổi nợ'), findsOneWidget);
      expect(find.text('Tổng phát hành'), findsOneWidget);
      expect(find.text('Đã thu thực tế'), findsOneWidget);
      expect(find.text('Công nợ tồn đọng'), findsOneWidget);
      expect(find.text('Tỷ lệ thu hồi'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('A0110'),
        100,
        scrollable: find.byType(Scrollable).at(1),
      );
      expect(find.text('A0110'), findsOneWidget);
    });

    testWidgets('Desktop 1200dp x 900dp render Executive KPI Bar va Workstation can doi', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(
              (ref) => _FakeAuthNotifier(
                UserModel(id: 'admin-01', fullName: 'BQL', role: 'admin'),
              ),
            ),
            financialAgingReportProvider.overrideWith((ref) async => mockReport),
            buildingDebtRadarProvider.overrideWith((ref, arg) async => mockRadar),
            filteredDebtRiskApartmentsProvider.overrideWith((ref, arg) => []),
          ],
          child: const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(1200, 900),
              ),
              child: FinancialReportScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Báo cáo Tài chính & Tuổi nợ'), findsOneWidget);
      expect(find.text('TỔNG QUAN TÀI CHÍNH'), findsOneWidget);
      expect(find.text('PHÂN LOẠI 4 XÔ TUỔI NỢ'), findsOneWidget);
      expect(find.text('TỶ LỆ THU HỒI THEO BLOCK'), findsOneWidget);
      expect(find.textContaining('DANH SÁCH CĂN HỘ NỢ'), findsOneWidget);
    });
  });

  group('MaintenanceFundLedgerScreen Responsive Tests', () {
    testWidgets('Mobile 320dp x 600dp (Zoom 1.3x) render an toan khong loi overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(
              (ref) => _FakeAuthNotifier(
                UserModel(id: 'admin-01', fullName: 'BQL', role: 'admin'),
              ),
            ),
            activeMaintenanceFundProvider.overrideWith((ref) => Future.value(mockFund)),
            maintenanceFundLedgerProvider.overrideWith((ref) => Future.value(mockTxs)),
            activeBuildingProvider.overrideWith((ref) => Future.value(mockBuilding)),
            userBuildingsProvider.overrideWith((ref) => Future.value([mockBuilding])),
          ],
          child: const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(320, 600),
                textScaler: TextScaler.linear(1.3),
              ),
              child: MaintenanceFundLedgerScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Sổ Quỹ Bảo Trì 2%'), findsOneWidget);
      expect(find.text('Số dư quỹ khả dụng'), findsOneWidget);
      expect(find.text('Tất cả'), findsOneWidget);
      expect(find.text('Thu quỹ'), findsOneWidget);
      expect(find.text('Chi quỹ'), findsOneWidget);
    });

    testWidgets('Desktop 1200dp x 900dp render Split-Screen Workstation', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(
              (ref) => _FakeAuthNotifier(
                UserModel(id: 'admin-01', fullName: 'BQL', role: 'admin'),
              ),
            ),
            activeMaintenanceFundProvider.overrideWith((ref) => Future.value(mockFund)),
            maintenanceFundLedgerProvider.overrideWith((ref) => Future.value(mockTxs)),
            activeBuildingProvider.overrideWith((ref) => Future.value(mockBuilding)),
            userBuildingsProvider.overrideWith((ref) => Future.value([mockBuilding])),
          ],
          child: const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(1200, 900),
              ),
              child: MaintenanceFundLedgerScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Sổ Quỹ Bảo Trì 2%'), findsOneWidget);
      expect(find.text('Số dư quỹ khả dụng'), findsOneWidget);
      expect(find.text('Nhật ký giao dịch chứng từ'), findsOneWidget);
      expect(find.textContaining('PT-202610-00001'), findsOneWidget);
      expect(find.textContaining('PC-202610-00002'), findsOneWidget);
    });
  });
}
