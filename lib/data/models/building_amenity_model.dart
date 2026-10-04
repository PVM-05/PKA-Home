class BuildingAmenityModel {
  final String id;
  final String name;
  final String? description;
  final String? openHours;
  final int displayOrder;
  final DateTime? createdAt;
  final String bookingType; // 'exclusive' | 'shared'
  final int maxCapacity;
  final int slotDurationMinutes;
  final double feeAmount;
  final double depositAmount;
  final bool requiresDeposit;
  final bool isActive;

  BuildingAmenityModel({
    required this.id,
    required this.name,
    this.description,
    this.openHours,
    required this.displayOrder,
    this.createdAt,
    this.bookingType = 'exclusive',
    this.maxCapacity = 1,
    this.slotDurationMinutes = 90,
    this.feeAmount = 0.0,
    this.depositAmount = 0.0,
    this.requiresDeposit = false,
    this.isActive = true,
  });

  bool get isShared => bookingType == 'shared';
  bool get isExclusive => bookingType == 'exclusive';

  factory BuildingAmenityModel.fromJson(Map<String, dynamic> json) {
    return BuildingAmenityModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      openHours: json['open_hours'] as String?,
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      bookingType: json['booking_type'] as String? ?? 'exclusive',
      maxCapacity: (json['max_capacity'] as num?)?.toInt() ?? 1,
      slotDurationMinutes: (json['slot_duration_minutes'] as num?)?.toInt() ?? 90,
      feeAmount: (json['fee_amount'] as num?)?.toDouble() ?? 0.0,
      depositAmount: (json['deposit_amount'] as num?)?.toDouble() ?? 0.0,
      requiresDeposit: json['requires_deposit'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'open_hours': openHours,
    'display_order': displayOrder,
    'booking_type': bookingType,
    'max_capacity': maxCapacity,
    'slot_duration_minutes': slotDurationMinutes,
    'fee_amount': feeAmount,
    'deposit_amount': depositAmount,
    'requires_deposit': requiresDeposit,
    'is_active': isActive,
  };
}
