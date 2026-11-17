import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivona/core/theme/app_radius.dart';
import 'package:vivona/core/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppTheme TextTheme 15 Styles & Component Themes Tests', () {
    test('Light Theme: Đầy đủ 15/15 kiểu chữ trong TextTheme và non-null', () {
      final theme = AppTheme.lightTheme;
      final textTheme = theme.textTheme;

      // Display Styles
      expect(textTheme.displayLarge, isNotNull);
      expect(textTheme.displayMedium, isNotNull);
      expect(textTheme.displaySmall, isNotNull);

      // Headline Styles
      expect(textTheme.headlineLarge, isNotNull);
      expect(textTheme.headlineMedium, isNotNull);
      expect(textTheme.headlineSmall, isNotNull);

      // Title Styles
      expect(textTheme.titleLarge, isNotNull);
      expect(textTheme.titleMedium, isNotNull);
      expect(textTheme.titleSmall, isNotNull);

      // Body Styles
      expect(textTheme.bodyLarge, isNotNull);
      expect(textTheme.bodyMedium, isNotNull);
      expect(textTheme.bodySmall, isNotNull);

      // Label Styles
      expect(textTheme.labelLarge, isNotNull);
      expect(textTheme.labelMedium, isNotNull);
      expect(textTheme.labelSmall, isNotNull);
    });

    test('Dark Theme: Đầy đủ 15/15 kiểu chữ trong TextTheme và non-null', () {
      final theme = AppTheme.darkTheme;
      final textTheme = theme.textTheme;

      // Display Styles
      expect(textTheme.displayLarge, isNotNull);
      expect(textTheme.displayMedium, isNotNull);
      expect(textTheme.displaySmall, isNotNull);

      // Headline Styles
      expect(textTheme.headlineLarge, isNotNull);
      expect(textTheme.headlineMedium, isNotNull);
      expect(textTheme.headlineSmall, isNotNull);

      // Title Styles
      expect(textTheme.titleLarge, isNotNull);
      expect(textTheme.titleMedium, isNotNull);
      expect(textTheme.titleSmall, isNotNull);

      // Body Styles
      expect(textTheme.bodyLarge, isNotNull);
      expect(textTheme.bodyMedium, isNotNull);
      expect(textTheme.bodySmall, isNotNull);

      // Label Styles
      expect(textTheme.labelLarge, isNotNull);
      expect(textTheme.labelMedium, isNotNull);
      expect(textTheme.labelSmall, isNotNull);
    });

    test('Light Theme: Các Component Themes được cấu hình đầy đủ', () {
      final theme = AppTheme.lightTheme;

      expect(theme.filledButtonTheme.style, isNotNull);
      expect(theme.chipTheme.shape, isNotNull);
      expect(theme.dialogTheme.shape, isNotNull);
      expect(theme.bottomSheetTheme.shape, isNotNull);
      expect(theme.bottomSheetTheme.showDragHandle, isTrue);
      expect(theme.switchTheme.thumbColor, isNotNull);
      expect(theme.floatingActionButtonTheme.shape, isNotNull);
      expect(theme.navigationBarTheme.backgroundColor, isNotNull);
    });

    test('Dark Theme: Các Component Themes được cấu hình đầy đủ', () {
      final theme = AppTheme.darkTheme;

      expect(theme.filledButtonTheme.style, isNotNull);
      expect(theme.chipTheme.shape, isNotNull);
      expect(theme.dialogTheme.shape, isNotNull);
      expect(theme.bottomSheetTheme.shape, isNotNull);
      expect(theme.bottomSheetTheme.showDragHandle, isTrue);
      expect(theme.switchTheme.thumbColor, isNotNull);
      expect(theme.floatingActionButtonTheme.shape, isNotNull);
      expect(theme.navigationBarTheme.backgroundColor, isNotNull);
    });

    test('AppTheme: BottomSheet sử dụng AppRadius.bottomSheet', () {
      final lightTheme = AppTheme.lightTheme;
      final darkTheme = AppTheme.darkTheme;

      const expectedShape = RoundedRectangleBorder(borderRadius: AppRadius.bottomSheet);
      expect(lightTheme.bottomSheetTheme.shape, equals(expectedShape));
      expect(darkTheme.bottomSheetTheme.shape, equals(expectedShape));
    });
  });
}
