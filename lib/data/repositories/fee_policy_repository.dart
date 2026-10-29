import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_config.dart';
import '../../core/utils/utility_fee_calculator.dart';
import '../models/fee_tier_policy_model.dart';
import '../models/tiered_calculation_result_model.dart';

/// Repository quản lý chính sách biểu giá phí và gọi các RPC tính toán phí lũy tiến/định mức/pro-rata/lãi phạt
class FeePolicyRepository {
  final SupabaseClient? _injectedClient;

  FeePolicyRepository([SupabaseClient? client]) : _injectedClient = client;

  FeePolicyRepository.withClient({SupabaseClient? client}) : _injectedClient = client;

  SupabaseClient? get _client {
    if (_injectedClient != null) return _injectedClient;
    try {
      return SupabaseConfig.client;
    } catch (_) {
      return null;
    }
  }

  /// Phân tích danh sách Map sang danh sách [FeeTierPolicyModel]
  List<FeeTierPolicyModel> parsePolicies(List<dynamic> list) {
    return list
        .map((item) => FeeTierPolicyModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Phân tích dữ liệu phản hồi sang [TieredCalculationResultModel]
  TieredCalculationResultModel parseTieredResult(dynamic data) {
    if (data is Map<String, dynamic>) {
      return TieredCalculationResultModel.fromJson(data);
    }
    if (data is Map) {
      return TieredCalculationResultModel.fromJson(Map<String, dynamic>.from(data));
    }
    throw ArgumentError('Dữ liệu không hợp lệ cho TieredCalculationResultModel');
  }

  /// Phân tích dữ liệu phản hồi sang [ProratedFeeResultModel]
  ProratedFeeResultModel parseProratedResult(dynamic data) {
    if (data is Map<String, dynamic>) {
      return ProratedFeeResultModel.fromJson(data);
    }
    if (data is Map) {
      return ProratedFeeResultModel.fromJson(Map<String, dynamic>.from(data));
    }
    throw ArgumentError('Dữ liệu không hợp lệ cho ProratedFeeResultModel');
  }

  /// Phân tích dữ liệu phản hồi sang [LatePenaltyResultModel]
  LatePenaltyResultModel parseLatePenaltyResult(dynamic data) {
    if (data is Map<String, dynamic>) {
      return LatePenaltyResultModel.fromJson(data);
    }
    if (data is Map) {
      return LatePenaltyResultModel.fromJson(Map<String, dynamic>.from(data));
    }
    throw ArgumentError('Dữ liệu không hợp lệ cho LatePenaltyResultModel');
  }

  /// Lấy danh sách chính sách biểu giá đang áp dụng cho tòa nhà hoặc toàn hệ thống
  Future<List<FeeTierPolicyModel>> fetchPolicies({
    String? buildingId,
    FeePolicyType? policyType,
  }) async {
    final client = _client;
    if (client == null) return [];

    try {
      var query = client.from('fee_tier_policies').select().eq('is_active', true);
      if (buildingId != null) {
        query = query.or('building_id.eq.$buildingId,building_id.is.null');
      }
      if (policyType != null) {
        query = query.eq('policy_type', policyType.toDbString());
      }

      final response = await query.order('effective_from', ascending: false);
      return parsePolicies(response as List<dynamic>);
    } catch (_) {
      return [];
    }
  }

  /// Tính tiền điện sinh hoạt theo 6 bậc lũy tiến chuẩn EVN
  /// Gọi RPC `calculate_progressive_electricity_fee` trên Supabase với fallback tự động sang [UtilityFeeCalculator]
  Future<TieredCalculationResultModel> calculateElectricityFee(
    num consumption, {
    String? buildingId,
  }) async {
    final client = _client;
    if (client != null) {
      try {
        final response = await client.rpc(
          'calculate_progressive_electricity_fee',
          params: {
            'p_consumption': consumption,
            'p_building_id': ?buildingId,
          },
        );
        if (response != null) {
          return parseTieredResult(response);
        }
      } catch (_) {
        // Tự động fallback sang tính toán cục bộ offline khi gặp lỗi mạng/RPC
      }
    }

    return UtilityFeeCalculator.calculateElectricityEVN6Tiers(consumption);
  }

  /// Tính tiền nước theo định mức nhân khẩu
  /// Gọi RPC `calculate_quota_water_fee` trên Supabase với fallback tự động sang [UtilityFeeCalculator]
  Future<TieredCalculationResultModel> calculateWaterFee(
    num consumption, {
    int residentCount = 1,
    String? buildingId,
  }) async {
    final client = _client;
    if (client != null) {
      try {
        final response = await client.rpc(
          'calculate_quota_water_fee',
          params: {
            'p_consumption': consumption,
            'p_resident_count': residentCount,
            'p_building_id': ?buildingId,
          },
        );
        if (response != null) {
          return parseTieredResult(response);
        }
      } catch (_) {
        // Tự động fallback sang tính toán cục bộ offline khi gặp lỗi mạng/RPC
      }
    }

    return UtilityFeeCalculator.calculateWaterQuota(
      consumption: consumption,
      residentCount: residentCount,
    );
  }

  /// Tính phí gửi xe/dịch vụ theo tỷ lệ ngày sử dụng thực tế trong tháng (Pro-rata)
  /// Gọi RPC `calculate_prorated_vehicle_fee` trên Supabase với fallback tự động sang [UtilityFeeCalculator]
  Future<ProratedFeeResultModel> calculateProratedVehicleFee({
    required num monthlyRate,
    required DateTime? startDate,
    required String period,
  }) async {
    final client = _client;
    if (client != null) {
      try {
        final response = await client.rpc(
          'calculate_prorated_vehicle_fee',
          params: {
            'p_monthly_rate': monthlyRate,
            'p_start_date': startDate != null ? DateFormat('yyyy-MM-dd').format(startDate) : null,
            'p_period': period,
          },
        );
        if (response != null) {
          return parseProratedResult(response);
        }
      } catch (_) {
        // Tự động fallback sang tính toán cục bộ offline khi gặp lỗi mạng/RPC
      }
    }

    return UtilityFeeCalculator.calculateProratedVehicleFee(
      monthlyRate: monthlyRate,
      startDate: startDate,
      period: period,
    );
  }

  /// Alias tiện ích cho [calculateProratedVehicleFee]
  Future<ProratedFeeResultModel> calculateProratedParkingFee({
    required num monthlyRate,
    required DateTime? startDate,
    required String period,
  }) =>
      calculateProratedVehicleFee(
        monthlyRate: monthlyRate,
        startDate: startDate,
        period: period,
      );

  /// Tính lãi phạt chậm thanh toán cho hóa đơn quá hạn
  /// Gọi RPC `calculate_late_payment_penalty` trên Supabase
  Future<LatePenaltyResultModel> calculateLatePaymentPenalty({
    required String invoiceId,
    DateTime? asOfDate,
  }) async {
    final client = _client;
    if (client == null) {
      throw Exception('Không có kết nối cơ sở dữ liệu để tính lãi phạt trễ hạn');
    }

    final response = await client.rpc(
      'calculate_late_payment_penalty',
      params: {
        'p_invoice_id': invoiceId,
        if (asOfDate != null) 'p_as_of_date': DateFormat('yyyy-MM-dd').format(asOfDate),
      },
    );

    if (response == null) {
      throw Exception('Không nhận được dữ liệu phản hồi từ RPC tính lãi phạt trễ hạn');
    }

    return parseLatePenaltyResult(response);
  }

  /// Alias tiện ích cho [calculateLatePaymentPenalty]
  Future<LatePenaltyResultModel> calculateLatePenalty(
    String invoiceId, {
    DateTime? asOfDate,
  }) =>
      calculateLatePaymentPenalty(
        invoiceId: invoiceId,
        asOfDate: asOfDate,
      );
}
