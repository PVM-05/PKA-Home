import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/permissions.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_card.dart';
import '../../../core/widgets/app_skeleton_shimmer.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/role_guard.dart';
import '../../../data/models/building_equipment_model.dart';
import '../../../data/models/equipment_maintenance_task_model.dart';
import '../../../data/providers/equipment_provider.dart';
import '../widgets/equipment_form_dialog.dart';
import '../widgets/maintenance_task_form_dialog.dart';

/// Màn hình Quản lý danh mục thiết bị và bảo trì định kỳ toàn tòa nhà
class EquipmentManagementScreen extends ConsumerStatefulWidget {
  const EquipmentManagementScreen({super.key});

  @override
  ConsumerState<EquipmentManagementScreen> createState() =>
      _EquipmentManagementScreenState();
}

class _EquipmentManagementScreenState
    extends ConsumerState<EquipmentManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _currencyFormat = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: 'đ',
    decimalDigits: 0,
  );
  final _dateFormat = DateFormat('dd/MM/yyyy');

  final _buildings = const ['Tất cả', 'Tòa A', 'Tòa B', 'Tòa C', 'Toàn khu'];
  final _categories = const [
    {'value': 'Tất cả', 'label': 'Tất cả loại'},
    {'value': 'elevator', 'label': 'Thang máy'},
    {'value': 'fire_safety', 'label': 'Hệ thống PCCC'},
    {'value': 'water_pump', 'label': 'Máy bơm nước'},
    {'value': 'generator', 'label': 'Máy phát điện'},
    {'value': 'electrical', 'label': 'Hệ thống điện'},
    {'value': 'hvac', 'label': 'Thông gió / HVAC'},
    {'value': 'other', 'label': 'Khác'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(_handleTabChanged);
  }

  void _handleTabChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _openAddEquipmentDialog() {
    showDialog(context: context, builder: (_) => const EquipmentFormDialog());
  }

  void _openCreateTaskDialog(List<BuildingEquipmentModel> equipments) {
    showDialog(
      context: context,
      builder: (_) => MaintenanceTaskFormDialog(equipmentList: equipments),
    );
  }

  Future<void> _updateTaskStatus(
    EquipmentMaintenanceTaskModel task,
    String newStatus,
  ) async {
    try {
      final repo = ref.read(equipmentRepositoryProvider);
      final now = DateTime.now();
      await repo.updateMaintenanceTaskStatus(
        task.id,
        newStatus,
        actualStart: newStatus == 'in_progress' ? now : null,
        actualEnd: newStatus == 'completed' ? now : null,
      );

      ref.invalidate(equipmentTasksProvider);
      ref.invalidate(equipmentListProvider);
      ref.invalidate(upcomingMaintenanceEquipmentsProvider);

      if (mounted) {
        final msg = newStatus == 'in_progress'
            ? 'Đã bắt đầu bảo trì!'
            : (newStatus == 'completed'
                  ? 'Nghiệm thu thành công! Chu kỳ bảo dưỡng tiếp theo đã được cập nhật.'
                  : 'Đã hủy phiếu bảo trì.');
        if (newStatus == 'completed') {
          AppSnackBar.showSuccess(context, msg);
        } else {
          AppSnackBar.showInfo(context, msg);
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, formatErrorMessage(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final equipmentsAsync = ref.watch(equipmentListProvider);
    final tasksAsync = ref.watch(equipmentTasksProvider(null));
    final selectedBuilding =
        ref.watch(equipmentFilterBuildingProvider) ?? 'Tất cả';
    final selectedCategory =
        ref.watch(equipmentFilterCategoryProvider) ?? 'Tất cả';

    return RoleGuard(
      permission: AppPermissions.equipmentManagement,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Bảo trì thiết bị tòa nhà'),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(
                icon: Icon(Icons.precision_manufacturing),
                text: 'Danh mục thiết bị',
              ),
              Tab(
                icon: Icon(Icons.assignment_outlined),
                text: 'Phiếu & Lịch bảo trì',
              ),
            ],
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              children: [
                // Bộ lọc Tòa nhà và Phân loại
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    border: Border(
                      bottom: BorderSide(
                        color: colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: selectedBuilding,
                            items: _buildings
                                .map(
                                  (b) => DropdownMenuItem(
                                    value: b,
                                    child: Text(
                                      'Tòa: $b',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              ref
                                  .read(equipmentFilterBuildingProvider.notifier)
                                  .state = val == 'Tất cả'
                                  ? null
                                  : val;
                            },
                          ),
                        ),
                      ),
                      AppSpacing.w12,
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: selectedCategory,
                            items: _categories
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c['value'],
                                    child: Text(
                                      c['label']!,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              ref
                                  .read(equipmentFilterCategoryProvider.notifier)
                                  .state = val == 'Tất cả'
                                  ? null
                                  : val;
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Nội dung 2 tab
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Tab 1: Danh mục thiết bị
                      equipmentsAsync.when(
                        loading: () => ListView(
                          padding: AppSpacing.p16,
                          children: [
                            AppSkeletonShimmer.cardList(
                              count: 3,
                              itemHeight: 120,
                            ),
                          ],
                        ),
                        error: (e, _) => ListView(
                          padding: AppSpacing.p16,
                          children: [
                            AppErrorCard(
                              error: e,
                              onRetry: () =>
                                  ref.invalidate(equipmentListProvider),
                            ),
                          ],
                        ),
                        data: (equipments) => _buildEquipmentsTab(equipments),
                      ),
                      // Tab 2: Lịch & Phiếu bảo trì
                      tasksAsync.when(
                        loading: () => ListView(
                          padding: AppSpacing.p16,
                          children: [
                            AppSkeletonShimmer.cardList(
                              count: 3,
                              itemHeight: 136,
                            ),
                          ],
                        ),
                        error: (e, _) => ListView(
                          padding: AppSpacing.p16,
                          children: [
                            AppErrorCard(
                              error: e,
                              onRetry: () =>
                                  ref.invalidate(equipmentTasksProvider(null)),
                            ),
                          ],
                        ),
                        data: (tasks) => equipmentsAsync.maybeWhen(
                          data: (equipments) =>
                              _buildTasksTab(tasks, equipments),
                          orElse: () => _buildTasksTab(tasks, []),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            if (_tabController.index == 0) {
              _openAddEquipmentDialog();
            } else {
              equipmentsAsync.whenData((list) => _openCreateTaskDialog(list));
            }
          },
          icon: const Icon(Icons.add),
          label: Text(
            _tabController.index == 0 ? 'Thêm thiết bị' : 'Lập phiếu bảo trì',
          ),
        ),
      ),
    );
  }

  Widget _buildEquipmentsTab(List<BuildingEquipmentModel> equipments) {
    final colorScheme = Theme.of(context).colorScheme;
    final successColor = AppTheme.getSemanticSuccess(context);
    final warningColor = AppTheme.getSemanticWarning(context);
    final upcomingColor = AppTheme.getSemanticSecondary(context);

    final total = equipments.length;
    final operational = equipments
        .where((e) => e.status == 'operational')
        .length;
    final underMaint = equipments.where((e) => e.isUnderMaintenance).length;
    final upcoming = equipments.where((e) => e.isUpcomingMaintenance).length;

    return RefreshIndicator(
      onRefresh: () async => ref.refresh(equipmentListProvider.future),
      child: ListView(
        padding: AppSpacing.p16,
        children: [
          // Thẻ KPI tổng quan responsive
          LayoutBuilder(
            builder: (context, constraints) {
              final cards = [
                _buildKpiCard('Tổng số', '$total', colorScheme.primary),
                _buildKpiCard('Hoạt động tốt', '$operational', successColor),
                _buildKpiCard('Đang bảo trì', '$underMaint', warningColor),
                _buildKpiCard('Sắp đến hạn', '$upcoming', upcomingColor),
              ];
              if (constraints.maxWidth < 520) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: cards[0]),
                        AppSpacing.w8,
                        Expanded(child: cards[1]),
                      ],
                    ),
                    AppSpacing.h8,
                    Row(
                      children: [
                        Expanded(child: cards[2]),
                        AppSpacing.w8,
                        Expanded(child: cards[3]),
                      ],
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: cards[0]),
                  AppSpacing.w8,
                  Expanded(child: cards[1]),
                  AppSpacing.w8,
                  Expanded(child: cards[2]),
                  AppSpacing.w8,
                  Expanded(child: cards[3]),
                ],
              );
            },
          ),
          AppSpacing.h16,
          if (equipments.isEmpty)
            const AppEmptyState(
              icon: Icons.precision_manufacturing_outlined,
              title: 'Chưa có thiết bị phù hợp',
              description: 'Không có thiết bị nào phù hợp với bộ lọc.',
            )
          else
            ...equipments.map((eq) => _buildEquipmentCard(eq)),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String label, String value, Color color) {
    final colorScheme = Theme.of(context).colorScheme;
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Column(
        children: [
          Text(
            value,
            style: context.titleLarge?.tabularFigures().copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          AppSpacing.h4,
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEquipmentCard(BuildingEquipmentModel eq) {
    final colorScheme = Theme.of(context).colorScheme;
    final successColor = AppTheme.getSemanticSuccess(context);
    final warningColor = AppTheme.getSemanticWarning(context);
    final errorColor = AppTheme.getSemanticError(context);
    final upcomingColor = AppTheme.getSemanticSecondary(context);

    final Color badgeColor;
    switch (eq.status) {
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

    final nextMaintText = eq.nextMaintenanceDate != null
        ? _dateFormat.format(eq.nextMaintenanceDate!)
        : 'Chưa có';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        borderRadius: AppRadius.r12,
        onTap: () {
          context.push(AppRoutes.managementEquipmentDetail, extra: eq);
        },
        child: AppCard(
          padding: AppSpacing.p16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: AppRadius.r6,
                    ),
                    child: Text(
                      eq.code,
                      style: context.bodyMedium?.tabularFigures().copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                  AppSpacing.w8,
                  Expanded(
                    child: Text(
                      eq.name,
                      style: context.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  AppSpacing.w8,
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.15),
                      borderRadius: AppRadius.r12,
                    ),
                    child: Text(
                      eq.statusDisplayName,
                      style: context.labelMedium?.copyWith(
                        color: badgeColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              AppSpacing.h8,
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  AppSpacing.w4,
                  Expanded(
                    child: Text(
                      '${eq.location} (${eq.building})',
                      style: context.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  AppSpacing.w8,
                  Text(
                    'Định kỳ: ${eq.maintenanceIntervalDays} ngày',
                    style: context.bodySmall?.tabularFigures().copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          eq.isOverdueMaintenance
                              ? Icons.warning_amber
                              : (eq.isUpcomingMaintenance
                                    ? Icons.alarm
                                    : Icons.event_available),
                          size: 16,
                          color: eq.isOverdueMaintenance
                              ? errorColor
                              : (eq.isUpcomingMaintenance
                                    ? upcomingColor
                                    : colorScheme.onSurfaceVariant),
                        ),
                        AppSpacing.w4,
                        Expanded(
                          child: Text(
                            'Hạn bảo dưỡng: $nextMaintText',
                            style: context.bodyMedium?.tabularFigures().copyWith(
                              fontWeight:
                                  (eq.isOverdueMaintenance ||
                                      eq.isUpcomingMaintenance)
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: eq.isOverdueMaintenance
                                  ? errorColor
                                  : (eq.isUpcomingMaintenance
                                        ? upcomingColor
                                        : colorScheme.onSurface),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTasksTab(
    List<EquipmentMaintenanceTaskModel> tasks,
    List<BuildingEquipmentModel> equipments,
  ) {
    if (tasks.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async => ref.refresh(equipmentTasksProvider(null).future),
        child: ListView(
          padding: AppSpacing.p16,
          children: [
            AppEmptyState(
              icon: Icons.assignment_turned_in_outlined,
              title: 'Chưa có phiếu bảo trì',
              description: 'Chưa có phiếu bảo trì nào được lập.',
              actionLabel: 'Lập phiếu mới ngay',
              onAction: () => _openCreateTaskDialog(equipments),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => ref.refresh(equipmentTasksProvider(null).future),
      child: ListView.builder(
        padding: AppSpacing.p16,
        itemCount: tasks.length + 1,
        itemBuilder: (context, index) {
          if (index == tasks.length) return const SizedBox(height: 80);
          final task = tasks[index];
          return _buildTaskCard(task);
        },
      ),
    );
  }

  Widget _buildTaskCard(EquipmentMaintenanceTaskModel task) {
    final colorScheme = Theme.of(context).colorScheme;
    final successColor = AppTheme.getSemanticSuccess(context);
    final warningColor = AppTheme.getSemanticWarning(context);

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

    final dateFormat = DateFormat('HH:mm dd/MM');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: AppCard(
        padding: AppSpacing.p16,
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
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: AppRadius.r12,
                  ),
                  child: Text(
                    task.statusDisplayName,
                    style: context.labelMedium?.copyWith(
                      color: badgeColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            AppSpacing.h6,
            if (task.equipmentName != null)
              Row(
                children: [
                  Icon(
                    Icons.precision_manufacturing,
                    size: 15,
                    color: colorScheme.primary,
                  ),
                  AppSpacing.w4,
                  Expanded(
                    child: Text(
                      '${task.equipmentCode ?? ""} - ${task.equipmentName}',
                      style: context.bodyMedium?.tabularFigures().copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            AppSpacing.h8,
            Wrap(
              spacing: 12,
              runSpacing: 4,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 15,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    AppSpacing.w4,
                    Text(
                      '${dateFormat.format(task.scheduledStart)} - ${dateFormat.format(task.scheduledEnd)}',
                      style: context.bodySmall?.tabularFigures().copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                Text(
                  _currencyFormat.format(task.cost),
                  style: context.titleSmall?.tabularFigures().copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (task.vendorName != null || task.technicianName != null) ...[
              AppSpacing.h4,
              Row(
                children: [
                  Icon(
                    Icons.engineering_outlined,
                    size: 15,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  AppSpacing.w4,
                  Expanded(
                    child: Text(
                      task.vendorName != null
                          ? 'Nhà thầu: ${task.vendorName}'
                          : 'Kỹ thuật: ${task.technicianName}',
                      style: context.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (task.affectsService) ...[
              AppSpacing.h6,
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: warningColor.withValues(alpha: 0.1),
                  borderRadius: AppRadius.r6,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 14,
                      color: warningColor,
                    ),
                    AppSpacing.w6,
                    Expanded(
                      child: Text(
                        task.serviceInterruptionNote ??
                            'Tạm ngưng phục vụ trong thời gian bảo trì',
                        style: context.labelMedium?.copyWith(
                          color: warningColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const Divider(height: 16),
            // Nút thao tác nhanh trạng thái
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (task.status == 'pending') ...[
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: () => _updateTaskStatus(task, 'cancelled'),
                      icon: const Icon(Icons.cancel_outlined, size: 16),
                      label: const Text('Hủy'),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: () => _updateTaskStatus(task, 'in_progress'),
                      icon: const Icon(Icons.play_arrow, size: 16),
                      label: const Text('Bắt đầu'),
                    ),
                  ] else if (task.status == 'in_progress') ...[
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: successColor,
                        foregroundColor: colorScheme.onPrimary,
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: () => _updateTaskStatus(task, 'completed'),
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text('Nghiệm thu hoàn tất'),
                    ),
                  ] else if (task.status == 'completed') ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check, size: 16, color: successColor),
                        AppSpacing.w4,
                        Text(
                          'Đã cập nhật chu kỳ kế tiếp',
                          style: context.labelMedium?.copyWith(
                            color: successColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
