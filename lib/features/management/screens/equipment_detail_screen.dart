import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../data/models/building_equipment_model.dart';
import '../../../data/models/equipment_maintenance_task_model.dart';
import '../../../data/providers/equipment_provider.dart';
import '../widgets/equipment_form_dialog.dart';
import '../widgets/maintenance_task_form_dialog.dart';
import '../../../core/utils/error_formatter.dart';

/// Màn hình Chi tiết Thiết bị, lịch sử bảo dưỡng và hạch toán chi phí
class EquipmentDetailScreen extends ConsumerStatefulWidget {
  final BuildingEquipmentModel equipment;

  const EquipmentDetailScreen({super.key, required this.equipment});

  @override
  ConsumerState<EquipmentDetailScreen> createState() => _EquipmentDetailScreenState();
}

class _EquipmentDetailScreenState extends ConsumerState<EquipmentDetailScreen> {
  late BuildingEquipmentModel _equipment;
  final _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);
  final _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _equipment = widget.equipment;
  }

  void _openEditDialog() async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => EquipmentFormDialog(equipment: _equipment),
    );
    if (updated == true) {
      final refreshed = await ref.read(equipmentRepositoryProvider).getEquipmentById(_equipment.id);
      if (mounted) {
        setState(() {
          _equipment = refreshed;
        });
      }
    }
  }

  void _openCreateTaskDialog() {
    showDialog(
      context: context,
      builder: (_) => MaintenanceTaskFormDialog(equipment: _equipment),
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa thiết bị'),
        content: Text('Bạn có chắc chắn muốn xóa "${_equipment.name}" (${_equipment.code}) không? Toàn bộ lịch sử bảo trì liên quan cũng sẽ bị xóa.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xóa thiết bị'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(equipmentRepositoryProvider).deleteEquipment(_equipment.id);
        ref.invalidate(equipmentListProvider);
        ref.invalidate(upcomingMaintenanceEquipmentsProvider);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã xóa thiết bị thành công!'),
              backgroundColor: AppTheme.success,
            ),
          );
          context.pop();
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

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(equipmentTasksProvider(_equipment.id));

    Color badgeColor;
    switch (_equipment.status) {
      case 'operational':
        badgeColor = AppTheme.success;
        break;
      case 'under_maintenance':
        badgeColor = AppTheme.warning;
        break;
      case 'degraded':
        badgeColor = AppTheme.error;
        break;
      default:
        badgeColor = Colors.grey;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_equipment.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Chỉnh sửa',
            onPressed: _openEditDialog,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppTheme.error),
            tooltip: 'Xóa thiết bị',
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thẻ tóm tắt thông số thiết bị
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _equipment.code,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _equipment.categoryDisplayName,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _equipment.statusDisplayName,
                          style: TextStyle(
                            color: badgeColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  _buildInfoRow('Tòa nhà', _equipment.building),
                  _buildInfoRow('Vị trí lắp đặt', _equipment.location),
                  _buildInfoRow('Chu kỳ bảo dưỡng', '${_equipment.maintenanceIntervalDays} ngày/lần'),
                  _buildInfoRow(
                    'Lần bảo dưỡng gần nhất',
                    _equipment.lastMaintenanceDate != null
                        ? _dateFormat.format(_equipment.lastMaintenanceDate!)
                        : 'Chưa có',
                  ),
                  _buildInfoRow(
                    'Hạn bảo dưỡng tiếp theo',
                    _equipment.nextMaintenanceDate != null
                        ? _dateFormat.format(_equipment.nextMaintenanceDate!)
                        : 'Chưa có',
                    isHighlight: _equipment.isUpcomingMaintenance || _equipment.isOverdueMaintenance,
                    highlightColor: _equipment.isOverdueMaintenance ? AppTheme.error : Colors.purple,
                  ),
                  if (_equipment.specifications != null) ...[
                    const Divider(height: 16),
                    const Text(
                      'Thông số kỹ thuật:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _equipment.specifications!,
                      style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Lịch sử bảo trì & Hạch toán chi phí
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Lịch sử bảo trì & sửa chữa',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: _openCreateTaskDialog,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Lập phiếu mới'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            tasksAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => Center(child: Text(formatErrorMessage(e))),
              data: (tasks) {
                if (tasks.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Center(
                      child: Text(
                        'Chưa có phiếu bảo trì nào cho thiết bị này.',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                  );
                }

                final totalCost = tasks
                    .where((t) => t.isCompleted)
                    .fold<double>(0.0, (sum, t) => sum + t.cost);

                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Tổng chi phí bảo dưỡng đã hoàn thành:',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          Text(
                            _currencyFormat.format(totalCost),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: AppTheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...tasks.map((t) => _buildTaskHistoryItem(t)),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    bool isHighlight = false,
    Color? highlightColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
              color: isHighlight ? highlightColor : AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskHistoryItem(EquipmentMaintenanceTaskModel task) {
    Color badgeColor;
    switch (task.status) {
      case 'completed':
        badgeColor = AppTheme.success;
        break;
      case 'in_progress':
        badgeColor = AppTheme.warning;
        break;
      case 'cancelled':
        badgeColor = Colors.grey;
        break;
      default:
        badgeColor = AppTheme.primary;
    }

    final dateFormat = DateFormat('dd/MM/yyyy');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: AppCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    task.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    task.statusDisplayName,
                    style: TextStyle(
                      color: badgeColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  '${task.taskTypeDisplayName} • ${dateFormat.format(task.scheduledStart)}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                const Spacer(),
                Text(
                  _currencyFormat.format(task.cost),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
            if (task.vendorName != null) ...[
              const SizedBox(height: 4),
              Text(
                'Đơn vị thực hiện: ${task.vendorName} (${task.vendorContact ?? "N/A"})',
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
            if (task.notes != null) ...[
              const SizedBox(height: 4),
              Text(
                'Ghi chú: ${task.notes!}',
                style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
