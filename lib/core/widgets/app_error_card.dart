import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/error_formatter.dart';

/// Card thông báo lỗi đồng nhất, hiển thị thông điệp tiếng Việt thân thiện kèm nút Thử lại.
class AppErrorCard extends StatelessWidget {
  final Object? error;
  final String? customMessage;
  final VoidCallback? onRetry;
  final EdgeInsetsGeometry margin;

  const AppErrorCard({
    super.key,
    this.error,
    this.customMessage,
    this.onRetry,
    this.margin = const EdgeInsets.symmetric(vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    final message = customMessage ?? formatErrorMessage(error);

    return Card(
      margin: margin,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.error.withValues(alpha: 0.3)),
      ),
      color: AppTheme.error.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, color: AppTheme.error, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.error,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onRetry,
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.error,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Thử lại', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
