import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Card chuẩn tuân thủ Design System và thích ứng Dark/Light Mode.
/// Tự động lấy màu nền từ Theme (`colorScheme.surface` / `cardTheme.color`)
/// và viền siêu mỏng mờ tinh tế từ `dividerColor`, không hardcode màu trắng.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Color? borderColor;
  final double borderRadius;
  final VoidCallback? onTap;
  final double elevation;
  final bool showSoftShadow;
  final String? semanticLabel;

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
    this.showSoftShadow = true,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final cardColor = color ?? 
        (isDark ? (theme.cardTheme.color ?? theme.colorScheme.surface) : theme.colorScheme.surface);
        
    final effectiveBorderColor = borderColor ?? 
        (isDark 
            ? Colors.white.withValues(alpha: 0.08) 
            : Colors.black.withValues(alpha: 0.07));
            
    final border = BorderSide(color: effectiveBorderColor, width: 1.0);

    final Widget content = padding != null 
        ? Padding(padding: padding!, child: child) 
        : child;

    final cardWidget = Card(
      elevation: elevation,
      color: cardColor,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        side: border,
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap != null
          ? InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(borderRadius),
              child: content,
            )
          : content,
    );

    Widget result = showSoftShadow && elevation == 0 && !isDark
        ? Container(
            margin: margin ?? EdgeInsets.zero,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              boxShadow: AppShadows.softSm,
            ),
            child: cardWidget,
          )
        : Padding(
            padding: margin ?? EdgeInsets.zero,
            child: cardWidget,
          );

    if (semanticLabel != null || onTap != null) {
      result = Semantics(
        label: semanticLabel,
        button: onTap != null,
        enabled: onTap != null,
        child: result,
      );
    }

    return result;
  }
}
