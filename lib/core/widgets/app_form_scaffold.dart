import 'package:flutter/material.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import 'app_unsaved_changes_guard.dart';
import 'bounceable.dart';

/// Khung biểu mẫu chuẩn hóa thương mại (Production Commercial Form Scaffold):
/// - Sticky CTA Footer: Cố định chân màn hình, tách biệt viền outlineVariant, không bị trôi khuất khi cuộn nội dung dài.
/// - Tự động bảo vệ dữ liệu chưa lưu qua `AppUnsavedChangesGuard` (PopScope).
/// - Hỗ trợ thao tác kéo cuộn để ẩn bàn phím (`keyboardDismissBehavior: onDrag`).
/// - Nút hành động chính (Primary CTA) với hiệu ứng `Bounceable` và chuẩn xúc giác >= 48dp.
class AppFormScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final bool hasUnsavedChanges;
  final String primaryButtonLabel;
  final VoidCallback? onPrimaryPressed;
  final bool isPrimaryLoading;
  final String? secondaryButtonLabel;
  final VoidCallback? onSecondaryPressed;
  final List<Widget>? actions;
  final Widget? bottomSheet;
  final Widget? floatingActionButton;
  final bool isScrollable;
  final EdgeInsetsGeometry padding;

  const AppFormScaffold({
    super.key,
    required this.title,
    required this.body,
    this.hasUnsavedChanges = false,
    required this.primaryButtonLabel,
    required this.onPrimaryPressed,
    this.isPrimaryLoading = false,
    this.secondaryButtonLabel,
    this.onSecondaryPressed,
    this.actions,
    this.bottomSheet,
    this.floatingActionButton,
    this.isScrollable = true,
    this.padding = const EdgeInsets.all(16.0),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Widget content = isScrollable
        ? SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: padding,
            child: body,
          )
        : Padding(padding: padding, child: body);

    final scaffold = Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: actions,
      ),
      bottomSheet: bottomSheet,
      floatingActionButton: floatingActionButton,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(child: content),
            _buildStickyFooter(context, colorScheme),
          ],
        ),
      ),
    );

    return AppUnsavedChangesGuard(
      hasUnsavedChanges: hasUnsavedChanges,
      child: scaffold,
    );
  }

  Widget _buildStickyFooter(BuildContext context, ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant,
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -2),
            blurRadius: 6,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (secondaryButtonLabel != null && onSecondaryPressed != null) ...[
              Expanded(
                flex: 1,
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      shape: AppRadius.shape12,
                      side: BorderSide(color: colorScheme.outlineVariant),
                    ),
                    onPressed: isPrimaryLoading ? null : onSecondaryPressed,
                    child: Text(
                      secondaryButtonLabel!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
              AppSpacing.w12,
            ],
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 48,
                child: Bounceable(
                  onTap: (isPrimaryLoading || onPrimaryPressed == null)
                      ? () {}
                      : onPrimaryPressed!,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      shape: AppRadius.shape12,
                      elevation: 0,
                    ),
                    onPressed: isPrimaryLoading ? null : onPrimaryPressed,
                    child: isPrimaryLoading
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                colorScheme.onPrimary,
                              ),
                            ),
                          )
                        : Text(
                            primaryButtonLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

