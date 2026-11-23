import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/action_runner.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_card.dart';
import '../../../../core/widgets/app_skeleton_shimmer.dart';
import '../../../../data/models/payment_transaction_model.dart';
import '../../../../data/providers/accounting_workstation_provider.dart';
import '../../../../data/providers/management_provider.dart';
import '../../../../data/providers/payment_provider.dart';

/// Thẻ KPI dùng chung cho Bàn làm việc Kế toán & Đối soát SePay.
class AccountingKpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color bgColor;

  const AccountingKpiCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: AppSpacing.p16,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: AppRadius.r12,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            padding: AppSpacing.p12,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: AppRadius.r12,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          AppSpacing.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: context.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                AppSpacing.h4,
                Text(
                  value,
                  style: context.titleLarge
                      ?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      )
                      .tabularFigures(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: context.labelSmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant)
                      .tabularFigures(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Hiển thị hộp thoại khớp nợ thủ công giao dịch SePay/VietQR với hóa đơn.
Future<void> showManualMatchTransactionDialog(
  BuildContext context,
  WidgetRef ref,
  PaymentTransactionModel tx,
) async {
  final currencyFormat = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: 'đ',
    decimalDigits: 0,
  );
  final allInvoices = ref.read(invoicesProvider).value ?? [];
  final unpaidInvoices =
      allInvoices
          .where((inv) => inv.status != 'paid' && inv.status != 'cancelled')
          .toList()
        ..sort((a, b) {
          final diffA = (a.totalAmount - tx.amount).abs();
          final diffB = (b.totalAmount - tx.amount).abs();
          return diffA.compareTo(diffB);
        });

  String? selectedInvoiceId =
      unpaidInvoices.isNotEmpty ? unpaidInvoices.first.id : null;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (dialogCtx, setDialogState) {
        final colorScheme = Theme.of(dialogCtx).colorScheme;
        final successColor = AppTheme.getSemanticSuccess(dialogCtx);
        final errorColor = AppTheme.getSemanticError(dialogCtx);

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: AppRadius.r16),
          title: Row(
            children: [
              Icon(Icons.link, color: colorScheme.primary),
              AppSpacing.w8,
              const Expanded(child: Text('Khớp Nợ Thủ Công')),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: AppSpacing.p12,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.45,
                      ),
                      borderRadius: AppRadius.r8,
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mã GD: ${tx.transactionCode}',
                          style: dialogCtx.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.bold)
                              .tabularFigures(),
                        ),
                        AppSpacing.h4,
                        Text(
                          'Số tiền: ${currencyFormat.format(tx.amount)}',
                          style: dialogCtx.titleSmall
                              ?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              )
                              .tabularFigures(),
                        ),
                        AppSpacing.h4,
                        Text(
                          'Nội dung CK: ${tx.title ?? tx.failureReason ?? "Không có nội dung"}',
                          style: dialogCtx.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        AppSpacing.h4,
                        Text(
                          'Cổng / Phương thức: ${tx.paymentMethod}',
                          style: dialogCtx.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.h16,
                  Text(
                    'Chọn Hóa Đơn Cần Gạch Nợ:',
                    style: dialogCtx.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  AppSpacing.h8,
                  if (unpaidInvoices.isEmpty)
                    Text(
                      'Không có hóa đơn nào đang chờ thanh toán.',
                      style: dialogCtx.bodyMedium?.copyWith(color: errorColor),
                    )
                  else
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: selectedInvoiceId,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      items: unpaidInvoices.map((inv) {
                        final aptCode = inv.apartment?.code ?? inv.apartmentId;
                        final isExactAmount =
                            (inv.totalAmount - tx.amount).abs() < 1;
                        final badge = isExactAmount ? ' [Khớp tiền]' : '';
                        return DropdownMenuItem<String>(
                          value: inv.id,
                          child: Text(
                            'Căn $aptCode - Kỳ ${inv.period} - ${currencyFormat.format(inv.totalAmount)}$badge',
                            style: dialogCtx.bodyMedium
                                ?.copyWith(
                                  fontWeight: isExactAmount
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isExactAmount
                                      ? successColor
                                      : colorScheme.onSurface,
                                )
                                .tabularFigures(),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setDialogState(() => selectedInvoiceId = val);
                      },
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 48),
              ),
              onPressed: selectedInvoiceId == null
                  ? null
                  : () => Navigator.of(dialogCtx).pop(true),
              child: const Text('Xác nhận gạch nợ'),
            ),
          ],
        );
      },
    ),
  );

  if (confirmed != true || selectedInvoiceId == null || !context.mounted) {
    return;
  }

  await runAction(
    context,
    () async {
      await ref.read(managementRepositoryProvider).matchUnmatchedTransaction(
            transactionId: tx.id,
            invoiceId: selectedInvoiceId!,
          );
      ref.invalidate(paymentTransactionsProvider);
      ref.invalidate(invoicesProvider);
      ref.invalidate(accountingWorkstationRowsProvider);
      return 'Đã khớp nợ thủ công thành công giao dịch vào hóa đơn!';
    },
    actionName: 'Khớp nợ thủ công',
  );
}

