import 'package:flutter/material.dart';

/// Card chuẩn tuân thủ Design System và thích ứng Dark/Light Mode.
/// Tự động lấy màu nền từ Theme (`colorScheme.surface` / `cardTheme.color`)
/// và viền mỏng từ `dividerColor`, không hardcode màu trắng.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Color? borderColor;
  final double borderRadius;
  final VoidCallback? onTap;
  final double elevation;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16.0),
    this.margin,
    this.color,
    this.borderColor,
    this.borderRadius = 16.0,
    this.onTap,
    this.elevation = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final cardColor = color ?? 
        (isDark ? (theme.cardTheme.color ?? theme.colorScheme.surface) : theme.colorScheme.surface);
        
    final effectiveBorderColor = borderColor ?? 
        (isDark 
            ? theme.dividerColor.withValues(alpha: 0.15) 
            : theme.dividerColor.withValues(alpha: 0.2));
            
    final border = BorderSide(color: effectiveBorderColor);

    final Widget content = padding != null 
        ? Padding(padding: padding!, child: child) 
        : child;

    if (onTap != null) {
      return Card(
        elevation: elevation,
        color: cardColor,
        margin: margin ?? EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          side: border,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: content,
        ),
      );
    }

    return Card(
      elevation: elevation,
      color: cardColor,
      margin: margin ?? EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        side: border,
      ),
      clipBehavior: Clip.antiAlias,
      child: content,
    );
  }
}
