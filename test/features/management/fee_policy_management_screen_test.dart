import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/fee_tier_policy_model.dart';
import 'package:pka_home/data/providers/fee_policy_providers.dart';
import 'package:pka_home/data/repositories/fee_policy_repository.dart';
import 'package:pka_home/features/management/screens/fee_policy_management_screen.dart';
import 'package:pka_home/features/management/widgets/quick_fee_calculator_sheet.dart';

class MockFeePolicyRepositoryForUI extends FeePolicyRepository {
  @override
  Future<List<FeeTierPolicyModel>> fetchPolicies({
    String? buildingId,
    FeePolicyType? policyType,
  }) async {
    return [
      FeeTierPolicyModel(
        id: 'policy-elec-1',
        buildingId: buildingId,
        policyType: FeePolicyType.electricityTier,
        name: 'Điện sinh hoạt EVN 6 bậc (QĐ 2024)',
        calculationMethod: FeeCalculationMethod.progressiveTier,
        tiers: [
          {'tier': 1, 'name': 'Bậc 1 (0 - 50 kWh)', 'from': 0, 'to': 50, 'rate': 1893},
          {'tier': 2, 'name': 'Bậc 2 (51 - 100 kWh)', 'from': 50, 'to': 100, 'rate': 1956},
          {'tier': 3, 'name': 'Bậc 3 (101 - 200 kWh)', 'from': 100, 'to': 200, 'rate': 2271},
          {'tier': 4, 'name': 'Bậc 4 (201 - 300 kWh)', 'from': 200, 'to': 300, 'rate': 2860},
          {'tier': 5, 'name': 'Bậc 5 (301 - 400 kWh)', 'from': 300, 'to': 400, 'rate': 3197},
          {'tier': 6, 'name': 'Bậc 6 (Trên 400 kWh)', 'from': 400, 'to': null, 'rate': 3302},
        ],
        effectiveFrom: DateTime(2024, 10, 11),
        isActive: true,
      ),
      FeeTierPolicyModel(
        id: 'policy-water-1',
        buildingId: buildingId,
        policyType: FeePolicyType.waterQuotaTier,
        name: 'Nước sinh hoạt định mức (4 m³/người/tháng)',
        calculationMethod: FeeCalculationMethod.perCapitaQuota,
        tiers: [
          {'tier': 1, 'name': 'Trong định mức (0 - 16 m³)', 'from': 0, 'to': 16, 'rate': 8500},
          {'tier': 2, 'name': 'Vượt định mức cấp 1 (16 - 24 m³)', 'from': 16, 'to': 24, 'rate': 12000},
          {'tier': 3, 'name': 'Vượt định mức cấp 2 (> 24 m³)', 'from': 24, 'to': null, 'rate': 18000},
        ],
        effectiveFrom: DateTime(2024, 1, 1),
        isActive: true,
      ),
      FeeTierPolicyModel(
        id: 'policy-parking-1',
        buildingId: buildingId,
        policyType: FeePolicyType.parkingProrata,
        name: 'Phí gửi xe pro-rata theo ngày thực tế',
        calculationMethod: FeeCalculationMethod.proRataDaily,
        tiers: {'rule': 'Tỷ lệ ngày thực tế trong tháng'},
        effectiveFrom: DateTime(2024, 1, 1),
        isActive: true,
      ),
      FeeTierPolicyModel(
        id: 'policy-penalty-1',
        buildingId: buildingId,
        policyType: FeePolicyType.latePaymentPenalty,
        name: 'Lãi phạt trễ hạn thanh toán (0.05%/ngày)',
        calculationMethod: FeeCalculationMethod.percentageDaily,
        tiers: {'grace_period_days': 3, 'penalty_rate_per_day': 0.0005},
        effectiveFrom: DateTime(2024, 1, 1),
        isActive: true,
      ),
    ];
  }
}

Widget createTestApp({String? buildingId}) {
  return ProviderScope(
    overrides: [
      feePolicyRepositoryProvider.overrideWithValue(MockFeePolicyRepositoryForUI()),
    ],
    child: MaterialApp(
      home: FeePolicyManagementScreen(buildingId: buildingId),
    ),
  );
}

