class ParcelModel {
  final String id;
  final String parcelCode;
  final String apartmentId;
  final String? apartmentCode;
  final String? recipientName;
  final String carrier; // SPX, GHTK, GHN, Viettel Post, J&T, NinjaVan, Grab, Khác
  final String? trackingNumber;
  final String? description;
  final String shelfLocation;
  final String? imageUrl;
  final String pickupPin;
  final String status; // arrived, collected, returned
  final DateTime arrivedAt;
  final String? receivedStaffId;
  final DateTime? collectedAt;
  final String? handoverStaffId;
  final String? collectedBy;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const ParcelModel({
    required this.id,
    required this.parcelCode,
    required this.apartmentId,
    this.apartmentCode,
    this.recipientName,
    this.carrier = 'SPX',
    this.trackingNumber,
    this.description,
    this.shelfLocation = 'Kệ chung',
    this.imageUrl,
    required this.pickupPin,
    this.status = 'arrived',
    required this.arrivedAt,
    this.receivedStaffId,
    this.collectedAt,
    this.handoverStaffId,
    this.collectedBy,
    required this.createdAt,
    this.updatedAt,
  });

  String get statusDisplayName {
    switch (status.toLowerCase()) {
      case 'collected':
        return 'Đã nhận hàng';
      case 'returned':
        return 'Đã hoàn trả';
      case 'arrived':
      default:
        return 'Chờ nhận tại kệ';
    }
  }

  String get carrierDisplayName {
    switch (carrier.toUpperCase()) {
      case 'SPX':
        return 'Shopee Xpress (SPX)';
      case 'GHTK':
        return 'Giao Hàng Tiết Kiệm (GHTK)';
      case 'GHN':
        return 'Giao Hàng Nhanh (GHN)';
      case 'VIETTEL_POST':
      case 'VIETTEL':
        return 'Viettel Post';
      case 'JT':
      case 'J&T':
        return 'J&T Express';
      case 'NINJAVAN':
        return 'Ninja Van';
      case 'GRAB':
        return 'GrabExpress';
      default:
        return carrier.isNotEmpty ? carrier : 'Đơn vị khác';
    }
  }

  int get daysInStorage {
    return DateTime.now().difference(arrivedAt).inDays;
  }

  bool get isOverdueStorage => status == 'arrived' && daysInStorage >= 3;

  factory ParcelModel.fromJson(Map<String, dynamic> json) {
    final aptJson = json['apartments'] as Map<String, dynamic>?;
    final aptCode = (json['apartment_code'] as String?) ?? (aptJson?['code'] as String?);

    return ParcelModel(
      id: json['id'] as String? ?? '',
      parcelCode: json['parcel_code'] as String? ?? '',
      apartmentId: json['apartment_id'] as String? ?? '',
      apartmentCode: aptCode,
      recipientName: json['recipient_name'] as String?,
      carrier: json['carrier'] as String? ?? 'SPX',
      trackingNumber: json['tracking_number'] as String?,
      description: json['description'] as String?,
      shelfLocation: json['shelf_location'] as String? ?? 'Kệ chung',
      imageUrl: json['image_url'] as String?,
      pickupPin: json['pickup_pin'] as String? ?? '',
      status: json['status'] as String? ?? 'arrived',
      arrivedAt: json['arrived_at'] != null
          ? DateTime.parse(json['arrived_at'] as String)
          : DateTime.now(),
      receivedStaffId: json['received_staff_id'] as String?,
      collectedAt: json['collected_at'] != null ? DateTime.parse(json['collected_at'] as String) : null,
      handoverStaffId: json['handover_staff_id'] as String?,
      collectedBy: json['collected_by'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'parcel_code': parcelCode,
      'apartment_id': apartmentId,
      'recipient_name': recipientName,
      'carrier': carrier,
      'tracking_number': trackingNumber,
      'description': description,
      'shelf_location': shelfLocation,
      'image_url': imageUrl,
      'pickup_pin': pickupPin,
      'status': status,
      'arrived_at': arrivedAt.toIso8601String(),
      'received_staff_id': receivedStaffId,
      'collected_at': collectedAt?.toIso8601String(),
      'handover_staff_id': handoverStaffId,
      'collected_by': collectedBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  ParcelModel copyWith({
    String? id,
    String? parcelCode,
    String? apartmentId,
    String? apartmentCode,
    String? recipientName,
    String? carrier,
    String? trackingNumber,
    String? description,
    String? shelfLocation,
    String? imageUrl,
    String? pickupPin,
    String? status,
    DateTime? arrivedAt,
    String? receivedStaffId,
    DateTime? collectedAt,
    String? handoverStaffId,
    String? collectedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ParcelModel(
      id: id ?? this.id,
      parcelCode: parcelCode ?? this.parcelCode,
      apartmentId: apartmentId ?? this.apartmentId,
      apartmentCode: apartmentCode ?? this.apartmentCode,
      recipientName: recipientName ?? this.recipientName,
      carrier: carrier ?? this.carrier,
      trackingNumber: trackingNumber ?? this.trackingNumber,
      description: description ?? this.description,
      shelfLocation: shelfLocation ?? this.shelfLocation,
      imageUrl: imageUrl ?? this.imageUrl,
      pickupPin: pickupPin ?? this.pickupPin,
      status: status ?? this.status,
      arrivedAt: arrivedAt ?? this.arrivedAt,
      receivedStaffId: receivedStaffId ?? this.receivedStaffId,
      collectedAt: collectedAt ?? this.collectedAt,
      handoverStaffId: handoverStaffId ?? this.handoverStaffId,
      collectedBy: collectedBy ?? this.collectedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

