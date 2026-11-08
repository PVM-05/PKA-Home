/// Model cấu hình biểu giá tiện ích (điện, nước) của tòa nhà
class BuildingUtilityRateModel {
  final String id;
  final String utilityType; // 'electricity' | 'water'
  final String pricingModel; // 'fixed' | 'tiered_evn' | 'tiered_water'
  final double baseUnitPrice;
  final double vatPercentage;
  final double environmentFeePercentage;
  final List<dynamic> tiers;
  final String? effectiveFrom;
  final bool isActive;

  const BuildingUtilityRateModel({
    required this.id,
    required this.utilityType,
    this.pricingModel = 'fixed',
    required this.baseUnitPrice,
    this.vatPercentage = 8.0,
    this.environmentFeePercentage = 0.0,
    this.tiers = const [],
    this.effectiveFrom,
    this.isActive = true,
  });

  bool get isElectricity => utilityType == 'electricity';
  bool get isWater => utilityType == 'water';

  /// Tính chi phí theo lượng tiêu thụ
  Map<String, double> calculateCost(double consumed) {
    if (consumed <= 0) {
      return {
        'subtotal': 0.0,
        'vat_amount': 0.0,
        'env_fee_amount': 0.0,
        'total_amount': 0.0,
      };
    }

    final subtotal = consumed * baseUnitPrice;
    final vat = subtotal * (vatPercentage / 100.0);
    final env = subtotal * (environmentFeePercentage / 100.0);
    final total = subtotal + vat + env;

    return {
      'subtotal': double.parse(subtotal.toStringAsFixed(2)),
      'vat_amount': double.parse(vat.toStringAsFixed(2)),
      'env_fee_amount': double.parse(env.toStringAsFixed(2)),
      'total_amount': double.parse(total.toStringAsFixed(2)),
    };
  }

  /// Tính tổng chi phí sau thuế & phí theo lượng tiêu thụ
  double calculateTotal(double consumed) {
    return calculateCost(consumed)['total_amount'] ?? 0.0;
  }

  factory BuildingUtilityRateModel.fromJson(Map<String, dynamic> json) {
    return BuildingUtilityRateModel(
      id: json['id'] as String? ?? '',
      utilityType: json['utility_type'] as String? ?? 'electricity',
      pricingModel: json['pricing_model'] as String? ?? 'fixed',
      baseUnitPrice: (json['base_unit_price'] as num?)?.toDouble() ?? 0.0,
      vatPercentage: (json['vat_percentage'] as num?)?.toDouble() ?? 8.0,
      environmentFeePercentage:
          (json['environment_fee_percentage'] as num?)?.toDouble() ?? 0.0,
      tiers: json['tiers'] as List<dynamic>? ?? const [],
      effectiveFrom: json['effective_from']?.toString(),
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'utility_type': utilityType,
      'pricing_model': pricingModel,
      'base_unit_price': baseUnitPrice,
      'vat_percentage': vatPercentage,
      'environment_fee_percentage': environmentFeePercentage,
      'tiers': tiers,
      'effective_from': effectiveFrom,
      'is_active': isActive,
    };
  }
}

