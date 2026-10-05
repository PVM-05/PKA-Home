import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../../data/models/payment_transaction_model.dart';
import '../../../data/providers/payment_provider.dart';

enum _PaymentFilter { all, invoice, service }

class PaymentHistoryScreen extends ConsumerStatefulWidget {
  const PaymentHistoryScreen({super.key});

  @override
  ConsumerState<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends ConsumerState<PaymentHistoryScreen> {
  _PaymentFilter _currentFilter = _PaymentFilter.all;

  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm');
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(paymentTransactionsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử thanh toán'),
      ),
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

          return Column(
            children: [
              // Thanh bộ lọc ngang
              Container(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    _buildFilterChip(
                      label: 'Tất cả (${transactions.length})',
                      isSelected: _currentFilter == _PaymentFilter.all,
                      onTap: () => setState(() => _currentFilter = _PaymentFilter.all),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: 'Hóa đơn ($invoiceCount)',
                      icon: Icons.home_outlined,
                      isSelected: _currentFilter == _PaymentFilter.invoice,
                      onTap: () => setState(() => _currentFilter = _PaymentFilter.invoice),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: 'Dịch vụ ($serviceCount)',
                      icon: Icons.sports_tennis_outlined,
                      isSelected: _currentFilter == _PaymentFilter.service,
                      onTap: () => setState(() => _currentFilter = _PaymentFilter.service),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Danh sách giao dịch
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(paymentTransactionsProvider);
                  },
                  child: filteredList.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredList.length,
                          itemBuilder: (context, index) {
                            final tx = filteredList[index];
                            return _buildTransactionCard(context, tx);
                          },
                        ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(formatErrorMessage(e), style: const TextStyle(color: AppTheme.error)),
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    IconData? icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary
              : (Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primary : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 15,
                color: isSelected ? Colors.white : AppTheme.textSecondary,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionCard(BuildContext context, PaymentTransactionModel tx) {
    final isInvoice = tx.isInvoice;
    final iconColor = isInvoice ? AppTheme.primary : Colors.deepOrange;
    final iconData = isInvoice
        ? Icons.receipt_long_rounded
        : (tx.title?.toLowerCase().contains('bơi') ?? false
            ? Icons.pool_rounded
            : (tx.title?.toLowerCase().contains('gym') ?? false
                ? Icons.fitness_center_rounded
                : Icons.sports_tennis_rounded));

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(iconData, color: iconColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.title ?? (isInvoice ? 'Hóa đơn định kỳ' : 'Dịch vụ tiện ích'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  _dateFormat.format(tx.createdAt),
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    tx.transactionCode,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _currencyFormat.format(tx.amount),
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    tx.isSuccess ? Icons.check_circle : Icons.error,
                    size: 14,
                    color: tx.isSuccess ? AppTheme.success : AppTheme.error,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    tx.statusDisplayName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: tx.isSuccess ? AppTheme.success : AppTheme.error,
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_long_outlined, size: 40, color: AppTheme.primary),
          ),
          const SizedBox(height: 16),
          const Text(
            'Chưa có giao dịch thanh toán nào',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Các hóa đơn và lịch đặt dịch vụ đã thanh toán sẽ hiển thị ở đây',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
