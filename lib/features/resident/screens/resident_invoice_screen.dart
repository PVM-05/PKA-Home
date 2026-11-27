import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/vietnamese_currency_words.dart';
import '../../../core/router/route_names.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_card.dart';
import '../../../core/widgets/app_skeleton_shimmer.dart';
import '../../../core/widgets/adaptive_master_detail_layout.dart';
import '../../../core/utils/app_haptics.dart';
import '../../../data/providers/payment_provider.dart';
import '../../../data/providers/resident_invoice_provider.dart';
import '../../../data/models/invoice_model.dart';
import 'resident_invoice_detail_screen.dart';

class ResidentInvoiceScreen extends ConsumerStatefulWidget {
  const ResidentInvoiceScreen({super.key});

  @override
  ConsumerState<ResidentInvoiceScreen> createState() =>
      _ResidentInvoiceScreenState();
}

class _ResidentInvoiceScreenState extends ConsumerState<ResidentInvoiceScreen> {
  InvoiceModel? _selectedInvoice;

  @override
  Widget build(BuildContext context) {
    final invoiceState = ref.watch(residentInvoiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hóa Đơn & Thanh Toán'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_outlined),
            tooltip: 'Lịch sử giao dịch VietQR',
            onPressed: () => context.push(AppRoutes.residentPaymentHistory),
          ),
        ],
      ),
      body: invoiceState.when(
        data: (invoices) {
          final unpaidInvoices =
              invoices
                  .where(
                    (i) =>
                        i.status != 'paid' &&
                        i.status != 'cancelled' &&
                        i.status != 'void',
                  )
                  .toList()..sort((
                a,
                b,
              ) {
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);
                final aDue = DateTime(
                  a.dueDate.year,
                  a.dueDate.month,
                  a.dueDate.day,
                );
                final bDue = DateTime(
                  b.dueDate.year,
                  b.dueDate.month,
                  b.dueDate.day,
                );
                final aOverdue =
                    a.status == 'overdue' ||
                    ((a.status == 'unpaid' || a.status == 'pending') &&
                        today.difference(aDue).inDays > 0);
                final bOverdue =
                    b.status == 'overdue' ||
                    ((b.status == 'unpaid' || b.status == 'pending') &&
                        today.difference(bDue).inDays > 0);
                if (aOverdue && !bOverdue) return -1;
                if (!aOverdue && bOverdue) return 1;
                return a.dueDate.compareTo(b.dueDate);
              });
          final paidInvoices =
              invoices.where((i) => i.status == 'paid').toList()..sort(
                (a, b) => (b.updatedAt ?? b.dueDate).compareTo(
                  a.updatedAt ?? a.dueDate,
                ),
              );

          return AdaptiveMasterDetailLayout<InvoiceModel>(
            selectedItem: _selectedInvoice,
            masterWidth: 420.0,
            emptyDetailBuilder: (ctx) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Theme.of(ctx).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.receipt_long_outlined,
                        size: 48,
                        color: Theme.of(ctx).colorScheme.primary.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Chi tiết hóa đơn',
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Chọn một hóa đơn từ danh sách bên trái để xem bảng kê chi tiết các khoản phí và thực hiện thanh toán.',
                      textAlign: TextAlign.center,
                      style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            detailBuilder: (ctx, item) => ResidentInvoiceDetailScreen(
              invoice: item,
              isEmbedded: true,
            ),
            masterBuilder: (ctx, isMasterOnly) => DefaultTabController(
              length: 3,
              child: Column(
                children: [
                  TabBar(
                    labelColor: Theme.of(ctx).colorScheme.primary,
                    unselectedLabelColor:
                        Theme.of(ctx).colorScheme.onSurfaceVariant,
                    indicatorColor: Theme.of(ctx).colorScheme.primary,
                    tabs: const [
                      Tab(
                        icon: Icon(Icons.pending_actions_outlined),
                        text: 'Cần thanh toán',
                      ),
                      Tab(
                        icon: Icon(Icons.history_outlined),
                        text: 'Lịch sử đã đóng',
                      ),
                      Tab(
                        icon: Icon(Icons.receipt_long_outlined),
                        text: 'Giao dịch',
                      ),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildInvoiceList(
                          ctx,
                          unpaidInvoices,
                          isMasterOnly: isMasterOnly,
                          emptyMessage:
                              'Tuyệt vời! Bạn không còn hóa đơn nào cần thanh toán.',
                          emptyIcon: Icons.check_circle_outline,
                        ),
                        _buildInvoiceList(
                          ctx,
                          paidInvoices,
                          isMasterOnly: isMasterOnly,
                          emptyMessage: 'Chưa có lịch sử hóa đơn đã thanh toán.',
                          emptyIcon: Icons.receipt_long_outlined,
                        ),
                        _buildTransactionsList(ctx, isMasterOnly: isMasterOnly),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppSkeletonShimmer.cardList(count: 4, itemHeight: 110),
          ],
        ),
        error: (error, stack) => Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: AppErrorCard(
              error: error,
              onRetry: () {
                ref.invalidate(residentInvoicePaginatedProvider);
                ref.invalidate(residentInvoiceProvider);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInvoiceList(
    BuildContext context,
    List<InvoiceModel> invoices, {
    required bool isMasterOnly,
    required String emptyMessage,
    required IconData emptyIcon,
  }) {
    return RefreshIndicator(
      color: Theme.of(context).colorScheme.primary,
      onRefresh: () async {
        HapticFeedback.lightImpact();
        ref.invalidate(residentInvoicePaginatedProvider);
        ref.invalidate(residentInvoiceProvider);
      },
      child: invoices.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: Center(
                    child: AppEmptyState(
                      icon: emptyIcon,
                      title: 'Danh sách trống',
                      description: emptyMessage,
                    ),
                  ),
                ),
              ],
            )
          : NotificationListener<ScrollNotification>(
              onNotification: (scrollInfo) {
                if (scrollInfo.metrics.pixels >=
                    scrollInfo.metrics.maxScrollExtent - 200) {
                  try {
                    ref.read(residentInvoicePaginatedProvider.notifier).loadMore();
                  } catch (_) {}
                }
                return false;
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: invoices.length,
                itemBuilder: (context, index) {
                  final invoice = invoices[index];
                  final isSelected = !isMasterOnly && invoice.id == _selectedInvoice?.id;
                  return _buildInvoiceCard(
                    context,
                    invoice,
                    isMasterOnly: isMasterOnly,
                    isSelected: isSelected,
                  );
                },
              ),
            ),
    );
  }

  Widget _buildInvoiceCard(
    BuildContext context,
    InvoiceModel invoice, {
    required bool isMasterOnly,
    required bool isSelected,
  }) {
    final formatCurrency = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    final formatDate = DateFormat('dd/MM/yyyy');
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final semanticError = AppTheme.getSemanticError(context);
    final semanticWarning = AppTheme.getSemanticWarning(context);

    Color statusColor;
    String statusText;
    IconData statusIcon;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(
      invoice.dueDate.year,
      invoice.dueDate.month,
      invoice.dueDate.day,
    );
    final diffDays = today.difference(dueDay).inDays;
    final isOverdue = invoice.status == 'unpaid' && diffDays > 0;
    final overdueDays = isOverdue ? diffDays : 0;
    final isDueToday = invoice.status == 'unpaid' && diffDays == 0;

    switch (invoice.status) {
      case 'paid':
        statusColor = AppStatusColors.getPaid(context);
        statusText = 'Đã thanh toán';
        statusIcon = Icons.check_circle_outline;
        break;
      case 'pending_confirmation':
        statusColor = AppStatusColors.getPendingConfirmation(context);
        statusText = 'Chờ xác nhận';
        statusIcon = Icons.schedule;
        break;
      default:
        if (isOverdue) {
          statusColor = semanticError;
          statusText = 'Quá hạn $overdueDays ngày';
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

    final borderColor = isSelected
        ? colorScheme.primary
        : (isOverdue
            ? semanticError.withValues(alpha: isDark ? 0.7 : 0.5)
            : null);

    final spokenAmount =
        VietnameseCurrencyWords.toVietnameseWords(invoice.totalAmount.toDouble());

    return Semantics(
      label:
          'Hóa đơn kỳ ${invoice.period}, hạn thanh toán ${formatDate.format(invoice.dueDate)}, số tiền $spokenAmount, trạng thái $statusText',
      button: true,
      child: AppCard(
        margin: const EdgeInsets.only(bottom: 12),
        borderColor: borderColor,
        onTap: () {
          if (isMasterOnly) {
            context.push(AppRoutes.residentInvoiceDetail, extra: invoice);
          } else {
            AppHaptics.selection();
            setState(() {
              _selectedInvoice = invoice;
            });
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Kỳ ${invoice.period}',
                    style: context.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: statusColor.withValues(alpha: isDark ? 0.35 : 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 14, color: statusColor),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            statusText,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: context.labelSmall?.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hạn thanh toán',
                        style: context.labelSmall?.copyWith(
                          color: isOverdue
                              ? semanticError
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatDate.format(invoice.dueDate),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isOverdue ? semanticError : null,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Tổng tiền',
                        style: context.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          formatCurrency.format(invoice.totalAmount),
                          style: context.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isOverdue
                                ? semanticError
                                : colorScheme.primary,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsList(
    BuildContext context, {
    required bool isMasterOnly,
  }) {
    final transactionsAsync = ref.watch(paymentTransactionsProvider);
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final paidColor = AppStatusColors.getPaid(context);
    final warningColor = AppTheme.getSemanticWarning(context);

    return RefreshIndicator(
      color: colorScheme.primary,
      onRefresh: () async {
        HapticFeedback.lightImpact();
        ref.invalidate(paymentTransactionsProvider);
      },
      child: transactionsAsync.when(
        loading: () => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppSkeletonShimmer.cardList(count: 4, itemHeight: 90),
          ],
        ),
        error: (err, _) => Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: AppErrorCard(
              error: err,
              onRetry: () => ref.invalidate(paymentTransactionsProvider),
            ),
          ),
        ),
        data: (transactions) {
          if (transactions.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: const Center(
                    child: AppEmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'Chưa có giao dịch thanh toán',
                      description:
                          'Các lịch sử nộp phí VietQR Napas 247 sẽ hiển thị đầy đủ tại đây sau khi giao dịch.',
                    ),
                  ),
                ),
              ],
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final tx = transactions[index];
              final isSuccess = tx.isSuccess;
              final txStatusColor = isSuccess ? paidColor : warningColor;

              return AppCard(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            tx.title ??
                                (tx.isInvoice
                                    ? 'Thanh toán hóa đơn'
                                    : 'Thanh toán dịch vụ'),
                            style: context.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              currencyFormat.format(tx.amount),
                              style: context.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isSuccess
                                    ? paidColor
                                    : colorScheme.primary,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            dateFormat.format(tx.createdAt),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: txStatusColor.withValues(
                                alpha: isDark ? 0.2 : 0.12,
                              ),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: txStatusColor.withValues(
                                  alpha: isDark ? 0.35 : 0.2,
                                ),
                              ),
                            ),
                            child: Text(
                              tx.statusDisplayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.labelSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: txStatusColor,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (tx.transactionCode.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Mã GD: ${tx.transactionCode}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Sao chép mã giao dịch',
                            constraints: const BoxConstraints(
                              minWidth: 48,
                              minHeight: 48,
                            ),
                            icon: Icon(
                              Icons.copy_rounded,
                              size: 16,
                              color: colorScheme.primary,
                            ),
                            onPressed: () {
                              AppHaptics.selection();
                              Clipboard.setData(
                                ClipboardData(text: tx.transactionCode),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Đã sao chép mã giao dịch: ${tx.transactionCode}',
                                  ),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
