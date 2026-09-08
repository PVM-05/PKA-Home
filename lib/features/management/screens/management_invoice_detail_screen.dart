import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../data/models/invoice_model.dart';
import '../../../data/providers/management_provider.dart';
import '../../../data/providers/resident_invoice_provider.dart' show invoiceDetailProvider;

class ManagementInvoiceDetailScreen extends ConsumerWidget {
  final InvoiceModel invoice;

  const ManagementInvoiceDetailScreen({super.key, required this.invoice});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatCurrency = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    final formatDate = DateFormat('dd/MM/yyyy');
    final detailState = ref.watch(invoiceDetailProvider(invoice.id)); // Provider dùng chung để lấy chi tiết invoice_items

    return Scaffold(
      appBar: AppBar(
        title: Text('Chi tiết Hóa đơn ${invoice.period}'),
      ),
      body: detailState.when(
        data: (items) {
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildSummaryCard(formatCurrency, formatDate),
                    const SizedBox(height: 24),
                    const Text(
                      'CHI TIẾT CÁC KHOẢN PHÍ',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...items.map((item) => _buildFeeItem(item, formatCurrency)),
                  ],
                ),
              ),
              _buildBottomAction(context, ref),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text(formatErrorMessage(error), style: const TextStyle(color: AppTheme.error))),
      ),
    );
  }

  Widget _buildSummaryCard(NumberFormat formatCurrency, DateFormat formatDate) {
    Color statusColor;
    String statusText;

    switch (invoice.status) {
      case 'paid':
        statusColor = AppTheme.success;
        statusText = 'Đã thanh toán';
        break;
      case 'pending_confirmation':
        statusColor = AppTheme.warning;
        statusText = 'Chờ xác nhận';
        break;
      default:
        statusColor = AppTheme.error;
        statusText = 'Chưa thanh toán';
    }

    return Card(
      color: statusColor.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: statusColor.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'TỔNG CỘNG',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              formatCurrency.format(invoice.totalAmount),
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            _buildInfoRow('Trạng thái', statusText, valueColor: statusColor),
            const SizedBox(height: 8),
            _buildInfoRow('Hạn thanh toán', formatDate.format(invoice.dueDate)),
            const SizedBox(height: 8),
            _buildInfoRow('Căn hộ', invoice.apartment?.code ?? 'N/A'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildFeeItem(Map<String, dynamic> item, NumberFormat formatCurrency) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['fee_type'] ?? 'Phí',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  '${formatCurrency.format(item['unit_price'] ?? 0)} x ${item['quantity'] ?? 1}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            formatCurrency.format(item['subtotal'] ?? 0),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomAction(BuildContext context, WidgetRef ref) {
    final isPending = invoice.status == 'pending_confirmation';
    final isUnpaid = invoice.status == 'unpaid';

    if (!isPending && !isUnpaid) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -4),
            blurRadius: 16,
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: AppTheme.success,
        ),
        onPressed: () async {
          try {
            await ref.read(managementRepositoryProvider).updateInvoiceStatus(invoice.id, 'paid');
            ref.invalidate(invoicesProvider);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Xác nhận thu tiền thành công.'),
                  backgroundColor: AppTheme.success,
                ),
              );
              Navigator.pop(context);
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(formatErrorMessage(e)),
                  backgroundColor: AppTheme.error,
                ),
              );
            }
          }
        },
        child: Text(isPending ? 'XÁC NHẬN ĐÃ THU (Cư dân báo đã CK)' : 'XÁC NHẬN ĐÃ THU (Tiền mặt)'),
      ),
    );
  }
}
