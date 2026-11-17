import 'package:flutter/material.dart';

/// Tiện ích mở rộng Typography giúp truy xuất TextTheme nhất quán và thích ứng
/// theo tiêu chuẩn Design System Modern Enterprise SaaS B2B của Vivona.
extension AppTypographyExtension on BuildContext {
  /// Theme gốc của ứng dụng
  ThemeData get theme => Theme.of(this);

  /// Bộ TextTheme hiện hành theo theme cấu hình
  TextTheme get textTheme => Theme.of(this).textTheme;

  // Display Styles
  TextStyle? get displayLarge => textTheme.displayLarge;
  TextStyle? get displayMedium => textTheme.displayMedium;
  TextStyle? get displaySmall => textTheme.displaySmall;

  // Headline Styles
  TextStyle? get headlineLarge => textTheme.headlineLarge;
  TextStyle? get headlineMedium => textTheme.headlineMedium;
  TextStyle? get headlineSmall => textTheme.headlineSmall;

  // Title Styles
  TextStyle? get titleLarge => textTheme.titleLarge;
  TextStyle? get titleMedium => textTheme.titleMedium;
  TextStyle? get titleSmall => textTheme.titleSmall;

  // Body Styles
  TextStyle? get bodyLarge => textTheme.bodyLarge;
  TextStyle? get bodyMedium => textTheme.bodyMedium;
  TextStyle? get bodySmall => textTheme.bodySmall;

  // Label Styles
  TextStyle? get labelLarge => textTheme.labelLarge;
  TextStyle? get labelMedium => textTheme.labelMedium;
  TextStyle? get labelSmall => textTheme.labelSmall;
}

/// Lớp hằng số kích thước Typography chuẩn (Theme Spec)
class AppTypography {
  const AppTypography._();

  static const double displayLargeSize = 32.0;
  static const double headlineLargeSize = 24.0;
  static const double headlineMediumSize = 20.0;
  static const double titleLargeSize = 18.0;
  static const double titleMediumSize = 16.0;
  static const double bodyLargeSize = 15.0;
  static const double bodyMediumSize = 14.0;
  static const double bodySmallSize = 13.0;
  static const double labelSmallSize = 12.0;
  static const double captionSize = 11.0;
}

