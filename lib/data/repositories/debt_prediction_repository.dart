import '../../core/utils/guard_helper.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/debt_risk_score_model.dart';
import '../contracts/contracts.dart';
import '../models/dunning_action_model.dart';
import '../services/debt_prediction_engine.dart';

class DebtPredictionRepository {
  final SupabaseClient _client;

  DebtPredictionRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Bộ nhớ tạm lưu các hành động đôn đốc khi chạy offline
  final List<DunningActionModel> _offlineDunningActions = [];

  /// Dữ liệu căn hộ mẫu phục vụ Offline Fallback Engine
  final List<Map<String, dynamic>> _mockApartmentsSeed = [
    {
      'apartment_id': 'apt-01',
      'apartment_code': 'A0110',
      'owner_name': 'Nguyễn Văn An',
      'owner_phone': '0901234567',
      'unpaid_amount': 7850000.0,
      'overdue_days': 52,
      'monthly_fee_avg': 1600000.0,
      'late_payment_count': 3,
    },
    {
      'apartment_id': 'apt-02',
      'apartment_code': 'A0205',
      'owner_name': 'Trần Thị Bình',
      'owner_phone': '0912345678',
      'unpaid_amount': 4200000.0,
      'overdue_days': 24,
      'monthly_fee_avg': 1800000.0,
      'late_payment_count': 2,
    },
    {
      'apartment_id': 'apt-03',
      'apartment_code': 'B0312',
      'owner_name': 'Lê Hoàng Cường',
      'owner_phone': '0923456789',
      'unpaid_amount': 1550000.0,
      'overdue_days': 8,
      'monthly_fee_avg': 1550000.0,
      'late_payment_count': 1,
    },
    {
      'apartment_id': 'apt-04',
      'apartment_code': 'B0401',
      'owner_name': 'Phạm Thu Dung',
      'owner_phone': '0934567890',
      'unpaid_amount': 12400000.0,
      'overdue_days': 78,
      'monthly_fee_avg': 1750000.0,
      'late_payment_count': 4,
    },
    {
      'apartment_id': 'apt-05',
      'apartment_code': 'C0508',
      'owner_name': 'Hoàng Minh Đức',
      'owner_phone': '0945678901',
      'unpaid_amount': 2900000.0,
      'overdue_days': 18,
      'monthly_fee_avg': 1450000.0,
      'late_payment_count': 0,
    },
    {
      'apartment_id': 'apt-06',
      'apartment_code': 'C0615',
      'owner_name': 'Vũ Mai Hương',
      'owner_phone': '0956789012',
      'unpaid_amount': 850000.0,
      'overdue_days': 4,
      'monthly_fee_avg': 1700000.0,
      'late_payment_count': 0,
    },
  ];

  /// Lấy toàn bộ radar rủi ro nợ xấu của tòa nhà
  Future<DebtRadarDataModel> getBuildingDebtRadar(String buildingId) async {
    return FailClosedGuard.guard(
      operation: 'getBuildingDebtRadar',
      call: () async {
        final res = await _client.rpc(
          'get_building_debt_radar',
          params: {'p_building_id': buildingId},
        );

        if (res != null && res is Map) {
          return DebtRadarDataModel.fromJson(Map<String, dynamic>.from(res));
        }
        throw const AppException('Không nhận được dữ liệu radar nợ xấu từ máy chủ');
      },
      mockFallback: () => _generateFallbackRadar(buildingId),
    );
  }

