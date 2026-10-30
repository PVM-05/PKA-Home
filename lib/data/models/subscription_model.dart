class SubscriptionUsageMetricsModel {
  final int usedApartments;
  final int maxApartments;
  final double apartmentUsagePercent;
  final bool isNearLimit;
  final bool isAtLimit;
  final int usedBuildings;
  final int maxBuildings;
  final int usedStaff;
  final int maxStaff;

  const SubscriptionUsageMetricsModel({
    required this.usedApartments,
    required this.maxApartments,
    required this.apartmentUsagePercent,
    required this.isNearLimit,
    required this.isAtLimit,
    required this.usedBuildings,
    required this.maxBuildings,
    required this.usedStaff,
    required this.maxStaff,
  });

  bool get isUnlimitedApartments => maxApartments < 0;
  bool get isUnlimitedBuildings => maxBuildings < 0;
  bool get isUnlimitedStaff => maxStaff < 0;

  String get displayApartmentRatio =>
      '$usedApartments / ${isUnlimitedApartments ? "∞" : maxApartments} căn';

  String get displayBuildingRatio =>
      '$usedBuildings / ${isUnlimitedBuildings ? "∞" : maxBuildings} tòa';

  String get displayStaffRatio =>
      '$usedStaff / ${isUnlimitedStaff ? "∞" : maxStaff} nhân viên';

  factory SubscriptionUsageMetricsModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionUsageMetricsModel(
      usedApartments: json['used_apartments'] is num
          ? (json['used_apartments'] as num).toInt()
          : 0,
      maxApartments: json['max_apartments'] is num
          ? (json['max_apartments'] as num).toInt()
          : 100,
      apartmentUsagePercent: json['apartment_usage_percent'] is num
          ? (json['apartment_usage_percent'] as num).toDouble()
          : 0.0,
      isNearLimit: json['is_near_limit'] == true,
      isAtLimit: json['is_at_limit'] == true,
      usedBuildings: json['used_buildings'] is num
          ? (json['used_buildings'] as num).toInt()
          : 0,
      maxBuildings: json['max_buildings'] is num
          ? (json['max_buildings'] as num).toInt()
          : 1,
      usedStaff: json['used_staff'] is num
          ? (json['used_staff'] as num).toInt()
          : 0,
      maxStaff: json['max_staff'] is num
          ? (json['max_staff'] as num).toInt()
          : 2,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'used_apartments': usedApartments,
      'max_apartments': maxApartments,
      'apartment_usage_percent': apartmentUsagePercent,
      'is_near_limit': isNearLimit,
      'is_at_limit': isAtLimit,
      'used_buildings': usedBuildings,
      'max_buildings': maxBuildings,
      'used_staff': usedStaff,
      'max_staff': maxStaff,
    };
  }
}

class SubscriptionStatusModel {
  final String organizationId;
  final String subscriptionId;
  final String planCode;
  final String planName;
  final String? planDescription;
  final String status;
  final DateTime? startDate;
  final DateTime? expiresAt;
  final int daysRemaining;
  final bool isExpiringSoon;
  final String billingCycle;
  final bool autoRenew;
  final double priceMonthly;
  final double priceYearly;
  final Map<String, dynamic> features;
  final SubscriptionUsageMetricsModel usage;

  const SubscriptionStatusModel({
    required this.organizationId,
    required this.subscriptionId,
    required this.planCode,
    required this.planName,
    this.planDescription,
    required this.status,
    this.startDate,
    this.expiresAt,
    required this.daysRemaining,
    required this.isExpiringSoon,
    required this.billingCycle,
    required this.autoRenew,
    required this.priceMonthly,
    required this.priceYearly,
    required this.features,
    required this.usage,
  });

  String get statusBadgeText {
    switch (status.toLowerCase()) {
      case 'active':
        return 'Đang hoạt động';
      case 'trialing':
        return 'Dùng thử';
      case 'past_due':
        return 'Quá hạn thanh toán';
      case 'cancelled':
        return 'Đã hủy';
      case 'expired':
        return 'Hết hạn';
      default:
        return 'Hoạt động';
    }
  }

  String get remainingDaysText {
    if (daysRemaining <= 0) {
      return 'Đã hết hạn';
    }
    return 'Còn $daysRemaining ngày';
  }

  factory SubscriptionStatusModel.fromJson(Map<String, dynamic> json) {
    final usageJson = json['usage'] is Map
        ? Map<String, dynamic>.from(json['usage'] as Map)
        : <String, dynamic>{};

    return SubscriptionStatusModel(
      organizationId: json['organization_id']?.toString() ?? '',
      subscriptionId: json['subscription_id']?.toString() ?? '',
      planCode: json['plan_code']?.toString() ?? 'starter',
      planName: json['plan_name']?.toString() ?? 'Gói dịch vụ',
      planDescription: json['plan_description']?.toString(),
      status: json['status']?.toString() ?? 'active',
      startDate: json['start_date'] != null
          ? DateTime.tryParse(json['start_date'].toString())
          : null,
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'].toString())
          : null,
      daysRemaining: json['days_remaining'] is num
          ? (json['days_remaining'] as num).toInt()
          : 0,
      isExpiringSoon: json['is_expiring_soon'] == true,
      billingCycle: json['billing_cycle']?.toString() ?? 'monthly',
      autoRenew: json['auto_renew'] == true,
      priceMonthly: json['price_monthly'] is num
          ? (json['price_monthly'] as num).toDouble()
          : 0.0,
      priceYearly: json['price_yearly'] is num
          ? (json['price_yearly'] as num).toDouble()
          : 0.0,
      features: json['features'] is Map
          ? Map<String, dynamic>.from(json['features'] as Map)
          : {},
      usage: SubscriptionUsageMetricsModel.fromJson(usageJson),
    );
  }
}

