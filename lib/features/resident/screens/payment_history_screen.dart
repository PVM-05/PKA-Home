import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_card.dart';
import '../../../core/widgets/app_skeleton_shimmer.dart';
import '../../../data/models/payment_transaction_model.dart';
import '../../../data/providers/payment_provider.dart';

enum _PaymentFilter { all, invoice, service }

class PaymentHistoryScreen extends ConsumerStatefulWidget {
  const PaymentHistoryScreen({super.key});

  @override
  ConsumerState<PaymentHistoryScreen> createState() =>
      _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends ConsumerState<PaymentHistoryScreen> {
  _PaymentFilter _currentFilter = _PaymentFilter.all;

  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm');
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: 'đ',
  );

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final transactionsAsync = ref.watch(paymentTransactionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Lịch sử thanh toán')),
      body: transactionsAsync.when(
        data: (transactions) {
          final invoiceCount = transactions.where((t) => t.isInvoice).length;
          final serviceCount = transactions.where((t) => t.isService).length;

          final filteredList = transactions.where((t) {
            switch (_currentFilter) {
              case _PaymentFilter.all:
                return true;
              case _PaymentFilter.invoice:
                return t.isInvoice;
              case _PaymentFilter.service:
                return t.isService;
            }
          }).toList();

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 840),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    color: colorScheme.surface,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip(
                            context: context,
                            label: 'Tất cả (${transactions.length})',
                            isSelected: _currentFilter == _PaymentFilter.all,
                            onTap: () => setState(
                              () => _currentFilter = _PaymentFilter.all,
                            ),
                          ),
                          AppSpacing.w8,
                          _buildFilterChip(
                            context: context,
                            label: 'Hóa đơn ($invoiceCount)',
                            icon: Icons.home_outlined,
                            isSelected:
                                _currentFilter == _PaymentFilter.invoice,
                            onTap: () => setState(
                              () => _currentFilter = _PaymentFilter.invoice,
                            ),
                          ),
                          AppSpacing.w8,
                          _buildFilterChip(
                            context: context,
                            label: 'Dịch vụ ($serviceCount)',
                            icon: Icons.sports_tennis_outlined,
                            isSelected:
                                _currentFilter == _PaymentFilter.service,
                            onTap: () => setState(
                              () => _currentFilter = _PaymentFilter.service,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(paymentTransactionsProvider);
                      },
                      child: filteredList.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 64,
                              ),
                              children: const [
                                AppEmptyState(
                                  icon: Icons.receipt_long_outlined,
                                  title: 'Chưa có giao dịch thanh toán nào',
                                  description:
                                      'Các hóa đơn và lịch đặt dịch vụ đã thanh toán sẽ hiển thị ở đây.',
                                ),
                              ],
                            )
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: AppSpacing.p16,
                              itemCount: filteredList.length,
                              itemBuilder: (context, index) =>
                                  _buildTransactionCard(
                                    context,
                                    filteredList[index],
                                  ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => ListView(
          padding: AppSpacing.p16,
          children: [AppSkeletonShimmer.cardList(count: 4, itemHeight: 100)],
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: AppSpacing.p24,
            child: AppErrorCard(
              error: e,
              onRetry: () => ref.invalidate(paymentTransactionsProvider),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required BuildContext context,
    required String label,
    IconData? icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return ChoiceChip(
      materialTapTargetSize: MaterialTapTargetSize.padded,
      selected: isSelected,
      showCheckmark: false,
      selectedColor: AppTheme.primary,
      backgroundColor: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? AppTheme.primary : colorScheme.outlineVariant,
        ),
      ),
      avatar: icon != null
          ? Icon(
              icon,
              size: 16,
              color: isSelected
                  ? colorScheme.onPrimary
                  : colorScheme.onSurfaceVariant,
            )
          : null,
      label: Text(
        label,
        style: context.bodySmall?.copyWith(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      onSelected: (_) => onTap(),
    );
  }

  Widget _buildTransactionCard(
    BuildContext context,
    PaymentTransactionModel tx,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isInvoice = tx.isInvoice;
    final iconColor = isInvoice
        ? colorScheme.primary
        : AppTheme.getSemanticWarning(context);
    final statusColor = tx.isSuccess
        ? AppTheme.getSemanticSuccess(context)
        : AppTheme.getSemanticError(context);

    final iconData = isInvoice
        ? Icons.receipt_long_rounded
        : (tx.title?.toLowerCase().contains('bơi') ?? false
              ? Icons.pool_rounded
              : (tx.title?.toLowerCase().contains('gym') ?? false
                    ? Icons.fitness_center_rounded
                    : Icons.sports_tennis_rounded));

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: AppSpacing.p16,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: AppSpacing.p12,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: isDark ? 0.18 : 0.10),
              borderRadius: AppRadius.r12,
            ),
            child: Icon(iconData, color: iconColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.title ??
                      (isInvoice ? 'Hóa đơn định kỳ' : 'Dịch vụ tiện ích'),
                  style: context.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                AppSpacing.h4,
                Text(
                  _dateFormat.format(tx.createdAt),
                  style: context.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                AppSpacing.h6,
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    borderRadius: AppRadius.r8,
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: Text(
                    tx.transactionCode,
                    style: context.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: colorScheme.onSurface,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.w10,
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _currencyFormat.format(tx.amount),
                style: context.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              AppSpacing.h6,
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    tx.isSuccess ? Icons.check_circle : Icons.error,
                    size: 15,
                    color: statusColor,
                  ),
                  AppSpacing.w4,
                  Text(
                    tx.statusDisplayName,
                    style: context.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