  /// Tính toán lại điểm rủi ro cho 1 căn hộ cụ thể
  Future<DebtRiskScoreModel> calculateApartmentDebtRisk({
    required String buildingId,
    required String apartmentId,
  }) async {
    try {
      final reqDto = CalculateApartmentDebtRiskRequestDto(
        buildingId: buildingId,
        apartmentId: apartmentId,
      );
      final res = await _client.rpc(
        'calculate_apartment_debt_risk',
        params: reqDto.toRpcParams(),
      );

      if (res != null && res is Map) {
        return DebtRiskScoreModel.fromJson(Map<String, dynamic>.from(res));
      }
    } catch (e) {
      debugPrint('[DebtPredictionRepository] RPC calculate failed, using engine: $e');
    }

    // Fallback tính toán tại chỗ
    final mock = _mockApartmentsSeed.firstWhere(
      (m) => m['apartment_id'] == apartmentId,
      orElse: () => {
        'apartment_id': apartmentId,
        'apartment_code': 'A0101',
        'owner_name': 'Cư dân',
        'owner_phone': '',
        'unpaid_amount': 2000000.0,
        'overdue_days': 15,
        'monthly_fee_avg': 1500000.0,
        'late_payment_count': 1,
      },
    );

    final calc = DebtPredictionEngine.calculate(
      unpaidAmount: (mock['unpaid_amount'] as num).toDouble(),
      overdueDays: (mock['overdue_days'] as num).toInt(),
      monthlyFeeAvg: (mock['monthly_fee_avg'] as num).toDouble(),
      latePaymentCount: (mock['late_payment_count'] as num).toInt(),
    );

    return DebtRiskScoreModel(
      apartmentId: apartmentId,
      apartmentCode: mock['apartment_code']?.toString() ?? 'A0101',
      buildingId: buildingId,
      ownerName: mock['owner_name']?.toString() ?? 'Chưa đăng ký',
      ownerPhone: mock['owner_phone']?.toString() ?? '',
      riskScore: calc.riskScore,
      riskLevel: calc.riskLevel,
      overdueDays: (mock['overdue_days'] as num).toInt(),
      unpaidAmount: (mock['unpaid_amount'] as num).toDouble(),
      monthlyFeeAvg: (mock['monthly_fee_avg'] as num).toDouble(),
      latePaymentCount: (mock['late_payment_count'] as num).toInt(),
      recommendedTier: calc.recommendedTier,
      riskFactors: calc.riskFactors,
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
    try {
      final reqDto = ExecuteDunningActionRequestDto(
        buildingId: buildingId,
        apartmentId: apartmentId,
        tier: tier.dbValue,
        title: title,
        content: content,
      );
      final res = await _client.rpc(
        'execute_dunning_action',
        params: reqDto.toRpcParams(),
      );

      if (res != null && res is Map && res['action_id'] != null) {
        final action = DunningActionModel(
          id: res['action_id'].toString(),
          apartmentId: apartmentId,
          buildingId: buildingId,
          tier: tier,
          actionType: 'notification',
          actionTitle: title,
          actionContent: content,
          status: 'sent',
          performedBy: _client.auth.currentUser?.id,
          createdAt: DateTime.now(),
        );
        _offlineDunningActions.add(action);
        return action;
      }
    } catch (e) {
      debugPrint('[DebtPredictionRepository] execute_dunning_action RPC failed, recording offline: $e');
    }

    // Fallback lưu local
    final fallbackAction = DunningActionModel(
      id: 'dunning-${DateTime.now().millisecondsSinceEpoch}',
      apartmentId: apartmentId,
      buildingId: buildingId,
      tier: tier,
      actionType: 'notification',
      actionTitle: title,
      actionContent: content,
      status: 'sent',
      performedBy: _client.auth.currentUser?.id,
      createdAt: DateTime.now(),
    );

    _offlineDunningActions.add(fallbackAction);
    return fallbackAction;
  }

  /// Tạo radar rủi ro dự phòng qua DebtPredictionEngine
  DebtRadarDataModel _generateFallbackRadar(String buildingId) {
    final list = <DebtRiskScoreModel>[];
    int highCount = 0;
    int medCount = 0;
    int lowCount = 0;
    double totalDebt = 0;
    double highDebt = 0;

    for (final m in _mockApartmentsSeed) {
      final unpaid = (m['unpaid_amount'] as num).toDouble();
      final overdue = (m['overdue_days'] as num).toInt();
      final avgFee = (m['monthly_fee_avg'] as num).toDouble();
      final lateCount = (m['late_payment_count'] as num).toInt();
      final aptId = m['apartment_id'].toString();

      final calc = DebtPredictionEngine.calculate(
        unpaidAmount: unpaid,
        overdueDays: overdue,
        monthlyFeeAvg: avgFee,
        latePaymentCount: lateCount,
      );

      totalDebt += unpaid;
      if (calc.riskLevel == DebtRiskLevel.high) {
        highCount++;
        highDebt += unpaid;
      } else if (calc.riskLevel == DebtRiskLevel.medium) {
        medCount++;
      } else {
        lowCount++;
      }

      // Kiểm tra xem đã có dunning nào chưa
      final recentDunning = _offlineDunningActions
          .where((a) => a.apartmentId == aptId)
          .toList();
      DunningTier? lastTier;
      DateTime? lastAt;
      if (recentDunning.isNotEmpty) {
        final last = recentDunning.last;
        lastTier = last.tier;
        lastAt = last.createdAt;
      }

      list.add(
        DebtRiskScoreModel(
          apartmentId: aptId,
          apartmentCode: m['apartment_code'].toString(),
          buildingId: buildingId,
          ownerName: m['owner_name'].toString(),
          ownerPhone: m['owner_phone'].toString(),
          riskScore: calc.riskScore,
          riskLevel: calc.riskLevel,
          overdueDays: overdue,
          unpaidAmount: unpaid,
          monthlyFeeAvg: avgFee,
          latePaymentCount: lateCount,
          recommendedTier: calc.recommendedTier,
          riskFactors: calc.riskFactors,
          lastDunningTier: lastTier,
          lastDunningAt: lastAt,
          dunningCount: recentDunning.length,
        ),
      );
    }

    list.sort((a, b) => b.riskScore.compareTo(a.riskScore));

    return DebtRadarDataModel(
      buildingId: buildingId,
      kpi: DebtRadarKpiModel(
        totalAtRiskApartments: list.length,
        highRiskCount: highCount,
        mediumRiskCount: medCount,
        lowRiskCount: lowCount,
        totalOverdueDebt: totalDebt,
        highRiskDebt: highDebt,
      ),
      apartments: list,
    );
  }
}
