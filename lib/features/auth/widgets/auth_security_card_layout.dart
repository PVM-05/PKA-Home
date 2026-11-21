import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';

/// Khung giao diện thống nhất cho cụm màn hình bảo mật (OTP, MFA, Khôi phục & Đổi mật khẩu).
/// Đảm bảo căn giữa maxWidth: 440dp, tương phản WCAG AA Light/Dark và ẩn bàn phím khi cuộn.
class AuthSecurityCardLayout extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String? title;
  final String subtitle;
  final Widget? subtitleExtra;
  final Widget cardChild;
  final Widget? footer;
  final double maxWidth;

  const AuthSecurityCardLayout({
    super.key,
    required this.icon,
    this.iconColor,
    this.title,
    required this.subtitle,
    this.subtitleExtra,
    required this.cardChild,
    this.footer,
    this.maxWidth = 440,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final resolvedIconColor = iconColor ?? colorScheme.primary;

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth < 360 ? 16.0 : 24.0;
          return Center(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 20.0,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: resolvedIconColor.withValues(
                            alpha: isDark ? 0.2 : 0.1,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, size: 42, color: resolvedIconColor),
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (title != null && title!.isNotEmpty) ...[
                      Text(
                        title!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (subtitleExtra != null) ...[
                      const SizedBox(height: 4),
                      subtitleExtra!,
                    ],
                    const SizedBox(height: 24),
                    AppCard(
                      padding: const EdgeInsets.all(24.0),
                      child: cardChild,
                    ),
                    if (footer != null) ...[
                      const SizedBox(height: 16),
                      footer!,
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Khối thông báo lỗi inline chuẩn WCAG AA Light/Dark cho biểu mẫu xác thực.
class AuthInlineErrorBanner extends StatelessWidget {
  final String message;

  const AuthInlineErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final semanticError = AppTheme.getSemanticError(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: semanticError.withValues(alpha: isDark ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: semanticError.withValues(alpha: isDark ? 0.45 : 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: semanticError),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: semanticError,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
