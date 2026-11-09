import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/handover_pdf_builder.dart';
import '../../../core/widgets/app_card.dart';
import '../../../data/models/apartment_handover_model.dart';
import '../../../data/providers/handover_provider.dart';
import 'inspection_workstation_screen.dart';

class HandoverManagementScreen extends ConsumerStatefulWidget {
  final String buildingId;

  const HandoverManagementScreen({
    super.key,
    this.buildingId = 'bld-01',
  });

  @override
  ConsumerState<HandoverManagementScreen> createState() =>
      _HandoverManagementScreenState();
}

class _HandoverManagementScreenState
    extends ConsumerState<HandoverManagementScreen> {
  String _selectedType = 'all'; // all, move_in, move_out
  String _selectedStatus =
      'all'; // all, draft, pending_resident, confirmed, disputed

  Color _getStatusColor(String status) {
    switch (status) {
      case 'confirmed':
        return AppStatusColors.paid;
      case 'pending_resident':
        return AppTheme.warning;
      case 'disputed':
        return AppTheme.error;
      case 'draft':
        return AppTheme.textSecondary;
      default:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final handoversAsync =
        ref.watch(buildingHandoversProvider(widget.buildingId));
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý bàn giao & kiểm kê'),
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
            onPressed: () =>
                ref.refresh(buildingHandoversProvider(widget.buildingId)),
          ),
        ],
      ),
      body: handoversAsync.when(
        data: (handovers) {
          final totalCount = handovers.length;
          final pendingCount =
              handovers.where((h) => h.status == 'pending_resident').length;
          final confirmedCount =
              handovers.where((h) => h.status == 'confirmed').length;
          final disputedCount =
              handovers.where((h) => h.status == 'disputed').length;

          final filtered = handovers.where((h) {
            if (_selectedType != 'all' && h.handoverType != _selectedType) {
              return false;
            }
            if (_selectedStatus != 'all' && h.status != _selectedStatus) {
              return false;
            }
            return true;
          }).toList();

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1400),
              child: Column(
                children: [
                  // 1. Dải KPI Header bọc LayoutBuilder chống tràn
                  _buildKpiHeader(
                    totalCount: totalCount,
                    pendingCount: pendingCount,
                    confirmedCount: confirmedCount,
                    disputedCount: disputedCount,
                  ),

                  // 2. Dải bộ lọc
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        FilterChip(
                          selected: _selectedType == 'all',
                          label: const Text('Tất cả loại'),
                          onSelected: (_) =>
                              setState(() => _selectedType = 'all'),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          selected: _selectedType == 'move_in',
                          label: const Text('Nhận nhà'),
                          onSelected: (_) =>
                              setState(() => _selectedType = 'move_in'),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          selected: _selectedType == 'move_out',
                          label: const Text('Trả nhà'),
                          onSelected: (_) =>
                              setState(() => _selectedType = 'move_out'),
                        ),
                        const VerticalDivider(width: 24),
                        FilterChip(
                          selected: _selectedStatus == 'all',
                          label: const Text('Mọi trạng thái'),
                          onSelected: (_) =>
                              setState(() => _selectedStatus = 'all'),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          selected: _selectedStatus == 'pending_resident',
                          label: const Text('Chờ ký'),
                          onSelected: (_) => setState(
                              () => _selectedStatus = 'pending_resident'),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          selected: _selectedStatus == 'confirmed',
                          label: const Text('Đã xác nhận'),
                          onSelected: (_) =>
                              setState(() => _selectedStatus = 'confirmed'),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // 3. Danh sách biên bản (GridView trên desktop, ListView trên mobile)
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.inventory_2_outlined,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Chưa có biên bản bàn giao nào',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : isDesktop
                            ? GridView.builder(
                                padding: const EdgeInsets.all(16),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                  childAspectRatio: 2.2,
                                ),
                                itemCount: filtered.length,
                                itemBuilder: (context, index) =>
                                    _buildHandoverCard(filtered[index]),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(16),
                                itemCount: filtered.length,
                                separatorBuilder: (_, index) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) =>
                                    _buildHandoverCard(filtered[index]),
                              ),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
              const SizedBox(height: 8),
              Text('Lỗi nạp dữ liệu: $err'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () =>
                    ref.refresh(buildingHandoversProvider(widget.buildingId)),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showCreateHandoverDialog(context);
        },
        icon: const Icon(Icons.add),
        label: const Text('Tạo biên bản mới'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildKpiHeader({
    required int totalCount,
    required int pendingCount,
    required int confirmedCount,
    required int disputedCount,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 460;
        if (isNarrow) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                SizedBox(
                  width: 105,
                  child: _buildKpiCard(
                    'Tổng số',
                    totalCount.toString(),
                    Icons.assignment,
                    AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 105,
                  child: _buildKpiCard(
                    'Chờ cư dân',
                    pendingCount.toString(),
                    Icons.pending_actions,
                    AppTheme.warning,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 105,
                  child: _buildKpiCard(
                    'Đã duyệt',
                    confirmedCount.toString(),
                    Icons.verified,
                    AppStatusColors.paid,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 105,
                  child: _buildKpiCard(
                    'Khiếu nại',
                    disputedCount.toString(),
                    Icons.warning_amber,
                    AppTheme.error,
                  ),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: _buildKpiCard(
                  'Tổng số',
                  totalCount.toString(),
                  Icons.assignment,
                  AppTheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildKpiCard(
                  'Chờ cư dân',
                  pendingCount.toString(),
                  Icons.pending_actions,
                  AppTheme.warning,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildKpiCard(
                  'Đã duyệt',
                  confirmedCount.toString(),
                  Icons.verified,
                  AppStatusColors.paid,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildKpiCard(
                  'Khiếu nại',
                  disputedCount.toString(),
                  Icons.warning_amber,
                  AppTheme.error,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildKpiCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHandoverCard(ApartmentHandoverModel item) {
    final statusColor = _getStatusColor(item.status);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item.reportCode,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 110),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      item.statusDisplayName,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Căn hộ: ${item.apartmentCode ?? 'A0110'}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Chip(
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                label: Text(
                  item.handoverTypeDisplayName,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Cư dân: ${item.residentName ?? 'Chưa gán'} • Người kiểm kê: ${item.staffName ?? 'BQL'}',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (item.handoverType == 'move_out') ...[
            const SizedBox(height: 4),
            Text(
              'Tiền cọc: ${_formatCurrency(item.depositHeld)} | Khấu trừ: ${_formatCurrency(item.totalDeduction)} | Hoàn trả: ${_formatCurrency(item.depositRefund)}',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.primary,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.picture_as_pdf,
                    color: AppTheme.textSecondary,
                  ),
                  tooltip: 'Xuất biên bản PDF',
                  onPressed: () async {
                    try {
                      final pdfBytes =
                          await HandoverPdfBuilder.buildHandoverReportPdf(
                        handover: item,
                        items: item.items,
                      );
                      await Printing.layoutPdf(
                        onLayout: (format) async => pdfBytes,
                        name: 'Bien_ban_ban_giao_${item.reportCode}.pdf',
                      );
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Lỗi tạo PDF: $e')),
                        );
                      }
                    }
                  },
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => InspectionWorkstationScreen(
                          buildingId: widget.buildingId,
                          apartmentId: item.apartmentId,
                          apartmentCode: item.apartmentCode ?? 'A0110',
                          existingHandoverId: item.id,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit_note, size: 18),
                  label: const Text('Mở trạm kiểm kê'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateHandoverDialog(BuildContext context) {
    final codeController = TextEditingController(text: 'A0110');
    String type = 'move_in';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Khởi tạo biên bản bàn giao'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeController,
                decoration: const InputDecoration(
                  labelText: 'Mã căn hộ (VD: A0110)',
                  prefixIcon: Icon(Icons.home),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(
                  labelText: 'Loại bàn giao',
                  prefixIcon: Icon(Icons.swap_horiz),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'move_in',
                    child: Text('Nhận nhà (Move-in)'),
                  ),
                  DropdownMenuItem(
                    value: 'move_out',
                    child: Text('Trả nhà (Move-out)'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => type = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () {
                final code = codeController.text.trim();
                if (code.isEmpty) return;
                Navigator.of(ctx).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => InspectionWorkstationScreen(
                      buildingId: widget.buildingId,
                      apartmentId: 'apt-01',
                      apartmentCode: code,
                      initialType: type,
                    ),
                  ),
                );
              },
              child: const Text('Tiếp tục'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(double amount) {
    return '${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} đ';
  }
}
