import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/debt_risk_score_model.dart';
import '../repositories/debt_prediction_repository.dart';

final debtPredictionRepositoryProvider = Provider<DebtPredictionRepository>((ref) {
  return DebtPredictionRepository();
});

/// Filter trạng thái rủi ro trên UI: 'all', 'high', 'medium', 'low'
final debtRiskFilterProvider = StateProvider<String>((ref) => 'all');

/// Tìm kiếm căn hộ hoặc chủ hộ
final debtRiskSearchQueryProvider = StateProvider<String>((ref) => '');

/// Radar dữ liệu nợ xấu thời gian thực của tòa nhà
final buildingDebtRadarProvider =
    FutureProvider.family<DebtRadarDataModel, String>((ref, buildingId) async {
  final repo = ref.watch(debtPredictionRepositoryProvider);
  return repo.getBuildingDebtRadar(buildingId);
});

/// Danh sách căn hộ đã được lọc theo filter và search query
final filteredDebtRiskApartmentsProvider =
    Provider.family<List<DebtRiskScoreModel>, String>((ref, buildingId) {
  final radarAsync = ref.watch(buildingDebtRadarProvider(buildingId));
  final filter = ref.watch(debtRiskFilterProvider);
  final query = ref.watch(debtRiskSearchQueryProvider).trim().toLowerCase();

  return radarAsync.maybeWhen(
    data: (radar) {
      return radar.apartments.where((apt) {
        // Lọc theo level
        if (filter == 'high' && apt.riskLevel != DebtRiskLevel.high) return false;
        if (filter == 'medium' && apt.riskLevel != DebtRiskLevel.medium) return false;
        if (filter == 'low' && apt.riskLevel != DebtRiskLevel.low) return false;

        // Lọc theo search
        if (query.isNotEmpty) {
          final matchCode = apt.apartmentCode.toLowerCase().contains(query);
          final matchName = apt.ownerName.toLowerCase().contains(query);
          final matchPhone = apt.ownerPhone.toLowerCase().contains(query);
          if (!matchCode && !matchName && !matchPhone) return false;
        }

        return true;
      }).toList();
    },
    orElse: () => [],
  );
});
