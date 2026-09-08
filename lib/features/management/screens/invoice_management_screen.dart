import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../data/providers/management_provider.dart';
import '../../../data/models/invoice_model.dart';

import 'create_invoice_screen.dart';
import 'management_invoice_detail_screen.dart';

class InvoiceManagementScreen extends ConsumerStatefulWidget {
  const InvoiceManagementScreen({super.key});

  @override
  ConsumerState<InvoiceManagementScreen> createState() => _InvoiceManagementScreenState();
}

class _InvoiceManagementScreenState extends ConsumerState<InvoiceManagementScreen> {
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'all'; // 'all', 'pending_confirmation', 'unpaid', 'paid'

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
          // Thanh tìm kiếm
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm theo căn hộ (VD: A0110, B0502)...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (val) {
                setState(() => _searchQuery = val.trim());
              },
            ),
          ),

          // Hàng FilterChips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _buildFilterChip('all', 'Tất cả', null),
                const SizedBox(width: 8),
                _buildFilterChip('pending_confirmation', 'Chờ xác nhận', AppStatusColors.pendingConfirmation),
                const SizedBox(width: 8),
                _buildFilterChip('unpaid', 'Đang nợ', AppStatusColors.unpaid),
                const SizedBox(width: 8),
                _buildFilterChip('paid', 'Đã thanh toán', AppStatusColors.paid),
              ],
            ),
          ),
          const SizedBox(height: 8),
          
          Expanded(
            child: AppStateView<List<InvoiceModel>>(
              asyncValue: invoicesAsync,
              emptyMessage: 'Không có hóa đơn nào.',
              emptyIcon: Icons.receipt_long_outlined,
              onRetry: () => ref.invalidate(invoicesProvider),
              dataBuilder: (invoices) {
                final filtered = invoices.where((inv) {
                  if (_statusFilter == 'pending_confirmation' && inv.status != 'pending_confirmation') {
                    return false;
                  }
                  if (_statusFilter == 'unpaid' && inv.status != 'unpaid') {
                    return false;
                  }
                  if (_statusFilter == 'paid' && inv.status != 'paid') {
                    return false;
                  }

                  if (_searchQuery.isNotEmpty) {
                    final code = (inv.apartment?.code ?? '').toLowerCase();
                    final period = inv.period.toLowerCase();
                    final q = _searchQuery.toLowerCase();
                    if (!code.contains(q) && !period.contains(q)) return false;
                  }

                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 64, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                        const SizedBox(height: 16),
                        Text(
                          'Không có hóa đơn nào ở trạng thái này.',
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
                      final isNew = DateTime.now().difference(invoice.createdAt).inMinutes < 15;
                      
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
                                        const Icon(Icons.domain, color: AppTheme.primary, size: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Căn hộ ${invoice.apartment?.code ?? 'N/A'}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                        if (isNew) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppStatusColors.paid,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text('MỚI', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                          )
                                        ]
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
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreateInvoiceScreen()));
        },
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Lập hóa đơn', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label, Color? highlightColor) {
    final isSelected = _statusFilter == filterKey;
    final color = highlightColor ?? AppTheme.primary;

    return FilterChip(
      selected: isSelected,
      label: Text(label),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppTheme.textPrimary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 13,
      ),
      backgroundColor: Colors.white,
      selectedColor: color,
      checkmarkColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? color : Colors.grey.shade300,
        ),
      ),
      onSelected: (_) {
        setState(() => _statusFilter = filterKey);
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'paid': return AppStatusColors.paid;
      case 'pending_confirmation': return AppStatusColors.pendingConfirmation;
      case 'unpaid': default: return AppStatusColors.unpaid;
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
