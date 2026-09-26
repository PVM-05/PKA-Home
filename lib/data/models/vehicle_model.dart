class VehicleModel {
  final String id;
  final String apartmentId;
  final String plateNumber;
  final String vehicleType; // 'motorbike' | 'car'
  final String? registeredBy;
  final DateTime createdAt;
  final DateTime? updatedAt;

  VehicleModel({
    required this.id,
    required this.apartmentId,
    required this.plateNumber,
    required this.vehicleType,
    this.registeredBy,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isMotorbike => vehicleType == 'motorbike';
  bool get isCar => vehicleType == 'car';

  String get vehicleTypeName {
    switch (vehicleType) {
      case 'motorbike':
        return 'Xe máy';
      case 'car':
        return 'Ô tô';
      default:
        return 'Khác';
    }
  }

  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    return VehicleModel(
      id: json['id'] as String? ?? '',
      apartmentId: json['apartment_id'] as String? ?? '',
      plateNumber: json['plate_number'] as String? ?? '',
      vehicleType: json['vehicle_type'] as String? ?? 'motorbike',
      registeredBy: json['registered_by'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'apartment_id': apartmentId,
      'plate_number': plateNumber,
      'vehicle_type': vehicleType,
      if (registeredBy != null) 'registered_by': registeredBy,
    };
  }
}
