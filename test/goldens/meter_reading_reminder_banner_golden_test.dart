import 'package:flutter_test/flutter_test.dart';
import 'package:vivona/features/resident/widgets/home/meter_reading_reminder_banner.dart';
import 'golden_test_helper.dart';

void main() {
  setUpAll(() {
    setupGoldenTests();
  });

  group('MeterReadingReminderBanner Golden Tests', () {
    testWidgets('MeterReadingReminderBanner renders correctly in Light Mode', (tester) async {
      await pumpGoldenWidget(
        tester,
        const MeterReadingReminderBanner(),
        isDark: false,
      );

      await expectLater(
        find.byType(MeterReadingReminderBanner),
        matchesGoldenFile('goldens/meter_reading_banner_light.png'),
      );
    });

    testWidgets('MeterReadingReminderBanner renders correctly in Dark Mode', (tester) async {
      await pumpGoldenWidget(
        tester,
        const MeterReadingReminderBanner(),
        isDark: true,
      );

      await expectLater(
        find.byType(MeterReadingReminderBanner),
        matchesGoldenFile('goldens/meter_reading_banner_dark.png'),
      );
    });
  });
}

