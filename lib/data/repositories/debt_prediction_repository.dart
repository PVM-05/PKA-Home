import '../../core/supabase_config.dart';
import '../../core/utils/guard_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/debt_risk_score_model.dart';
import '../contracts/contracts.dart';
import '../models/dunning_action_model.dart';

class DebtPredictionRepository {
  final SupabaseClient? client;

  DebtPredictionRepository({this.client});

  SupabaseClient get _supabase {
    final c = client;
    if (c != null) return c;
    if (SupabaseConfig.isConfigured) {
      return SupabaseConfig.client;
    }
    throw const AppException('Supabase chưa sẵn sàng');
  }

  /// Lấy toàn bộ radar rủi ro nợ xấu của tòa nhà
  Future<DebtRadarDataModel> getBuildingDebtRadar(String buildingId) async {
    return FailClosedGuard.guard(
      operation: 'getBuildingDebtRadar',
      call: () async {
        final res = await _supabase.rpc(
          'get_building_debt_radar',
          params: {'p_building_id': buildingId},
        );

        if (res != null && res is Map) {
          return DebtRadarDataModel.fromJson(Map<String, dynamic>.from(res));
        }
        throw const AppException(
          'Không nhận được dữ liệu radar nợ xấu từ máy chủ',
        );
      },
    );
  }

  /// Tính toán lại điểm rủi ro cho 1 căn hộ cụ thể
  Future<DebtRiskScoreModel> calculateApartmentDebtRisk({
    required String buildingId,
    required String apartmentId,
  }) async {
    return FailClosedGuard.guard(
      operation: 'calculateApartmentDebtRisk',
      call: () async {
        final reqDto = CalculateApartmentDebtRiskRequestDto(
          buildingId: buildingId,
          apartmentId: apartmentId,
        );
        final res = await _supabase.rpc(
          'calculate_apartment_debt_risk',
          params: reqDto.toRpcParams(),
        );

        if (res != null && res is Map) {
          return DebtRiskScoreModel.fromJson(Map<String, dynamic>.from(res));
        }
        throw const AppException(
          'Không nhận được dữ liệu rủi ro căn hộ từ máy chủ',
        );
      },
    );
  }

  /// Thực thi hành động đôn đốc nợ đa tầng
  Future<DunningActionModel> executeDunningAction({
    required String buildingId,
    required String apartmentId,
    required DunningTier tier,
    required String title,
    required String content,
  }) async {
    return FailClosedGuard.guard(
      operation: 'executeDunningAction',
      call: () async {
        final reqDto = ExecuteDunningActionRequestDto(
          buildingId: buildingId,
          apartmentId: apartmentId,
          tier: tier.dbValue,
          title: title,
          content: content,
        );
        final res = await _supabase.rpc(
          'execute_dunning_action',
          params: reqDto.toRpcParams(),
        );

        if (res != null && res is Map && res['action_id'] != null) {
          return DunningActionModel(
            id: res['action_id'].toString(),
            apartmentId: apartmentId,
            buildingId: buildingId,
            tier: tier,
            actionType: 'notification',
            actionTitle: title,
            actionContent: content,
            status: 'sent',
            performedBy: _supabase.auth.currentUser?.id,
            createdAt: DateTime.now(),
          );
        }
        throw const AppException('Không thể thực thi hành động đôn đốc nợ');
      },
    );
  }
}
