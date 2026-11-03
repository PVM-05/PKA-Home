class VisitorPassModel {
  final String id;
  final String passCode;
  final String apartmentId;
  final String? apartmentCode;
  final String hostUserId;
  final String visitorName;
  final String? visitorPhone;
  final String? licensePlate;
  final String vehicleType; // none, motorcycle, car
  final int visitorCount;
  final DateTime expectedArrival;
  final DateTime? expectedDeparture;
  final String purpose; // visit, delivery, repair, other
  final String qrPayload;
  final String status; // pending, checked_in, checked_out, cancelled, expired
  final DateTime? checkInAt;
  final String? checkInGuardId;
  final DateTime? checkOutAt;
  final String? checkOutGuardId;
  final String? note;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const VisitorPassModel({
    required this.id,
    required this.passCode,
    required this.apartmentId,
    this.apartmentCode,
    required this.hostUserId,
    required this.visitorName,
    this.visitorPhone,
    this.licensePlate,
    this.vehicleType = 'none',
    this.visitorCount = 1,
    required this.expectedArrival,
    this.expectedDeparture,
    this.purpose = 'visit',
    required this.qrPayload,
    this.status = 'pending',
    this.checkInAt,
    this.checkInGuardId,
    this.checkOutAt,
    this.checkOutGuardId,
    this.note,
    required this.createdAt,
    this.updatedAt,
  });

  String get statusDisplayName {
    switch (status.toLowerCase()) {
      case 'checked_in':
        return 'Đang trong tòa nhà';
      case 'checked_out':
        return 'Đã rời khỏi';
      case 'cancelled':
        return 'Đã hủy';
      case 'expired':
        return 'Quá hạn';
      case 'pending':
      default:
        return 'Chờ đến';
    }
  }

  String get purposeDisplayName {
    switch (purpose.toLowerCase()) {
      case 'delivery':
        return 'Giao hàng / Shipper';
      case 'repair':
        return 'Sửa chữa / Thi công nội thất';
      case 'other':
        return 'Mục đích khác';
      case 'visit':
      default:
        return 'Thăm hỏi bạn bè / người thân';
    }
  }

  String get vehicleDisplayName {
    final plate = licensePlate != null && licensePlate!.isNotEmpty ? ' ($licensePlate)' : '';
    switch (vehicleType.toLowerCase()) {
      case 'car':
        return 'Ô tô$plate';
      case 'motorcycle':
        return 'Xe máy$plate';
      case 'none':
      default:
        return 'Đi bộ / Không gửi xe';
    }
  }

  bool get isCheckInAllowed => status == 'pending';
  bool get isCheckOutAllowed => status == 'checked_in';

  factory VisitorPassModel.fromJson(Map<String, dynamic> json) {
    final aptJson = json['apartments'] as Map<String, dynamic>?;
    final aptCode = (json['apartment_code'] as String?) ?? (aptJson?['code'] as String?);

    return VisitorPassModel(
      id: json['id'] as String? ?? '',
      passCode: json['pass_code'] as String? ?? '',
      apartmentId: json['apartment_id'] as String? ?? '',
      apartmentCode: aptCode,
      hostUserId: json['host_user_id'] as String? ?? '',
      visitorName: json['visitor_name'] as String? ?? '',
      visitorPhone: json['visitor_phone'] as String?,
      licensePlate: json['license_plate'] as String?,
      vehicleType: json['vehicle_type'] as String? ?? 'none',
      visitorCount: (json['visitor_count'] as num?)?.toInt() ?? 1,
      expectedArrival: json['expected_arrival'] != null
          ? DateTime.parse(json['expected_arrival'] as String)
          : DateTime.now(),
      expectedDeparture: json['expected_departure'] != null
          ? DateTime.parse(json['expected_departure'] as String)
          : null,
      purpose: json['purpose'] as String? ?? 'visit',
      qrPayload: json['qr_payload'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      checkInAt: json['check_in_at'] != null ? DateTime.parse(json['check_in_at'] as String) : null,
      checkInGuardId: json['check_in_guard_id'] as String?,
      checkOutAt: json['check_out_at'] != null ? DateTime.parse(json['check_out_at'] as String) : null,
      checkOutGuardId: json['check_out_guard_id'] as String?,
      note: json['note'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pass_code': passCode,
      'apartment_id': apartmentId,
      'host_user_id': hostUserId,
      'visitor_name': visitorName,
      'visitor_phone': visitorPhone,
      'license_plate': licensePlate,
      'vehicle_type': vehicleType,
      'visitor_count': visitorCount,
      'expected_arrival': expectedArrival.toIso8601String(),
      'expected_departure': expectedDeparture?.toIso8601String(),
      'purpose': purpose,
      'qr_payload': qrPayload,
      'status': status,
      'check_in_at': checkInAt?.toIso8601String(),
      'check_in_guard_id': checkInGuardId,
      'check_out_at': checkOutAt?.toIso8601String(),
      'check_out_guard_id': checkOutGuardId,
      'note': note,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  VisitorPassModel copyWith({
    String? id,
    String? passCode,
    String? apartmentId,
    String? apartmentCode,
    String? hostUserId,
    String? visitorName,
    String? visitorPhone,
    String? licensePlate,
    String? vehicleType,
    int? visitorCount,
    DateTime? expectedArrival,
    DateTime? expectedDeparture,
    String? purpose,
    String? qrPayload,
    String? status,
    DateTime? checkInAt,
    String? checkInGuardId,
    DateTime? checkOutAt,
    String? checkOutGuardId,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VisitorPassModel(
      id: id ?? this.id,
      passCode: passCode ?? this.passCode,
      apartmentId: apartmentId ?? this.apartmentId,
      apartmentCode: apartmentCode ?? this.apartmentCode,
      hostUserId: hostUserId ?? this.hostUserId,
      visitorName: visitorName ?? this.visitorName,
      visitorPhone: visitorPhone ?? this.visitorPhone,
      licensePlate: licensePlate ?? this.licensePlate,
      vehicleType: vehicleType ?? this.vehicleType,
      visitorCount: visitorCount ?? this.visitorCount,
      expectedArrival: expectedArrival ?? this.expectedArrival,
      expectedDeparture: expectedDeparture ?? this.expectedDeparture,
      purpose: purpose ?? this.purpose,
      qrPayload: qrPayload ?? this.qrPayload,
      status: status ?? this.status,
      checkInAt: checkInAt ?? this.checkInAt,
      checkInGuardId: checkInGuardId ?? this.checkInGuardId,
      checkOutAt: checkOutAt ?? this.checkOutAt,
      checkOutGuardId: checkOutGuardId ?? this.checkOutGuardId,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

