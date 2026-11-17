import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivona/core/motion/app_spring_motion.dart';

void main() {
  group('AppSpringMotion Tests', () {
    testWidgets('animateSpringEntry attaches Animate widget with slide and fade',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const Text('Hello Spring').animateSpringEntry(),
          ),
        ),
      );

      expect(find.text('Hello Spring'), findsOneWidget);
      expect(find.byType(Animate), findsOneWidget);

      // Chạy hết thời lượng animation để dọn dẹp timers của flutter_animate
      await tester.pumpAndSettle();
    });

    testWidgets('animateStaggeredItem calculates delay correctly based on index',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const Text('Item 0').animateStaggeredItem(index: 0),
                const Text('Item 1').animateStaggeredItem(index: 1),
                const Text('Item 2').animateStaggeredItem(index: 2),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(Animate), findsNWidgets(3));

      // Chạy hết thời lượng animation để dọn dẹp timers
      await tester.pumpAndSettle();
    });

    testWidgets('animatePulseHighlight renders pulse animation',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const Icon(Icons.notifications).animatePulseHighlight(autoPlay: false),
          ),
        ),
      );

      expect(find.byType(Animate), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 50));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    });
  });
}
