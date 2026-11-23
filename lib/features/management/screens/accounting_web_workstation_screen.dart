import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/permissions.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/action_runner.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_card.dart';
import '../../../core/widgets/app_skeleton_shimmer.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/role_guard.dart';
import '../../../data/providers/accounting_workstation_provider.dart';
import '../../../data/providers/building_provider.dart';
import '../../../data/providers/management_provider.dart';
import '../../../data/providers/payment_provider.dart';
import '../widgets/accounting/accounting_sepay_reconciliation_view.dart';

class AccountingWebWorkstationScreen extends ConsumerStatefulWidget {
  const AccountingWebWorkstationScreen({super.key});

  @override
  ConsumerState<AccountingWebWorkstationScreen> createState() =>
      _AccountingWebWorkstationScreenState();
}

class _AccountingWebWorkstationScreenState
    extends ConsumerState<AccountingWebWorkstationScreen> {
  final TextEditingController _searchController = TextEditingController();
  int? _sortColumnIndex;
  bool _sortAscending = true;
  int _currentTab = 0; // 0: Sổ công nợ, 1: Đối soát SePay

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
    });
  }

  List<InvoiceTableRowItem> _getSortedRows(List<InvoiceTableRowItem> rows) {
    if (_sortColumnIndex == null) return rows;
    final sorted = List<InvoiceTableRowItem>.from(rows);
    sorted.sort((a, b) {
      int cmp = 0;
      switch (_sortColumnIndex) {
        case 0:
          cmp = a.apartmentCode.compareTo(b.apartmentCode);
          break;
        case 1:
          cmp = a.residentName.compareTo(b.residentName);
          break;
        case 2:
          cmp = a.period.compareTo(b.period);
          break;
        case 3:
          cmp = a.totalAmount.compareTo(b.totalAmount);
          break;
        case 4:
          cmp = a.status.compareTo(b.status);
          break;
        case 6:
          final aDue = a.dueDate ?? DateTime(0);
          final bDue = b.dueDate ?? DateTime(0);
          cmp = aDue.compareTo(bDue);
          break;
        case 7:
          final aPaid = a.paidAt ?? DateTime(0);
          final bPaid = b.paidAt ?? DateTime(0);
          cmp = aPaid.compareTo(bPaid);
          break;
        default:
          cmp = 0;
      }
      return _sortAscending ? cmp : -cmp;
    });
    return sorted;
  }

  Future<void> _confirmSendReminders(
    BuildContext context,
    Set<String> selectedIds,
    List<InvoiceTableRowItem> rows,
  ) async {
    final targetRows = rows.where((r) => selectedIds.contains(r.id)).toList();
    if (targetRows.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        final warningColor = AppTheme.getSemanticWarning(ctx);

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: AppRadius.r16),
          title: Row(
            children: [
              Icon(Icons.notifications_active_outlined, color: warningColor),
              AppSpacing.w8,
              const Expanded(child: Text('Xác nhận gửi nhắc nợ')),
            ],
          ),
          content: SingleChildScrollView(
            child: Text(
              'Bạn có chắc chắn muốn gửi thông báo nhắc nợ tới ${targetRows.length} căn hộ đã chọn?\n\n'
              'Cư dân các căn hộ này sẽ nhận được thông báo về kỳ thu và số tiền cần thanh toán.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.textWarning,
                foregroundColor: colorScheme.onPrimary,
                minimumSize: const Size(0, 48),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Xác nhận gửi'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    await runAction(
      this.context,
      () async {
        final activeBuilding = ref.read(activeBuildingProvider).value;
        final allInvoices = ref.read(invoicesProvider).value ?? [];
        final invMap = {for (var inv in allInvoices) inv.id: inv};

        int sentCount = 0;
        for (final row in targetRows) {
          final inv = invMap[row.id];
          final aptId = inv?.apartmentId;

          await Supabase.instance.client.from('notifications').insert({
            'apartment_id': ?aptId,
            'building_id': ?activeBuilding?.id,
            'title': 'Nhắc nợ hóa đơn kỳ ${row.period}',
            'body':
                'Hóa đơn căn hộ ${row.apartmentCode} kỳ ${row.period} trị giá ${row.formattedAmount} đến hạn thanh toán. Kính đề nghị Quý cư dân thanh toán sớm.',
            'type': 'invoice_reminder',
            'payload': {
              'invoice_id': row.id,
              'period': row.period,
              'amount': row.totalAmount,
            },
          });
          sentCount++;
        }

        ref.read(selectedInvoiceIdsProvider.notifier).clear();
        return 'Đã gửi thành công $sentCount thông báo nhắc nợ đến cư dân.';
      },
      actionName: 'Gửi thông báo nhắc nợ',
    );
  }

  @override
  Widget build(BuildContext context) {
    final rowsAsync = ref.watch(accountingWorkstationRowsProvider);
    final summary = ref.watch(accountingWorkstationSummaryProvider);
    final filter = ref.watch(accountingWorkstationFilterProvider);
    final selectedIds = ref.watch(selectedInvoiceIdsProvider);
    final periods = ref.watch(accountingWorkstationAvailablePeriodsProvider);
    final isNarrow = MediaQuery.sizeOf(context).width < 600;

    return RoleGuard(
      permission: AppPermissions.accountingWorkstation,
      child: Scaffold(
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(accountingWorkstationRawInvoicesProvider);
            ref.invalidate(paymentTransactionsProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: isNarrow ? AppSpacing.p16 : AppSpacing.p24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Header & Actions Bar
                _buildHeader(context, rowsAsync.value ?? []),
                AppSpacing.h16,

                // 1b. Tab Bar chuyển đổi chế độ xem
                _buildTabBar(),

                if (_currentTab == 0) ...[
                  // 2. Top KPI Strip
                  _buildKpiStrip(summary),
                  AppSpacing.h24,

                  // 3. Filter Bar
                  _buildFilterBar(filter, periods),
                  AppSpacing.h16,

                  // 4. Bulk Action Bar (hiện khi có ít nhất 1 dòng được chọn)
                  if (selectedIds.isNotEmpty) ...[
                    _buildBulkActionBar(selectedIds, rowsAsync.value ?? []),
                    AppSpacing.h16,
                  ],

                  // 5. Main Table Card
                  _buildMainTableCard(rowsAsync, selectedIds),
                ] else ...[
                  // Chế độ Đối Soát SePay & Giao dịch chưa khớp
                  const AccountingSepayReconciliationView(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          ChoiceChip(
            label: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.receipt_long_rounded, size: 16),
                SizedBox(width: 6),
                Text('Sổ Công Nợ Hóa Đơn'),
              ],
            ),
            selected: _currentTab == 0,
            onSelected: (val) {
              if (val) setState(() => _currentTab = 0);
            },
          ),
          ChoiceChip(
            label: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.qr_code_2_rounded, size: 16),
                SizedBox(width: 6),
                Text('Đối Soát SePay & Chưa Khớp'),
              ],
            ),
            selected: _currentTab == 1,
            onSelected: (val) {
              if (val) setState(() => _currentTab = 1);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, List<InvoiceTableRowItem> rows) {
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 800;
        final titleContent = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.table_chart_rounded,
                  color: colorScheme.primary,
                  size: 28,
                ),
                AppSpacing.w10,
                Expanded(
                  child: Text(
                    'Bàn Làm Việc Kế Toán & Đối Soát',
                    style: context.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            AppSpacing.h4,
            Text(
              'Quản lý công nợ, đối soát ngân hàng và phát hành hóa đơn tập trung',
              style: context.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );

        final actionButtons = Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () {
                ref.invalidate(accountingWorkstationRawInvoicesProvider);
                ref.invalidate(paymentTransactionsProvider);
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Làm mới'),
              style: OutlinedButton.styleFrom(
                foregroundColor: colorScheme.onSurface,
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: () {
                exportWorkstationToCsv(rows);
                AppSnackBar.showSuccess(
                  context,
                  'Đã xuất dữ liệu ${rows.length} dòng thành công sang file bảng tính.',
                );
              },
              icon: const Icon(Icons.file_download_outlined, size: 18),
              label: const Text('Xuất Excel'),
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ],
        );

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [titleContent, AppSpacing.h12, actionButtons],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: titleContent),
            AppSpacing.w16,
            actionButtons,
          ],
        );
      },
    );
  }

  Widget _buildKpiStrip(AccountingWorkstationSummary summary) {
    final colorScheme = Theme.of(context).colorScheme;
    final successColor = AppTheme.getSemanticSuccess(context);
    final warningColor = AppTheme.getSemanticWarning(context);
    final errorColor = AppTheme.getSemanticError(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        int crossAxisCount = 4;
        if (width < 600) {
          crossAxisCount = 1;
        } else if (width < 1000) {
          crossAxisCount = 2;
        }

        final cards = [
          AccountingKpiCard(
            title: 'Tổng Phát Hành',
            value: summary.formattedTotalAmount,
            subtitle: '${summary.totalInvoices} hóa đơn kỳ này',
            icon: Icons.receipt_long_rounded,
            iconColor: colorScheme.primary,
            bgColor: colorScheme.primary.withValues(alpha: 0.1),
          ),
          AccountingKpiCard(
            title: 'Thực Thu',
            value: summary.formattedPaidAmount,
            subtitle: 'Tỷ lệ thu hồi: ${summary.collectionRate}%',
            icon: Icons.check_circle_outline_rounded,
            iconColor: successColor,
            bgColor: successColor.withValues(alpha: 0.1),
          ),
          AccountingKpiCard(
            title: 'Chờ Thu Trong Hạn',
            value: summary.formattedUnpaidAmount,
            subtitle: 'Chờ đối soát / chuyển khoản',
            icon: Icons.pending_actions_rounded,
            iconColor: warningColor,
            bgColor: warningColor.withValues(alpha: 0.1),
          ),
          AccountingKpiCard(
            title: 'Nợ Quá Hạn',
            value: summary.formattedOverdueAmount,
            subtitle: 'Cần gửi thông báo đôn đốc',
            icon: Icons.warning_amber_rounded,
            iconColor: errorColor,
            bgColor: errorColor.withValues(alpha: 0.1),
          ),
        ];

        if (crossAxisCount == 1) {
          return Column(
            children: cards
                .map(
                  (card) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: card,
                  ),
                )
                .toList(),
          );
        }

        if (crossAxisCount == 2) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: cards[0]),
                  AppSpacing.w12,
                  Expanded(child: cards[1]),
                ],
              ),
              AppSpacing.h12,
              Row(
                children: [
                  Expanded(child: cards[2]),
                  AppSpacing.w12,
                  Expanded(child: cards[3]),
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: cards[0]),
            AppSpacing.w12,
            Expanded(child: cards[1]),
            AppSpacing.w12,
            Expanded(child: cards[2]),
            AppSpacing.w12,
            Expanded(child: cards[3]),
          ],
        );
      },
    );
  }

  Widget _buildFilterBar(
    AccountingWorkstationFilter filter,
    List<String> periods,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: AppSpacing.p16,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: AppRadius.r12,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 800;

          final searchField = TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Tìm theo mã căn hộ, tên cư dân hoặc mã VietQR...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      tooltip: 'Xóa tìm kiếm',
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        ref
                            .read(accountingWorkstationFilterProvider.notifier)
                            .state = filter.copyWith(
                          searchQuery: '',
                        );
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: AppRadius.r8,
                borderSide: BorderSide(color: colorScheme.outlineVariant),
              ),
              isDense: true,
            ),
            onChanged: (val) {
              ref.read(accountingWorkstationFilterProvider.notifier).state =
                  filter.copyWith(searchQuery: val);
            },
          );

          final periodDropdown = DropdownButtonFormField<String?>(
            isExpanded: true,
            initialValue: filter.period,
            decoration: InputDecoration(
              labelText: 'Kỳ thu',
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: AppRadius.r8,
                borderSide: BorderSide(color: colorScheme.outlineVariant),
              ),
              isDense: true,
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Tất cả kỳ'),
              ),
              ...periods.map(
                (p) =>
                    DropdownMenuItem<String?>(value: p, child: Text('Kỳ $p')),
              ),
            ],
            onChanged: (val) {
              ref.read(accountingWorkstationFilterProvider.notifier).state =
                  filter.copyWith(period: val);
            },
          );

          final statusDropdown = DropdownButtonFormField<String?>(
            isExpanded: true,
            initialValue: filter.status,
            decoration: InputDecoration(
              labelText: 'Trạng thái',
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: AppRadius.r8,
                borderSide: BorderSide(color: colorScheme.outlineVariant),
              ),
              isDense: true,
            ),
            items: const [
              DropdownMenuItem<String?>(
                value: null,
                child: Text('Tất cả trạng thái'),
              ),
              DropdownMenuItem<String?>(
                value: 'paid',
                child: Text('Đã thanh toán'),
              ),
              DropdownMenuItem<String?>(
                value: 'unpaid',
                child: Text('Chờ thanh toán'),
              ),
              DropdownMenuItem<String?>(
                value: 'overdue',
                child: Text('Quá hạn'),
              ),
              DropdownMenuItem<String?>(
                value: 'cancelled',
                child: Text('Đã hủy'),
              ),
            ],
            onChanged: (val) {
              ref.read(accountingWorkstationFilterProvider.notifier).state =
                  filter.copyWith(status: val);
            },
          );

          if (isCompact) {
            return Column(
              children: [
                searchField,
                AppSpacing.h12,
                Row(
                  children: [
                    Expanded(child: periodDropdown),
                    AppSpacing.w12,
                    Expanded(child: statusDropdown),
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(flex: 3, child: searchField),
              AppSpacing.w12,
              Expanded(flex: 2, child: periodDropdown),
              AppSpacing.w12,
              Expanded(flex: 2, child: statusDropdown),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBulkActionBar(
    Set<String> selectedIds,
    List<InvoiceTableRowItem> rows,
  ) {
    final selectedCount = selectedIds.length;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: AppRadius.r12,
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.3)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_box_outlined,
                color: colorScheme.primary,
                size: 20,
              ),
              AppSpacing.w10,
              Text(
                'Đã chọn $selectedCount hóa đơn',
                style: context.bodyMedium
                    ?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    )
                    .tabularFigures(),
              ),
            ],
          ),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () =>
                    _confirmSendReminders(context, selectedIds, rows),
                icon: const Icon(
                  Icons.notifications_active_outlined,
                  size: 18,
                ),
                label: const Text('Gửi Nhắc Nợ'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.textWarning,
                  foregroundColor: colorScheme.onPrimary,
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
              ),
              OutlinedButton(
                onPressed: () {
                  ref.read(selectedInvoiceIdsProvider.notifier).clear();
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
                child: const Text('Bỏ chọn'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainTableCard(
    AsyncValue<List<InvoiceTableRowItem>> rowsAsync,
    Set<String> selectedIds,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: AppRadius.r12,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: rowsAsync.when(
        loading: () => Padding(
          padding: AppSpacing.p16,
          child: AppSkeletonShimmer.cardList(count: 5, itemHeight: 56),
        ),
        error: (err, _) => Padding(
          padding: AppSpacing.p24,
          child: AppErrorCard(
            error: err,
            onRetry: () =>
                ref.invalidate(accountingWorkstationRawInvoicesProvider),
          ),
        ),
        data: (rows) {
          if (rows.isEmpty) {
            return const Padding(
              padding: AppSpacing.p32,
              child: AppEmptyState(
                icon: Icons.inbox_outlined,
                title: 'Không có hóa đơn',
                description: 'Không tìm thấy hóa đơn phù hợp với bộ lọc.',
              ),
            );
          }

          final sortedRows = _getSortedRows(rows);

          return ClipRRect(
            borderRadius: AppRadius.r12,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 900),
                child: DataTable(
                  sortColumnIndex: _sortColumnIndex,
                  sortAscending: _sortAscending,
                  headingRowColor: WidgetStateProperty.all(
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                  ),
                  dataRowMinHeight: 56,
                  dataRowMaxHeight: 68,
                  showCheckboxColumn: true,
                  onSelectAll: (val) {
                    if (val == true) {
                      ref
                          .read(selectedInvoiceIdsProvider.notifier)
                          .selectAll(sortedRows.map((e) => e.id));
                    } else {
                      ref.read(selectedInvoiceIdsProvider.notifier).clear();
                    }
                  },
                  columns: [
                    DataColumn(
                      label: Text(
                        'Căn Hộ',
                        style: context.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onSort: _handleSort,
                    ),
                    DataColumn(
                      label: Text(
                        'Cư Dân',
                        style: context.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onSort: _handleSort,
                    ),
                    DataColumn(
                      label: Text(
                        'Kỳ Thu',
                        style: context.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onSort: _handleSort,
                    ),
                    DataColumn(
                      label: Text(
                        'Tổng Tiền',
                        style: context.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onSort: _handleSort,
                    ),
                    DataColumn(
                      label: Text(
                        'Trạng Thái',
                        style: context.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onSort: _handleSort,
                    ),
                    DataColumn(
                      label: Text(
                        'Mã VietQR',
                        style: context.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Hạn Nộp',
                        style: context.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onSort: _handleSort,
                    ),
                    DataColumn(
                      label: Text(
                        'Ngày Nộp / Thu',
                        style: context.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onSort: _handleSort,
                    ),
                  ],
                  rows: sortedRows.map((row) {
                    final isRowSelected = selectedIds.contains(row.id);

                    return DataRow(
                      selected: isRowSelected,
                      onSelectChanged: (_) {
                        ref
                            .read(selectedInvoiceIdsProvider.notifier)
                            .toggle(row.id);
                      },
                      cells: [
                        DataCell(
                          Text(
                            row.apartmentCode,
                            style: context.bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                )
                                .tabularFigures(),
                          ),
                        ),
                        DataCell(Text(row.residentName)),
                        DataCell(
                          Text(
                            row.period,
                            style: context.bodyMedium?.tabularFigures(),
                          ),
                        ),
                        DataCell(
                          Text(
                            row.formattedAmount,
                            style: context.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600)
                                .tabularFigures(),
                          ),
                        ),
                        DataCell(
                          _buildStatusChip(
                            context,
                            row.status,
                            row.displayStatus,
                          ),
                        ),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.6),
                              borderRadius: AppRadius.r6,
                            ),
                            child: Text(
                              row.vietQrCode,
                              style: context.labelSmall
                                  ?.copyWith(
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w500,
                                  )
                                  .tabularFigures(),
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            row.formattedDueDate,
                            style: context.bodyMedium?.tabularFigures(),
                          ),
                        ),
                        DataCell(
                          Text(
                            row.formattedPaidAt,
                            style: context.bodyMedium?.tabularFigures(),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusChip(
    BuildContext context,
    String status,
    String displayStatus,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final successColor = AppTheme.getSemanticSuccess(context);
    final warningColor = AppTheme.getSemanticWarning(context);
    final errorColor = AppTheme.getSemanticError(context);

    final Color fg;
    switch (status.toLowerCase()) {
      case 'paid':
        fg = successColor;
        break;
      case 'overdue':
        fg = errorColor;
        break;
      case 'cancelled':
        fg = colorScheme.onSurfaceVariant;
        break;
      case 'unpaid':
      default:
        fg = warningColor;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: fg.withValues(alpha: 0.12),
        borderRadius: AppRadius.r12,
      ),
      child: Text(
        displayStatus,
        style: context.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
