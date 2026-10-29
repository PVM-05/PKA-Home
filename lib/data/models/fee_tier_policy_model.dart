import 'package:intl/intl.dart';

/// Các loại chính sách biểu giá phí trong hệ thống PKA-Home
enum FeePolicyType {
  electricityTier,
  waterQuotaTier,
  parkingProrata,
  latePaymentPenalty,
  managementFee;

  static FeePolicyType fromString(String? val) {
    if (val == null) return FeePolicyType.electricityTier;
    switch (val.toUpperCase().trim()) {
      case 'ELECTRICITY_TIER':
        return FeePolicyType.electricityTier;
      case 'WATER_QUOTA_TIER':
        return FeePolicyType.waterQuotaTier;
      case 'PARKING_PRORATA':
        return FeePolicyType.parkingProrata;
      case 'LATE_PAYMENT_PENALTY':
        return FeePolicyType.latePaymentPenalty;
      case 'MANAGEMENT_FEE':
        return FeePolicyType.managementFee;
      default:
        return FeePolicyType.electricityTier;
    }
  }

  String toDbString() {
    switch (this) {
      case FeePolicyType.electricityTier:
        return 'ELECTRICITY_TIER';
      case FeePolicyType.waterQuotaTier:
        return 'WATER_QUOTA_TIER';
      case FeePolicyType.parkingProrata:
        return 'PARKING_PRORATA';
      case FeePolicyType.latePaymentPenalty:
        return 'LATE_PAYMENT_PENALTY';
      case FeePolicyType.managementFee:
        return 'MANAGEMENT_FEE';
    }
  }

  String get dbValue => toDbString();

  String get vietnameseName {
    switch (this) {
      case FeePolicyType.electricityTier:
        return 'Điện sinh hoạt lũy tiến';
      case FeePolicyType.waterQuotaTier:
        return 'Nước sinh hoạt định mức';
      case FeePolicyType.parkingProrata:
        return 'Phí gửi xe theo ngày';
      case FeePolicyType.latePaymentPenalty:
        return 'Lãi phạt trễ hạn';
      case FeePolicyType.managementFee:
        return 'Phí quản lý';
    }
  }
}

/// Phương pháp tính toán giá
enum FeeCalculationMethod {
  progressiveTier,
  perCapitaQuota,
  proRataDaily,
  percentageDaily,
  flatRate;

  static FeeCalculationMethod fromString(String? val) {
    if (val == null) return FeeCalculationMethod.flatRate;
    switch (val.toUpperCase().trim()) {
      case 'PROGRESSIVE_TIER':
        return FeeCalculationMethod.progressiveTier;
      case 'PER_CAPITA_QUOTA':
        return FeeCalculationMethod.perCapitaQuota;
      case 'PRO_RATA_DAILY':
        return FeeCalculationMethod.proRataDaily;
      case 'PERCENTAGE_DAILY':
        return FeeCalculationMethod.percentageDaily;
      case 'FLAT_RATE':
        return FeeCalculationMethod.flatRate;
      default:
        return FeeCalculationMethod.flatRate;
    }
  }

  String toDbString() {
    switch (this) {
      case FeeCalculationMethod.progressiveTier:
        return 'PROGRESSIVE_TIER';
      case FeeCalculationMethod.perCapitaQuota:
        return 'PER_CAPITA_QUOTA';
      case FeeCalculationMethod.proRataDaily:
        return 'PRO_RATA_DAILY';
      case FeeCalculationMethod.percentageDaily:
        return 'PERCENTAGE_DAILY';
      case FeeCalculationMethod.flatRate:
        return 'FLAT_RATE';
    }
  }

  String get dbValue => toDbString();

  String get vietnameseName {
    switch (this) {
      case FeeCalculationMethod.progressiveTier:
        return 'Lũy tiến nhiều bậc';
      case FeeCalculationMethod.perCapitaQuota:
        return 'Định mức theo nhân khẩu';
      case FeeCalculationMethod.proRataDaily:
        return 'Tỷ lệ theo ngày thực tế';
      case FeeCalculationMethod.percentageDaily:
        return 'Tỷ lệ phần trăm theo ngày';
      case FeeCalculationMethod.flatRate:
        return 'Cố định hàng tháng';
    }
  }
}

/// Model quản lý chính sách biểu giá phí (fee_tier_policies)
class FeeTierPolicyModel {
  final String id;
  final String? buildingId;
  final FeePolicyType policyType;
  final String name;
  final FeeCalculationMethod calculationMethod;
  final dynamic tiers;
  final DateTime effectiveFrom;
  final DateTime? effectiveTo;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const FeeTierPolicyModel({
    required this.id,
    this.buildingId,
    required this.policyType,
    required this.name,
    required this.calculationMethod,
    required this.tiers,
    required this.effectiveFrom,
    this.effectiveTo,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  factory FeeTierPolicyModel.fromJson(Map<String, dynamic> json) {
    return FeeTierPolicyModel(
      id: json['id'] as String? ?? '',
      buildingId: json['building_id'] as String?,
      policyType: FeePolicyType.fromString(json['policy_type'] as String?),
      name: json['name'] as String? ?? '',
      calculationMethod: FeeCalculationMethod.fromString(
        json['calculation_method'] as String?,
      ),
      tiers: json['tiers'],
      effectiveFrom: json['effective_from'] != null
          ? DateTime.tryParse(json['effective_from'].toString()) ?? DateTime.now()
          : DateTime.now(),
      effectiveTo: json['effective_to'] != null
          ? DateTime.tryParse(json['effective_to'].toString())
          : null,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'building_id': buildingId,
      'policy_type': policyType.toDbString(),
      'name': name,
      'calculation_method': calculationMethod.toDbString(),
      'tiers': tiers,
      'effective_from': DateFormat('yyyy-MM-dd').format(effectiveFrom),
      'effective_to': effectiveTo != null
          ? DateFormat('yyyy-MM-dd').format(effectiveTo!)
          : null,
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  FeeTierPolicyModel copyWith({
    String? id,
    String? buildingId,
    FeePolicyType? policyType,
    String? name,
    FeeCalculationMethod? calculationMethod,
    dynamic tiers,
    DateTime? effectiveFrom,
    DateTime? effectiveTo,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FeeTierPolicyModel(
      id: id ?? this.id,
      buildingId: buildingId ?? this.buildingId,
      policyType: policyType ?? this.policyType,
      name: name ?? this.name,
      calculationMethod: calculationMethod ?? this.calculationMethod,
      tiers: tiers ?? this.tiers,
      effectiveFrom: effectiveFrom ?? this.effectiveFrom,
      effectiveTo: effectiveTo ?? this.effectiveTo,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get statusVietnamese => isActive ? 'Đang áp dụng' : 'Tạm ngưng';

  String get policyTypeVietnamese => policyType.vietnameseName;

  String get calculationMethodVietnamese => calculationMethod.vietnameseName;

  String get formattedEffectiveRange {
    final fromStr = DateFormat('dd/MM/yyyy').format(effectiveFrom);
    final toStr = effectiveTo != null
        ? DateFormat('dd/MM/yyyy').format(effectiveTo!)
        : 'Hiện tại';
    return '$fromStr - $toStr';
  }
}
