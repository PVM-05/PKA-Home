import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/apartment_asset_model.dart';
import '../models/apartment_handover_model.dart';
import '../repositories/handover_repository.dart';

final handoverRepositoryProvider = Provider<HandoverRepository>((ref) {
  return HandoverRepository();
});

final apartmentAssetsProvider = FutureProvider.family<List<ApartmentAssetModel>, String>((ref, apartmentId) async {
  final repo = ref.watch(handoverRepositoryProvider);
  return repo.fetchAssetsByApartment(apartmentId);
});

final buildingHandoversProvider = FutureProvider.family<List<ApartmentHandoverModel>, String>((ref, buildingId) async {
  final repo = ref.watch(handoverRepositoryProvider);
  return repo.fetchHandoversByBuilding(buildingId);
});

final residentHandoversProvider = FutureProvider.family<List<ApartmentHandoverModel>, String>((ref, residentId) async {
  final repo = ref.watch(handoverRepositoryProvider);
  return repo.fetchHandoversByResident(residentId);
});

final handoverDetailProvider = FutureProvider.family<ApartmentHandoverModel?, String>((ref, handoverId) async {
  final repo = ref.watch(handoverRepositoryProvider);
  return repo.fetchHandoverDetail(handoverId);
});

