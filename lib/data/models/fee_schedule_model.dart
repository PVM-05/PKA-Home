class FeeScheduleModel {
  final String id;
  final String feeType;
  final String name;
  final String unit;
  final double unitPrice;
  final DateTime effectiveFrom;
  final DateTime? effectiveTo;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  FeeScheduleModel({
    required this.id,
    required this.feeType,
    required this.name,
    required this.unit,
    required this.unitPrice,
    required this.effectiveFrom,
    this.effectiveTo,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory FeeScheduleModel.fromJson(Map<String, dynamic> json) {
    return FeeScheduleModel(
      id: json['id'] as String,
      feeType: json['fee_type'] as String,
      name: json['name'] as String,
      unit: json['unit'] as String,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0.0,
      effectiveFrom: json['effective_from'] != null
          ? DateTime.parse(json['effective_from'] as String)
          : DateTime.now(),
      effectiveTo: json['effective_to'] != null
          ? DateTime.parse(json['effective_to'] as String)
          : null,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'fee_type': feeType,
    'name': name,
    'unit': unit,
    'unit_price': unitPrice,
    'effective_from': effectiveFrom.toIso8601String().split('T').first,
    'effective_to': effectiveTo?.toIso8601String().split('T').first,
    'is_active': isActive,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FeeScheduleModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
