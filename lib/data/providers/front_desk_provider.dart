import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/visitor_pass_model.dart';
import '../models/parcel_model.dart';
import '../models/front_desk_stats_model.dart';
import '../repositories/front_desk_repository.dart';
import 'building_provider.dart';
import 'management_provider.dart';

final frontDeskRepositoryProvider = Provider<FrontDeskRepository>((ref) {
  return FrontDeskRepository();
});

/// Danh sách vé khách theo bộ lọc status và apartmentId (tự lọc theo tòa nhà đang chọn)
final visitorPassesProvider = FutureProvider.family<List<VisitorPassModel>, ({String? status, String? apartmentId})>((ref, filter) async {
  final repo = ref.watch(frontDeskRepositoryProvider);
  final effectiveBuildingId = ref.watch(effectiveBuildingIdProvider);
  final passes = await repo.fetchVisitorPasses(status: filter.status, apartmentId: filter.apartmentId);
  if (filter.apartmentId != null || effectiveBuildingId == null) {
    return passes;
  }
  final apts = await ref.watch(apartmentsProvider.future);
  final allowedAptIds = apts.map((a) => a.id).toSet();
  return passes.where((p) => allowedAptIds.contains(p.apartmentId)).toList();
});

/// Danh sách bưu kiện theo bộ lọc status và apartmentId (tự lọc theo tòa nhà đang chọn)
final parcelsProvider = FutureProvider.family<List<ParcelModel>, ({String? status, String? apartmentId})>((ref, filter) async {
  final repo = ref.watch(frontDeskRepositoryProvider);
  final effectiveBuildingId = ref.watch(effectiveBuildingIdProvider);
  final parcels = await repo.fetchParcels(status: filter.status, apartmentId: filter.apartmentId);
  if (filter.apartmentId != null || effectiveBuildingId == null) {
    return parcels;
  }
  final apts = await ref.watch(apartmentsProvider.future);
  final allowedAptIds = apts.map((a) => a.id).toSet();
  return parcels.where((p) => allowedAptIds.contains(p.apartmentId)).toList();
});

/// Thống kê trạm lễ tân & an ninh
final frontDeskStatsProvider = FutureProvider<FrontDeskStatsModel>((ref) async {
  final repo = ref.watch(frontDeskRepositoryProvider);
  final effectiveBuildingId = ref.watch(effectiveBuildingIdProvider);
  return repo.fetchFrontDeskStats(buildingId: effectiveBuildingId);
});

/// Danh sách vé khách của một căn hộ dành cho Cư dân
final residentVisitorPassesProvider = FutureProvider.family<List<VisitorPassModel>, String>((ref, apartmentId) async {
  final repo = ref.watch(frontDeskRepositoryProvider);
  return repo.fetchVisitorPasses(apartmentId: apartmentId);
});

/// Danh sách bưu kiện của một căn hộ dành cho Cư dân
final residentParcelsProvider = FutureProvider.family<List<ParcelModel>, String>((ref, apartmentId) async {
  final repo = ref.watch(frontDeskRepositoryProvider);
  return repo.fetchParcels(apartmentId: apartmentId);
});

