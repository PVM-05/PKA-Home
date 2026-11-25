import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../core/widgets/accounting_voucher_dialog.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_card.dart';
import '../../../core/widgets/app_skeleton_shimmer.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../data/models/building_equipment_model.dart';
import '../../../data/models/equipment_maintenance_task_model.dart';
import '../../../data/models/maintenance_fund_transaction_model.dart';
import '../../../data/providers/building_provider.dart';
import '../../../data/providers/equipment_provider.dart';
import '../../../data/providers/maintenance_fund_provider.dart';
import '../widgets/equipment_form_dialog.dart';
import '../widgets/maintenance_task_form_dialog.dart';

/// Màn hình Chi tiết Thiết bị, lịch sử bảo dưỡng và hạch toán chi phí
class EquipmentDetailScreen extends ConsumerStatefulWidget {
  final BuildingEquipmentModel equipment;

  const EquipmentDetailScreen({super.key, required this.equipment});

  @override
  ConsumerState<EquipmentDetailScreen> createState() =>
      _EquipmentDetailScreenState();
}

class _EquipmentDetailScreenState extends ConsumerState<EquipmentDetailScreen> {
  late BuildingEquipmentModel _equipment;
  final Set<String> _disbursedTaskIds = {};
  final _currencyFormat = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: 'đ',
    decimalDigits: 0,
  );
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
      final refreshed = await ref
          .read(equipmentRepositoryProvider)
          .getEquipmentById(_equipment.id);
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
    if (task.cost <= 0) {
      AppSnackBar.showWarning(
        context,
        'Hạng mục không phát sinh chi phí để lập phiếu chi.',
      );
      return;
    }

    final activeBuilding = ref.read(activeBuildingProvider).valueOrNull;
    final buildingId =
        (activeBuilding?.id != null && activeBuilding!.id.isNotEmpty)
        ? activeBuilding.id
        : (_equipment.building.length == 36 ? _equipment.building : null);

    if (buildingId == null) {
      AppSnackBar.showError(
        context,
        'Vui lòng chọn tòa nhà hợp lệ trước khi lập phiếu chi Quỹ bảo trì.',
      );
      return;
    }

    final vendorName = task.vendorName ?? 'Đơn vị bảo trì thiết bị';
    final desc =
        'Nghiệm thu bảo dưỡng ${_equipment.name} (${_equipment.code}): ${task.title}';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final dialogScheme = Theme.of(ctx).colorScheme;
        final errorColor = AppTheme.getSemanticError(ctx);
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                color: errorColor,
              ),
              AppSpacing.w8,
              Expanded(
                child: Text(
                  'Lập phiếu chi Quỹ bảo trì',
                  style: ctx.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Xác nhận lập phiếu chi từ Quỹ bảo trì 2% cho hạng mục sau:',
                  style: ctx.bodySmall?.copyWith(
                    color: dialogScheme.onSurfaceVariant,
                  ),
                ),
                AppSpacing.h12,
                Text(
                  'Thiết bị: ${_equipment.name} (${_equipment.code})',
                  style: ctx.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                AppSpacing.h4,
                Text('Công việc: ${task.title}'),
                AppSpacing.h4,
                Text('Đơn vị nhận: $vendorName'),
                AppSpacing.h8,
                Text(
                  'Số tiền chi: ${_currencyFormat.format(task.cost)}',
                  style: ctx.titleMedium?.tabularFigures().copyWith(
                    fontWeight: FontWeight.bold,
                    color: errorColor,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: errorColor,
                foregroundColor: dialogScheme.onError,
                minimumSize: const Size(0, 44),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Xác nhận chi'),
            ),
          ],
        );
      },
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
          setState(() {
            _disbursedTaskIds.add(task.id);
          });
          ref.invalidate(activeMaintenanceFundProvider);
          ref.invalidate(maintenanceFundLedgerProvider);
          AppSnackBar.showSuccess(
            context,
            'Đã lập phiếu chi ${res['voucher_number']} thành công!',
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
            buildingName: activeBuilding?.name ?? 'Tòa nhà Vivona',
          );
        } else {
          AppSnackBar.showError(
            context,
            'Không thể lập phiếu chi. Vui lòng kiểm tra lại số dư Quỹ bảo trì.',
          );
        }
      }
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final dialogScheme = Theme.of(ctx).colorScheme;
        final errorColor = AppTheme.getSemanticError(ctx);
        return AlertDialog(
          title: const Text('Xác nhận xóa thiết bị'),
          content: Text(
            'Bạn có chắc chắn muốn xóa "${_equipment.name}" (${_equipment.code}) không? Toàn bộ lịch sử bảo trì liên quan cũng sẽ bị xóa.',
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: errorColor,
                foregroundColor: dialogScheme.onError,
                minimumSize: const Size(0, 48),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Xóa thiết bị'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await ref
            .read(equipmentRepositoryProvider)
            .deleteEquipment(_equipment.id);
        ref.invalidate(equipmentListProvider);
        ref.invalidate(upcomingMaintenanceEquipmentsProvider);

        if (mounted) {
          AppSnackBar.showSuccess(context, 'Đã xóa thiết bị thành công!');
          context.pop();
        }
      } catch (e) {
        if (mounted) {
          AppSnackBar.showError(context, formatErrorMessage(e));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final successColor = AppTheme.getSemanticSuccess(context);
    final warningColor = AppTheme.getSemanticWarning(context);
    final errorColor = AppTheme.getSemanticError(context);
    final upcomingColor = AppTheme.getSemanticSecondary(context);

    final tasksAsync = ref.watch(equipmentTasksProvider(_equipment.id));

    final Color badgeColor;
    switch (_equipment.status) {
      case 'operational':
        badgeColor = successColor;
        break;
      case 'under_maintenance':
        badgeColor = warningColor;
        break;
      case 'degraded':
        badgeColor = errorColor;
        break;
      default:
        badgeColor = colorScheme.onSurfaceVariant;
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
            icon: Icon(Icons.delete_outline, color: errorColor),
            tooltip: 'Xóa thiết bị',
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(equipmentTasksProvider(_equipment.id));
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: AppSpacing.p16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Thẻ tóm tắt thông số thiết bị
                  AppCard(
                    padding: AppSpacing.p16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: AppRadius.r6,
                              ),
                              child: Text(
                                _equipment.code,
                                style: context.titleSmall
                                    ?.tabularFigures()
                                    .copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.primary,
                                    ),
                              ),
                            ),
                            AppSpacing.w8,
                            Expanded(
                              child: Text(
                                _equipment.categoryDisplayName,
                                style: context.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            AppSpacing.w8,
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: badgeColor.withValues(alpha: 0.15),
                                borderRadius: AppRadius.r12,
                              ),
                              child: Text(
                                _equipment.statusDisplayName,
                                style: context.bodySmall?.copyWith(
                                  color: badgeColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        _buildInfoRow('Tòa nhà', _equipment.building),
                        _buildInfoRow('Vị trí lắp đặt', _equipment.location),
                        _buildInfoRow(
                          'Chu kỳ bảo dưỡng',
                          '${_equipment.maintenanceIntervalDays} ngày/lần',
                        ),
                        _buildInfoRow(
                          'Lần bảo dưỡng gần nhất',
                          _equipment.lastMaintenanceDate != null
                              ? _dateFormat.format(
                                  _equipment.lastMaintenanceDate!,
                                )
                              : 'Chưa có',
                        ),
                        _buildInfoRow(
                          'Hạn bảo dưỡng tiếp theo',
                          _equipment.nextMaintenanceDate != null
                              ? _dateFormat.format(
                                  _equipment.nextMaintenanceDate!,
                                )
                              : 'Chưa có',
                          isHighlight:
                              _equipment.isUpcomingMaintenance ||
                              _equipment.isOverdueMaintenance,
                          highlightColor: _equipment.isOverdueMaintenance
                              ? errorColor
                              : upcomingColor,
                        ),
                        if (_equipment.specifications != null) ...[
                          const Divider(height: 16),
                          Text(
                            'Thông số kỹ thuật:',
                            style: context.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          AppSpacing.h4,
                          Text(
                            _equipment.specifications!,
                            style: context.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  AppSpacing.h16,

                  // Lịch sử bảo trì & Hạch toán chi phí
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Lịch sử bảo trì & sửa chữa',
                        style: context.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                        ),
                        onPressed: _openCreateTaskDialog,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Lập phiếu mới'),
                      ),
                    ],
                  ),
                  AppSpacing.h12,

                  tasksAsync.when(
                    loading: () => AppSkeletonShimmer.cardList(
                      count: 2,
                      itemHeight: 100,
                    ),
                    error: (e, _) => AppErrorCard(
                      error: e,
                      onRetry: () =>
                          ref.invalidate(equipmentTasksProvider(_equipment.id)),
                    ),
                    data: (tasks) {
                      if (tasks.isEmpty) {
                        return const AppEmptyState(
                          icon: Icons.build_circle_outlined,
                          title: 'Chưa có lịch sử bảo trì',
                          description:
                              'Chưa có phiếu bảo trì nào cho thiết bị này.',
                        );
                      }

                      final totalCost = tasks
                          .where((t) => t.isCompleted)
                          .fold<double>(0.0, (sum, t) => sum + t.cost);

                      return Column(
                        children: [
                          Container(
                            padding: AppSpacing.p12,
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(
                                alpha: 0.08,
                              ),
                              borderRadius: AppRadius.r8,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Tổng chi phí bảo dưỡng đã hoàn thành:',
                                    style: context.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                AppSpacing.w8,
                                Text(
                                  _currencyFormat.format(totalCost),
                                  style: context.titleMedium
                                      ?.tabularFigures()
                                      .copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.primary,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          AppSpacing.h12,
                          ...tasks.map((t) => _buildTaskHistoryItem(t)),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
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
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: context.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          AppSpacing.w12,
          Text(
            value,
            style: context.bodyMedium?.tabularFigures().copyWith(
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
              color: isHighlight ? highlightColor : colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskHistoryItem(EquipmentMaintenanceTaskModel task) {
    final colorScheme = Theme.of(context).colorScheme;
    final successColor = AppTheme.getSemanticSuccess(context);
    final warningColor = AppTheme.getSemanticWarning(context);
    final errorColor = AppTheme.getSemanticError(context);
    final paidColor = AppStatusColors.getPaid(context);

    final Color badgeColor;
    switch (task.status) {
      case 'completed':
        badgeColor = successColor;
        break;
      case 'in_progress':
        badgeColor = warningColor;
        break;
      case 'cancelled':
        badgeColor = colorScheme.onSurfaceVariant;
        break;
      default:
        badgeColor = colorScheme.primary;
    }

    final dateFormat = DateFormat('dd/MM/yyyy');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: AppCard(
        padding: AppSpacing.p12,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    task.title,
                    style: context.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                AppSpacing.w8,
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: AppRadius.r8,
                  ),
                  child: Text(
                    task.statusDisplayName,
                    style: context.labelSmall?.copyWith(
                      color: badgeColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            AppSpacing.h6,
            Wrap(
              spacing: 12,
              runSpacing: 4,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '${task.taskTypeDisplayName} • ${dateFormat.format(task.scheduledStart)}',
                  style: context.bodySmall?.tabularFigures().copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  _currencyFormat.format(task.cost),
                  style: context.titleSmall?.tabularFigures().copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (task.vendorName != null) ...[
              AppSpacing.h4,
              Text(
                'Đơn vị thực hiện: ${task.vendorName} (${task.vendorContact ?? "N/A"})',
                style: context.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (task.notes != null) ...[
              AppSpacing.h4,
              Text(
                'Ghi chú: ${task.notes!}',
                style: context.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            if (task.isCompleted && task.cost > 0) ...[
              AppSpacing.h8,
              Align(
                alignment: Alignment.centerRight,
                child: _disbursedTaskIds.contains(task.id)
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: paidColor.withValues(alpha: 0.1),
                          borderRadius: AppRadius.r6,
                          border: Border.all(
                            color: paidColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 14,
                              color: paidColor,
                            ),
                            AppSpacing.w4,
                            Text(
                              'Đã giải ngân Quỹ bảo trì',
                              style: context.labelMedium?.copyWith(
                                color: paidColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      )
                    : OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: errorColor,
                          side: BorderSide(color: errorColor),
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        icon: const Icon(Icons.receipt_long_outlined, size: 16),
                        label: const Text('Chi từ Quỹ bảo trì'),
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
