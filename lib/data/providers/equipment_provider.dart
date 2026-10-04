import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/building_equipment_model.dart';
import '../models/equipment_maintenance_task_model.dart';
import '../repositories/equipment_repository.dart';

/// Bộ lọc tòa nhà
final equipmentFilterBuildingProvider = StateProvider<String?>((ref) => null);

/// Bộ lọc phân loại thiết bị
final equipmentFilterCategoryProvider = StateProvider<String?>((ref) => null);

/// Bộ lọc trạng thái thiết bị
final equipmentFilterStatusProvider = StateProvider<String?>((ref) => null);

/// Danh sách thiết bị tòa nhà áp dụng các bộ lọc hiện tại
final equipmentListProvider = FutureProvider<List<BuildingEquipmentModel>>((ref) async {
  final repo = ref.watch(equipmentRepositoryProvider);
  final building = ref.watch(equipmentFilterBuildingProvider);
  final category = ref.watch(equipmentFilterCategoryProvider);
  final status = ref.watch(equipmentFilterStatusProvider);

  return repo.getEquipments(
    building: building,
    category: category,
    status: status,
  );
});

/// Danh sách phiếu bảo trì (có thể lọc theo equipmentId hoặc toàn bộ)
final equipmentTasksProvider =
    FutureProvider.family<List<EquipmentMaintenanceTaskModel>, String?>((ref, equipmentId) async {
  final repo = ref.watch(equipmentRepositoryProvider);
  final building = ref.watch(equipmentFilterBuildingProvider);
  return repo.getMaintenanceTasks(
    equipmentId: equipmentId,
    building: building,
  );
});

/// Chi tiết 1 thiết bị cụ thể theo ID
final equipmentDetailProvider =
    FutureProvider.family<BuildingEquipmentModel, String>((ref, id) async {
  final repo = ref.watch(equipmentRepositoryProvider);
  return repo.getEquipmentById(id);
});

/// Danh sách thiết bị sắp đến hạn bảo dưỡng trong 7 ngày tới
final upcomingMaintenanceEquipmentsProvider =
    FutureProvider<List<BuildingEquipmentModel>>((ref) async {
  final repo = ref.watch(equipmentRepositoryProvider);
  return repo.getUpcomingMaintenanceEquipments(daysAhead: 7);
});

/// Danh sách thiết bị đang bảo trì gián đoạn dịch vụ thuộc tòa nhà của cư dân
final activeServiceInterruptionsProvider =
    FutureProvider.family<List<EquipmentMaintenanceTaskModel>, String>((ref, building) async {
  final repo = ref.watch(equipmentRepositoryProvider);
  return repo.getActiveServiceInterruptions(building: building);
});
