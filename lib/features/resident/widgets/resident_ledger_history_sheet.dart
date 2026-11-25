import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../data/providers/accounting_providers.dart';

class ResidentLedgerHistorySheet extends ConsumerWidget {
  final String apartmentId;
  final String apartmentCode;

  const ResidentLedgerHistorySheet({
    super.key,
    required this.apartmentId,
    required this.apartmentCode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(apartmentBalanceProvider(apartmentId));
    final entriesAsync = ref.watch(apartmentLedgerEntriesProvider(apartmentId));
    final colorScheme = Theme.of(context).colorScheme;
    final successColor = AppTheme.getSemanticSuccess(context);
    final errorColor = AppTheme.getSemanticError(context);

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Lịch Sử Đối Soát Công Nợ - $apartmentCode',
                  style: context.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Hiển thị số dư công nợ tức thời
          balanceAsync.when(
            data: (balance) {
              final formattedMoney =
                  NumberFormat.currency(locale: 'vi_VN', symbol: 'đ').format(balance.abs());
              final isDebt = balance > 0;
              final isZero = balance == 0;
              final color = isDebt ? errorColor : (isZero ? successColor : colorScheme.primary);
              final text = isDebt
                  ? 'Còn nợ: $formattedMoney'
                  : (isZero ? 'Đã thanh toán đủ (0 đ)' : 'Đã nộp trước: $formattedMoney');

              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    Icon(
                      isDebt
                          ? Icons.warning_amber_rounded
                          : (isZero ? Icons.check_circle_outline : Icons.savings_outlined),
                      size: 18,
                      color: color,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Số dư công nợ căn hộ: $text',
                        style: context.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (e, s) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 12),

          // Danh sách bút toán
          Expanded(
            child: entriesAsync.when(
              data: (entries) {
                if (entries.isEmpty) {
                  return Center(
                    child: Text(
                      'Chưa có giao dịch sổ cái nào được ghi nhận.',
                      style: context.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: entries.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = entries[index];
                    final isDebit = item.isDebit;
                    final prefix = isDebit ? '+' : '-';
                    final color = isDebit ? errorColor : successColor;

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              item.entryCode,
                              style: context.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$prefix${item.formattedAmount}',
                            style: context.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(item.description, style: context.bodyMedium),
                          const SizedBox(height: 2),
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            spacing: 8,
                            runSpacing: 2,
                            children: [
                              Text(
                                item.formattedCreatedAtWithTime,
                                style: context.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
                              ),
                              Text(
                                'Dư sau GD: ${item.formattedBalanceAfter}',
                                style: context.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text(formatErrorMessage(err))),
            ),
          ),
        ],
      ),
    );
  }
}
