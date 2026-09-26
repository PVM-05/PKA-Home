class AmenityBookingModel {
  final String id;
  final String amenityId;
  final String apartmentId;
  final String? bookedBy;
  final DateTime bookingDate;
  final String timeSlot;
  final String status; // 'confirmed' | 'cancelled'
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? amenityName;
  final String? apartmentCode;
  final String? bookerName;

  AmenityBookingModel({
    required this.id,
    required this.amenityId,
    required this.apartmentId,
    this.bookedBy,
    required this.bookingDate,
    required this.timeSlot,
    this.status = 'confirmed',
    required this.createdAt,
    this.updatedAt,
    this.amenityName,
    this.apartmentCode,
    this.bookerName,
  });

  bool get isConfirmed => status == 'confirmed';
  bool get isCancelled => status == 'cancelled';

  factory AmenityBookingModel.fromJson(Map<String, dynamic> json) {
    String? aName;
    if (json['building_amenities'] != null) {
      aName = json['building_amenities']['name'] as String?;
    }

    String? aptCode;
    if (json['apartments'] != null) {
      aptCode = json['apartments']['code'] as String?;
    }

    String? uName;
    if (json['users'] != null) {
      uName = json['users']['full_name'] as String?;
    }

    return AmenityBookingModel(
      id: json['id'] as String? ?? '',
      amenityId: json['amenity_id'] as String? ?? '',
      apartmentId: json['apartment_id'] as String? ?? '',
      bookedBy: json['booked_by'] as String?,
      bookingDate: json['booking_date'] != null
          ? DateTime.parse(json['booking_date'] as String)
          : DateTime.now(),
      timeSlot: json['time_slot'] as String? ?? '',
      status: json['status'] as String? ?? 'confirmed',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      amenityName: aName,
      apartmentCode: aptCode,
      bookerName: uName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amenity_id': amenityId,
      'apartment_id': apartmentId,
      if (bookedBy != null) 'booked_by': bookedBy,
      'booking_date': "${bookingDate.year.toString().padLeft(4, '0')}-${bookingDate.month.toString().padLeft(2, '0')}-${bookingDate.day.toString().padLeft(2, '0')}",
      'time_slot': timeSlot,
      'status': status,
    };
  }
}
