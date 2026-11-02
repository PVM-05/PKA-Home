import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/maintenance_material_model.dart';
import '../models/issue_material_usage_model.dart';
import '../models/issue_sla_stats_model.dart';
import '../repositories/material_repository.dart';

final materialRepositoryProvider = Provider<MaterialRepository>((ref) {
  return MaterialRepository();
});

/// Danh sách vật tư trong kho theo bộ lọc category
final maintenanceMaterialsProvider = FutureProvider.family<List<MaintenanceMaterialModel>, String?>((ref, category) async {
  final repo = ref.watch(materialRepositoryProvider);
  return repo.fetchMaterials(category: category);
});

/// Danh sách vật tư của 1 sự cố cụ thể
final issueMaterialsProvider = FutureProvider.family<List<IssueMaterialUsageModel>, String>((ref, issueId) async {
  final repo = ref.watch(materialRepositoryProvider);
  return repo.fetchIssueMaterials(issueId);
});

/// Thống kê SLA toàn tòa nhà
final issueSlaStatsProvider = FutureProvider<IssueSlaStatsModel>((ref) async {
  final repo = ref.watch(materialRepositoryProvider);
  return repo.fetchSlaStats();
});
