import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/providers/resident_invoice_provider.dart';
import '../../../data/models/invoice_model.dart';
import 'resident_invoice_detail_screen.dart';

class ResidentInvoiceScreen extends ConsumerWidget {
  const ResidentInvoiceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoiceState = ref.watch(residentInvoiceProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Hóa Đơn & Thanh Toán'),
          bottom: const TabBar(
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textSecondary,
            indicatorColor: AppTheme.primary,
            tabs: [
              Tab(icon: Icon(Icons.pending_actions_outlined), text: 'Cần thanh toán'),
              Tab(icon: Icon(Icons.history_outlined), text: 'Lịch sử đã đóng'),
            ],
          ),
        ),
        body: invoiceState.when(
          data: (invoices) {
            final unpaidInvoices = invoices
                .where((i) => i.status != 'paid')
                .toList();
            final paidInvoices = invoices
                .where((i) => i.status == 'paid')
                .toList()
              ..sort((a, b) => (b.updatedAt ?? b.dueDate).compareTo(a.updatedAt ?? a.dueDate));

            return TabBarView(
              children: [
                _buildInvoiceList(
                  context,
                  ref,
                  unpaidInvoices,
                  emptyMessage: 'Tuyệt vời! Bạn không còn hóa đơn nào cần thanh toán.',
                  emptyIcon: Icons.check_circle_outline,
                  emptyColor: AppStatusColors.paid,
                ),
                _buildInvoiceList(
                  context,
                  ref,
                  paidInvoices,
                  emptyMessage: 'Chưa có lịch sử hóa đơn đã thanh toán.',
                  emptyIcon: Icons.receipt_long_outlined,
                  emptyColor: AppTheme.textSecondary,
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Text(
              'Lỗi tải dữ liệu: $error',
              style: const TextStyle(color: AppTheme.error),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInvoiceList(
    BuildContext context,
    WidgetRef ref,
    List<InvoiceModel> invoices, {
    required String emptyMessage,
    required IconData emptyIcon,
    required Color emptyColor,
  }) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(residentInvoiceProvider);
      },
      child: invoices.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      emptyIcon,
                      size: 64,
                      color: emptyColor.withValues(alpha: 0.6),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      emptyMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: invoices.length,
              itemBuilder: (context, index) {
                final invoice = invoices[index];
                return _buildInvoiceCard(context, invoice);
              },
            ),
    );
  }

  Widget _buildInvoiceCard(BuildContext context, InvoiceModel invoice) {
    final formatCurrency = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    final formatDate = DateFormat('dd/MM/yyyy');

    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (invoice.status) {
      case 'paid':
        statusColor = AppStatusColors.paid;
        statusText = 'Đã thanh toán';
        statusIcon = Icons.check_circle_outline;
        break;
      case 'pending_confirmation':
        statusColor = AppStatusColors.pending;
        statusText = 'Chờ xác nhận';
        statusIcon = Icons.schedule;
        break;
      default:
        statusColor = AppStatusColors.unpaid;
        statusText = 'Chưa thanh toán';
        statusIcon = Icons.error_outline;
    }

    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ResidentInvoiceDetailScreen(invoice: invoice),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Kỳ ${invoice.period}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 14, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
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
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          formatDate.format(invoice.dueDate),
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Tổng tiền',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          formatCurrency.format(invoice.totalAmount),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppTheme.primary,
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
      ),
    );
  }
}
