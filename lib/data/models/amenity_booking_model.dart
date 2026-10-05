class AmenityBookingModel {
  final String id;
  final String amenityId;
  final String apartmentId;
  final String? bookedBy;
  final DateTime bookingDate;
  final String timeSlot;
  final String status; // 'confirmed' | 'waitlist' | 'cancelled' | 'completed' | 'no_show'
  final int guestsCount;
  final double feeAmount;
  final double depositAmount;
  final String depositStatus; // 'none' | 'pending' | 'received' | 'refunded' | 'forfeited'
  final String? depositNotes;
  final DateTime? checkedInAt;
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
    this.guestsCount = 1,
    this.feeAmount = 0.0,
    this.depositAmount = 0.0,
    this.depositStatus = 'none',
    this.depositNotes,
    this.checkedInAt,
    required this.createdAt,
    this.updatedAt,
    this.amenityName,
    this.apartmentCode,
    this.bookerName,
  });

  bool get isConfirmed => status == 'confirmed';
  bool get isWaitlist => status == 'waitlist';
  bool get isCancelled => status == 'cancelled';
  bool get isCompleted => status == 'completed';
  bool get isNoShow => status == 'no_show';

  factory AmenityBookingModel.fromJson(Map<String, dynamic> json) {
    String? aName;
    if (json['building_amenities'] != null) {
      aName = json['building_amenities']['name'] as String?;
    }

    String? aptCode = json['apartment_code'] as String?;
    if (aptCode == null && json['apartments'] != null) {
      aptCode = json['apartments']['code'] as String?;
    }

    String? uName = json['booker_name'] as String?;
    if (uName == null && json['users'] != null) {
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
      guestsCount: (json['guests_count'] as num?)?.toInt() ?? 1,
      feeAmount: (json['fee_amount'] as num?)?.toDouble() ?? 0.0,
      depositAmount: (json['deposit_amount'] as num?)?.toDouble() ?? 0.0,
      depositStatus: json['deposit_status'] as String? ?? 'none',
      depositNotes: json['deposit_notes'] as String?,
      checkedInAt: json['checked_in_at'] != null
          ? DateTime.parse(json['checked_in_at'] as String)
          : null,
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
      'guests_count': guestsCount,
      'fee_amount': feeAmount,
      'deposit_amount': depositAmount,
      'deposit_status': depositStatus,
      if (depositNotes != null) 'deposit_notes': depositNotes,
      if (checkedInAt != null) 'checked_in_at': checkedInAt!.toIso8601String(),
    };
  }
}
