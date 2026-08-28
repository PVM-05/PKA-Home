import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/providers/management_provider.dart';

import 'create_invoice_screen.dart';
import 'management_invoice_detail_screen.dart';

class InvoiceManagementScreen extends ConsumerStatefulWidget {
  const InvoiceManagementScreen({super.key});

  @override
  ConsumerState<InvoiceManagementScreen> createState() => _InvoiceManagementScreenState();
}

class _InvoiceManagementScreenState extends ConsumerState<InvoiceManagementScreen> {
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
  int _tabIndex = 0; // 0 = Chưa thanh toán, 1 = Đã thanh toán


  @override
  Widget build(BuildContext context) {
    final invoicesAsync = ref.watch(invoicesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Hóa đơn'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: _buildTab(0, 'Đang nợ', AppTheme.warning),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTab(1, 'Đã thu', AppTheme.success),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: invoicesAsync.when(
              data: (invoices) {
                final filtered = invoices.where((inv) {
                  if (_tabIndex == 0) return inv.status == 'unpaid' || inv.status == 'pending_confirmation';
                  return inv.status == 'paid';
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(FluentIcons.receipt_24_regular, size: 64, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                        const SizedBox(height: 16),
                        Text(
                          'Không có hóa đơn nào.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(invoicesProvider);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final invoice = filtered[index];
                      
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ManagementInvoiceDetailScreen(invoice: invoice),
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
                                    Row(
                                      children: [
                                        const Icon(FluentIcons.building_24_regular, color: AppTheme.primary, size: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Căn hộ ${invoice.apartment?.code ?? 'N/A'}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(invoice.status).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        _getStatusText(invoice.status),
                                        style: TextStyle(
                                          color: _getStatusColor(invoice.status),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text('Kỳ hóa đơn: ${invoice.period}', style: Theme.of(context).textTheme.bodyMedium),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Số tiền: ${_currencyFormat.format(invoice.totalAmount)}', 
                                      style: const TextStyle(
                                        color: AppTheme.error, 
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16
                                      )
                                    ),
                                    const Text('Xem chi tiết >', style: TextStyle(color: AppTheme.primary, fontSize: 12)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Lỗi: $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreateInvoiceScreen()));
        },
        backgroundColor: AppTheme.primary,
        icon: const Icon(FluentIcons.add_24_regular, color: Colors.white),
        label: const Text('Lập hóa đơn', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildTab(int index, String title, Color activeColor) {
    final isActive = _tabIndex == index;
    return InkWell(
      onTap: () => setState(() => _tabIndex = index),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withValues(alpha: 0.1) : AppTheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? activeColor : const Color(0xFFE0E0E0),
          ),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isActive) ...[
                Icon(
                  index == 0 ? FluentIcons.clock_24_filled : FluentIcons.checkmark_circle_24_filled, 
                  color: activeColor, 
                  size: 16
                ),
                const SizedBox(width: 8),
              ],
              Text(
                title,
                style: TextStyle(
                  color: isActive ? activeColor : AppTheme.textSecondary,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'paid': return AppTheme.success;
      case 'pending_confirmation': return AppTheme.warning;
      case 'unpaid': default: return AppTheme.error;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'paid': return 'Đã thanh toán';
      case 'pending_confirmation': return 'Chờ xác nhận';
      case 'unpaid': default: return 'Đang nợ';
    }
  }
}
