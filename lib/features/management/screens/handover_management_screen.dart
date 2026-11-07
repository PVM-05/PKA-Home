import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import '../../../core/utils/handover_pdf_builder.dart';
import '../../../data/providers/handover_provider.dart';
import 'inspection_workstation_screen.dart';

class HandoverManagementScreen extends ConsumerStatefulWidget {
  final String buildingId;

  const HandoverManagementScreen({
    super.key,
    this.buildingId = 'bld-01',
  });

  @override
  ConsumerState<HandoverManagementScreen> createState() => _HandoverManagementScreenState();
}

class _HandoverManagementScreenState extends ConsumerState<HandoverManagementScreen> {
  String _selectedType = 'all'; // all, move_in, move_out
  String _selectedStatus = 'all'; // all, draft, pending_resident, confirmed, disputed

  Color _getStatusColor(String status) {
    switch (status) {
      case 'confirmed':
        return Colors.green;
      case 'pending_resident':
        return Colors.orange;
      case 'disputed':
        return Colors.red;
      case 'draft':
        return Colors.blueGrey;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final handoversAsync = ref.watch(buildingHandoversProvider(widget.buildingId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý bàn giao & kiểm kê'),
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(buildingHandoversProvider(widget.buildingId)),
          ),
        ],
      ),
      body: handoversAsync.when(
        data: (handovers) {
          final totalCount = handovers.length;
          final pendingCount = handovers.where((h) => h.status == 'pending_resident').length;
          final confirmedCount = handovers.where((h) => h.status == 'confirmed').length;
          final disputedCount = handovers.where((h) => h.status == 'disputed').length;

          final filtered = handovers.where((h) {
            if (_selectedType != 'all' && h.handoverType != _selectedType) return false;
            if (_selectedStatus != 'all' && h.status != _selectedStatus) return false;
            return true;
          }).toList();

          return Column(
            children: [
              // 1. Dải KPI Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _buildKpiCard('Tổng số', totalCount.toString(), Icons.assignment, const Color(0xFF1E3A8A)),
                    const SizedBox(width: 8),
                    _buildKpiCard('Chờ cư dân', pendingCount.toString(), Icons.pending_actions, Colors.orange.shade700),
                    const SizedBox(width: 8),
                    _buildKpiCard('Đã duyệt', confirmedCount.toString(), Icons.verified, Colors.green.shade700),
                    const SizedBox(width: 8),
                    _buildKpiCard('Khiếu nại', disputedCount.toString(), Icons.warning_amber, Colors.red.shade700),
                  ],
                ),
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
                      onSelected: (_) => setState(() => _selectedType = 'all'),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      selected: _selectedType == 'move_in',
                      label: const Text('Nhận nhà'),
                      onSelected: (_) => setState(() => _selectedType = 'move_in'),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      selected: _selectedType == 'move_out',
                      label: const Text('Trả nhà'),
                      onSelected: (_) => setState(() => _selectedType = 'move_out'),
                    ),
                    const VerticalDivider(width: 24),
                    FilterChip(
                      selected: _selectedStatus == 'all',
                      label: const Text('Mọi trạng thái'),
                      onSelected: (_) => setState(() => _selectedStatus = 'all'),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      selected: _selectedStatus == 'pending_resident',
                      label: const Text('Chờ ký'),
                      onSelected: (_) => setState(() => _selectedStatus = 'pending_resident'),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      selected: _selectedStatus == 'confirmed',
                      label: const Text('Đã xác nhận'),
                      onSelected: (_) => setState(() => _selectedStatus = 'confirmed'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // 3. Danh sách biên bản
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              'Chưa có biên bản bàn giao nào',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          return Card(
                            elevation: 1,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1E3A8A).withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          item.reportCode,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1E3A8A),
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(item.status).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          item.statusDisplayName,
                                          style: TextStyle(
                                            color: _getStatusColor(item.status),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Text(
                                        'Căn hộ: ${item.apartmentCode ?? 'A0110'}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
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
                                  const SizedBox(height: 8),
                                  Text(
                                    'Cư dân: ${item.residentName ?? 'Chưa gán'} - Người kiểm kê: ${item.staffName ?? 'BQL'}',
                                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                                  ),
                                  if (item.handoverType == 'move_out') ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'Tiền cọc giữ: ${_formatCurrency(item.depositHeld)} | Khấu trừ: ${_formatCurrency(item.totalDeduction)} | Hoàn trả: ${_formatCurrency(item.depositRefund)}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.indigo.shade800,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.picture_as_pdf, color: Colors.blueGrey),
                                        tooltip: 'Xuất biên bản PDF',
                                        onPressed: () async {
                                          try {
                                            final pdfBytes = await HandoverPdfBuilder.buildHandoverReportPdf(
                                              handover: item,
                                              items: item.items,
                                            );
                                            await Printing.layoutPdf(
                                              onLayout: (format) async => pdfBytes,
                                              name: 'Bien_ban_ban_giao_${item.reportCode}.pdf',
                                            );
                                          } catch (e) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('Lỗi tạo PDF: $e')),
                                              );
                                            }
                                          }
                                        },
                                      ),
                                      const SizedBox(width: 8),
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
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 8),
              Text('Lỗi nạp dữ liệu: $err'),
              ElevatedButton(
                onPressed: () => ref.refresh(buildingHandoversProvider(widget.buildingId)),
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
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildKpiCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
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
                  DropdownMenuItem(value: 'move_in', child: Text('Nhận nhà (Move-in)')),
                  DropdownMenuItem(value: 'move_out', child: Text('Trả nhà (Move-out)')),
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
