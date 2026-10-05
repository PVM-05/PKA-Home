class VehicleModel {
  final String id;
  final String apartmentId;
  final String? userId;
  final String vehicleType; // 'motorbike', 'car', 'electric_bicycle'
  final String licensePlate;
  final String? brandModel;
  final String status; // 'pending', 'approved', 'rejected'
  final DateTime createdAt;

  VehicleModel({
    required this.id,
    required this.apartmentId,
    this.userId,
    required this.vehicleType,
    required this.licensePlate,
    this.brandModel,
    this.status = 'pending',
    required this.createdAt,
  });

  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    return VehicleModel(
      id: json['id'] as String? ?? '',
      apartmentId: json['apartment_id'] as String? ?? '',
      userId: json['user_id'] as String?,
      vehicleType: json['vehicle_type'] as String? ?? 'motorbike',
      licensePlate: json['license_plate'] as String? ?? '',
      brandModel: json['brand_model'] as String?,
      status: json['status'] as String? ?? 'pending',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'apartment_id': apartmentId,
      'user_id': userId,
      'vehicle_type': vehicleType,
      'license_plate': licensePlate,
      'brand_model': brandModel,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }

  VehicleModel copyWith({
    String? id,
    String? apartmentId,
    String? userId,
    String? vehicleType,
    String? licensePlate,
    String? brandModel,
    String? status,
    DateTime? createdAt,
  }) {
    return VehicleModel(
      id: id ?? this.id,
      apartmentId: apartmentId ?? this.apartmentId,
      userId: userId ?? this.userId,
      vehicleType: vehicleType ?? this.vehicleType,
      licensePlate: licensePlate ?? this.licensePlate,
      brandModel: brandModel ?? this.brandModel,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  String get vehicleTypeDisplayName {
    switch (vehicleType) {
      case 'car':
        return 'Ô tô';
      case 'electric_bicycle':
        return 'Xe đạp điện';
      case 'motorbike':
      default:
        return 'Xe máy';
    }
  }

  String get statusDisplayName {
    switch (status) {
      case 'approved':
        return 'Đã phê duyệt';
      case 'rejected':
        return 'Đã từ chối';
      case 'pending':
      default:
        return 'Chờ phê duyệt';
    }
  }
}
