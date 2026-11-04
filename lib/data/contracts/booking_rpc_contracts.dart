// Hợp đồng RPC cho Nhóm Tiện Ích & Đặt Chỗ (Amenities & Bookings)

// -------------------------------------------------------------
// 1. Đặt Lịch Tiện Ích (book_amenity_slot)
// -------------------------------------------------------------
class BookAmenitySlotRequestDto {
  final String amenityId;
  final String apartmentId;
  final String bookingDate; // YYYY-MM-DD
  final String timeSlot;
  final int guestsCount;
  final bool allowWaitlist;
  final String? notes;

  const BookAmenitySlotRequestDto({
    required this.amenityId,
    required this.apartmentId,
    required this.bookingDate,
    required this.timeSlot,
    required this.guestsCount,
    this.allowWaitlist = false,
    this.notes,
  });

  Map<String, dynamic> toRpcParams() {
    return {
      'p_amenity_id': amenityId,
      'p_apartment_id': apartmentId,
      'p_booking_date': bookingDate,
      'p_time_slot': timeSlot,
      'p_guests_count': guestsCount,
      'p_allow_waitlist': allowWaitlist,
      'p_notes': notes,
    };
  }
}

class BookAmenitySlotResponseDto {
  final bool success;
  final String? bookingId;
  final String? status;
  final String message;

  const BookAmenitySlotResponseDto({
    required this.success,
    this.bookingId,
    this.status,
    required this.message,
  });

  factory BookAmenitySlotResponseDto.fromRpc(dynamic raw) {
    if (raw == null) {
      return const BookAmenitySlotResponseDto(
        success: false,
        message: 'Phản hồi từ máy chủ trống rỗng.',
      );
    }
    final map = Map<String, dynamic>.from(raw as Map);
    return BookAmenitySlotResponseDto(
      success: map['success'] == true,
      bookingId: map['booking_id'] as String?,
      status: map['status'] as String?,
      message: map['message'] as String? ?? '',
    );
  }
}

// -------------------------------------------------------------
// 2. Hủy Lịch Đặt Chỗ Fail-Closed (cancel_amenity_booking)
// -------------------------------------------------------------
class CancelAmenityBookingRequestDto {
  final String bookingId;

  const CancelAmenityBookingRequestDto({required this.bookingId});

  Map<String, dynamic> toRpcParams() => {'p_booking_id': bookingId};
}

class CancelAmenityBookingResponseDto {
  final bool success;
  final String? bookingId;
  final String? status;
  final String message;

  const CancelAmenityBookingResponseDto({
    required this.success,
    this.bookingId,
    this.status,
    required this.message,
  });

  factory CancelAmenityBookingResponseDto.fromRpc(dynamic raw) {
    if (raw == null) {
      return const CancelAmenityBookingResponseDto(
        success: false,
        message: 'Phản hồi từ máy chủ trống rỗng.',
      );
    }
    final map = Map<String, dynamic>.from(raw as Map);
    return CancelAmenityBookingResponseDto(
      success: map['success'] == true,
      bookingId: map['booking_id'] as String?,
      status: map['status'] as String?,
      message: map['message'] as String? ?? '',
    );
  }
}

// -------------------------------------------------------------
// 3. Check-In Lượt Đặt Chỗ (check_in_amenity_booking)
// -------------------------------------------------------------
class CheckInAmenityBookingRequestDto {
  final String bookingId;

  const CheckInAmenityBookingRequestDto({required this.bookingId});

  Map<String, dynamic> toRpcParams() => {'p_booking_id': bookingId};
}

class CheckInAmenityBookingResponseDto {
  final bool success;
  final String? bookingId;
  final String? checkedInAt;
  final String message;

  const CheckInAmenityBookingResponseDto({
    required this.success,
    this.bookingId,
    this.checkedInAt,
    required this.message,
  });

  factory CheckInAmenityBookingResponseDto.fromRpc(dynamic raw) {
    if (raw == null) {
      return const CheckInAmenityBookingResponseDto(
        success: false,
        message: 'Phản hồi từ máy chủ trống rỗng.',
      );
    }
    final map = Map<String, dynamic>.from(raw as Map);
    return CheckInAmenityBookingResponseDto(
      success: map['success'] == true,
      bookingId: map['booking_id'] as String?,
      checkedInAt: map['checked_in_at'] as String?,
      message: map['message'] as String? ?? '',
    );
  }
}

// -------------------------------------------------------------
// 4. Lấy Tình Trạng Khung Giờ (get_amenity_slot_availability)
// -------------------------------------------------------------
class GetSlotAvailabilityRequestDto {
  final String amenityId;
  final String bookingDate; // YYYY-MM-DD

  const GetSlotAvailabilityRequestDto({
    required this.amenityId,
    required this.bookingDate,
  });

  Map<String, dynamic> toRpcParams() {
    return {
      'p_amenity_id': amenityId,
      'p_booking_date': bookingDate,
    };
  }
}

class SlotAvailabilityItemDto {
  final String timeSlot;
  final int bookedCount;
  final int maxCapacity;
  final bool isAvailable;

  const SlotAvailabilityItemDto({
    required this.timeSlot,
    required this.bookedCount,
    required this.maxCapacity,
    required this.isAvailable,
  });

  factory SlotAvailabilityItemDto.fromRpc(dynamic raw) {
    final map = Map<String, dynamic>.from(raw as Map);
    final booked = (map['booked_count'] as num?)?.toInt() ?? 0;
    final max = (map['max_capacity'] as num?)?.toInt() ?? 0;
    return SlotAvailabilityItemDto(
      timeSlot: map['time_slot'] as String? ?? '',
      bookedCount: booked,
      maxCapacity: max,
      isAvailable: map['is_available'] as bool? ?? (booked < max),
    );
  }
}