void main() {
  group('FeePolicyManagementScreen & QuickFeeCalculatorSheet Tests', () {
    testWidgets('Test 1: Hiển thị đầy đủ 4 chính sách biểu giá chuẩn', (tester) async {
      await tester.pumpWidget(createTestApp(buildingId: 'bld-01'));
      await tester.pumpAndSettle();

      // Kiểm tra tiêu đề màn hình
      expect(find.text('Quản Lý Biểu Giá & Phí'), findsOneWidget);

      // Kiểm tra 4 chính sách cốt lõi
      expect(find.textContaining('Điện sinh hoạt EVN 6 bậc'), findsWidgets);
      expect(find.textContaining('Nước sinh hoạt định mức'), findsWidgets);
      expect(find.textContaining('Phí gửi xe pro-rata'), findsWidgets);
      expect(find.textContaining('Lãi phạt trễ hạn'), findsWidgets);

      // Kiểm tra nút mở công cụ tính nhanh
      expect(find.byKey(const Key('btn_open_quick_calculator')), findsOneWidget);
    });

    testWidgets('Test 2: Nhấn vào chính sách mở rộng chi tiết các bậc giá', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Ban đầu các bậc giá chưa hiển thị chi tiết (trong ExpansionTile)
      expect(find.text('Bậc 1 (0 - 50 kWh)'), findsNothing);

      // Nhấn mở chính sách Điện EVN
      final elecTile = find.byKey(const Key('policy_tile_electricity'));
      expect(elecTile, findsOneWidget);
      await tester.tap(elecTile);
      await tester.pumpAndSettle();

      // Kiểm tra các bậc điện được hiển thị
      expect(find.text('Bậc 1 (0 - 50 kWh)'), findsOneWidget);
      expect(find.textContaining('1.893'), findsWidgets);
      expect(find.textContaining('3.302'), findsWidgets);

      // Nhấn mở chính sách Nước sinh hoạt
      final waterTile = find.byKey(const Key('policy_tile_water'));
      expect(waterTile, findsOneWidget);
      await tester.ensureVisible(waterTile);
      await tester.pumpAndSettle();
      await tester.tap(waterTile);
      await tester.pumpAndSettle();

      // Cuộn để thấy chi tiết nếu cần
      final quotaText = find.textContaining('Trong định mức');
      await tester.ensureVisible(quotaText);
      await tester.pumpAndSettle();

      // Kiểm tra các bậc nước được hiển thị
      expect(quotaText, findsWidgets);
      expect(find.textContaining('8.500'), findsWidgets);
    });

    testWidgets('Test 3: Nút Công cụ tính nhanh mở modal bottom sheet', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final fab = find.byKey(const Key('btn_open_quick_calculator'));
      await tester.tap(fab);
      await tester.pumpAndSettle();

      // Xác nhận sheet đã mở
      expect(find.byType(QuickFeeCalculatorSheet), findsOneWidget);
      expect(find.text('Công Cụ Tính Nhanh Biểu Phí'), findsOneWidget);

      // Kiểm tra các tab chuyển đổi
      expect(find.text('Điện EVN'), findsWidgets);
      expect(find.text('Nước'), findsWidgets);
      expect(find.text('Gửi xe'), findsWidgets);
      expect(find.text('Lãi phạt'), findsWidgets);
    });

    testWidgets('Test 4: Tab Điện EVN - Nhập 250 kWh tính đúng 562.550 đ và bảng bậc thang', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: QuickFeeCalculatorSheet(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Chọn tab Điện EVN (mặc định tab 0)
      final inputConsumption = find.byKey(const Key('input_electricity_consumption'));
      expect(inputConsumption, findsOneWidget);

      await tester.enterText(inputConsumption, '250');
      await tester.pumpAndSettle();

      final btnCalc = find.byKey(const Key('btn_calculate_electricity'));
      await tester.tap(btnCalc);
      await tester.pumpAndSettle();

      // Kết quả tính: 50*1893 + 50*1956 + 100*2271 + 50*2860 = 562.550 đ
      expect(find.textContaining('562.550'), findsWidgets);
      // Hiển thị chi tiết các bậc thang
      expect(find.textContaining('Bậc 1'), findsWidgets);
      expect(find.textContaining('Bậc 4'), findsWidgets);
    });

    testWidgets('Test 5: Tab Nước - Nhập 25 m3 & 4 nhân khẩu tính đúng 250.000 đ', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: QuickFeeCalculatorSheet(initialTabIndex: 1),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final inputWaterM3 = find.byKey(const Key('input_water_consumption'));
      final inputResidents = find.byKey(const Key('input_water_residents'));
      expect(inputWaterM3, findsOneWidget);
      expect(inputResidents, findsOneWidget);

      await tester.enterText(inputWaterM3, '25');
      await tester.enterText(inputResidents, '4');
      await tester.pumpAndSettle();

      final btnCalc = find.byKey(const Key('btn_calculate_water'));
      await tester.tap(btnCalc);
      await tester.pumpAndSettle();

      // Quota: 16 m3 (136.000) + 8 m3 (96.000) + 1 m3 (18.000) = 250.000 đ
      expect(find.textContaining('250.000'), findsWidgets);
      expect(find.textContaining('16 m³'), findsWidgets);
    });

    testWidgets('Test 6: Tab Gửi xe pro-rata và Tab Lãi phạt tính toán chuẩn xác', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: QuickFeeCalculatorSheet(initialTabIndex: 2),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Test Phí gửi xe pro-rata
      final inputRate = find.byKey(const Key('input_parking_monthly_rate'));
      final inputPeriod = find.byKey(const Key('input_parking_period'));
      final inputStartDay = find.byKey(const Key('input_parking_start_day'));

      await tester.enterText(inputRate, '100000');
      await tester.enterText(inputPeriod, '2026-10');
      await tester.enterText(inputStartDay, '15');
      await tester.pumpAndSettle();

      final btnCalcParking = find.byKey(const Key('btn_calculate_parking'));
      await tester.tap(btnCalcParking);
      await tester.pumpAndSettle();

      // 100.000 * 17 / 31 = 54.839 đ
      expect(find.textContaining('54.839'), findsWidgets);
      expect(find.textContaining('17/31 ngày'), findsWidgets);

      // Chuyển sang tab Lãi phạt trễ hạn (tab index 3)
      final penaltyTab = find.text('Lãi phạt');
      await tester.tap(penaltyTab);
      await tester.pumpAndSettle();

      final inputBaseAmount = find.byKey(const Key('input_penalty_base_amount'));
      final inputDays = find.byKey(const Key('input_penalty_overdue_days'));

      await tester.enterText(inputBaseAmount, '2000000');
      await tester.enterText(inputDays, '10');
      await tester.pumpAndSettle();

      final btnCalcPenalty = find.byKey(const Key('btn_calculate_penalty'));
      await tester.tap(btnCalcPenalty);
      await tester.pumpAndSettle();

      // 2.000.000 * 0.0005 * 10 = 10.000 đ
      expect(find.textContaining('10.000'), findsWidgets);
      expect(find.textContaining('Quá hạn 10 ngày'), findsWidgets);
    });
  });
}
