import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/utility_fee_calculator.dart';
import '../../../../core/utils/vietnamese_currency_words.dart';
import '../../../../data/models/invoice_model.dart';
import '../../../../data/models/tiered_calculation_result_model.dart';
import '../../../../data/providers/fee_policy_providers.dart';
import '../resident_ledger_history_sheet.dart';

class ResidentInvoiceSummaryCard extends ConsumerWidget {
  final InvoiceModel invoice;
  final NumberFormat formatCurrency;
  final DateFormat formatDate;

  const ResidentInvoiceSummaryCard({
    super.key,
    required this.invoice,
    required this.formatCurrency,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final semanticError = AppTheme.getSemanticError(context);
    final semanticWarning = AppTheme.getSemanticWarning(context);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(
      invoice.dueDate.year,
      invoice.dueDate.month,
      invoice.dueDate.day,
    );
    final diffDays = today.difference(dueDay).inDays;
    final isOverdue = invoice.status == 'unpaid' && diffDays > 0;
    final isDueToday = invoice.status == 'unpaid' && diffDays == 0;

    late final Color statusColor;
    late final String statusText;
    late final IconData statusIcon;

    switch (invoice.status) {
      case 'paid':
        statusColor = AppStatusColors.getPaid(context);
        statusText = 'Đã thanh toán';
        statusIcon = Icons.check_circle;
        break;
      case 'pending_confirmation':
        statusColor = AppStatusColors.getPendingConfirmation(context);
        statusText = 'Chờ xác nhận';
        statusIcon = Icons.hourglass_top;
        break;
      default:
        if (isOverdue) {
          statusColor = semanticError;
          statusText = 'Quá hạn $diffDays ngày';
          statusIcon = Icons.warning_amber_rounded;
        } else if (isDueToday) {
          statusColor = semanticWarning;
          statusText = 'Đến hạn hôm nay';
          statusIcon = Icons.access_time_filled;
        } else {
          statusColor = AppStatusColors.getUnpaid(context);
          statusText = 'Chưa thanh toán';
          statusIcon = Icons.error_outline;
        }
    }

    final latePenaltyAsync = isOverdue
        ? ref.watch(calculatedLatePenaltyProvider(invoice.id))
        : null;
    final latePenalty = isOverdue
        ? (latePenaltyAsync?.valueOrNull ??
              UtilityFeeCalculator.calculateLatePaymentPenalty(
                invoiceId: invoice.id,
                totalAmount: invoice.totalAmount,
                dueDate: invoice.dueDate,
                asOfDate: DateTime.now(),
              ))
        : null;

    final cardBg = theme.cardTheme.color ?? colorScheme.surface;
    final borderColor = isOverdue
        ? semanticError.withValues(alpha: isDark ? 0.7 : 0.5)
        : colorScheme.outlineVariant.withValues(alpha: isDark ? 0.6 : 0.8);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark
            ? null
            : isOverdue
                ? [
                    BoxShadow(
                      color: semanticError.withValues(alpha: 0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : AppShadows.softSm,
      ),
      child: Card(
        elevation: 0,
        color: cardBg,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: borderColor,
            width: isOverdue ? 1.5 : 1.0,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                statusColor.withValues(alpha: isDark ? 0.2 : 0.1),
                cardBg,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: isDark ? 0.22 : 0.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: statusColor.withValues(alpha: isDark ? 0.35 : 0.22),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, color: statusColor, size: 20),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        statusText,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: context.labelLarge?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'TỔNG CỘNG',
                style: context.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Semantics(
                  label:
                      'Tổng tiền ${VietnameseCurrencyWords.toVietnameseWords(invoice.totalAmount.toDouble())}',
                  child: Text(
                    formatCurrency.format(invoice.totalAmount),
                    style: context.displayMedium?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w900,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
              if (latePenalty != null && latePenalty.daysOverdue > 0) ...[
                const SizedBox(height: 16),
                _LatePenaltyWarningBox(
                  penalty: latePenalty,
                  formatCurrency: formatCurrency,
                ),
              ],
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              _InfoRow(
                icon: Icons.calendar_today,
                label: 'Hạn thanh toán',
                value: formatDate.format(invoice.dueDate),
              ),
              const SizedBox(height: 12),
              _InfoRow(
                icon: Icons.apartment,
                label: 'Căn hộ',
                value: invoice.apartment?.code ?? 'N/A',
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.history_edu_outlined, size: 18),
                  label: const Text('Lịch sử đối soát công nợ'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      builder: (_) => FractionallySizedBox(
                        heightFactor: 0.7,
                        child: ResidentLedgerHistorySheet(
                          apartmentId: invoice.apartmentId,
                          apartmentCode: invoice.apartment?.code ?? 'N/A',
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          flex: 5,
          child: Text(
            label,
            style: context.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 6,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: context.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _LatePenaltyWarningBox extends StatelessWidget {
  final LatePenaltyResultModel penalty;
  final NumberFormat formatCurrency;

  const _LatePenaltyWarningBox({
    required this.penalty,
    required this.formatCurrency,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final semanticError = AppTheme.getSemanticError(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: semanticError.withValues(alpha: isDark ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: semanticError.withValues(alpha: isDark ? 0.45 : 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: semanticError,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Cảnh báo trễ hạn',
                      style: context.titleSmall?.copyWith(
                        color: semanticError,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.textError,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Quá hạn ${penalty.daysOverdue} ngày',
                        style: context.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Hóa đơn đã quá hạn thanh toán. Tiền lãi phạt trễ hạn ước tính: ${penalty.formattedPenaltyAmount} (0.05%/ngày).',
                  style: context.bodySmall?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
                if (penalty.penaltyAmount > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Tổng cộng kèm tiền phạt: ${formatCurrency.format(penalty.totalWithPenalty)}',
                    style: context.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: semanticError,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
