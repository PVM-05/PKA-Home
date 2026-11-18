import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/bounceable.dart';

/// Banner nhắc nhở cư dân ghi chỉ số điện nước cuối chu kỳ (từ ngày 20 đến cuối tháng)
/// Thiết kế Bento Box theo chuẩn Design System 2026, hỗ trợ Semantics và haptic feedback.
class MeterReadingReminderBanner extends StatelessWidget {
  final VoidCallback? onDismiss;

  const MeterReadingReminderBanner({
    super.key,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Semantics(
      container: true,
      label: 'Thông báo: Đã mở cổng ghi chỉ số điện nước cuối kỳ. Chọn để khai báo ngay.',
      child: Bounceable(
        onTap: () => context.push(AppRoutes.residentMeterReading),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: AppRadius.rLg,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      colorScheme.primaryContainer.withValues(alpha: 0.35),
                      colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                    ]
                  : [
                      colorScheme.primary.withValues(alpha: 0.08),
                      colorScheme.primaryContainer.withValues(alpha: 0.15),
                    ],
            ),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: isDark ? 0.3 : 0.2),
              width: 1.0,
            ),
          ),
          padding: AppSpacing.p16,
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: isDark ? 0.2 : 0.12),
                  borderRadius: AppRadius.rMd,
                ),
                child: Icon(
                  Icons.speed_outlined,
                  color: colorScheme.primary,
                  size: 24,
                ),
              ),
              AppSpacing.w12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Kỳ ghi chỉ số điện nước',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.warning.withValues(alpha: 0.15),
                            borderRadius: AppRadius.rXs,
                          ),
                          child: Text(
                            'Đang mở',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppTheme.warning,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.h4,
                    Text(
                      'Cổng ghi nhận mở từ 20 đến cuối tháng. Cập nhật để hóa đơn chính xác.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              AppSpacing.w8,
              Icon(
                Icons.chevron_right,
                color: colorScheme.primary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
