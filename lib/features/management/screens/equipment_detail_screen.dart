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
import '../../../core/widgets/accounting_voucher_dialog.dart';
import '../../../data/models/maintenance_fund_transaction_model.dart';
import '../../../data/providers/maintenance_fund_provider.dart';
import '../../../data/providers/building_provider.dart';

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

  void _disburseMaintenanceFund(EquipmentMaintenanceTaskModel task) async {
    final activeBuilding = ref.read(activeBuildingProvider).valueOrNull;
    final buildingId = activeBuilding?.id ?? _equipment.building ?? '';
    final vendorName = task.vendorName ?? 'Đơn vị bảo trì thiết bị';
    final desc = 'Nghiệm thu bảo dưỡng ${_equipment.name} (${_equipment.code}): ${task.title}';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.account_balance_wallet_outlined, color: AppTheme.error),
            SizedBox(width: 8),
            Expanded(child: Text('Lập phiếu chi Quỹ bảo trì', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Xác nhận lập phiếu chi từ Quỹ bảo trì 2% cho hạng mục sau:', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            Text('Thiết bị: ${_equipment.name} (${_equipment.code})', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Công việc: ${task.title}'),
            const SizedBox(height: 4),
            Text('Đơn vị nhận: $vendorName'),
            const SizedBox(height: 8),
            Text('Số tiền chi: ${_currencyFormat.format(task.cost)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.error, fontSize: 16)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xác nhận chi'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final repo = ref.read(maintenanceFundRepositoryProvider);
      final res = await repo.recordTransaction(
        buildingId: buildingId,
        transactionType: 'EXPENSE',
        category: 'EQUIPMENT_REPAIR',
        amount: task.cost,
        description: desc,
        recipientOrPayer: vendorName,
        referenceType: 'EQUIPMENT_TASK',
        referenceId: task.id,
      );

      if (mounted) {
        if (res != null && res['success'] == true) {
          ref.invalidate(activeMaintenanceFundProvider);
          ref.invalidate(maintenanceFundLedgerProvider);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã lập phiếu chi ${res['voucher_number']} thành công!'),
              backgroundColor: AppTheme.success,
            ),
          );

          final dummyTx = MaintenanceFundTransactionModel(
            id: res['transaction_id']?.toString() ?? '',
            buildingId: buildingId,
            fundId: '',
            voucherNumber: res['voucher_number']?.toString() ?? 'PC-...',
            transactionType: 'EXPENSE',
            category: 'EQUIPMENT_REPAIR',
            amount: task.cost,
            balanceAfter: (res['new_balance'] as num?)?.toDouble() ?? 0.0,
            recipientOrPayer: vendorName,
            description: desc,
            referenceType: 'EQUIPMENT_TASK',
            referenceId: task.id,
            createdAt: DateTime.now(),
          );

          AccountingVoucherDialog.show(
            context,
            transaction: dummyTx,
            buildingName: activeBuilding?.name ?? 'Tòa nhà Landmark PKA',
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Không thể lập phiếu chi. Vui lòng kiểm tra lại số dư Quỹ bảo trì.'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    }
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
            if (task.isCompleted && task.cost > 0) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.error,
                    side: const BorderSide(color: AppTheme.error),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                  icon: const Icon(Icons.receipt_long_outlined, size: 16),
                  label: const Text('Chi từ Quỹ bảo trì', style: TextStyle(fontSize: 12)),
                  onPressed: () => _disburseMaintenanceFund(task),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
