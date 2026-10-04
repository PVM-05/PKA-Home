import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../data/models/building_equipment_model.dart';
import '../../../data/models/equipment_maintenance_task_model.dart';
import '../../../data/providers/equipment_provider.dart';
import '../widgets/equipment_form_dialog.dart';
import '../widgets/maintenance_task_form_dialog.dart';

/// Màn hình Quản lý danh mục thiết bị và bảo trì định kỳ toàn tòa nhà
class EquipmentManagementScreen extends ConsumerStatefulWidget {
  const EquipmentManagementScreen({super.key});

  @override
  ConsumerState<EquipmentManagementScreen> createState() => _EquipmentManagementScreenState();
}

class _EquipmentManagementScreenState extends ConsumerState<EquipmentManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);
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
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openAddEquipmentDialog() {
    showDialog(
      context: context,
      builder: (_) => const EquipmentFormDialog(),
    );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus == 'in_progress'
                  ? 'Đã bắt đầu bảo trì!'
                  : (newStatus == 'completed'
                      ? 'Nghiệm thu thành công! Chu kỳ bảo dưỡng tiếp theo đã được cập nhật.'
                      : 'Đã hủy phiếu bảo trì.'),
            ),
            backgroundColor: newStatus == 'completed' ? AppTheme.success : AppTheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString().replaceFirst("Exception: ", "")}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final equipmentsAsync = ref.watch(equipmentListProvider);
    final tasksAsync = ref.watch(equipmentTasksProvider(null));
    final selectedBuilding = ref.watch(equipmentFilterBuildingProvider) ?? 'Tất cả';
    final selectedCategory = ref.watch(equipmentFilterCategoryProvider) ?? 'Tất cả';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bảo trì thiết bị tòa nhà'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.precision_manufacturing), text: 'Danh mục thiết bị'),
            Tab(icon: Icon(Icons.assignment_outlined), text: 'Phiếu & Lịch bảo trì'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Bộ lọc Tòa nhà và Phân loại
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: selectedBuilding,
                      items: _buildings
                          .map((b) => DropdownMenuItem(value: b, child: Text('Tòa: $b')))
                          .toList(),
                      onChanged: (val) {
                        ref.read(equipmentFilterBuildingProvider.notifier).state =
                            val == 'Tất cả' ? null : val;
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: selectedCategory,
                      items: _categories
                          .map((c) => DropdownMenuItem(value: c['value'], child: Text(c['label']!)))
                          .toList(),
                      onChanged: (val) {
                        ref.read(equipmentFilterCategoryProvider.notifier).state =
                            val == 'Tất cả' ? null : val;
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
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Lỗi tải dữ liệu: $e')),
                  data: (equipments) => _buildEquipmentsTab(equipments),
                ),
                // Tab 2: Lịch & Phiếu bảo trì
                tasksAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Lỗi tải dữ liệu: $e')),
                  data: (tasks) => equipmentsAsync.maybeWhen(
                    data: (equipments) => _buildTasksTab(tasks, equipments),
                    orElse: () => _buildTasksTab(tasks, []),
                  ),
                ),
              ],
            ),
          ),
        ],
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
        label: Text(_tabController.index == 0 ? 'Thêm thiết bị' : 'Lập phiếu bảo trì'),
      ),
    );
  }

  Widget _buildEquipmentsTab(List<BuildingEquipmentModel> equipments) {
    final total = equipments.length;
    final operational = equipments.where((e) => e.status == 'operational').length;
    final underMaint = equipments.where((e) => e.isUnderMaintenance).length;
    final upcoming = equipments.where((e) => e.isUpcomingMaintenance).length;

    return RefreshIndicator(
      onRefresh: () async => ref.refresh(equipmentListProvider.future),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Thẻ KPI tổng quan
          Row(
            children: [
              _buildKpiCard('Tổng số', '$total', AppTheme.primary),
              const SizedBox(width: 8),
              _buildKpiCard('Hoạt động tốt', '$operational', AppTheme.success),
              const SizedBox(width: 8),
              _buildKpiCard('Đang bảo trì', '$underMaint', AppTheme.warning),
              const SizedBox(width: 8),
              _buildKpiCard('Sắp đến hạn', '$upcoming', Colors.purple),
            ],
          ),
          const SizedBox(height: 16),
          if (equipments.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text('Không có thiết bị nào phù hợp với bộ lọc.'),
              ),
            )
          else
            ...equipments.map((eq) => _buildEquipmentCard(eq)),
          const SizedBox(height: 72),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String label, String value, Color color) {
    return Expanded(
      child: AppCard(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEquipmentCard(BuildingEquipmentModel eq) {
    Color badgeColor;
    switch (eq.status) {
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

    final nextMaintText = eq.nextMaintenanceDate != null
        ? _dateFormat.format(eq.nextMaintenanceDate!)
        : 'Chưa có';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          context.push(AppRoutes.managementEquipmentDetail, extra: eq);
        },
        child: AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      eq.code,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      eq.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      eq.statusDisplayName,
                      style: TextStyle(
                        color: badgeColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 16, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${eq.location} (${eq.building})',
                      style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                    ),
                  ),
                  Text(
                    'Định kỳ: ${eq.maintenanceIntervalDays} ngày',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        eq.isOverdueMaintenance
                            ? Icons.warning_amber
                            : (eq.isUpcomingMaintenance ? Icons.alarm : Icons.event_available),
                        size: 16,
                        color: eq.isOverdueMaintenance
                            ? AppTheme.error
                            : (eq.isUpcomingMaintenance ? Colors.purple : AppTheme.textSecondary),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Hạn bảo dưỡng: $nextMaintText',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: (eq.isOverdueMaintenance || eq.isUpcomingMaintenance)
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: eq.isOverdueMaintenance
                              ? AppTheme.error
                              : (eq.isUpcomingMaintenance ? Colors.purple : AppTheme.textPrimary),
                        ),
                      ),
                    ],
                  ),
                  const Icon(Icons.chevron_right, size: 18, color: AppTheme.textSecondary),
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.assignment_turned_in_outlined, size: 64, color: AppTheme.textSecondary),
            const SizedBox(height: 16),
            const Text(
              'Chưa có phiếu bảo trì nào được lập.',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _openCreateTaskDialog(equipments),
              icon: const Icon(Icons.add),
              label: const Text('Lập phiếu mới ngay'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => ref.refresh(equipmentTasksProvider(null).future),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: tasks.length + 1,
        itemBuilder: (context, index) {
          if (index == tasks.length) return const SizedBox(height: 72);
          final task = tasks[index];
          return _buildTaskCard(task);
        },
      ),
    );
  }

  Widget _buildTaskCard(EquipmentMaintenanceTaskModel task) {
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

    final dateFormat = DateFormat('HH:mm dd/MM');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    task.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    task.statusDisplayName,
                    style: TextStyle(
                      color: badgeColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (task.equipmentName != null)
              Row(
                children: [
                  const Icon(Icons.precision_manufacturing, size: 15, color: AppTheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    '${task.equipmentCode ?? ""} - ${task.equipmentName}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.schedule, size: 15, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Text(
                  '${dateFormat.format(task.scheduledStart)} - ${dateFormat.format(task.scheduledEnd)}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                const Spacer(),
                Text(
                  _currencyFormat.format(task.cost),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            if (task.vendorName != null || task.technicianName != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.engineering_outlined, size: 15, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    task.vendorName != null
                        ? 'Nhà thầu: ${task.vendorName}'
                        : 'Kỹ thuật: ${task.technicianName}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ],
            if (task.affectsService) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 14, color: AppTheme.warning),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        task.serviceInterruptionNote ?? 'Tạm ngưng phục vụ trong thời gian bảo trì',
                        style: const TextStyle(fontSize: 12, color: AppTheme.warning),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const Divider(height: 16),
            // Nút thao tác nhanh trạng thái
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (task.status == 'pending') ...[
                  OutlinedButton.icon(
                    onPressed: () => _updateTaskStatus(task, 'cancelled'),
                    icon: const Icon(Icons.cancel_outlined, size: 16),
                    label: const Text('Hủy'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _updateTaskStatus(task, 'in_progress'),
                    icon: const Icon(Icons.play_arrow, size: 16),
                    label: const Text('Bắt đầu'),
                  ),
                ] else if (task.status == 'in_progress') ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
                    onPressed: () => _updateTaskStatus(task, 'completed'),
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('Nghiệm thu hoàn tất'),
                  ),
                ] else if (task.status == 'completed') ...[
                  const Row(
                    children: [
                      Icon(Icons.check, size: 16, color: AppTheme.success),
                      SizedBox(width: 4),
                      Text(
                        'Đã cập nhật chu kỳ kế tiếp',
                        style: TextStyle(fontSize: 12, color: AppTheme.success),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
