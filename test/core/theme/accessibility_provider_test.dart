import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/core/theme/accessibility_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FontSizeOption Tests', () {
    test('fromScale maps correct options based on threshold', () {
      expect(FontSizeOption.fromScale(1.0), equals(FontSizeOption.normal));
      expect(FontSizeOption.fromScale(1.05), equals(FontSizeOption.normal));
      expect(FontSizeOption.fromScale(1.10), equals(FontSizeOption.large));
      expect(FontSizeOption.fromScale(1.15), equals(FontSizeOption.large));
      expect(FontSizeOption.fromScale(1.24), equals(FontSizeOption.large));
      expect(FontSizeOption.fromScale(1.25), equals(FontSizeOption.extraLarge));
      expect(FontSizeOption.fromScale(1.30), equals(FontSizeOption.extraLarge));
      expect(FontSizeOption.fromScale(1.50), equals(FontSizeOption.extraLarge));
    });

    test('FontSizeOption values contain valid scales and labels', () {
      expect(FontSizeOption.normal.scale, 1.0);
      expect(FontSizeOption.large.scale, 1.15);
      expect(FontSizeOption.extraLarge.scale, 1.30);

      expect(FontSizeOption.normal.label, 'Tiêu chuẩn');
      expect(FontSizeOption.large.label, 'Lớn');
      expect(FontSizeOption.extraLarge.label, 'Rất lớn');
    });
  });

  group('FontSizeNotifier Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('defaults to 1.0 if no preference stored', () {
      final notifier = FontSizeNotifier();
      expect(notifier.state, equals(1.0));
    });

    test('setScale updates state and saves to SharedPreferences', () async {
      final notifier = FontSizeNotifier();
      await notifier.setScale(1.15);
      expect(notifier.state, equals(1.15));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble(kFontSizeScaleKey), equals(1.15));
    });
  });
}
