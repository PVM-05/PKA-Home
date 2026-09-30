import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/core/widgets/app_card.dart';

void main() {
  group('AppCard Widget Tests', () {
    testWidgets('renders child content with default padding', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppCard(
              child: Text('Nội dung thẻ'),
            ),
          ),
        ),
      );

      expect(find.text('Nội dung thẻ'), findsOneWidget);
      expect(find.byType(Card), findsOneWidget);
    });

    testWidgets('triggers onTap callback when tapped', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppCard(
              onTap: () => tapped = true,
              child: const Text('Thẻ có thể nhấn'),
            ),
          ),
        ),
      );

      expect(find.byType(InkWell), findsOneWidget);
      await tester.tap(find.text('Thẻ có thể nhấn'));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('adapts to dark mode without crashing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: AppCard(
              child: Text('Giao diện tối'),
            ),
          ),
        ),
      );

      expect(find.text('Giao diện tối'), findsOneWidget);
    });
  });
}
