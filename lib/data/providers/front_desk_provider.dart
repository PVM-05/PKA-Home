import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/visitor_pass_model.dart';
import '../models/parcel_model.dart';
import '../models/front_desk_stats_model.dart';
import '../repositories/front_desk_repository.dart';

final frontDeskRepositoryProvider = Provider<FrontDeskRepository>((ref) {
  return FrontDeskRepository();
});

/// Danh sách vé khách theo bộ lọc status và apartmentId
final visitorPassesProvider = FutureProvider.family<List<VisitorPassModel>, ({String? status, String? apartmentId})>((ref, filter) async {
  final repo = ref.watch(frontDeskRepositoryProvider);
  return repo.fetchVisitorPasses(status: filter.status, apartmentId: filter.apartmentId);
});

/// Danh sách bưu kiện theo bộ lọc status và apartmentId
final parcelsProvider = FutureProvider.family<List<ParcelModel>, ({String? status, String? apartmentId})>((ref, filter) async {
  final repo = ref.watch(frontDeskRepositoryProvider);
  return repo.fetchParcels(status: filter.status, apartmentId: filter.apartmentId);
});

/// Thống kê trạm lễ tân & an ninh
final frontDeskStatsProvider = FutureProvider<FrontDeskStatsModel>((ref) async {
  final repo = ref.watch(frontDeskRepositoryProvider);
  return repo.fetchFrontDeskStats();
});
