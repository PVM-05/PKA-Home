import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivona/core/widgets/bounceable.dart';

void main() {
  testWidgets('Bounceable renders child and triggers onTap', (WidgetTester tester) async {
    bool tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Bounceable(
            onTap: () {
              tapped = true;
            },
            child: const Text('Nút bấm'),
          ),
        ),
      ),
    );

    expect(find.text('Nút bấm'), findsOneWidget);

    await tester.tap(find.text('Nút bấm'));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
  });

  testWidgets('Bounceable animates scale down when pointer is down', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Bounceable(
              scaleFactor: 0.9,
              onTap: () {},
              child: const SizedBox(width: 100, height: 100, child: Text('Scale Box')),
            ),
          ),
        ),
      ),
    );

    // Bắt đầu ấn xuống (tap down)
    await tester.press(find.text('Scale Box'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Tìm widget AnimatedScale
    final animatedScaleFinder = find.byType(AnimatedScale);
    expect(animatedScaleFinder, findsOneWidget);

    final AnimatedScale animatedScale = tester.widget(animatedScaleFinder);
    expect(animatedScale.scale, equals(0.9));

    // Nhả tay ra
    await tester.pumpAndSettle();
  });
}
