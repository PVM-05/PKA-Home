class ParkingSlotModel {
  final String id;
  final String? buildingId;
  final String zone; // 'B1', 'B2', 'B3'
  final String slotNumber; // 'P-B1-01', 'M-B1-01'
  final String slotType; // 'car', 'motorcycle'
  final String status; // 'available', 'occupied', 'reserved', 'maintenance'
  final String? assignedVehicleId;
  final String? assignedApartmentId;
  final String? licensePlate;
  final String? apartmentCode;
  final String? note;
  final DateTime createdAt;

  ParkingSlotModel({
    required this.id,
    this.buildingId,
    required this.zone,
    required this.slotNumber,
    required this.slotType,
    required this.status,
    this.assignedVehicleId,
    this.assignedApartmentId,
    this.licensePlate,
    this.apartmentCode,
    this.note,
    required this.createdAt,
  });

  bool get isAvailable => status == 'available';
  bool get isOccupied => status == 'occupied';
  bool get isMaintenance => status == 'maintenance';
  bool get isCar => slotType == 'car';
  bool get isMotorcycle => slotType == 'motorcycle';

  String get displayType => isCar ? 'Ô tô' : 'Xe máy';

  String get displayStatus {
    switch (status) {
      case 'available':
        return 'Còn trống';
      case 'occupied':
        return 'Đã có xe';
      case 'reserved':
        return 'Đã đặt trước';
      case 'maintenance':
        return 'Bảo trì';
      default:
        return status;
    }
  }

  factory ParkingSlotModel.fromJson(Map<String, dynamic> json) {
    return ParkingSlotModel(
      id: json['id'] as String? ?? '',
      buildingId: json['building_id'] as String?,
      zone: json['zone'] as String? ?? 'B1',
      slotNumber: json['slot_number'] as String? ?? '',
      slotType: json['slot_type'] as String? ?? 'car',
      status: json['status'] as String? ?? 'available',
      assignedVehicleId: json['assigned_vehicle_id'] as String?,
      assignedApartmentId: json['assigned_apartment_id'] as String?,
      licensePlate: json['license_plate'] as String?,
      apartmentCode: json['apartment_code'] as String?,
      note: json['note'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'building_id': buildingId,
      'zone': zone,
      'slot_number': slotNumber,
      'slot_type': slotType,
      'status': status,
      'assigned_vehicle_id': assignedVehicleId,
      'assigned_apartment_id': assignedApartmentId,
      'license_plate': licensePlate,
      'apartment_code': apartmentCode,
      'note': note,
      'created_at': createdAt.toIso8601String(),
    };
  }

  ParkingSlotModel copyWith({
    String? id,
    String? buildingId,
    String? zone,
    String? slotNumber,
    String? slotType,
    String? status,
    String? assignedVehicleId,
    String? assignedApartmentId,
    String? licensePlate,
    String? apartmentCode,
    String? note,
    DateTime? createdAt,
  }) {
    return ParkingSlotModel(
      id: id ?? this.id,
      buildingId: buildingId ?? this.buildingId,
      zone: zone ?? this.zone,
      slotNumber: slotNumber ?? this.slotNumber,
      slotType: slotType ?? this.slotType,
      status: status ?? this.status,
      assignedVehicleId: assignedVehicleId ?? this.assignedVehicleId,
      assignedApartmentId: assignedApartmentId ?? this.assignedApartmentId,
      licensePlate: licensePlate ?? this.licensePlate,
      apartmentCode: apartmentCode ?? this.apartmentCode,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
