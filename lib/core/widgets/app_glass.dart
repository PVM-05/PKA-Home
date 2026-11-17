import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

/// Thẻ hiệu ứng kính mờ (Glassmorphism 2.0 / Frosted Surface) chuẩn Vivona 2026.
/// Kết hợp BackdropFilter, viền vi mô và lớp nền thích ứng Light/Dark theme.
class AppGlassCard extends StatelessWidget {
  const AppGlassCard({
    super.key,
    required this.child,
    this.borderRadius,
    this.blur = 10.0,
    this.opacity = 0.75,
    this.padding,
    this.margin,
    this.borderWidth = 1.0,
    this.borderColor,
  });

  final Widget child;
  final BorderRadius? borderRadius;
  final double blur;
  final double opacity;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderWidth;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveRadius = borderRadius ?? AppRadius.rLg;
    final effectivePadding = padding ?? AppSpacing.p16;

    final defaultBorderColor = theme.brightness == Brightness.dark
        ? theme.colorScheme.outlineVariant.withValues(alpha: 0.18)
        : theme.colorScheme.outlineVariant.withValues(alpha: 0.35);

    final surfaceColor = theme.colorScheme.surface.withValues(alpha: opacity);

    Widget content = ClipRRect(
      borderRadius: effectiveRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: effectivePadding,
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: effectiveRadius,
            border: Border.all(
              color: borderColor ?? defaultBorderColor,
              width: borderWidth,
            ),
          ),
          child: child,
        ),
      ),
    );

    if (margin != null) {
      content = Padding(
        padding: margin!,
        child: content,
      );
    }

    return content;
  }
}

/// Nền kính mờ dành cho SliverAppBar hoặc BottomNavigationBar
class FrostedBackground extends StatelessWidget {
  const FrostedBackground({
    super.key,
    this.blur = 12.0,
    this.opacity = 0.82,
    this.child,
  });

  final double blur;
  final double opacity;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaceColor = theme.colorScheme.surface.withValues(alpha: opacity);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          color: surfaceColor,
          child: child,
        ),
      ),
    );
  }
}
