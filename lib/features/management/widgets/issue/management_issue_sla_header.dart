import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../data/providers/material_provider.dart';

class ManagementIssueSlaHeader extends ConsumerWidget {
  final bool isDesktop;

  const ManagementIssueSlaHeader({
    super.key,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slaStatsAsync = ref.watch(issueSlaStatsProvider);
    final successColor = AppTheme.getSemanticSuccess(context);
    final warningColor = AppTheme.getSemanticWarning(context);
    final errorColor = AppTheme.getSemanticError(context);

    return slaStatsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (stats) {
        final cards = [
          _SlaKpiBox(
            title: 'Đúng hạn',
            count: '${stats.onTimeCount} sự cố',
            color: successColor,
            icon: Icons.check_circle_outline,
          ),
          _SlaKpiBox(
            title: 'Sắp trễ (<2h)',
            count: '${stats.warningCount} sự cố',
            color: warningColor,
            icon: Icons.warning_amber_rounded,
          ),
          _SlaKpiBox(
            title: 'Trễ SLA',
            count: '${stats.breachedCount} sự cố',
            color: errorColor,
            icon: Icons.timer_off_outlined,
          ),
          if (isDesktop)
            _SlaKpiBox(
              title: 'Tỷ lệ tuân thủ',
              count: '${stats.complianceRate.toStringAsFixed(1)}%',
              color: stats.complianceRate >= 80 ? successColor : warningColor,
              icon: Icons.trending_up,
            ),
        ];

        if (isDesktop) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Row(
              children: cards
                  .map(
                    (c) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: c,
                      ),
                    ),
                  )
                  .toList(),
            ),
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: cards
                .map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: SizedBox(width: 128, child: c),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }
}

class _SlaKpiBox extends StatelessWidget {
  final String title;
  final String count;
  final Color color;
  final IconData icon;

  const _SlaKpiBox({
    required this.title,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.16 : 0.08),
        borderRadius: AppRadius.r12,
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.42 : 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              AppSpacing.w4,
              Expanded(
                child: Text(
                  title,
                  style: context.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          AppSpacing.h4,
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              count,
              style: context.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
