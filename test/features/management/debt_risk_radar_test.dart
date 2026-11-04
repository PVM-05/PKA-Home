import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pka_home/data/models/debt_risk_score_model.dart';
import 'package:pka_home/data/models/dunning_action_model.dart';
import 'package:pka_home/data/providers/debt_prediction_provider.dart';
import 'package:pka_home/data/repositories/debt_prediction_repository.dart';
import 'package:pka_home/features/management/widgets/debt_risk_radar_tab.dart';
import 'package:pka_home/features/management/widgets/execute_dunning_dialog.dart';

class MockDebtPredictionRepository extends Mock implements DebtPredictionRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(DunningTier.tier1);
  });

  group('ExecuteDunningDialog Widget Tests', () {
    testWidgets('Hiển thị đầy đủ thông tin nợ và tự động điền mẫu văn bản theo tầng đề xuất', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExecuteDunningDialog(
              buildingId: 'bld-01',
              apartmentId: 'apt-01',
              apartmentCode: 'A0110',
              ownerName: 'Nguyễn Văn An',
              unpaidAmount: 7850000,
              overdueDays: 52,
              riskScore: 85,
              initialTier: DunningTier.tier3,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Kiểm tra header & thông tin căn hộ
      expect(find.text('Thực Thi Đôn Đốc Đa Tầng'), findsOneWidget);
      expect(find.text('Căn hộ: A0110 - Nguyễn Văn An'), findsOneWidget);
      expect(find.text('52 ngày'), findsOneWidget);
      expect(find.text('85 / 100'), findsOneWidget);

      // Kiểm tra 3 tầng đôn đốc
      expect(find.text('Tầng 1 - Nhắc nhở lịch sự'), findsOneWidget);
      expect(find.text('Tầng 2 - Cảnh báo tài chính'), findsOneWidget);
      expect(find.text('Tầng 3 - Tạm ngừng dịch vụ'), findsOneWidget);
      expect(find.text('Đề xuất AI'), findsOneWidget);

      // Kiểm tra mẫu văn bản tầng 3
      expect(find.text(DunningTier.tier3.defaultTitle), findsOneWidget);
      expect(find.textContaining('CẢNH BÁO ĐÔN ĐỐC ĐẶC BIỆT'), findsOneWidget);

      // Thử chuyển sang Tầng 1
      await tester.tap(find.text('Tầng 1 - Nhắc nhở lịch sự'));
      await tester.pumpAndSettle();

      expect(find.text(DunningTier.tier1.defaultTitle), findsOneWidget);
      expect(find.textContaining('Ban Quản Lý xin nhắc Quý cư dân'), findsOneWidget);
    });
  });

  group('DebtRiskRadarTab Widget Tests', () {
    late MockDebtPredictionRepository mockRepo;

    final mockRadarData = DebtRadarDataModel(
      buildingId: 'bld-01',
      kpi: const DebtRadarKpiModel(
        totalAtRiskApartments: 2,
        highRiskCount: 1,
        mediumRiskCount: 1,
        lowRiskCount: 0,
        totalOverdueDebt: 12050000,
        highRiskDebt: 7850000,
      ),
      apartments: [
        const DebtRiskScoreModel(
          apartmentId: 'apt-01',
          apartmentCode: 'A0110',
          buildingId: 'bld-01',
          ownerName: 'Nguyễn Văn An',
          ownerPhone: '0901234567',
          riskScore: 85,
          riskLevel: DebtRiskLevel.high,
          overdueDays: 52,
          unpaidAmount: 7850000,
          monthlyFeeAvg: 1600000,
          latePaymentCount: 3,
          recommendedTier: DunningTier.tier3,
          riskFactors: [
            RiskFactorModel(factor: 'overdue_duration', label: 'Quá hạn 52 ngày', severity: 'high'),
          ],
        ),
        const DebtRiskScoreModel(
          apartmentId: 'apt-02',
          apartmentCode: 'A0205',
          buildingId: 'bld-01',
          ownerName: 'Trần Thị Bình',
          ownerPhone: '0912345678',
          riskScore: 55,
          riskLevel: DebtRiskLevel.medium,
          overdueDays: 24,
          unpaidAmount: 4200000,
          monthlyFeeAvg: 1800000,
          latePaymentCount: 2,
          recommendedTier: DunningTier.tier2,
          riskFactors: [
            RiskFactorModel(factor: 'overdue_duration', label: 'Quá hạn 24 ngày', severity: 'medium'),
          ],
        ),
      ],
    );

    setUp(() {
      mockRepo = MockDebtPredictionRepository();
      when(() => mockRepo.getBuildingDebtRadar('bld-01'))
          .thenAnswer((_) async => mockRadarData);
    });

    testWidgets('Hiển thị KPI, bộ lọc, thẻ căn hộ và mở hộp thoại đôn đốc', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            debtPredictionRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DebtRiskRadarTab(buildingId: 'bld-01'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Kiểm tra KPI strip
      expect(find.text('Rủi ro cao'), findsWidgets);
      expect(find.text('1 căn'), findsNWidgets(2)); // 1 căn cao, 1 căn chú ý
      expect(find.text('Cần chú ý'), findsWidgets);
      expect(find.text('Tổng nợ quá hạn'), findsOneWidget);

      // Kiểm tra danh sách căn hộ
      expect(find.text('A0110'), findsOneWidget);
      expect(find.text('Nguyễn Văn An'), findsOneWidget);
      expect(find.text('85/100'), findsOneWidget);
      expect(find.text('A0205'), findsOneWidget);
      expect(find.text('Trần Thị Bình'), findsOneWidget);
      expect(find.text('55/100'), findsOneWidget);

      // Nút Đôn đốc
      final dunningButtons = find.widgetWithText(ElevatedButton, 'Đôn đốc');
      expect(dunningButtons, findsNWidgets(2));

      // Bấm nút Đôn đốc trên căn A0110 để mở dialog
      await tester.ensureVisible(dunningButtons.first);
      await tester.tap(dunningButtons.first);
      await tester.pumpAndSettle();

      expect(find.text('Thực Thi Đôn Đốc Đa Tầng'), findsOneWidget);
      expect(find.text('Căn hộ: A0110 - Nguyễn Văn An'), findsOneWidget);
    });
  });
}
