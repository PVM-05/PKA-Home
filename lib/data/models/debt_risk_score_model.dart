import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

enum DebtRiskLevel {
  low,
  medium,
  high;

  String get label {
    switch (this) {
      case DebtRiskLevel.low:
        return 'An toàn';
      case DebtRiskLevel.medium:
        return 'Cần chú ý';
      case DebtRiskLevel.high:
        return 'Rủi ro cao';
    }
  }

  Color get color {
    switch (this) {
      case DebtRiskLevel.low:
        return AppTheme.success;
      case DebtRiskLevel.medium:
        return AppTheme.warning;
      case DebtRiskLevel.high:
        return AppTheme.error;
    }
  }

  static DebtRiskLevel fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'high':
        return DebtRiskLevel.high;
      case 'medium':
        return DebtRiskLevel.medium;
      case 'low':
      default:
        return DebtRiskLevel.low;
    }
  }
}

enum DunningTier {
  tier1,
  tier2,
  tier3;

  String get dbValue {
    switch (this) {
      case DunningTier.tier1:
        return 'tier_1';
      case DunningTier.tier2:
        return 'tier_2';
      case DunningTier.tier3:
        return 'tier_3';
    }
  }

  String get shortName {
    switch (this) {
      case DunningTier.tier1:
        return 'Tầng 1';
      case DunningTier.tier2:
        return 'Tầng 2';
      case DunningTier.tier3:
        return 'Tầng 3';
    }
  }

  String get label {
    switch (this) {
      case DunningTier.tier1:
        return 'Tầng 1 - Nhắc nhở lịch sự';
      case DunningTier.tier2:
        return 'Tầng 2 - Cảnh báo tài chính';
      case DunningTier.tier3:
        return 'Tầng 3 - Tạm ngừng dịch vụ';
    }
  }

  Color get color {
    switch (this) {
      case DunningTier.tier1:
        return AppTheme.primary;
      case DunningTier.tier2:
        return AppTheme.warning;
      case DunningTier.tier3:
        return AppTheme.error;
    }
  }

  String get defaultTitle {
    switch (this) {
      case DunningTier.tier1:
        return 'Nhắc nhở thanh toán phí dịch vụ';
      case DunningTier.tier2:
        return 'Cảnh báo quá hạn thanh toán & tính lãi chậm nộp';
      case DunningTier.tier3:
        return 'Thông báo tạm ngưng dịch vụ tiện ích & xử lý công nợ';
    }
  }

  String defaultContent(String apartmentCode, double amount, int overdueDays) {
    final formattedAmount = '${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} đ';
    switch (this) {
      case DunningTier.tier1:
        return 'Kính gửi Quý cư dân căn hộ $apartmentCode. Ban Quản Lý xin nhắc Quý cư dân hóa đơn dịch vụ hiện còn dư nợ $formattedAmount (quá hạn $overdueDays ngày). Kính mong Quý cư dân sớm hoàn tất thanh toán để đảm bảo tiện ích liên tục.';
      case DunningTier.tier2:
        return 'Thông báo đôn đốc công nợ lần 2 tới căn hộ $apartmentCode. Dư nợ chưa thanh toán là $formattedAmount (quá hạn $overdueDays ngày). Theo Quy chế quản lý chung cư, các khoản nợ quá 15 ngày sẽ bắt đầu tính lãi chậm trả và phát sinh phí phạt. Đề nghị Quý cư dân nộp tiền trước ngày quy định.';
      case DunningTier.tier3:
        return 'CẢNH BÁO ĐÔN ĐỐC ĐẶC BIỆT tới căn hộ $apartmentCode. Tổng số tiền nợ đọng kéo dài là $formattedAmount (quá hạn $overdueDays ngày). Ban Quản Lý xin thông báo sẽ tiến hành tạm dừng quyền sử dụng các dịch vụ tiện ích bổ sung (thẻ ra vào xe, hồ bơi/gym) và báo cáo Ban Quản Trị / Pháp chế giải quyết nếu không nhận được thanh toán trong vòng 3 ngày làm việc.';
    }
  }

  static DunningTier fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'tier_3':
      case 'tier3':
        return DunningTier.tier3;
      case 'tier_2':
      case 'tier2':
        return DunningTier.tier2;
      case 'tier_1':
      case 'tier1':
      default:
        return DunningTier.tier1;
    }
  }
}

class RiskFactorModel {
  final String factor;
  final String label;
  final String severity;

  const RiskFactorModel({
    required this.factor,
    required this.label,
    required this.severity,
  });

  factory RiskFactorModel.fromJson(Map<String, dynamic> json) {
    return RiskFactorModel(
      factor: json['factor']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      severity: json['severity']?.toString() ?? 'low',
    );
  }

  Map<String, dynamic> toJson() => {
    'factor': factor,
    'label': label,
    'severity': severity,
  };
}

class DebtRiskScoreModel {
  final String apartmentId;
  final String apartmentCode;
  final String buildingId;
  final String ownerName;
  final String ownerPhone;
  final int riskScore;
  final DebtRiskLevel riskLevel;
  final int overdueDays;
  final double unpaidAmount;
  final double monthlyFeeAvg;
  final int latePaymentCount;
  final DunningTier recommendedTier;
  final List<RiskFactorModel> riskFactors;
  final DunningTier? lastDunningTier;
  final DateTime? lastDunningAt;
  final int dunningCount;

