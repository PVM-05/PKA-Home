import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/permissions.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_search_field.dart';
import '../../../core/widgets/app_snack_bar.dart';
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
  String _statusFilter =
      'all'; // 'all', 'pending_confirmation', 'unpaid', 'paid'
  bool _isExporting = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _exportExcel(List<InvoiceModel> invoices) async {
    setState(() => _isExporting = true);
    final activeBuilding = ref.read(activeBuildingProvider).value;
    final buildingName = activeBuilding?.name ?? 'Tòa nhà Vivona';
    final period = invoices.isNotEmpty ? invoices.first.period : 'Tất cả';

    final service = AccountingExportService();
    final path = await service.exportAndShare(
      invoices: invoices,
      buildingName: buildingName,
      period: period,
    );
    if (!mounted) return;
    setState(() => _isExporting = false);

    if (path != null) {
      AppSnackBar.showSuccess(
        context,
        'Đã xuất báo cáo đối soát Excel thành công!',
      );
    } else {
      AppSnackBar.showError(context, 'Lỗi khi xuất file Excel.');
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
    final colorScheme = Theme.of(context).colorScheme;

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
                    showDialog<void>(
                      context: context,
                      builder: (_) => const BulkInvoiceDialog(),
                    );
                  } else if (value == 'export') {
                    final invoices = invoicesAsync.valueOrNull;
                    if (invoices != null && invoices.isNotEmpty) {
                      _exportExcel(_filterInvoices(invoices));
                    } else {
                      AppSnackBar.showWarning(
                        context,
                        'Không có dữ liệu để xuất Excel.',
                      );
                    }
                  }
                },
                itemBuilder: (ctx) {
                  final menuScheme = Theme.of(ctx).colorScheme;
                  return [
                    PopupMenuItem(
                      value: 'bulk',
                      child: Row(
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            size: 20,
                            color: menuScheme.primary,
                          ),
                          AppSpacing.w10,
                          const Text('Tạo HĐ hàng loạt'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'export',
                      child: Row(
                        children: [
                          Icon(
                            Icons.download,
                            size: 20,
                            color: menuScheme.primary,
                          ),
                          AppSpacing.w10,
                          const Text('Xuất báo cáo Excel'),
                        ],
                      ),
                    ),
                  ];
                },
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
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(0, 48),
                          ),
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
                          padding: AppSpacing.p16,
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
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          icon: const Icon(Icons.add),
          label: const Text(
            'Lập hóa đơn',
            style: TextStyle(fontWeight: FontWeight.bold),
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
    final searchField = AppSearchField(
      controller: _searchController,
      hintText: 'Tìm theo căn hộ (VD: A0110, B0502)...',
      onChanged: (val) {
        setState(() => _searchQuery = val.trim());
      },
      onClear: () {
        setState(() => _searchQuery = '');
      },
    );

    final filterRow = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildFilterChip('all', 'Tất cả ($allCount)', null),
          AppSpacing.w8,
          _buildFilterChip(
            'pending_confirmation',
            'Chờ xác nhận ($pendingConfirmationCount)',
            AppStatusColors.getPendingConfirmation(context),
            hasBadge: pendingConfirmationCount > 0,
          ),
          AppSpacing.w8,
          _buildFilterChip(
            'unpaid',
            'Đang nợ ($unpaidCount)',
            AppStatusColors.getUnpaid(context),
          ),
          AppSpacing.w8,
          _buildFilterChip(
            'paid',
            'Đã thanh toán ($paidCount)',
            AppStatusColors.getPaid(context),
          ),
        ],
      ),
    );

    if (isDesktop) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Row(
          children: [
            Expanded(flex: 4, child: searchField),
            AppSpacing.w16,
            Expanded(flex: 6, child: filterRow),
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
        AppSpacing.h6,
      ],
    );
  }

  Widget _buildEmptyFilterView() {
    final colorScheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      color: colorScheme.primary,
      onRefresh: () async {
        HapticFeedback.lightImpact();
        ref.invalidate(invoicesProvider);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppSpacing.p24,
        children: const [
          SizedBox(height: 48),
          AppEmptyState(
            icon: Icons.search_off_outlined,
            title: 'Không tìm thấy hóa đơn nào',
            description:
                'Không có hóa đơn nào phù hợp với bộ lọc hoặc từ khóa tìm kiếm hiện tại.',
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopWorkstation(List<InvoiceModel> filtered) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final errorColor = AppTheme.getSemanticError(context);
    final pendingConfirmColor = AppStatusColors.getPendingConfirmation(context);
    final isDark = theme.brightness == Brightness.dark;

    return RefreshIndicator(
      color: colorScheme.primary,
      onRefresh: () async {
        HapticFeedback.lightImpact();
        ref.invalidate(invoicesProvider);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
        children: [
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: AppRadius.r16,
              border: Border.all(color: colorScheme.outlineVariant),
              boxShadow: isDark ? null : AppShadows.softSm,
            ),
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 900),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                  ),
                  headingRowHeight: 48,
                  dataRowMinHeight: 56,
                  dataRowMaxHeight: 68,
                  horizontalMargin: 20,
                  columnSpacing: 24,
                  columns: [
                    DataColumn(
                      label: Text(
                        'CĂN HỘ',
                        style: context.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'KỲ PHÍ',
                        style: context.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'TỔNG TIỀN',
                        style: context.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'HẠN THANH TOÁN',
                        style: context.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'TRẠNG THÁI',
                        style: context.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'THAO TÁC',
                        style: context.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  rows: filtered.map((invoice) {
                    final isPending = invoice.status == 'pending_confirmation';
                    final isOverdueUnpaid =
                        invoice.dueDate.isBefore(DateTime.now()) &&
                        invoice.status == 'unpaid';
                    final statusColor = _getStatusColor(
                      context,
                      invoice.status,
                    );
                    final statusText = _getStatusText(invoice.status);

                    return DataRow(
                      onSelectChanged: (_) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                ManagementInvoiceDetailScreen(invoice: invoice),
                          ),
                        );
                      },
                      cells: [
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: AppSpacing.p8,
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: AppRadius.r8,
                                ),
                                child: Icon(
                                  Icons.domain,
                                  color: colorScheme.primary,
                                  size: 18,
                                ),
                              ),
                              AppSpacing.w10,
                              Text(
                                invoice.apartment?.code ?? 'N/A',
                                style: context.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.bold)
                                    .tabularFigures(),
                              ),
                            ],
                          ),
                        ),
                        DataCell(
                          Text(
                            invoice.period,
                            style: context.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600)
                                .tabularFigures(),
                          ),
                        ),
                        DataCell(
                          Text(
                            _currencyFormat.format(invoice.totalAmount),
                            style: context.bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                )
                                .tabularFigures(),
                          ),
                        ),
                        DataCell(
                          Text(
                            _dateFormat.format(invoice.dueDate),
                            style: context.bodyMedium
                                ?.copyWith(
                                  color: isOverdueUnpaid
                                      ? errorColor
                                      : colorScheme.onSurfaceVariant,
                                  fontWeight: isOverdueUnpaid
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                )
                                .tabularFigures(),
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
                              borderRadius: AppRadius.r16,
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
                                AppSpacing.w6,
                                Text(
                                  statusText,
                                  style: context.labelSmall?.copyWith(
                                    color: statusColor,
                                    fontWeight: FontWeight.bold,
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
                                      ? pendingConfirmColor
                                      : colorScheme.primary,
                                ),
                                tooltip: isPending
                                    ? 'Đối soát & Phê duyệt'
                                    : 'Xem chi tiết',
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          ManagementInvoiceDetailScreen(
                                            invoice: invoice,
                                          ),
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.edit_outlined,
                                  size: 20,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                tooltip: 'Chỉnh sửa',
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          EditInvoiceScreen(invoice: invoice),
                                    ),
                                  );
                                },
                              ),
                              if (!invoice.isPaid)
                                IconButton(
                                  icon: Icon(
                                    Icons.delete_outline,
                                    size: 20,
                                    color: errorColor,
                                  ),
                                  tooltip: 'Xóa hóa đơn',
                                  onPressed: () =>
                                      _confirmDeleteInvoice(invoice),
                                ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileCardList(List<InvoiceModel> filtered) {
    final colorScheme = Theme.of(context).colorScheme;
    final errorColor = AppTheme.getSemanticError(context);
    final pendingConfirmColor = AppStatusColors.getPendingConfirmation(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      color: colorScheme.primary,
      onRefresh: () async {
        HapticFeedback.lightImpact();
        ref.invalidate(invoicesProvider);
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final invoice = filtered[index];
          final isNew =
              DateTime.now().difference(invoice.createdAt).inMinutes < 15;
          final isPending = invoice.status == 'pending_confirmation';
          final statusColor = _getStatusColor(context, invoice.status);
          final statusText = _getStatusText(invoice.status);

          return AppCard(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            child: InkWell(
              borderRadius: AppRadius.r12,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        ManagementInvoiceDetailScreen(invoice: invoice),
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
                                  ? pendingConfirmColor
                                  : colorScheme.primary,
                              size: 20,
                            ),
                            AppSpacing.w8,
                            Flexible(
                              child: Text(
                                'Căn hộ ${invoice.apartment?.code ?? 'N/A'}',
                                style: context.titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: isPending
                                          ? pendingConfirmColor
                                          : colorScheme.onSurface,
                                    )
                                    .tabularFigures(),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isNew) ...[
                              AppSpacing.w6,
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppStatusColors.getPaid(context),
                                  borderRadius: AppRadius.r4,
                                ),
                                child: Text(
                                  'MỚI',
                                  style: context.labelSmall?.copyWith(
                                    color: colorScheme.onPrimary,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Tùy chọn hóa đơn',
                        icon: Icon(
                          Icons.more_vert,
                          size: 20,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        onSelected: (value) {
                          if (value == 'edit') {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    EditInvoiceScreen(invoice: invoice),
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
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete,
                                    color: errorColor,
                                    size: 18,
                                  ),
                                  AppSpacing.w8,
                                  Text(
                                    'Xóa',
                                    style: TextStyle(color: errorColor),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  AppSpacing.h8,

                  // Hàng trạng thái & kỳ phí
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(
                              alpha: isDark ? 0.2 : 0.1,
                            ),
                            borderRadius: AppRadius.r6,
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            statusText,
                            style: context.labelSmall?.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ),
                      AppSpacing.w8,
                      Flexible(
                        child: Text(
                          'Kỳ: ${invoice.period}',
                          style: context.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w600)
                              .tabularFigures(),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.h12,

                  // Hàng số tiền & nút hành động
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Số tiền: ${_currencyFormat.format(invoice.totalAmount)}',
                            style: context.titleSmall
                                ?.copyWith(
                                  color: statusColor,
                                  fontWeight: FontWeight.bold,
                                )
                                .tabularFigures(),
                          ),
                        ),
                      ),
                      AppSpacing.w8,
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            isPending ? 'Duyệt →' : 'Xem >',
                            style: context.labelSmall?.copyWith(
                              color: isPending
                                  ? pendingConfirmColor
                                  : colorScheme.primary,
                              fontWeight: FontWeight.bold,
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
    final colorScheme = Theme.of(context).colorScheme;
    final color = highlightColor ?? colorScheme.primary;

    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(label, overflow: TextOverflow.ellipsis, maxLines: 1),
          ),
          if (hasBadge && !isSelected) ...[
            AppSpacing.w4,
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ],
        ],
      ),
      labelStyle: context.labelSmall
          ?.copyWith(
            color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          )
          .tabularFigures(),
      backgroundColor: colorScheme.surfaceContainerLow,
      selectedColor: color,
      checkmarkColor: colorScheme.onPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.r20,
        side: BorderSide(
          color: (isSelected || hasBadge) ? color : colorScheme.outlineVariant,
          width: hasBadge ? 1.5 : 1.0,
        ),
      ),
      onSelected: (_) {
        setState(() => _statusFilter = filterKey);
      },
    );
  }

  Color _getStatusColor(BuildContext context, String status) {
    switch (status) {
      case 'paid':
        return AppStatusColors.getPaid(context);
      case 'pending_confirmation':
        return AppStatusColors.getPendingConfirmation(context);
      case 'unpaid':
      default:
        return AppStatusColors.getUnpaid(context);
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
      AppSnackBar.showWarning(
        context,
        'Hóa đơn đã thanh toán là bất biến và đã hạch toán kế toán. Không được phép xóa. Để điều chỉnh số tiền hoặc hoàn tiền, vui lòng lập Phiếu giảm trừ công nợ.',
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: AppRadius.r16),
          title: const Text('Xác nhận xóa hóa đơn'),
          content: SingleChildScrollView(
            child: Text(
              'Bạn có chắc chắn muốn xóa hóa đơn kỳ ${invoice.period} của căn hộ ${invoice.apartment?.code ?? ''}?\n\nToàn bộ các khoản phí liên quan sẽ bị xóa và không thể khôi phục.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
                minimumSize: const Size(0, 48),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Xóa'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(managementRepositoryProvider).deleteInvoice(invoice.id);
        ref.invalidate(invoicesProvider);
        if (mounted) {
          AppSnackBar.showSuccess(context, 'Đã xóa hóa đơn thành công!');
        }
      } catch (e) {
        if (mounted) {
          AppSnackBar.showError(context, formatErrorMessage(e));
        }
      }
    }
  }
}
