import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:vivona/core/theme/app_radius.dart';
import 'package:vivona/core/theme/app_spacing.dart';
import 'package:vivona/core/theme/app_theme.dart';
import 'package:vivona/core/widgets/app_card.dart';
import 'package:vivona/core/widgets/app_error_card.dart';
import 'package:vivona/core/widgets/app_skeleton_shimmer.dart';
import 'package:vivona/data/models/invoice_model.dart';

class ResidentHomeUpcomingInvoiceCard extends StatelessWidget {
  final AsyncValue<List<InvoiceModel>> invoiceAsync;
  final VoidCallback onNavigateToInvoices;
  final VoidCallback onRetry;

  const ResidentHomeUpcomingInvoiceCard({
    super.key,
    required this.invoiceAsync,
    required this.onNavigateToInvoices,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tổng quan hóa đơn',
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        AppSpacing.h8,
        invoiceAsync.when(
          data: (invoices) {
            final unpaidInvoices = invoices
                .where(
                  (i) =>
                      i.status == 'unpaid' ||
                      i.status == 'pending_confirmation',
                )
                .toList();
            final totalUnpaid = unpaidInvoices.fold<double>(
              0,
              (sum, item) => sum + item.totalAmount,
            );
            final unpaidCount = unpaidInvoices.length;

            if (totalUnpaid > 0) {
              return Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primary, AppTheme.sapphire],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: AppRadius.r20,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: AppSpacing.p20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: AppRadius.r20,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                              AppSpacing.w4,
                              Text(
                                'Đến hạn thanh toán',
                                style: textTheme.labelSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Flexible(
                          child: Text(
                            '( $unpaidCount hóa đơn chưa thanh toán )',
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Tổng tiền cần đóng',
                      style: textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    AppSpacing.h4,
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        NumberFormat.currency(
                          locale: 'vi_VN',
                          symbol: 'VNĐ',
                        ).format(totalUnpaid),
                        style: textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    AppSpacing.h16,
                    ElevatedButton.icon(
                      onPressed: onNavigateToInvoices,
                      icon: const Icon(
                        Icons.qr_code_scanner,
                        size: 18,
                      ),
                      label: Text(
                        'THANH TOÁN NGAY',
                        style: textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.sapphire,
                        elevation: 0,
                        padding: AppSpacing.py12,
                        shape: AppRadius.shape12,
                      ),
                    ),
                  ],
                ),
              )
                  .animate()
                  .fade(duration: 400.ms, delay: 100.ms)
                  .slideX(begin: 0.1, curve: Curves.easeOut);
            }

            return AppCard(
              padding: AppSpacing.p20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withValues(alpha: 0.12),
                          borderRadius: AppRadius.r20,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check_circle_outline,
                              color: AppTheme.success,
                              size: 14,
                            ),
                            AppSpacing.w4,
                            Text(
                              'Đã hoàn tất',
                              style: textTheme.labelSmall?.copyWith(
                                color: AppTheme.success,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Flexible(
                        child: Text(
                          '( Đã thanh toán đầy đủ các kỳ phí )',
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: AppTheme.success,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.h12,
                  Text(
                    'Đã thanh toán đầy đủ các kỳ phí',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  AppSpacing.h4,
                  Text(
                    'Căn hộ của bạn không có hóa đơn quá hạn hoặc đang chờ đối soát.',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: onNavigateToInvoices,
                    icon: const Icon(Icons.receipt_long, size: 18),
                    label: Text(
                      'XEM HÓA ĐƠN',
                      style: textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: AppSpacing.py12,
                      shape: AppRadius.shape12,
                    ),
                  ),
                ],
              ),
            )
                .animate()
                .fade(duration: 400.ms, delay: 100.ms)
                .slideX(begin: 0.1, curve: Curves.easeOut);
          },
          loading: () => AppSkeletonShimmer.rectangular(
            width: double.infinity,
            height: 160,
            borderRadius: AppRadius.r20,
          ),
          error: (err, st) => AppErrorCard(
            error: err,
            onRetry: onRetry,
          ),
        ),
      ],
    );
  }
}
