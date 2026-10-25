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
import '../widgets/bulk_invoice_dialog.dart';
import '../../../core/utils/excel_export_helper.dart';

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
  bool _isExporting = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _exportExcel(List<InvoiceModel> invoices) async {
    setState(() => _isExporting = true);
    final path = await ExcelExportHelper.exportInvoices(invoices);
    setState(() => _isExporting = false);
    
    if (mounted) {
      if (path != null) {
        ExcelExportHelper.shareFile(path, subject: 'Danh sách hóa đơn PKA-Home');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Đã xuất file thành công!'),
            backgroundColor: AppTheme.success,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Chia sẻ lại',
              textColor: Colors.white,
              onPressed: () => ExcelExportHelper.shareFile(path, subject: 'Danh sách hóa đơn PKA-Home'),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lỗi khi xuất file Excel.'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  List<InvoiceModel> _filterInvoices(List<InvoiceModel> invoices) {
    return invoices.where((inv) {
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
  }

  @override
  Widget build(BuildContext context) {
    final invoicesAsync = ref.watch(invoicesProvider);
    final allInvoices = invoicesAsync.valueOrNull ?? [];
    final allCount = allInvoices.length;
    final pendingConfirmationCount = allInvoices.where((i) => i.status == 'pending_confirmation').length;
    final unpaidCount = allInvoices.where((i) => i.status == 'unpaid').length;
    final paidCount = allInvoices.where((i) => i.status == 'paid').length;

    return RoleGuard(
      permission: AppPermissions.invoiceManagement,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Quản lý Hóa đơn'),
          actions: [
            if (_isExporting)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: Center(
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              )
            else
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                tooltip: 'Tùy chọn khác',
                onSelected: (value) {
                  if (value == 'bulk') {
                    showDialog(
                      context: context,
                      builder: (_) => const BulkInvoiceDialog(),
                    );
                  } else if (value == 'export') {
                    final invoices = invoicesAsync.valueOrNull;
                    if (invoices != null && invoices.isNotEmpty) {
                      _exportExcel(_filterInvoices(invoices));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Không có dữ liệu để xuất Excel.')),
                      );
                    }
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'bulk',
                    child: Row(
                      children: [
                        Icon(Icons.auto_awesome, size: 20, color: AppTheme.primary),
                        SizedBox(width: 10),
                        Text('Tạo HĐ hàng loạt'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'export',
                    child: Row(
                      children: [
                        Icon(Icons.download, size: 20, color: AppTheme.primary),
                        SizedBox(width: 10),
                        Text('Xuất Excel'),
                      ],
                    ),
                  ),
                ],
              ),
          ],
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
                _buildFilterChip('all', 'Tất cả ($allCount)', null),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'pending_confirmation',
                  'Chờ xác nhận ($pendingConfirmationCount)',
                  AppStatusColors.pendingConfirmation,
                  hasBadge: pendingConfirmationCount > 0,
                ),
                const SizedBox(width: 8),
                _buildFilterChip('unpaid', 'Đang nợ ($unpaidCount)', AppStatusColors.unpaid),
                const SizedBox(width: 8),
                _buildFilterChip('paid', 'Đã thanh toán ($paidCount)', AppStatusColors.paid),
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
                final filtered = _filterInvoices(invoices);

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
                      
                      final isPendingConfirmation = invoice.status == 'pending_confirmation';

                      return Card(
                        clipBehavior: Clip.antiAlias,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: isPendingConfirmation
                              ? BorderSide(color: AppStatusColors.pendingConfirmation, width: 1.5)
                              : BorderSide(color: Colors.grey.shade200, width: 1),
                        ),
                        color: isPendingConfirmation
                            ? AppStatusColors.pendingConfirmation.withValues(alpha: 0.04)
                            : Colors.white,
                        elevation: isPendingConfirmation ? 2 : 1,
                        margin: const EdgeInsets.only(bottom: 12),
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
                                          Icon(
                                            Icons.domain,
                                            color: isPendingConfirmation ? AppStatusColors.pendingConfirmation : AppTheme.primary,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Text(
                                              'Căn hộ ${invoice.apartment?.code ?? 'N/A'}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: isPendingConfirmation ? AppStatusColors.pendingConfirmation : null,
                                              ),
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
                                            color: _getStatusColor(invoice.status).withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(4),
                                            border: isPendingConfirmation
                                                ? Border.all(color: AppStatusColors.pendingConfirmation.withValues(alpha: 0.4))
                                                : null,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (isPendingConfirmation) ...[
                                                const Icon(Icons.rate_review_outlined, size: 12, color: AppStatusColors.pendingConfirmation),
                                                const SizedBox(width: 4),
                                              ],
                                              Text(
                                                _getStatusText(invoice.status),
                                                style: TextStyle(
                                                  color: _getStatusColor(invoice.status),
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
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
                                    Expanded(
                                      child: Text(
                                        'Số tiền: ${_currencyFormat.format(invoice.totalAmount)}', 
                                        style: const TextStyle(
                                          color: AppTheme.error, 
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      isPendingConfirmation ? 'Đối soát & Duyệt →' : 'Xem chi tiết >',
                                      style: TextStyle(
                                        color: isPendingConfirmation ? AppStatusColors.pendingConfirmation : AppTheme.primary,
                                        fontWeight: isPendingConfirmation ? FontWeight.bold : FontWeight.normal,
                                        fontSize: 12,
                                      ),
                                    ),
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

  Widget _buildFilterChip(String filterKey, String label, Color? highlightColor, {bool hasBadge = false}) {
    final isSelected = _statusFilter == filterKey;
    final color = highlightColor ?? AppTheme.primary;

    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (hasBadge && !isSelected) ...[
            const SizedBox(width: 4),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: highlightColor ?? AppTheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
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
          color: isSelected ? color : (hasBadge ? color : Colors.grey.shade300),
          width: hasBadge ? 1.5 : 1.0,
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
