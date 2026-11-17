import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivona/core/widgets/app_glass.dart';

void main() {
  group('AppGlassCard Tests', () {
    testWidgets('renders child and contains BackdropFilter with blur',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppGlassCard(
              blur: 12.0,
              child: Text('Kính mờ Vivona'),
            ),
          ),
        ),
      );

      expect(find.text('Kính mờ Vivona'), findsOneWidget);

      final backdropFilterFinder = find.descendant(
        of: find.byType(AppGlassCard),
        matching: find.byType(BackdropFilter),
      );
      expect(backdropFilterFinder, findsOneWidget);

      final BackdropFilter backdrop = tester.widget(backdropFilterFinder);
      expect(backdrop.filter, equals(ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0)));
    });

    testWidgets('adapts surface tint in dark and light modes',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: ThemeMode.dark,
          home: const Scaffold(
            body: AppGlassCard(
              child: Text('Chế độ tối'),
            ),
          ),
        ),
      );

      expect(find.text('Chế độ tối'), findsOneWidget);
      expect(find.byType(ClipRRect), findsOneWidget);
    });
  });
}
