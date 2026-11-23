import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/permissions.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_card.dart';
import '../../../core/widgets/app_skeleton_shimmer.dart';
import '../../../core/widgets/role_guard.dart';
import '../../../data/models/payment_transaction_model.dart';
import '../../../data/providers/payment_provider.dart';

class ManagementPaymentTransactionsScreen extends ConsumerStatefulWidget {
  const ManagementPaymentTransactionsScreen({super.key});

  @override
  ConsumerState<ManagementPaymentTransactionsScreen> createState() =>
      _ManagementPaymentTransactionsScreenState();
}

class _ManagementPaymentTransactionsScreenState
    extends ConsumerState<ManagementPaymentTransactionsScreen> {
  String _selectedFilter = 'all'; // 'all', 'INVOICE', 'SERVICE'
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: 'đ',
  );

  void _showTransactionDetails(PaymentTransactionModel tx) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final successColor = AppTheme.getSemanticSuccess(ctx);
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: AppRadius.r16),
          title: Row(
            children: [
              Icon(Icons.verified, color: successColor),
              AppSpacing.w8,
              Expanded(
                child: Text(
                  'Chi tiết Giao dịch',
                  style: ctx.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow(ctx, 'Mã GD', tx.transactionCode),
                const Divider(),
                _buildDetailRow(
                  ctx,
                  'Nội dung',
                  tx.title ?? 'Thanh toán dịch vụ',
                ),
                const Divider(),
                _buildDetailRow(
                  ctx,
                  'Loại GD',
                  tx.isInvoice ? 'Hóa đơn định kỳ' : 'Dịch vụ tiện ích',
                ),
                const Divider(),
                _buildDetailRow(
                  ctx,
                  'Số tiền',
                  _currencyFormat.format(tx.amount),
                  isAmount: true,
                ),
                const Divider(),
                _buildDetailRow(ctx, 'Phương thức', tx.paymentMethod),
                const Divider(),
                _buildDetailRow(
                  ctx,
                  'Thời gian',
                  DateFormat('dd/MM/yyyy HH:mm:ss').format(tx.createdAt),
                ),
                const Divider(),
                _buildDetailRow(ctx, 'Trạng thái', tx.statusDisplayName),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Đóng'),
            ),
          ],
        );
      },
    );
  }

  Color _getStatusColor(BuildContext context, PaymentTransactionModel tx) {
    final colorScheme = Theme.of(context).colorScheme;
    if (tx.isSuccess) return AppTheme.getSemanticSuccess(context);
    if (tx.isFailed) return AppTheme.getSemanticError(context);
    if (tx.isCancelled) return colorScheme.onSurfaceVariant;
    return AppTheme.getSemanticWarning(context);
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value, {
    bool isAmount = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: context.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          AppSpacing.w12,
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: context.bodySmall
                  ?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isAmount
                        ? colorScheme.primary
                        : colorScheme.onSurface,
                  )
                  .tabularFigures(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(paymentTransactionsProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final secondaryColor = AppTheme.getSemanticSecondary(context);

    return RoleGuard(
      permission: AppPermissions.paymentTransactions,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Đối soát Giao dịch'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Làm mới',
              onPressed: () => ref.invalidate(paymentTransactionsProvider),
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(paymentTransactionsProvider),
              child: transactionsAsync.when(
                data: (transactions) {
                  final invoiceCount = transactions
                      .where((t) => t.isInvoice)
                      .length;
                  final serviceCount = transactions
                      .where((t) => t.isService)
                      .length;

                  final filtered = transactions.where((t) {
                    if (_selectedFilter == 'INVOICE') return t.isInvoice;
                    if (_selectedFilter == 'SERVICE') return t.isService;
                    return true;
                  }).toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Bộ lọc Chips (cuộn ngang chống tràn màn 320dp)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            FilterChip(
                              label: Text(
                                'Tất cả (${transactions.length})',
                                style: context.labelMedium?.tabularFigures(),
                              ),
                              selected: _selectedFilter == 'all',
                              onSelected: (_) =>
                                  setState(() => _selectedFilter = 'all'),
                            ),
                            AppSpacing.w8,
                            FilterChip(
                              label: Text(
                                'Hóa đơn ($invoiceCount)',
                                style: context.labelMedium?.tabularFigures(),
                              ),
                              selected: _selectedFilter == 'INVOICE',
                              onSelected: (_) =>
                                  setState(() => _selectedFilter = 'INVOICE'),
                            ),
                            AppSpacing.w8,
                            FilterChip(
                              label: Text(
                                'Dịch vụ ($serviceCount)',
                                style: context.labelMedium?.tabularFigures(),
                              ),
                              selected: _selectedFilter == 'SERVICE',
                              onSelected: (_) =>
                                  setState(() => _selectedFilter = 'SERVICE'),
                            ),
                          ],
                        ),
                      ),

                      // Danh sách giao dịch
                      Expanded(
                        child: filtered.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: const [
                                  SizedBox(height: 60),
                                  AppEmptyState(
                                    icon: Icons.receipt_long_outlined,
                                    title: 'Không có giao dịch',
                                    description:
                                        'Không có giao dịch nào phù hợp.',
                                  ),
                                ],
                              )
                            : ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: AppSpacing.p16,
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final tx = filtered[index];
                                  final statusColor = _getStatusColor(
                                    context,
                                    tx,
                                  );
                                  final typeColor = tx.isInvoice
                                      ? colorScheme.primary
                                      : secondaryColor;

                                  return AppCard(
                                    padding: AppSpacing.p12,
                                    margin: const EdgeInsets.only(bottom: 10),
                                    child: InkWell(
                                      borderRadius: AppRadius.r12,
                                      onTap: () => _showTransactionDetails(tx),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: AppSpacing.p12,
                                            decoration: BoxDecoration(
                                              color: typeColor.withValues(
                                                alpha: 0.12,
                                              ),
                                              borderRadius: AppRadius.r12,
                                            ),
                                            child: Icon(
                                              tx.isInvoice
                                                  ? Icons.home_outlined
                                                  : Icons
                                                        .sports_tennis_outlined,
                                              color: typeColor,
                                              size: 24,
                                            ),
                                          ),
                                          AppSpacing.w12,
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  tx.title ??
                                                      'Giao dịch thanh toán',
                                                  style: context.titleSmall
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                ),
                                                AppSpacing.h4,
                                                Text(
                                                  '${tx.transactionCode} • ${DateFormat('dd/MM/yyyy HH:mm').format(tx.createdAt)}',
                                                  style: context.bodySmall
                                                      ?.copyWith(
                                                        color: colorScheme
                                                            .onSurfaceVariant,
                                                      )
                                                      .tabularFigures(),
                                                ),
                                              ],
                                            ),
                                          ),
                                          AppSpacing.w8,
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                _currencyFormat.format(
                                                  tx.amount,
                                                ),
                                                style: context.titleSmall
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color:
                                                          colorScheme.primary,
                                                    )
                                                    .tabularFigures(),
                                              ),
                                              AppSpacing.h4,
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: statusColor.withValues(
                                                    alpha: 0.12,
                                                  ),
                                                  borderRadius: AppRadius.r4,
                                                ),
                                                child: Text(
                                                  tx.statusDisplayName,
                                                  style: context.labelSmall
                                                      ?.copyWith(
                                                        color: statusColor,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
                loading: () => ListView(
                  padding: AppSpacing.p16,
                  children: [
                    AppSkeletonShimmer.cardList(count: 4, itemHeight: 88),
                  ],
                ),
                error: (e, _) => Center(
                  child: Padding(
                    padding: AppSpacing.p16,
                    child: AppErrorCard(
                      error: e,
                      onRetry: () =>
                          ref.invalidate(paymentTransactionsProvider),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
