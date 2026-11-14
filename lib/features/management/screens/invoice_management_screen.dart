import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/permissions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/role_guard.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../../../data/models/invoice_model.dart';
import '../../../data/providers/building_provider.dart';
import '../../../data/providers/management_provider.dart';
import '../../../data/services/accounting_export_service.dart';
import '../widgets/bulk_invoice_dialog.dart';
import 'create_invoice_screen.dart';
import 'edit_invoice_screen.dart';
import 'management_invoice_detail_screen.dart';

class InvoiceManagementScreen extends ConsumerStatefulWidget {
  const InvoiceManagementScreen({super.key});

  @override
  ConsumerState<InvoiceManagementScreen> createState() =>
      _InvoiceManagementScreenState();
}

class _InvoiceManagementScreenState
    extends ConsumerState<InvoiceManagementScreen> {
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: 'đ',
  );
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
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
    final activeBuilding = ref.read(activeBuildingProvider).value;
    final buildingName = activeBuilding?.name ?? 'Tòa nhà PKA';
    final period = invoices.isNotEmpty ? invoices.first.period : 'Tất cả';

    final service = AccountingExportService();
    final path = await service.exportAndShare(
      invoices: invoices,
      buildingName: buildingName,
      period: period,
    );
    setState(() => _isExporting = false);

    if (mounted) {
      if (path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xuất báo cáo đối soát Excel thành công!'),
            backgroundColor: AppTheme.success,
            duration: Duration(seconds: 4),
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
      if (_statusFilter == 'pending_confirmation' &&
          inv.status != 'pending_confirmation') {
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
    final pendingConfirmationCount = allInvoices
        .where((i) => i.status == 'pending_confirmation')
        .length;
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
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
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
                        const SnackBar(
                          content: Text('Không có dữ liệu để xuất Excel.'),
                        ),
                      );
                    }
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'bulk',
                    child: Row(
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 20,
                          color: AppTheme.primary,
                        ),
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
                        Text('Xuất báo cáo Excel'),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1400),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 900;

                return Column(
                  children: [
                    // Toolbar tìm kiếm và bộ lọc
                    _buildToolbar(
                      isDesktop: isDesktop,
                      allCount: allCount,
                      pendingConfirmationCount: pendingConfirmationCount,
                      unpaidCount: unpaidCount,
                      paidCount: paidCount,
                    ),

                    Expanded(
                      child: AppStateView<List<InvoiceModel>>(
                        asyncValue: invoicesAsync,
                        emptyMessage: 'Chưa có hóa đơn nào được tạo.',
                        emptyIcon: Icons.receipt_long_outlined,
                        actionButton: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const CreateInvoiceScreen(),
                              ),
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
                            return _buildEmptyFilterView();
                          }

                          if (isDesktop) {
                            return _buildDesktopWorkstation(filtered);
                          } else {
                            return _buildMobileCardList(filtered);
                          }
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'invoice_management_fab',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CreateInvoiceScreen()),
            );
          },
          backgroundColor: AppTheme.primary,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text(
            'Lập hóa đơn',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildToolbar({
    required bool isDesktop,
    required int allCount,
    required int pendingConfirmationCount,
    required int unpaidCount,
    required int paidCount,
  }) {
    final searchField = TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Tìm theo căn hộ (VD: A0110, B0502)...',
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
      ),
      onChanged: (val) {
        setState(() => _searchQuery = val.trim());
      },
    );

    final filterRow = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
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
          _buildFilterChip(
            'unpaid',
            'Đang nợ ($unpaidCount)',
            AppStatusColors.unpaid,
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            'paid',
            'Đã thanh toán ($paidCount)',
            AppStatusColors.paid,
          ),
        ],
      ),
    );

    if (isDesktop) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: searchField,
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 6,
              child: filterRow,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: searchField,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: filterRow,
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _buildEmptyFilterView() {
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
                    child: const Icon(
                      Icons.receipt_long_outlined,
                      size: 48,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Không có hóa đơn nào phù hợp với bộ lọc.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopWorkstation(List<InvoiceModel> filtered) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.07);

    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: () async {
        HapticFeedback.lightImpact();
        ref.invalidate(invoicesProvider);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
        children: [
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? (Theme.of(context).cardTheme.color ??
                      Theme.of(context).colorScheme.surface)
                  : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
              boxShadow: isDark ? null : AppShadows.softSm,
            ),
            clipBehavior: Clip.antiAlias,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                isDark
                    ? Colors.white.withValues(alpha: 0.03)
                    : Colors.black.withValues(alpha: 0.02),
              ),
              headingRowHeight: 48,
              dataRowMinHeight: 56,
              dataRowMaxHeight: 64,
              horizontalMargin: 20,
              columnSpacing: 24,
              columns: const [
                DataColumn(
                  label: Text(
                    'CĂN HỘ',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'KỲ PHÍ',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'TỔNG TIỀN',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'HẠN THANH TOÁN',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'TRẠNG THÁI',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'THAO TÁC',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
              rows: filtered.map((invoice) {
                final isPending = invoice.status == 'pending_confirmation';
                final statusColor = _getStatusColor(invoice.status);
                final statusText = _getStatusText(invoice.status);

                return DataRow(
                  onSelectChanged: (_) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ManagementInvoiceDetailScreen(
                          invoice: invoice,
                        ),
                      ),
                    );
                  },
                  cells: [
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.domain,
                              color: AppTheme.primary,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            invoice.apartment?.code ?? 'N/A',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    DataCell(
                      Text(
                        invoice.period,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    DataCell(
                      Text(
                        _currencyFormat.format(invoice.totalAmount),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        _dateFormat.format(invoice.dueDate),
                        style: TextStyle(
                          color: invoice.dueDate.isBefore(DateTime.now()) &&
                                  invoice.status == 'unpaid'
                              ? AppTheme.error
                              : AppTheme.textSecondary,
                          fontWeight:
                              invoice.dueDate.isBefore(DateTime.now()) &&
                                      invoice.status == 'unpaid'
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              statusText,
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              isPending
                                  ? Icons.fact_check_outlined
                                  : Icons.visibility_outlined,
                              size: 20,
                              color: isPending
                                  ? AppStatusColors.pendingConfirmation
                                  : AppTheme.primary,
                            ),
                            tooltip: isPending
                                ? 'Đối soát & Phê duyệt'
                                : 'Xem chi tiết',
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ManagementInvoiceDetailScreen(
                                    invoice: invoice,
                                  ),
                                ),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.edit_outlined,
                              size: 20,
                              color: AppTheme.textSecondary,
                            ),
                            tooltip: 'Chỉnh sửa',
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => EditInvoiceScreen(
                                    invoice: invoice,
                                  ),
                                ),
                              );
                            },
                          ),
                          if (!invoice.isPaid)
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 20,
                                color: AppTheme.error,
                              ),
                              tooltip: 'Xóa hóa đơn',
                              onPressed: () => _confirmDeleteInvoice(invoice),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileCardList(List<InvoiceModel> filtered) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: () async {
        HapticFeedback.lightImpact();
        ref.invalidate(invoicesProvider);
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final invoice = filtered[index];
          final isNew =
              DateTime.now().difference(invoice.createdAt).inMinutes < 15;
          final isPending = invoice.status == 'pending_confirmation';
          final statusColor = _getStatusColor(invoice.status);
          final statusText = _getStatusText(invoice.status);

          return AppCard(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            child: InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ManagementInvoiceDetailScreen(
                      invoice: invoice,
                    ),
                  ),
                );
              },
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
                              color: isPending
                                  ? AppStatusColors.pendingConfirmation
                                  : AppTheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Căn hộ ${invoice.apartment?.code ?? 'N/A'}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: isPending
                                      ? AppStatusColors.pendingConfirmation
                                      : null,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isNew) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppStatusColors.paid,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'MỚI',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(
                          Icons.more_vert,
                          size: 20,
                          color: AppTheme.textSecondary,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onSelected: (value) {
                          if (value == 'edit') {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => EditInvoiceScreen(
                                  invoice: invoice,
                                ),
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
                          if (!invoice.isPaid)
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete,
                                    color: AppTheme.error,
                                    size: 18,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Xóa',
                                    style: TextStyle(
                                      color: AppTheme.error,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Hàng trạng thái & kỳ phí
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(
                              alpha: isDark ? 0.2 : 0.1,
                            ),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Kỳ: ${invoice.period}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Hàng số tiền & nút hành động (Bọc chống tràn tuyệt đối)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Số tiền: ${_currencyFormat.format(invoice.totalAmount)}',
                            style: const TextStyle(
                              color: AppTheme.error,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            isPending ? 'Duyệt →' : 'Xem >',
                            style: TextStyle(
                              color: isPending
                                  ? AppStatusColors.pendingConfirmation
                                  : AppTheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
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
    );
  }

  Widget _buildFilterChip(
    String filterKey,
    String label,
    Color? highlightColor, {
    bool hasBadge = false,
  }) {
    final isSelected = _statusFilter == filterKey;
    final color = highlightColor ?? AppTheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          if (hasBadge && !isSelected) ...[
            const SizedBox(width: 4),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppTheme.textPrimary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      backgroundColor: isDark
          ? (Theme.of(context).cardTheme.color ??
              Theme.of(context).colorScheme.surface)
          : Colors.white,
      selectedColor: color,
      checkmarkColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected
              ? color
              : (hasBadge
                  ? color
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.1))),
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
      case 'paid':
        return AppStatusColors.paid;
      case 'pending_confirmation':
        return AppStatusColors.pendingConfirmation;
      case 'unpaid':
      default:
        return AppStatusColors.unpaid;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'paid':
        return 'Đã thanh toán';
      case 'pending_confirmation':
        return 'Chờ xác nhận';
      case 'unpaid':
      default:
        return 'Đang nợ';
    }
  }

  Future<void> _confirmDeleteInvoice(InvoiceModel invoice) async {
    if (invoice.isPaid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Hóa đơn đã thanh toán là bất biến và đã hạch toán kế toán. Không được phép xóa. Để điều chỉnh số tiền hoặc hoàn tiền, vui lòng lập Phiếu giảm trừ (Credit Note).',
          ),
          backgroundColor: AppTheme.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

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
