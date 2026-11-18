import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivona/core/widgets/app_semantic_badge.dart';
import 'package:vivona/core/widgets/bounceable.dart';
import 'package:vivona/features/resident/widgets/home/resident_utility_consumption_chart_card.dart';

void main() {
  group('App Accessibility & Semantics Tests (WCAG AA)', () {
    testWidgets('AppSemanticBadge wraps child with readOnly container Semantics', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppSemanticBadge(
              label: 'Trạng thái hóa đơn: Đã thanh toán',
              tooltip: 'Hóa đơn đã được thanh toán đầy đủ',
              child: Text('Đã thanh toán'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final semanticsFinder = find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.readOnly == true &&
            w.properties.label == 'Trạng thái hóa đơn: Đã thanh toán',
      );
      expect(semanticsFinder, findsOneWidget);
      expect(find.byType(Tooltip), findsOneWidget);
    });

    testWidgets('Bounceable automatically exposes button semantics when onTap is provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Bounceable(
              onTap: () {},
              semanticLabel: 'Thanh toán ngay',
              child: const Text('Thanh toán'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final buttonFinder = find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.button == true &&
            w.properties.label == 'Thanh toán ngay',
      );
      expect(buttonFinder, findsOneWidget);
    });

    testWidgets('ResidentUtilityConsumptionChartCard contains accessible descriptive chart semantics', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ResidentUtilityConsumptionChartCard(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final chartSemanticsFinder = find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.label != null &&
            w.properties.label!.contains('Biểu đồ tiêu thụ') &&
            w.properties.label!.contains('6 tháng gần nhất'),
      );
      expect(chartSemanticsFinder, findsOneWidget);
    });
  });
}

