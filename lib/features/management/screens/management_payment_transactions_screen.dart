import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../data/models/payment_transaction_model.dart';
import '../../../data/providers/payment_provider.dart';

class ManagementPaymentTransactionsScreen extends ConsumerStatefulWidget {
  const ManagementPaymentTransactionsScreen({super.key});

  @override
  ConsumerState<ManagementPaymentTransactionsScreen> createState() => _ManagementPaymentTransactionsScreenState();
}

class _ManagementPaymentTransactionsScreenState extends ConsumerState<ManagementPaymentTransactionsScreen> {
  String _selectedFilter = 'all'; // 'all', 'INVOICE', 'SERVICE'
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

  void _showTransactionDetails(PaymentTransactionModel tx) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.verified, color: AppTheme.success),
            SizedBox(width: 8),
            Text('Chi tiết Giao dịch', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Mã GD', tx.transactionCode),
            const Divider(),
            _buildDetailRow('Nội dung', tx.title ?? 'Thanh toán dịch vụ'),
            const Divider(),
            _buildDetailRow('Loại GD', tx.isInvoice ? 'Hóa đơn định kỳ' : 'Dịch vụ tiện ích'),
            const Divider(),
            _buildDetailRow('Số tiền', _currencyFormat.format(tx.amount), isAmount: true),
            const Divider(),
            _buildDetailRow('Phương thức', tx.paymentMethod),
            const Divider(),
            _buildDetailRow('Thời gian', DateFormat('dd/MM/yyyy HH:mm:ss').format(tx.createdAt)),
            const Divider(),
            _buildDetailRow('Trạng thái', tx.isSuccess ? 'Thành công (Đã đối soát)' : tx.status),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isAmount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isAmount ? AppTheme.primary : AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(paymentTransactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Đối soát Giao dịch'),
      ),
      body: transactionsAsync.when(
        data: (transactions) {
          final invoiceCount = transactions.where((t) => t.isInvoice).length;
          final serviceCount = transactions.where((t) => t.isService).length;

          final filtered = transactions.where((t) {
            if (_selectedFilter == 'INVOICE') return t.isInvoice;
            if (_selectedFilter == 'SERVICE') return t.isService;
            return true;
          }).toList();

          return Column(
            children: [
              // Bộ lọc Chips
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    FilterChip(
                      label: Text('Tất cả (${transactions.length})'),
                      selected: _selectedFilter == 'all',
                      onSelected: (_) => setState(() => _selectedFilter = 'all'),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: Text('Hóa đơn ($invoiceCount)'),
                      selected: _selectedFilter == 'INVOICE',
                      onSelected: (_) => setState(() => _selectedFilter = 'INVOICE'),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: Text('Dịch vụ ($serviceCount)'),
                      selected: _selectedFilter == 'SERVICE',
                      onSelected: (_) => setState(() => _selectedFilter = 'SERVICE'),
                    ),
                  ],
                ),
              ),

              // Danh sách giao dịch
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 64, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                            const SizedBox(height: 16),
                            const Text('Không có giao dịch nào phù hợp.', style: TextStyle(color: AppTheme.textSecondary)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final tx = filtered[index];
                          return AppCard(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 10),
                            child: InkWell(
                              onTap: () => _showTransactionDetails(tx),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: tx.isInvoice
                                          ? AppTheme.primary.withValues(alpha: 0.1)
                                          : AppTheme.secondary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      tx.isInvoice ? Icons.home_outlined : Icons.sports_tennis_outlined,
                                      color: tx.isInvoice ? AppTheme.primary : AppTheme.secondary,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          tx.title ?? 'Giao dịch thanh toán',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${tx.transactionCode} • ${DateFormat('dd/MM/yyyy HH:mm').format(tx.createdAt)}',
                                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        _currencyFormat.format(tx.amount),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: AppTheme.primary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppTheme.success.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'Thành công',
                                          style: TextStyle(fontSize: 10, color: AppTheme.success, fontWeight: FontWeight.bold),
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e', style: const TextStyle(color: AppTheme.error))),
      ),
    );
  }
}