/// Tab Đối soát SePay / VietQR và xử lý giao dịch chưa khớp cú pháp.
class AccountingSepayReconciliationView extends ConsumerWidget {
  const AccountingSepayReconciliationView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txsAsync = ref.watch(paymentTransactionsProvider);
    final currencyFormat = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: 'đ',
      decimalDigits: 0,
    );
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final colorScheme = Theme.of(context).colorScheme;
    final successColor = AppTheme.getSemanticSuccess(context);
    final warningColor = AppTheme.getSemanticWarning(context);
    final errorColor = AppTheme.getSemanticError(context);

    return txsAsync.when(
      loading: () => Padding(
        padding: AppSpacing.p16,
        child: AppSkeletonShimmer.cardList(count: 4, itemHeight: 96),
      ),
      error: (err, _) => Padding(
        padding: AppSpacing.p24,
        child: AppErrorCard(
          error: err,
          onRetry: () => ref.invalidate(paymentTransactionsProvider),
        ),
      ),
      data: (transactions) {
        final sepayTxs = transactions.where((t) {
          final m = t.paymentMethod.toLowerCase();
          return m == 'sepay' || m == 'vietqr' || t.status == 'UNMATCHED';
        }).toList();

        final totalTxs = sepayTxs.length;
        final autoPaidTxs = sepayTxs.where((t) => t.isSuccess).length;
        final unmatchedTxs = sepayTxs.where((t) => t.isUnmatched).length;
        final totalAmount = sepayTxs
            .where((t) => t.isSuccess)
            .fold<double>(0.0, (sum, t) => sum + t.amount);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final double width = constraints.maxWidth;
                int crossAxisCount = 4;
                if (width < 600) {
                  crossAxisCount = 1;
                } else if (width < 1000) {
                  crossAxisCount = 2;
                }

                final cards = [
                  AccountingKpiCard(
                    title: 'Tổng Giao Dịch SePay',
                    value: '$totalTxs',
                    subtitle: 'Biến động số dư nhận được',
                    icon: Icons.account_balance_wallet_outlined,
                    iconColor: colorScheme.primary,
                    bgColor: colorScheme.primary.withValues(alpha: 0.1),
                  ),
                  AccountingKpiCard(
                    title: 'Đã Gạch Nợ Tự Động',
                    value: '$autoPaidTxs',
                    subtitle: 'Khớp mã hóa đơn tức thì',
                    icon: Icons.check_circle_outline_rounded,
                    iconColor: successColor,
                    bgColor: successColor.withValues(alpha: 0.1),
                  ),
                  AccountingKpiCard(
                    title: 'Giao Dịch Chưa Khớp',
                    value: '$unmatchedTxs',
                    subtitle: 'Cần kế toán viên kiểm tra',
                    icon: Icons.warning_amber_rounded,
                    iconColor: warningColor,
                    bgColor: warningColor.withValues(alpha: 0.1),
                  ),
                  AccountingKpiCard(
                    title: 'Tổng Tiền Thực Nhận',
                    value: currencyFormat.format(totalAmount),
                    subtitle: 'Đã vào tài khoản ngân hàng',
                    icon: Icons.monetization_on_outlined,
                    iconColor: successColor,
                    bgColor: successColor.withValues(alpha: 0.1),
                  ),
                ];

                if (crossAxisCount == 1) {
                  return Column(
                    children: cards
                        .map(
                          (c) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: c,
                          ),
                        )
                        .toList(),
                  );
                }
                if (crossAxisCount == 2) {
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: cards[0]),
                          AppSpacing.w12,
                          Expanded(child: cards[1]),
                        ],
                      ),
                      AppSpacing.h12,
                      Row(
                        children: [
                          Expanded(child: cards[2]),
                          AppSpacing.w12,
                          Expanded(child: cards[3]),
                        ],
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: cards[0]),
                    AppSpacing.w12,
                    Expanded(child: cards[1]),
                    AppSpacing.w12,
                    Expanded(child: cards[2]),
                    AppSpacing.w12,
                    Expanded(child: cards[3]),
                  ],
                );
              },
            ),
            AppSpacing.h20,
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: AppRadius.r12,
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: sepayTxs.isEmpty
                  ? const Padding(
                      padding: AppSpacing.p32,
                      child: AppEmptyState(
                        icon: Icons.qr_code_2_outlined,
                        title: 'Chưa có giao dịch SePay',
                        description:
                            'Chưa có giao dịch SePay nào được ghi nhận.',
                      ),
                    )
                  : ClipRRect(
                      borderRadius: AppRadius.r12,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 900),
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(
                              colorScheme.surfaceContainerHighest.withValues(
                                alpha: 0.45,
                              ),
                            ),
                            dataRowMinHeight: 56,
                            dataRowMaxHeight: 68,
                            columns: [
                              DataColumn(
                                label: Text(
                                  'Mã Giao Dịch',
                                  style: context.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Số Tiền',
                                  style: context.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Nội Dung Chuyển Khoản',
                                  style: context.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Thời Gian',
                                  style: context.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Trạng Thái',
                                  style: context.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Thao Tác',
                                  style: context.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                            rows: sepayTxs.map((tx) {
                              final statusColor = tx.isSuccess
                                  ? successColor
                                  : (tx.isUnmatched
                                        ? errorColor
                                        : warningColor);
                              return DataRow(
                                cells: [
                                  DataCell(
                                    Text(
                                      tx.transactionCode,
                                      style: context.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: colorScheme.primary,
                                          )
                                          .tabularFigures(),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      currencyFormat.format(tx.amount),
                                      style: context.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          )
                                          .tabularFigures(),
                                    ),
                                  ),
                                  DataCell(
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 260,
                                      ),
                                      child: Text(
                                        tx.title ?? tx.failureReason ?? '-',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      dateFormat.format(tx.createdAt),
                                      style: context.bodyMedium
                                          ?.tabularFigures(),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: AppRadius.r12,
                                      ),
                                      child: Text(
                                        tx.statusDisplayName,
                                        style: context.labelSmall?.copyWith(
                                          color: statusColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    tx.isUnmatched
                                        ? FilledButton.tonal(
                                            onPressed: () =>
                                                showManualMatchTransactionDialog(
                                                  context,
                                                  ref,
                                                  tx,
                                                ),
                                            style: FilledButton.styleFrom(
                                              minimumSize: const Size(0, 40),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 8,
                                                  ),
                                            ),
                                            child: Text(
                                              'Khớp nợ thủ công',
                                              style: context.labelSmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                            ),
                                          )
                                        : Text(
                                            'Tự động khớp',
                                            style: context.labelSmall?.copyWith(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}
