import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivona/core/theme/app_theme.dart';

/// Hàm tính độ sáng tương đối (Relative Luminance) theo chuẩn WCAG 2.1
double _calculateRelativeLuminance(Color color) {
  double transformChannel(double channel) {
    return channel <= 0.04045
        ? channel / 12.92
        : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
  }

  final r = transformChannel(color.r);
  final g = transformChannel(color.g);
  final b = transformChannel(color.b);

  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

/// Hàm tính tỷ lệ tương phản (Contrast Ratio) giữa 2 màu theo chuẩn W3C WCAG 2.1:
/// (L1 + 0.05) / (L2 + 0.05), trong đó L1 là màu sáng hơn.
double _calculateContrastRatio(Color c1, Color c2) {
  final l1 = _calculateRelativeLuminance(c1);
  final l2 = _calculateRelativeLuminance(c2);
  final lighter = math.max(l1, l2);
  final darker = math.min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ColorScheme Toàn Diện & Xóa Màu Tím Mặc Định M3', () {
    test('ColorScheme Light định nghĩa đủ toàn bộ role và không rò rỉ màu tím baseline', () {
      final scheme = AppTheme.lightTheme.colorScheme;

      // Kiểm tra viền kính AppGlassCard và các thẻ giao diện
      expect(scheme.outlineVariant, equals(const Color(0xFFE2E8F0)));
      expect(scheme.surfaceContainerHighest, equals(const Color(0xFFE2E8F0)));

      // Đảm bảo không bị fallback về màu tím mặc định của M3 baseline (#CAC4D0 hoặc các tone tím)
      expect(scheme.outlineVariant, isNot(equals(const Color(0xFFCAC4D0))));
      expect(scheme.outlineVariant.r, isNot(equals(const Color(0xFF6750A4).r)));

      // Kiểm tra các container role
      expect(scheme.primaryContainer, equals(const Color(0xFFDBEAFE)));
      expect(scheme.secondaryContainer, equals(const Color(0xFFE0F2FE)));
      expect(scheme.tertiary, equals(AppTheme.emerald));
      expect(scheme.tertiaryContainer, equals(const Color(0xFFD1FAE5)));
      expect(scheme.surfaceContainer, equals(const Color(0xFFF1F5F9)));
      expect(scheme.surfaceContainerLow, equals(const Color(0xFFF8FAFC)));
    });

    test('ColorScheme Dark định nghĩa đủ toàn bộ role và màu sắc Slate trung tính', () {
      final scheme = AppTheme.darkTheme.colorScheme;

      // Kiểm tra viền kính AppGlassCard trong Dark Mode
      expect(scheme.outlineVariant, equals(const Color(0xFF334155)));
      expect(scheme.surfaceContainerHighest, equals(const Color(0xFF383838)));

      // Đảm bảo không bị fallback về màu tím dark mặc định của M3 baseline
      expect(scheme.outlineVariant, isNot(equals(const Color(0xFF49454F))));

      expect(scheme.surface, equals(const Color(0xFF1E1E1E)));
      expect(scheme.onSurface, equals(Colors.white));
      expect(scheme.onSurfaceVariant, equals(const Color(0xFF94A3B8)));
      expect(scheme.surfaceContainer, equals(const Color(0xFF242424)));
    });
  });

  group('Kiểm Toán Tương Phản Màu Semantic WCAG AA (>= 4.5:1)', () {
    const whiteSurface = Color(0xFFFFFFFF);
    const darkSurface = Color(0xFF1E1E1E);

    test('Màu chữ semantic trên nền sáng đạt chuẩn WCAG AA >= 4.5:1', () {
      final successRatio = _calculateContrastRatio(AppTheme.textSuccess, whiteSurface);
      final warningRatio = _calculateContrastRatio(AppTheme.textWarning, whiteSurface);
      final errorRatio = _calculateContrastRatio(AppTheme.textError, whiteSurface);
      final secondaryRatio = _calculateContrastRatio(AppTheme.textSecondaryAction, whiteSurface);
      final primaryRatio = _calculateContrastRatio(AppTheme.primary, whiteSurface);

      expect(successRatio, greaterThanOrEqualTo(4.5),
          reason: 'textSuccess (Emerald 700) phải đạt >= 4.5:1 trên nền trắng (thực tế: $successRatio)');
      expect(warningRatio, greaterThanOrEqualTo(4.5),
          reason: 'textWarning (Amber 700) phải đạt >= 4.5:1 trên nền trắng (thực tế: $warningRatio)');
      expect(errorRatio, greaterThanOrEqualTo(4.5),
          reason: 'textError (Rose 700) phải đạt >= 4.5:1 trên nền trắng (thực tế: $errorRatio)');
      expect(secondaryRatio, greaterThanOrEqualTo(4.5),
          reason: 'textSecondaryAction (Sky 700) phải đạt >= 4.5:1 trên nền trắng (thực tế: $secondaryRatio)');
      expect(primaryRatio, greaterThanOrEqualTo(4.5),
          reason: 'primary (Sapphire) phải đạt >= 4.5:1 trên nền trắng (thực tế: $primaryRatio)');
    });

    test('Màu trạng thái AppStatusColors trên nền sáng đạt chuẩn WCAG AA >= 4.5:1', () {
      final paidRatio = _calculateContrastRatio(AppStatusColors.paid, whiteSurface);
      final unpaidRatio = _calculateContrastRatio(AppStatusColors.unpaid, whiteSurface);
      final pendingRatio = _calculateContrastRatio(AppStatusColors.pendingConfirmation, whiteSurface);

      expect(paidRatio, greaterThanOrEqualTo(4.5),
          reason: 'AppStatusColors.paid phải đạt >= 4.5:1 trên nền trắng (thực tế: $paidRatio)');
      expect(unpaidRatio, greaterThanOrEqualTo(4.5),
          reason: 'AppStatusColors.unpaid phải đạt >= 4.5:1 trên nền trắng (thực tế: $unpaidRatio)');
      expect(pendingRatio, greaterThanOrEqualTo(4.5),
          reason: 'AppStatusColors.pendingConfirmation phải đạt >= 4.5:1 trên nền trắng (thực tế: $pendingRatio)');
    });

    test('Màu chữ và trạng thái trong Dark Mode đạt chuẩn WCAG AA >= 4.5:1', () {
      final darkTextSecRatio = _calculateContrastRatio(const Color(0xFF94A3B8), darkSurface);
      final darkSuccessRatio = _calculateContrastRatio(AppTheme.darkTextSuccess, darkSurface);
      final darkWarningRatio = _calculateContrastRatio(AppTheme.darkTextWarning, darkSurface);
      final darkErrorRatio = _calculateContrastRatio(AppTheme.darkTextError, darkSurface);

      expect(darkTextSecRatio, greaterThanOrEqualTo(4.5),
          reason: 'darkTextSecondary (#94A3B8) phải đạt >= 4.5:1 trên nền tối (thực tế: $darkTextSecRatio)');
      expect(darkSuccessRatio, greaterThanOrEqualTo(4.5),
          reason: 'darkTextSuccess phải đạt >= 4.5:1 trên nền tối (thực tế: $darkSuccessRatio)');
      expect(darkWarningRatio, greaterThanOrEqualTo(4.5),
          reason: 'darkTextWarning phải đạt >= 4.5:1 trên nền tối (thực tế: $darkWarningRatio)');
      expect(darkErrorRatio, greaterThanOrEqualTo(4.5),
          reason: 'darkTextError phải đạt >= 4.5:1 trên nền tối (thực tế: $darkErrorRatio)');
    });
  });
}
