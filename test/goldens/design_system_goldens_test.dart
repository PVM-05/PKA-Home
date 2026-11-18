import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivona/core/widgets/app_card.dart';
import 'package:vivona/core/widgets/app_glass.dart';
import 'package:vivona/core/widgets/bounceable.dart';
import 'golden_test_helper.dart';

void main() {
  setUpAll(() {
    setupGoldenTests();
  });

  group('Design System Core Golden Tests', () {
    testWidgets('AppCard renders correctly in Light Mode', (tester) async {
      await pumpGoldenWidget(
        tester,
        const AppCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tiêu đề Thẻ', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('Nội dung thẻ mô tả chuẩn Design System 2026.'),
            ],
          ),
        ),
        isDark: false,
      );

      await expectLater(
        find.byType(AppCard),
        matchesGoldenFile('goldens/app_card_light.png'),
      );
    });

    testWidgets('AppCard renders correctly in Dark Mode', (tester) async {
      await pumpGoldenWidget(
        tester,
        const AppCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tiêu đề Thẻ Tối', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('Nội dung thẻ mô tả trong chế độ tối.'),
            ],
          ),
        ),
        isDark: true,
      );

      await expectLater(
        find.byType(AppCard),
        matchesGoldenFile('goldens/app_card_dark.png'),
      );
    });

    testWidgets('AppGlassCard renders frosted glass in Light Mode', (tester) async {
      await pumpGoldenWidget(
        tester,
        const AppGlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Thẻ Kính Mờ', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('Hiệu ứng kính mờ Glassmorphism 2.0.'),
            ],
          ),
        ),
        isDark: false,
      );

      await expectLater(
        find.byType(AppGlassCard),
        matchesGoldenFile('goldens/app_glass_card_light.png'),
      );
    });

    testWidgets('AppGlassCard renders frosted glass in Dark Mode', (tester) async {
      await pumpGoldenWidget(
        tester,
        const AppGlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Thẻ Kính Mờ Tối', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('Hiệu ứng kính mờ trong không gian tối.'),
            ],
          ),
        ),
        isDark: true,
      );

      await expectLater(
        find.byType(AppGlassCard),
        matchesGoldenFile('goldens/app_glass_card_dark.png'),
      );
    });

    testWidgets('Bounceable interactive widget renders resting state', (tester) async {
      await pumpGoldenWidget(
        tester,
        Bounceable(
          onTap: () {},
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('Nút Lò Xo Spring', style: TextStyle(color: Colors.white)),
          ),
        ),
        isDark: false,
      );

      await expectLater(
        find.byType(Bounceable),
        matchesGoldenFile('goldens/bounceable_resting.png'),
      );
    });
  });
}

