import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../data/models/invoice_model.dart';
import '../../../data/providers/management_provider.dart';
import '../../../data/providers/invoice_items_provider.dart';
import '../../../data/providers/payment_provider.dart';
import 'edit_invoice_screen.dart';
import '../../../core/utils/invoice_fee_helper.dart';

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
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Sửa hóa đơn',
            onPressed: () async {
              final updated = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => EditInvoiceScreen(invoice: invoice),
                ),
              );
              if (updated == true) {
                ref.invalidate(invoiceDetailProvider(invoice.id));
                ref.invalidate(invoicesProvider);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppTheme.error),
            tooltip: 'Xóa hóa đơn',
            onPressed: () => _confirmDeleteInvoice(context, ref),
          ),
        ],
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
    final rawFeeType = item['fee_type'] as String?;
    final feeDisplayName = InvoiceFeeHelper.getFeeName(rawFeeType);
    final feeIcon = InvoiceFeeHelper.getFeeIcon(rawFeeType);
    final feeColor = InvoiceFeeHelper.getFeeColor(rawFeeType);
    final feeUnit = InvoiceFeeHelper.getFeeUnit(rawFeeType);

    final qty = item['quantity'] ?? 1;
    final qtyStr = (qty is num && qty == qty.roundToDouble())
        ? qty.toInt().toString()
        : qty.toString();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: feeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(feeIcon, color: feeColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feeDisplayName,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatCurrency.format(item['unit_price'] ?? 0)} x $qtyStr$feeUnit',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatCurrency.format(item['subtotal'] ?? 0),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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

    final reqMethod = (invoice.paymentMethod ?? '').toLowerCase();
    final isCashRequest = reqMethod == 'cash' || reqMethod == 'tiền mặt';

    final String buttonLabel;
    if (isPending) {
      buttonLabel = isCashRequest
          ? 'XÁC NHẬN ĐÃ THU (Cư dân báo nộp Tiền mặt)'
          : 'XÁC NHẬN ĐÃ THU (Cư dân báo Chuyển khoản)';
    } else {
      buttonLabel = 'XÁC NHẬN ĐÃ THU (Thu trực tiếp tại quầy)';
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            offset: const Offset(0, -3),
            blurRadius: 12,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success,
                foregroundColor: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.check_circle_outline, size: 20),
              label: Text(
                buttonLabel,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              onPressed: () => _confirmPayment(context, ref, isPending),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmPayment(BuildContext context, WidgetRef ref, bool isPending) async {
    final reqMethod = (invoice.paymentMethod ?? '').toLowerCase();
    final isCashRequest = reqMethod == 'cash' || reqMethod == 'tiền mặt';
    String selectedMethod = isCashRequest ? 'CASH' : 'BANK_TRANSFER';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: AppTheme.success),
              SizedBox(width: 8),
              Text('Xác nhận thu tiền'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Vui lòng kiểm tra và xác nhận phương thức đã nhận đủ:'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• Căn hộ: ${invoice.apartment?.code ?? "Chưa rõ"}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('• Kỳ phí: ${invoice.period}'),
                    const SizedBox(height: 4),
                    Text('• Số tiền: ${NumberFormat.currency(locale: "vi_VN", symbol: "đ").format(invoice.totalAmount)}', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                    if (isPending) ...[
                      const SizedBox(height: 4),
                      Text(
                        '• Cư dân đã báo: ${isCashRequest ? "Nộp tiền mặt tại BQL" : "Chuyển khoản (VietQR)"}',
                        style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text('Hình thức thanh toán thực thu:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              // ignore: deprecated_member_use
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Tiền mặt (CASH)'),
                value: 'CASH',
                // ignore: deprecated_member_use
                groupValue: selectedMethod,
                // ignore: deprecated_member_use
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedMethod = val);
                },
              ),
              // ignore: deprecated_member_use
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Chuyển khoản (BANK_TRANSFER)'),
                value: 'BANK_TRANSFER',
                // ignore: deprecated_member_use
                groupValue: selectedMethod,
                // ignore: deprecated_member_use
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedMethod = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Xác nhận đã thu'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final repo = ref.read(managementRepositoryProvider);
      final methodTitle = selectedMethod == 'CASH' ? 'Tiền mặt' : 'Chuyển khoản';
      final txnTitle = 'Thanh toán hóa đơn kỳ ${invoice.period} ($methodTitle)';
      
      // Sử dụng recordManualPayment thay thế cho recordPaymentTransaction để đảm bảo tính nguyên tử (atomic transaction)
      await repo.recordManualPayment(
        invoiceId: invoice.id,
        paymentMethod: selectedMethod,
        notes: txnTitle,
      );

      ref.invalidate(invoicesProvider);
      ref.invalidate(paymentTransactionsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Xác nhận thu tiền ($methodTitle) thành công.'),
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
  }

  Future<void> _confirmDeleteInvoice(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa hóa đơn'),
        content: Text(
          'Bạn có chắc chắn muốn xóa hóa đơn kỳ ${invoice.period} của căn hộ ${invoice.apartment?.code ?? ''}?\n\nToàn bộ các khoản phí liên quan sẽ bị xóa và không thể khôi phục.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref.read(managementRepositoryProvider).deleteInvoice(invoice.id);
        ref.invalidate(invoicesProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã xóa hóa đơn thành công!'),
              backgroundColor: AppTheme.success,
            ),
          );
          Navigator.of(context).pop();
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
    }
  }
}
