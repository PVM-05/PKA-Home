import 'package:intl/intl.dart';

class VisitorParkingTicketModel {
  final String id;
  final String? buildingId;
  final String ticketCode; // 'TKT-202611-0001'
  final String licensePlate;
  final String vehicleType; // 'car', 'motorcycle'
  final DateTime checkInAt;
  final DateTime? checkOutAt;
  final String status; // 'in_parking', 'completed', 'cancelled'
  final double hourlyRate;
  final double? totalHours;
  final double feeAmount;
  final String paymentStatus; // 'unpaid', 'paid'
  final String? paymentMethod; // 'vietqr', 'cash'
  final String qrPayload;
  final String? note;
  final DateTime createdAt;

  VisitorParkingTicketModel({
    required this.id,
    this.buildingId,
    required this.ticketCode,
    required this.licensePlate,
    required this.vehicleType,
    required this.checkInAt,
    this.checkOutAt,
    this.status = 'in_parking',
    this.hourlyRate = 5000,
    this.totalHours,
    this.feeAmount = 0,
    this.paymentStatus = 'unpaid',
    this.paymentMethod,
    required this.qrPayload,
    this.note,
    required this.createdAt,
  });

  bool get isInParking => status == 'in_parking';
  bool get isCompleted => status == 'completed';
  bool get isPaid => paymentStatus == 'paid';
  bool get isCar => vehicleType == 'car';
  bool get isMotorcycle => vehicleType == 'motorcycle';

  String get displayVehicleType => isCar ? 'Ô tô' : 'Xe máy';

  String get displayStatus {
    switch (status) {
      case 'in_parking':
        return 'Đang gửi';
      case 'completed':
        return 'Đã xuất bến';
      case 'cancelled':
        return 'Đã hủy';
      default:
        return status;
    }
  }

  String get feeFormatted {
    final format = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    return format.format(feeAmount).replaceAll('\u00A0', ' ').trim();
  }

  factory VisitorParkingTicketModel.fromJson(Map<String, dynamic> json) {
    return VisitorParkingTicketModel(
      id: json['id'] as String? ?? '',
      buildingId: json['building_id'] as String?,
      ticketCode: json['ticket_code'] as String? ?? '',
      licensePlate: json['license_plate'] as String? ?? '',
      vehicleType: json['vehicle_type'] as String? ?? 'motorcycle',
      checkInAt: json['check_in_at'] != null
          ? DateTime.tryParse(json['check_in_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      checkOutAt: json['check_out_at'] != null
          ? DateTime.tryParse(json['check_out_at'] as String)
          : null,
      status: json['status'] as String? ?? 'in_parking',
      hourlyRate: (json['hourly_rate'] as num?)?.toDouble() ?? 5000.0,
      totalHours: (json['total_hours'] as num?)?.toDouble(),
      feeAmount: (json['fee_amount'] as num?)?.toDouble() ?? 0.0,
      paymentStatus: json['payment_status'] as String? ?? 'unpaid',
      paymentMethod: json['payment_method'] as String?,
      qrPayload: json['qr_payload'] as String? ?? '',
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
      'ticket_code': ticketCode,
      'license_plate': licensePlate,
      'vehicle_type': vehicleType,
      'check_in_at': checkInAt.toIso8601String(),
      'check_out_at': checkOutAt?.toIso8601String(),
      'status': status,
      'hourly_rate': hourlyRate,
      'total_hours': totalHours,
      'fee_amount': feeAmount,
      'payment_status': paymentStatus,
      'payment_method': paymentMethod,
      'qr_payload': qrPayload,
      'note': note,
      'created_at': createdAt.toIso8601String(),
    };
  }

  VisitorParkingTicketModel copyWith({
    String? id,
    String? buildingId,
    String? ticketCode,
    String? licensePlate,
    String? vehicleType,
    DateTime? checkInAt,
    DateTime? checkOutAt,
    String? status,
    double? hourlyRate,
    double? totalHours,
    double? feeAmount,
    String? paymentStatus,
    String? paymentMethod,
    String? qrPayload,
    String? note,
    DateTime? createdAt,
  }) {
    return VisitorParkingTicketModel(
      id: id ?? this.id,
      buildingId: buildingId ?? this.buildingId,
      ticketCode: ticketCode ?? this.ticketCode,
      licensePlate: licensePlate ?? this.licensePlate,
      vehicleType: vehicleType ?? this.vehicleType,
      checkInAt: checkInAt ?? this.checkInAt,
      checkOutAt: checkOutAt ?? this.checkOutAt,
      status: status ?? this.status,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      totalHours: totalHours ?? this.totalHours,
      feeAmount: feeAmount ?? this.feeAmount,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      qrPayload: qrPayload ?? this.qrPayload,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
