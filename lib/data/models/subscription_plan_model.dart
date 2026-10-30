import 'package:intl/intl.dart';

class SubscriptionPlanModel {
  final String id;
  final String code;
  final String name;
  final String? description;
  final int maxApartments;
  final int maxBuildings;
  final int maxStaff;
  final double priceMonthly;
  final double priceYearly;
  final Map<String, dynamic> features;
  final bool isActive;
  final int sortOrder;

  const SubscriptionPlanModel({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    this.maxApartments = 100,
    this.maxBuildings = 1,
    this.maxStaff = 2,
    this.priceMonthly = 0.0,
    this.priceYearly = 0.0,
    this.features = const {},
    this.isActive = true,
    this.sortOrder = 0,
  });

  bool get isUnlimitedApartments => maxApartments < 0;
  bool get isUnlimitedBuildings => maxBuildings < 0;
  bool get isUnlimitedStaff => maxStaff < 0;

  String get displayMaxApartments =>
      isUnlimitedApartments ? 'Không giới hạn' : '$maxApartments căn';

  String get displayMaxBuildings =>
      isUnlimitedBuildings ? 'Không giới hạn' : '$maxBuildings tòa';

  String get displayMaxStaff =>
      isUnlimitedStaff ? 'Không giới hạn' : '$maxStaff nhân viên';

  String get formattedPriceMonthly {
    final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    return '${formatter.format(priceMonthly)}/tháng';
  }

  String get formattedPriceYearly {
    final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    return '${formatter.format(priceYearly)}/năm';
  }

  factory SubscriptionPlanModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlanModel(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? 'starter',
      name: json['name']?.toString() ?? 'Gói dịch vụ',
      description: json['description']?.toString(),
      maxApartments: json['max_apartments'] is num
          ? (json['max_apartments'] as num).toInt()
          : 100,
      maxBuildings: json['max_buildings'] is num
          ? (json['max_buildings'] as num).toInt()
          : 1,
      maxStaff: json['max_staff'] is num
          ? (json['max_staff'] as num).toInt()
          : 2,
      priceMonthly: json['price_monthly'] is num
          ? (json['price_monthly'] as num).toDouble()
          : 0.0,
      priceYearly: json['price_yearly'] is num
          ? (json['price_yearly'] as num).toDouble()
          : 0.0,
      features: json['features'] is Map
          ? Map<String, dynamic>.from(json['features'] as Map)
          : {},
      isActive: json['is_active'] == true,
      sortOrder: json['sort_order'] is num
          ? (json['sort_order'] as num).toInt()
          : 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      if (description != null) 'description': description,
      'max_apartments': maxApartments,
      'max_buildings': maxBuildings,
      'max_staff': maxStaff,
      'price_monthly': priceMonthly,
      'price_yearly': priceYearly,
      'features': features,
      'is_active': isActive,
      'sort_order': sortOrder,
    };
  }
}
