import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivona/features/resident/widgets/home/meter_reading_reminder_banner.dart';

void main() {
  group('MeterReadingReminderBanner Widget Tests', () {
    testWidgets('renders banner with title, subtitle, and badge correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MeterReadingReminderBanner(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Kỳ ghi chỉ số điện nước'), findsOneWidget);
      expect(find.text('Đang mở'), findsOneWidget);
      expect(find.byIcon(Icons.speed_outlined), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('provides Semantics container and label for accessibility', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MeterReadingReminderBanner(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final semanticsFinder = find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.label != null &&
            w.properties.label!.contains('Đã mở cổng ghi chỉ số điện nước'),
      );
      expect(semanticsFinder, findsOneWidget);
    });
  });
}