  const DebtRiskScoreModel({
    required this.apartmentId,
    required this.apartmentCode,
    required this.buildingId,
    required this.ownerName,
    required this.ownerPhone,
    required this.riskScore,
    required this.riskLevel,
    required this.overdueDays,
    required this.unpaidAmount,
    required this.monthlyFeeAvg,
    required this.latePaymentCount,
    required this.recommendedTier,
    required this.riskFactors,
    this.lastDunningTier,
    this.lastDunningAt,
    this.dunningCount = 0,
  });

  factory DebtRiskScoreModel.fromJson(Map<String, dynamic> json) {
    var rawFactors = json['risk_factors'];
    List<RiskFactorModel> factors = [];
    if (rawFactors is List) {
      factors = rawFactors
          .map((e) => RiskFactorModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }

    return DebtRiskScoreModel(
      apartmentId: json['apartment_id']?.toString() ?? '',
      apartmentCode: json['apartment_code']?.toString() ?? '',
      buildingId: json['building_id']?.toString() ?? '',
      ownerName: json['owner_name']?.toString() ?? 'Chưa đăng ký',
      ownerPhone: json['owner_phone']?.toString() ?? '',
      riskScore: (json['risk_score'] as num?)?.toInt() ?? 0,
      riskLevel: DebtRiskLevel.fromString(json['risk_level']?.toString()),
      overdueDays: (json['overdue_days'] as num?)?.toInt() ?? 0,
      unpaidAmount: (json['unpaid_amount'] as num?)?.toDouble() ?? 0.0,
      monthlyFeeAvg: (json['monthly_fee_avg'] as num?)?.toDouble() ?? 0.0,
      latePaymentCount: (json['late_payment_count'] as num?)?.toInt() ?? 0,
      recommendedTier: DunningTier.fromString(json['recommended_tier']?.toString()),
      riskFactors: factors,
      lastDunningTier: json['last_dunning_tier'] != null
          ? DunningTier.fromString(json['last_dunning_tier']?.toString())
          : null,
      lastDunningAt: json['last_dunning_at'] != null
          ? DateTime.tryParse(json['last_dunning_at'].toString())
          : null,
      dunningCount: (json['dunning_count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'apartment_id': apartmentId,
    'apartment_code': apartmentCode,
    'building_id': buildingId,
    'owner_name': ownerName,
    'owner_phone': ownerPhone,
    'risk_score': riskScore,
    'risk_level': riskLevel.name,
    'overdue_days': overdueDays,
    'unpaid_amount': unpaidAmount,
    'monthly_fee_avg': monthlyFeeAvg,
    'late_payment_count': latePaymentCount,
    'recommended_tier': recommendedTier.dbValue,
    'risk_factors': riskFactors.map((e) => e.toJson()).toList(),
    'last_dunning_tier': lastDunningTier?.dbValue,
    'last_dunning_at': lastDunningAt?.toIso8601String(),
    'dunning_count': dunningCount,
  };
}

class DebtRadarKpiModel {
  final int totalAtRiskApartments;
  final int highRiskCount;
  final int mediumRiskCount;
  final int lowRiskCount;
  final double totalOverdueDebt;
  final double highRiskDebt;

  const DebtRadarKpiModel({
    required this.totalAtRiskApartments,
    required this.highRiskCount,
    required this.mediumRiskCount,
    required this.lowRiskCount,
    required this.totalOverdueDebt,
    required this.highRiskDebt,
  });

  factory DebtRadarKpiModel.fromJson(Map<String, dynamic> json) {
    return DebtRadarKpiModel(
      totalAtRiskApartments: (json['total_at_risk_apartments'] as num?)?.toInt() ?? 0,
      highRiskCount: (json['high_risk_count'] as num?)?.toInt() ?? 0,
      mediumRiskCount: (json['medium_risk_count'] as num?)?.toInt() ?? 0,
      lowRiskCount: (json['low_risk_count'] as num?)?.toInt() ?? 0,
      totalOverdueDebt: (json['total_overdue_debt'] as num?)?.toDouble() ?? 0.0,
      highRiskDebt: (json['high_risk_debt'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'total_at_risk_apartments': totalAtRiskApartments,
    'high_risk_count': highRiskCount,
    'medium_risk_count': mediumRiskCount,
    'low_risk_count': lowRiskCount,
    'total_overdue_debt': totalOverdueDebt,
    'high_risk_debt': highRiskDebt,
  };
}

class DebtRadarDataModel {
  final String buildingId;
  final DebtRadarKpiModel kpi;
  final List<DebtRiskScoreModel> apartments;

  const DebtRadarDataModel({
    required this.buildingId,
    required this.kpi,
    required this.apartments,
  });

  factory DebtRadarDataModel.fromJson(Map<String, dynamic> json) {
    var rawList = json['apartments'];
    List<DebtRiskScoreModel> apartments = [];
    if (rawList is List) {
      apartments = rawList
          .map((e) => DebtRiskScoreModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }

    return DebtRadarDataModel(
      buildingId: json['building_id']?.toString() ?? '',
      kpi: DebtRadarKpiModel.fromJson(
        Map<String, dynamic>.from(json['kpi'] as Map? ?? {}),
      ),
      apartments: apartments,
    );
  }
}
