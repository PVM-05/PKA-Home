class VehicleModel {
  final String id;
  final String apartmentId;
  final String? userId;
  final String vehicleType; // 'motorbike', 'car', 'electric_bicycle'
  final String licensePlate;
  final String? brandModel;
  final String status; // 'pending', 'approved', 'rejected', 'cancelled'
  final String? rejectionReason;
  final String? registrationImageUrl;
  final String? parkingSlotId;
  final String? parkingSlotNumber;
  final DateTime? approvedAt;
  final String? approvedBy;
  final DateTime createdAt;

  VehicleModel({
    required this.id,
    required this.apartmentId,
    this.userId,
    required this.vehicleType,
    required this.licensePlate,
    this.brandModel,
    this.status = 'pending',
    this.rejectionReason,
    this.registrationImageUrl,
    this.parkingSlotId,
    this.parkingSlotNumber,
    this.approvedAt,
    this.approvedBy,
    required this.createdAt,
  });

  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    return VehicleModel(
      id: json['id'] as String? ?? '',
      apartmentId: json['apartment_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? json['registered_by'] as String?,
      vehicleType: json['vehicle_type'] as String? ?? 'motorbike',
      licensePlate: json['license_plate'] as String? ?? json['plate_number'] as String? ?? '',
      brandModel: json['brand_model'] as String?,
      status: json['status'] as String? ?? 'pending',
      rejectionReason: json['rejection_reason'] as String?,
      registrationImageUrl: json['registration_image_url'] as String?,
      parkingSlotId: json['parking_slot_id'] as String?,
      parkingSlotNumber: json['parking_slot_number'] as String?,
      approvedAt: json['approved_at'] != null
          ? DateTime.tryParse(json['approved_at'] as String)
          : null,
      approvedBy: json['approved_by'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
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
      'plate_number': licensePlate,
      'brand_model': brandModel,
      'status': status,
      'rejection_reason': rejectionReason,
      'registration_image_url': registrationImageUrl,
      'parking_slot_id': parkingSlotId,
      'parking_slot_number': parkingSlotNumber,
      'approved_at': approvedAt?.toIso8601String(),
      'approved_by': approvedBy,
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
    String? rejectionReason,
    String? registrationImageUrl,
    String? parkingSlotId,
    String? parkingSlotNumber,
    DateTime? approvedAt,
    String? approvedBy,
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
      rejectionReason: rejectionReason ?? this.rejectionReason,
      registrationImageUrl: registrationImageUrl ?? this.registrationImageUrl,
      parkingSlotId: parkingSlotId ?? this.parkingSlotId,
      parkingSlotNumber: parkingSlotNumber ?? this.parkingSlotNumber,
      approvedAt: approvedAt ?? this.approvedAt,
      approvedBy: approvedBy ?? this.approvedBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get isCancelled => status == 'cancelled';
  bool get isActive => isPending || isApproved;
  bool get hasRejectionReason =>
      rejectionReason != null && rejectionReason!.trim().isNotEmpty;
  bool get hasRegistrationImage =>
      registrationImageUrl != null && registrationImageUrl!.trim().isNotEmpty;
  bool get hasAssignedSlot =>
      parkingSlotNumber != null && parkingSlotNumber!.trim().isNotEmpty;

  String get plateNumber => licensePlate;
  bool get isMotorbike => vehicleType == 'motorbike';
  bool get isCar => vehicleType == 'car';
  bool get isElectricBicycle => vehicleType == 'electric_bicycle';
  String get vehicleTypeName => vehicleTypeDisplayName;

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
      case 'cancelled':
        return 'Đã hủy';
      case 'pending':
      default:
        return 'Chờ phê duyệt';
    }
  }

  double get monthlyFee {
    switch (vehicleType) {
      case 'car':
        return 1200000.0;
      case 'electric_bicycle':
        return 30000.0;
      case 'motorbike':
      default:
        return 100000.0;
    }
  }
}
