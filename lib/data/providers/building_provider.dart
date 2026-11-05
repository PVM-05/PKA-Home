import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/supabase_config.dart';
import '../models/building_model.dart';
import '../repositories/building_repository.dart';
import 'resident_apartment_provider.dart';

final buildingRepositoryProvider = Provider<BuildingRepository>((ref) {
  return BuildingRepository();
});

/// Danh sách toàn bộ các tòa nhà đang hoạt động
final allBuildingsProvider = FutureProvider<List<BuildingModel>>((ref) async {
  final repo = ref.watch(buildingRepositoryProvider);
  return repo.getAllActiveBuildings();
});

/// Danh sách các tòa nhà mà user hiện tại được phân quyền quản lý
final userBuildingsProvider = FutureProvider<List<BuildingModel>>((ref) async {
  final repo = ref.watch(buildingRepositoryProvider);
  String? userId;
  try {
    userId = SupabaseConfig.client.auth.currentUser?.id;
  } catch (_) {}

  if (userId == null) {
    return repo.getAllActiveBuildings();
  }

  final assigned = await repo.getUserAssignedBuildings(userId);
  if (assigned.isNotEmpty) return assigned;

  return repo.getAllActiveBuildings();
});

/// Quản lý ID tòa nhà đang được chọn làm ngữ cảnh làm việc của Ban Quản Lý
class ActiveBuildingIdNotifier extends StateNotifier<String> {
  ActiveBuildingIdNotifier() : super(BuildingRepository.kDefaultCanonicalBuildingId);

  void setBuildingId(String buildingId) {
    state = buildingId;
  }
}

final activeBuildingIdProvider =
    StateNotifierProvider<ActiveBuildingIdNotifier, String>((ref) {
  return ActiveBuildingIdNotifier();
});

/// Thông tin chi tiết tòa nhà đang được chọn
final activeBuildingProvider = FutureProvider<BuildingModel?>((ref) async {
  final activeId = ref.watch(activeBuildingIdProvider);
  final repo = ref.watch(buildingRepositoryProvider);
  return repo.getBuildingById(activeId);
});

/// Thông tin chi tiết tòa nhà của căn hộ cư dân đang chọn
final residentBuildingProvider = FutureProvider<BuildingModel?>((ref) async {
  final buildingId = ref.watch(residentBuildingIdProvider);
  if (buildingId == null || buildingId.isEmpty) return null;
  final repo = ref.watch(buildingRepositoryProvider);
  return repo.getBuildingById(buildingId);
});

/// Provider tìm kiếm thông tin tòa nhà theo ID
final buildingByIdProvider = FutureProvider.family<BuildingModel?, String>((ref, buildingId) async {
  if (buildingId.isEmpty) return null;
  final repo = ref.watch(buildingRepositoryProvider);
  return repo.getBuildingById(buildingId);
});
