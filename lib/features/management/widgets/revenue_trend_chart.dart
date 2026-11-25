import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../data/providers/dashboard_providers.dart';
import '../../../core/utils/error_formatter.dart';

/// Biểu đồ xu hướng thu phí và công nợ 6 kỳ hóa đơn gần nhất dành cho Ban Quản lý.
class RevenueTrendChart extends ConsumerWidget {
  const RevenueTrendChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendAsync = ref.watch(monthlyRevenueTrendProvider);
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

    return AppCard(
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tiêu đề & chú thích chống tràn layout trên màn hình hẹp
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bar_chart_rounded, color: AppTheme.primary, size: 22),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Xu hướng thu phí 6 kỳ',
                        style: context.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                // Chú thích
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildLegendItem(context, color: AppStatusColors.paid, label: 'Đã thu'),
                    const SizedBox(width: 12),
                    _buildLegendItem(context, color: AppStatusColors.unpaid, label: 'Còn nợ'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'So sánh thực thu và nợ phí theo từng kỳ hóa đơn',
              style: context.bodySmall?.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),

            trendAsync.when(
              data: (items) {
                if (items.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24.0),
                    child: Center(
                      child: Text(
                        'Chưa có dữ liệu hóa đơn nào.',
                        style: context.bodyMedium?.copyWith(color: AppTheme.textSecondary),
                      ),
                    ),
                  );
                }

                final maxAmount = items
                    .map((item) => max(item.paidAmount, item.unpaidAmount))
                    .fold<double>(0.0, max);

                final totalPaidAll = items.fold<double>(0.0, (sum, i) => sum + i.paidAmount);
                final totalUnpaidAll = items.fold<double>(0.0, (sum, i) => sum + i.unpaidAmount);
                final totalAll = totalPaidAll + totalUnpaidAll;
                final avgRate = totalAll > 0 ? (totalPaidAll / totalAll * 100) : 0.0;

                return Column(
                  children: [
                    // Khung cột đồ thị
                    SizedBox(
                      height: 150,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: items.map((item) {
                          final double paidHeight = maxAmount > 0
                              ? ((item.paidAmount / maxAmount) * 110).clamp(item.paidAmount > 0 ? 6.0 : 0.0, 110.0)
                              : 0.0;
                          final double unpaidHeight = maxAmount > 0
                              ? ((item.unpaidAmount / maxAmount) * 110).clamp(item.unpaidAmount > 0 ? 6.0 : 0.0, 110.0)
                              : 0.0;

                          return Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => _showMonthDetail(context, item, currencyFormat),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Expanded(
                                      child: Align(
                                        alignment: Alignment.bottomCenter,
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            // Cột đã thu
                                            Container(
                                              width: 10,
                                              height: paidHeight,
                                              decoration: BoxDecoration(
                                                color: AppStatusColors.paid,
                                                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            // Cột còn nợ
                                            Container(
                                              width: 10,
                                              height: unpaidHeight,
                                              decoration: BoxDecoration(
                                                color: AppStatusColors.unpaid,
                                                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      item.shortLabel,
                                      style: context.labelSmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                    ),
                                    Text(
                                      item.period.length >= 7 ? item.period.substring(3) : '',
                                      style: context.labelSmall?.copyWith(
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const Divider(height: 24),

                    // Tóm tắt 6 kỳ
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Tổng thực thu', style: context.labelSmall?.copyWith(color: AppTheme.textSecondary)),
                              const SizedBox(height: 2),
                              Text(
                                currencyFormat.format(totalPaidAll),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.bodyMedium?.copyWith(
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
                              Text('Tổng nợ tồn', style: context.labelSmall?.copyWith(color: AppTheme.textSecondary)),
                              const SizedBox(height: 2),
                              Text(
                                currencyFormat.format(totalUnpaidAll),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.bodyMedium?.copyWith(
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
                              Text('Tỷ lệ thu hồi', style: context.labelSmall?.copyWith(color: AppTheme.textSecondary)),
                              const SizedBox(height: 2),
                              Text(
                                '${avgRate.toStringAsFixed(1)}%',
                                style: context.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
              loading: () => const SizedBox(
                height: 140,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off_rounded, color: AppTheme.textSecondary, size: 28),
                      const SizedBox(height: 8),
                      Text(
                        formatErrorMessage(err),
                        textAlign: TextAlign.center,
                        style: context.bodyMedium?.copyWith(color: AppTheme.error),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: AppTheme.primary,
                        ),
                        onPressed: () {
                          ref.invalidate(rawInvoicesStream);
                          ref.invalidate(monthlyRevenueTrendProvider);
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: Text('Thử lại', style: context.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
    );
  }

  static Widget _buildLegendItem(BuildContext context, {required Color color, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: context.labelSmall?.copyWith(color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  void _showMonthDetail(BuildContext context, MonthlyRevenueItem item, NumberFormat currencyFormat) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_month, color: AppTheme.primary, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Chi tiết kỳ hóa đơn ${item.period}',
                      style: ctx.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildDetailRow(ctx, 'Đã thu:', currencyFormat.format(item.paidAmount), AppStatusColors.getPaid(ctx)),
              const Divider(height: 16),
              _buildDetailRow(ctx, 'Còn nợ:', currencyFormat.format(item.unpaidAmount), AppStatusColors.getUnpaid(ctx)),
              const Divider(height: 16),
              _buildDetailRow(ctx, 'Tổng phát sinh:', currencyFormat.format(item.totalAmount), Theme.of(ctx).colorScheme.onSurface),
              const Divider(height: 16),
              _buildDetailRow(ctx, 'Tỷ lệ hoàn thành:', '${(item.collectionRate * 100).toStringAsFixed(1)}%', Theme.of(ctx).colorScheme.primary),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Đóng', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value, Color valueColor) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(label, style: context.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: context.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: valueColor),
          ),
        ),
      ],
    );
  }
}
