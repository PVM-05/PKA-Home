import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/providers/accounting_workstation_provider.dart';

class AccountingWebWorkstationScreen extends ConsumerStatefulWidget {
  const AccountingWebWorkstationScreen({super.key});

  @override
  ConsumerState<AccountingWebWorkstationScreen> createState() =>
      _AccountingWebWorkstationScreenState();
}

class _AccountingWebWorkstationScreenState
    extends ConsumerState<AccountingWebWorkstationScreen> {
  final TextEditingController _searchController = TextEditingController();
  int _rowsPerPage = 10;
  int _sortColumnIndex = 0;
  bool _sortAscending = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rowsAsync = ref.watch(accountingWorkstationRowsProvider);
    final summary = ref.watch(accountingWorkstationSummaryProvider);
    final filter = ref.watch(accountingWorkstationFilterProvider);
    final selectedIds = ref.watch(selectedInvoiceIdsProvider);
    final periods = ref.watch(accountingWorkstationAvailablePeriodsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header & Actions Bar
            _buildHeader(context, rowsAsync.value ?? []),

            const SizedBox(height: 20),

            // 2. Top KPI Strip
            _buildKpiStrip(summary),

            const SizedBox(height: 24),

            // 3. Filter Bar
            _buildFilterBar(filter, periods),

            const SizedBox(height: 16),

            // 4. Bulk Action Bar (hien khi co it nhat 1 row duoc chon)
            if (selectedIds.isNotEmpty) ...[
              _buildBulkActionBar(selectedIds.length),
              const SizedBox(height: 16),
            ],

            // 5. Main Table Card
            _buildMainTableCard(rowsAsync, selectedIds),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, List<InvoiceTableRowItem> rows) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 600;
        final titleContent = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.table_chart_rounded, color: AppTheme.primary, size: 28),
                const SizedBox(width: 10),
                const Text(
                  'Bàn Làm Việc Kế Toán & Đối Soát',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Quản lý công nợ, đối soát ngân hàng và phát hành hóa đơn tập trung',
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
          ],
        );

        final actionButtons = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton.icon(
              onPressed: () {
                ref.invalidate(accountingWorkstationRawInvoicesProvider);
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Làm mới'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: () {
                final csvData = exportWorkstationToCsv(rows);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Đã xuất dữ liệu ${rows.length} dòng thành công sang file bảng tính.',
                    ),
                    backgroundColor: AppTheme.primary,
                  ),
                );
              },
              icon: const Icon(Icons.file_download_outlined, size: 18),
              label: const Text('Xuất Excel'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ],
        );

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleContent,
              const SizedBox(height: 12),
              actionButtons,
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: titleContent),
            actionButtons,
          ],
        );
      },
    );
  }

  Widget _buildKpiStrip(AccountingWorkstationSummary summary) {
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
          _buildKpiCard(
            title: 'Tổng Phát Hành',
            value: summary.formattedTotalAmount,
            subtitle: '${summary.totalInvoices} hóa đơn kỳ này',
            icon: Icons.receipt_long_rounded,
            iconColor: AppTheme.primary,
            bgColor: AppTheme.primary.withValues(alpha: 0.08),
          ),
          _buildKpiCard(
            title: 'Thực Thu',
            value: summary.formattedPaidAmount,
            subtitle: 'Tỷ lệ thu hồi: ${summary.collectionRate}%',
            icon: Icons.check_circle_outline_rounded,
            iconColor: Colors.teal,
            bgColor: Colors.teal.withValues(alpha: 0.08),
          ),
          _buildKpiCard(
            title: 'Chờ Thu Trong Hạn',
            value: summary.formattedUnpaidAmount,
            subtitle: 'Chờ đối soát / chuyển khoản',
            icon: Icons.pending_actions_rounded,
            iconColor: Colors.orange,
            bgColor: Colors.orange.withValues(alpha: 0.08),
          ),
          _buildKpiCard(
            title: 'Nợ Quá Hạn',
            value: summary.formattedOverdueAmount,
            subtitle: 'Cần gửi thông báo đôn đốc',
            icon: Icons.warning_amber_rounded,
            iconColor: Colors.redAccent,
            bgColor: Colors.redAccent.withValues(alpha: 0.08),
          ),
        ];

        if (crossAxisCount == 1) {
          return Column(
            children: cards
                .map((card) => Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: card,
                    ))
                .toList(),
          );
        }

        if (crossAxisCount == 2) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 12),
                  Expanded(child: cards[1]),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: cards[2]),
                  const SizedBox(width: 12),
                  Expanded(child: cards[3]),
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 12),
            Expanded(child: cards[1]),
            const SizedBox(width: 12),
            Expanded(child: cards[2]),
            const SizedBox(width: 12),
            Expanded(child: cards[3]),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(AccountingWorkstationFilter filter, List<String> periods) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
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
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        ref
                            .read(accountingWorkstationFilterProvider.notifier)
                            .state = filter.copyWith(searchQuery: '');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              isDense: true,
            ),
            onChanged: (val) {
              ref
                  .read(accountingWorkstationFilterProvider.notifier)
                  .state = filter.copyWith(searchQuery: val);
            },
          );

          final periodDropdown = DropdownButtonFormField<String?>(
            value: filter.period,
            decoration: InputDecoration(
              labelText: 'Kỳ thu',
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              isDense: true,
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Tất cả kỳ'),
              ),
              ...periods.map((p) => DropdownMenuItem<String?>(
                    value: p,
                    child: Text('Kỳ $p'),
                  )),
            ],
            onChanged: (val) {
              ref
                  .read(accountingWorkstationFilterProvider.notifier)
                  .state = filter.copyWith(period: val);
            },
          );

          final statusDropdown = DropdownButtonFormField<String?>(
            value: filter.status,
            decoration: InputDecoration(
              labelText: 'Trạng thái',
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.border),
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
              ref
                  .read(accountingWorkstationFilterProvider.notifier)
                  .state = filter.copyWith(status: val);
            },
          );

          if (isCompact) {
            return Column(
              children: [
                searchField,
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: periodDropdown),
                    const SizedBox(width: 12),
                    Expanded(child: statusDropdown),
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(flex: 3, child: searchField),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: periodDropdown),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: statusDropdown),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBulkActionBar(int selectedCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_box_outlined, color: AppTheme.primary, size: 20),
          const SizedBox(width: 10),
          Text(
            'Đã chọn $selectedCount hóa đơn',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Đã gửi thông báo nhắc nợ tới $selectedCount căn hộ được chọn.'),
                  backgroundColor: AppTheme.primary,
                ),
              );
            },
            icon: const Icon(Icons.notifications_active_outlined, size: 18),
            label: const Text('Gửi Nhắc Nợ'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton(
            onPressed: () {
              ref.read(selectedInvoiceIdsProvider.notifier).clear();
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            child: const Text('Bỏ chọn'),
          ),
        ],
      ),
    );
  }

  Widget _buildMainTableCard(
    AsyncValue<List<InvoiceTableRowItem>> rowsAsync,
    Set<String> selectedIds,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: rowsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(48.0),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (err, _) => Padding(
          padding: const EdgeInsets.all(32.0),
          child: Center(
            child: Text(
              'Lỗi tải danh sách: $err',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
        data: (rows) {
          if (rows.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(48.0),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.inbox_outlined, size: 48, color: AppTheme.textSecondary),
                    SizedBox(height: 12),
                    Text(
                      'Không tìm thấy hóa đơn phù hợp với bộ lọc.',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            );
          }

          final allSelected = rows.isNotEmpty && rows.every((r) => selectedIds.contains(r.id));

          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 900),
                child: DataTable(
                  sortColumnIndex: _sortColumnIndex,
                  sortAscending: _sortAscending,
                  headingRowColor: WidgetStateProperty.all(AppTheme.background),
                  showCheckboxColumn: true,
                  onSelectAll: (val) {
                    if (val == true) {
                      ref
                          .read(selectedInvoiceIdsProvider.notifier)
                          .selectAll(rows.map((e) => e.id));
                    } else {
                      ref.read(selectedInvoiceIdsProvider.notifier).clear();
                    }
                  },
                  columns: const [
                    DataColumn(label: Text('Căn Hộ', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Cư Dân', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Kỳ Thu', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Tổng Tiền', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Trạng Thái', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Mã VietQR', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Hạn Nộp', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Ngày Nộp / Thu', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: rows.map((row) {
                    final isRowSelected = selectedIds.contains(row.id);

                    return DataRow(
                      selected: isRowSelected,
                      onSelectChanged: (val) {
                        ref.read(selectedInvoiceIdsProvider.notifier).toggle(row.id);
                      },
                      cells: [
                        DataCell(
                          Text(
                            row.apartmentCode,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary),
                          ),
                        ),
                        DataCell(Text(row.residentName)),
                        DataCell(Text(row.period)),
                        DataCell(
                          Text(
                            row.formattedAmount,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        DataCell(_buildStatusChip(row.status, row.displayStatus)),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.background,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              row.vietQrCode,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        DataCell(Text(row.formattedDueDate)),
                        DataCell(Text(row.formattedPaidAt)),
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

  Widget _buildStatusChip(String status, String displayStatus) {
    Color bg;
    Color fg;

    switch (status.toLowerCase()) {
      case 'paid':
        bg = Colors.teal.withValues(alpha: 0.12);
        fg = Colors.teal.shade800;
        break;
      case 'overdue':
        bg = Colors.red.withValues(alpha: 0.12);
        fg = Colors.red.shade800;
        break;
      case 'cancelled':
        bg = Colors.grey.withValues(alpha: 0.15);
        fg = Colors.grey.shade800;
        break;
      case 'unpaid':
      default:
        bg = Colors.orange.withValues(alpha: 0.12);
        fg = Colors.orange.shade800;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        displayStatus,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
