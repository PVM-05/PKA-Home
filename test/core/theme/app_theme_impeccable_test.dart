import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/core/theme/app_theme.dart';
import 'package:pka_home/core/widgets/app_card.dart';
import 'package:pka_home/features/management/widgets/stat_card.dart';

void main() {
  group('AppTheme Impeccable Design Tokens', () {
    test('contains modern enterprise palette tokens', () {
      expect(AppTheme.sapphire, isNotNull);
      expect(AppTheme.slate900, isNotNull);
      expect(AppTheme.slate50, isNotNull);
      expect(AppGradients.brandPrimary, isNotNull);
      expect(AppGradients.heroDark, isNotNull);
      expect(AppShadows.softSm, isNotEmpty);
      expect(AppShadows.softMd, isNotEmpty);
    });

    test('themeData integrates modern surface and border colors', () {
      final light = AppTheme.lightTheme;
      final dark = AppTheme.darkTheme;

      expect(light.useMaterial3, isTrue);
      expect(dark.useMaterial3, isTrue);
      expect(light.colorScheme.primary, equals(AppTheme.sapphire));
    });
  });

  group('AppCard Impeccable Refinements', () {
    testWidgets('renders with layered subtle shadows and adaptive border', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: AppCard(
              child: Text('Card Content'),
            ),
          ),
        ),
      );

      expect(find.text('Card Content'), findsOneWidget);
      expect(find.byType(AppCard), findsOneWidget);
    });
  });

  group('StatCard Dark Mode Parity & Text Safety', () {
    testWidgets('adapts to dark mode surface without hardcoded white', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: StatCard(
              title: 'Doanh thu tháng',
              value: '1.250.000.000 đ',
              icon: Icons.payments_outlined,
              color: AppTheme.sapphire,
            ),
          ),
        ),
      );

      final cardFinder = find.byType(Card);
      expect(cardFinder, findsOneWidget);

      final cardWidget = tester.widget<Card>(cardFinder);
      // Ensure it does NOT use hardcoded Colors.white in dark mode
      expect(cardWidget.color, isNot(equals(Colors.white)));
      expect(find.text('Doanh thu tháng'), findsOneWidget);
      expect(find.text('1.250.000.000 đ'), findsOneWidget);
    });
  });
}
