import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../data/providers/management_provider.dart';
import '../../../data/models/invoice_model.dart';
import '../../../core/constants/permissions.dart';
import '../../../core/widgets/role_guard.dart';

import 'create_invoice_screen.dart';
import 'edit_invoice_screen.dart';
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

    return RoleGuard(
      permission: AppPermissions.invoiceManagement,
      child: Scaffold(
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
              emptyMessage: 'Chưa có hóa đơn nào được tạo.',
              emptyIcon: Icons.receipt_long_outlined,
              actionButton: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CreateInvoiceScreen()),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('Lập hóa đơn mới'),
              ),
              skeletonBuilder: (_) => ListView(
                padding: const EdgeInsets.all(16),
                children: const [
                  InvoiceCardSkeleton(),
                  InvoiceCardSkeleton(),
                  InvoiceCardSkeleton(),
                ],
              ),
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
                  return RefreshIndicator(
                    color: AppTheme.primary,
                    onRefresh: () async {
                      HapticFeedback.lightImpact();
                      ref.invalidate(invoicesProvider);
                    },
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.4,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withValues(alpha: 0.08),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.receipt_long_outlined, size: 48, color: AppTheme.primary),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Không có hóa đơn nào phù hợp với bộ lọc.',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  color: AppTheme.primary,
                  onRefresh: () async {
                    HapticFeedback.lightImpact();
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
                                    Expanded(
                                      child: Row(
                                        children: [
                                          const Icon(Icons.domain, color: AppTheme.primary, size: 20),
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Text(
                                              'Căn hộ ${invoice.apartment?.code ?? 'N/A'}',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (isNew) ...[
                                            const SizedBox(width: 6),
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
                                    ),
                                    const SizedBox(width: 8),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
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
                                        PopupMenuButton<String>(
                                          icon: const Icon(Icons.more_vert, size: 20, color: AppTheme.textSecondary),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onSelected: (value) {
                                            if (value == 'edit') {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) => EditInvoiceScreen(invoice: invoice),
                                                ),
                                              );
                                            } else if (value == 'delete') {
                                              _confirmDeleteInvoice(invoice);
                                            }
                                          },
                                          itemBuilder: (context) => [
                                            const PopupMenuItem(
                                              value: 'edit',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.edit, size: 18),
                                                  SizedBox(width: 8),
                                                  Text('Chỉnh sửa'),
                                                ],
                                              ),
                                            ),
                                            const PopupMenuItem(
                                              value: 'delete',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.delete, color: AppTheme.error, size: 18),
                                                  SizedBox(width: 8),
                                                  Text('Xóa', style: TextStyle(color: AppTheme.error)),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
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
        heroTag: 'invoice_management_fab',
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreateInvoiceScreen()));
        },
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Lập hóa đơn', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    ));
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

  Future<void> _confirmDeleteInvoice(InvoiceModel invoice) async {
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

    if (confirmed == true && mounted) {
      try {
        await ref.read(managementRepositoryProvider).deleteInvoice(invoice.id);
        ref.invalidate(invoicesProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã xóa hóa đơn thành công!'),
              backgroundColor: AppTheme.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
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
