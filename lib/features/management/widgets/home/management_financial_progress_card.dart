import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_skeleton_shimmer.dart';
import '../../../../data/providers/dashboard_providers.dart';

/// Card thể hiện tiến độ thu phí tòa nhà (biểu đồ tròn + chỉ số chi tiết)
class ManagementFinancialProgressCard extends ConsumerWidget {
  const ManagementFinancialProgressCard({super.key});

  Widget _buildLegendItem({
    required BuildContext context,
    required Color color,
    required String label,
  }) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        AppSpacing.w8,
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(financialStatsProvider);
    final formatCurrency = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

    return statsAsync.when(
      data: (stats) {
        final percent = (stats.collectionRate * 100).toInt();
        final textScale = MediaQuery.textScalerOf(context).scale(1.0);
        final chartHeight = (120.0 * textScale).clamp(120.0, 160.0);

        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(
                          Icons.pie_chart_outline,
                          color: AppTheme.primary,
                          size: 20,
                        ),
                        AppSpacing.w8,
                        Expanded(
                          child: Text(
                            'Tiến độ thu phí tòa nhà',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.w8,
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppStatusColors.paid.withValues(alpha: 0.1),
                      borderRadius: AppRadius.r12,
                    ),
                    child: Text(
                      '$percent% Đã thu',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppStatusColors.paid,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ],
              ),
              AppSpacing.h16,
              SizedBox(
                height: chartHeight,
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 30,
                          sections: [
                            PieChartSectionData(
                              color: AppStatusColors.paid,
                              value: stats.paidTotal,
                              title: '',
                              radius: 25,
                            ),
                            PieChartSectionData(
                              color: AppStatusColors.unpaid,
                              value: stats.unpaidTotal,
                              title: '',
                              radius: 25,
                            ),
                          ],
                        ),
                      ),
                    ),
                    AppSpacing.w16,
                    Expanded(
                      flex: 2,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLegendItem(
                            context: context,
                            color: AppStatusColors.paid,
                            label:
                                'Đã thu: ${formatCurrency.format(stats.paidTotal)}',
                          ),
                          AppSpacing.h8,
                          _buildLegendItem(
                            context: context,
                            color: AppStatusColors.unpaid,
                            label:
                                'Còn nợ: ${formatCurrency.format(stats.unpaidTotal)}',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              AppSpacing.h16,
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Đã thu',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                        ),
                        AppSpacing.h4,
                        Text(
                          formatCurrency.format(stats.paidTotal),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppStatusColors.paid,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Còn nợ',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                        ),
                        AppSpacing.h4,
                        Text(
                          formatCurrency.format(stats.unpaidTotal),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppStatusColors.unpaid,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Căn đã đóng',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                        ),
                        AppSpacing.h4,
                        Text(
                          '${stats.paidCount}/${stats.paidCount + stats.unpaidCount}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color:
                                    Theme.of(context).colorScheme.onSurface,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => AppSkeletonShimmer.rectangular(
        width: double.infinity,
        height: 140,
        borderRadius: AppRadius.r16,
      ),
      error: (e, _) => const SizedBox.shrink(),
    );
  }
}

