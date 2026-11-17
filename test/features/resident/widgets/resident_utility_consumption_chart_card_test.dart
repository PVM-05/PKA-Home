import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivona/features/resident/widgets/home/resident_utility_consumption_chart_card.dart';

void main() {
  testWidgets('ResidentUtilityConsumptionChartCard renders chart and toggles electricity and water tabs',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ResidentUtilityConsumptionChartCard(),
          ),
        ),
      ),
    );

    // Kiểm tra tiêu đề chính
    expect(find.text('Tiêu thụ điện & nước'), findsOneWidget);

    // Kiểm tra 2 tabs
    expect(find.text('Điện'), findsOneWidget);
    expect(find.text('Nước'), findsOneWidget);

    // Kiểm tra BarChart tồn tại
    expect(find.byType(BarChart), findsOneWidget);

    // Mặc định tab Điện: có chữ kWh
    expect(find.textContaining('kWh'), findsAtLeastNWidgets(1));

    // Chuyển sang tab Nước
    await tester.tap(find.text('Nước'));
    await tester.pumpAndSettle();

    // Tab Nước: có chữ m³
    expect(find.textContaining('m³'), findsAtLeastNWidgets(1));
  });
}

