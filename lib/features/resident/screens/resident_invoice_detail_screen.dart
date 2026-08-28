import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/invoice_model.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import '../../../data/providers/resident_invoice_provider.dart';

class ResidentInvoiceDetailScreen extends ConsumerWidget {
  final InvoiceModel invoice;

  const ResidentInvoiceDetailScreen({super.key, required this.invoice});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatCurrency = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    final formatDate = DateFormat('dd/MM/yyyy');
    final detailState = ref.watch(residentInvoiceDetailProvider(invoice.id));

    return Scaffold(
      appBar: AppBar(
        title: Text('Chi tiết hóa đơn ${invoice.period}'),
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
        error: (error, stack) => Center(child: Text('Lỗi: $error')),
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
    if (invoice.status != 'unpaid') {
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
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: AppTheme.primary,
        ),
        icon: const Icon(FluentIcons.payment_24_regular),
        label: const Text('THANH TOÁN NGAY', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        onPressed: () {
          _showPaymentBottomSheet(context, ref);
        },
      ),
    );
  }

  void _showPaymentBottomSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext bottomSheetContext) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Chọn phương thức thanh toán',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              _buildPaymentOption(
                bottomSheetContext, 
                ref,
                icon: FluentIcons.building_bank_24_regular,
                title: 'Thẻ ATM / Tài khoản ngân hàng',
                color: Colors.blue,
              ),
              const SizedBox(height: 12),
              _buildPaymentOption(
                bottomSheetContext, 
                ref,
                icon: FluentIcons.wallet_24_regular,
                title: 'Ví MoMo',
                color: const Color(0xFFA50064),
              ),
              const SizedBox(height: 12),
              _buildPaymentOption(
                bottomSheetContext, 
                ref,
                icon: FluentIcons.wallet_24_regular,
                title: 'ZaloPay',
                color: Colors.green,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPaymentOption(BuildContext context, WidgetRef ref, {required IconData icon, required String title, required Color color}) {
    return InkWell(
      onTap: () async {
        Navigator.pop(context); // Đóng bottom sheet
        
        // Hiển thị loading giả lập
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (c) => const Center(child: CircularProgressIndicator()),
        );

        await Future.delayed(const Duration(seconds: 1)); // Giả lập call API
        
        try {
          await ResidentInvoiceService.confirmPayment(ref, invoice.id);
          if (context.mounted) {
            Navigator.pop(context); // Đóng loading
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Thanh toán thành công!'),
                backgroundColor: AppTheme.success,
              ),
            );
            Navigator.pop(context); // Quay lại trang trước
          }
        } catch (e) {
          if (context.mounted) {
            Navigator.pop(context); // Đóng loading
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Lỗi: $e'),
                backgroundColor: AppTheme.error,
              ),
            );
          }
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(12),
          color: color.withValues(alpha: 0.05),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 16),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const Spacer(),
            Icon(FluentIcons.chevron_right_24_regular, color: color),
          ],
        ),
      ),
    );
  }
}
