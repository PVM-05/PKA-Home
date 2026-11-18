import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivona/data/models/meter_reading_submission_model.dart';
import 'package:vivona/data/providers/meter_reading_provider.dart';
import 'package:vivona/features/resident/widgets/home/resident_utility_consumption_chart_card.dart';

MeterReadingSubmissionModel _createMockSubmission({
  required String id,
  required String period,
  required double electricReading,
  required double waterReading,
  required double prevElectric,
  required double prevWater,
  required DateTime createdAt,
}) {
  return MeterReadingSubmissionModel(
    id: id,
    apartmentId: 'apt-001',
    submittedBy: 'user-001',
    period: period,
    electricReading: electricReading,
    waterReading: waterReading,
    previousElectricReading: prevElectric,
    previousWaterReading: prevWater,
    electricConsumed: electricReading - prevElectric,
    waterConsumed: waterReading - prevWater,
    status: 'approved',
    createdAt: createdAt,
  );
}

void main() {
  group('ResidentUtilityConsumptionChartCard Truthfulness Tests', () {
    testWidgets('Tự động ẩn thẻ (SizedBox.shrink) khi chưa có đủ 2 kỳ chốt chỉ số thật', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            residentUtilityConsumptionHistoryProvider.overrideWith(
              (ref) async => [
                _createMockSubmission(
                  id: 'sub-1',
                  period: '10/2026',
                  electricReading: 120,
                  waterReading: 15,
                  prevElectric: 100,
                  prevWater: 10,
                  createdAt: DateTime(2026, 10, 25),
                ),
              ],
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ResidentUtilityConsumptionChartCard(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Không hiển thị bất kỳ text hoặc biểu đồ nào
      expect(find.text('Tiêu thụ điện & nước'), findsNothing);
      expect(find.byType(Card), findsNothing);
    });

    testWidgets('Tự động ẩn thẻ khi danh sách lịch sử rỗng', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            residentUtilityConsumptionHistoryProvider.overrideWith(
              (ref) async => [],
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ResidentUtilityConsumptionChartCard(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Tiêu thụ điện & nước'), findsNothing);
    });

    testWidgets('Hiển thị biểu đồ dữ liệu thật khi có từ 2 kỳ chốt chỉ số trở lên', (tester) async {
      final mockSubmissions = [
        _createMockSubmission(
          id: 'sub-1',
          period: '09/2026',
          electricReading: 200,
          waterReading: 20,
          prevElectric: 100, // Tiêu thụ: 100 kWh
          prevWater: 10, // Tiêu thụ: 10 m3
          createdAt: DateTime(2026, 9, 25),
        ),
        _createMockSubmission(
          id: 'sub-2',
          period: '10/2026',
          electricReading: 350,
          waterReading: 32,
          prevElectric: 200, // Tiêu thụ: 150 kWh
          prevWater: 20, // Tiêu thụ: 12 m3
          createdAt: DateTime(2026, 10, 25),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            residentUtilityConsumptionHistoryProvider.overrideWith(
              (ref) async => mockSubmissions,
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ResidentUtilityConsumptionChartCard(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Phải hiển thị tiêu đề thẻ
      expect(find.text('Tiêu thụ điện & nước'), findsOneWidget);

      // Hiển thị tháng thật
      expect(find.text('T9'), findsOneWidget);
      expect(find.text('T10'), findsOneWidget);

      // Mặc định hiển thị điện: kỳ mới nhất là 150 kWh (350 - 200)
      expect(find.text('150'), findsOneWidget);
      expect(find.text('kWh'), findsOneWidget);

      // Chuyển sang tab Nước
      await tester.tap(find.text('Nước'));
      await tester.pumpAndSettle();

      // Kỳ mới nhất là 12 m3 (32 - 20)
      expect(find.text('12'), findsOneWidget);
      expect(find.text('m³'), findsOneWidget);
    });
  });
}
