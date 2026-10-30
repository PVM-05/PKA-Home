import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/subscription_model.dart';
import '../models/subscription_plan_model.dart';
import '../repositories/building_repository.dart';
import '../repositories/subscription_repository.dart';
import 'building_provider.dart';

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  return SubscriptionRepository();
});

/// Provider nạp trạng thái gói thuê bao và hạn mức của tòa nhà đang hoạt động
final subscriptionStatusProvider = FutureProvider<SubscriptionStatusModel>((ref) async {
  final repo = ref.watch(subscriptionRepositoryProvider);
  final activeBuilding = ref.watch(activeBuildingProvider).value;
  final buildingId = activeBuilding?.id ?? BuildingRepository.kDefaultCanonicalBuildingId;

  return repo.fetchSubscriptionStatus(buildingId: buildingId);
});

/// Provider nạp danh sách các gói cước đang mở bán
final availablePlansProvider = FutureProvider<List<SubscriptionPlanModel>>((ref) async {
  final repo = ref.watch(subscriptionRepositoryProvider);
  return repo.fetchAvailablePlans();
});

