class AmenityBookingModel {
  final String id;
  final String amenityId;
  final String apartmentId;
  final String? bookedBy;
  final DateTime bookingDate;
  final String timeSlot;
  final String status; // 'confirmed' | 'pending_payment' | 'checked_in' | 'waitlist' | 'cancelled' | 'completed' | 'no_show'
  final int guestsCount;
  final double feeAmount;
  final double depositAmount;
  final String depositStatus; // 'none' | 'pending' | 'received' | 'refunded' | 'forfeited'
  final String? depositNotes;
  final String? notes;
  final DateTime? checkedInAt;
  final String? checkedInBy;
  final String? qrTicketToken;
  final String? inspectedBy;
  final DateTime? inspectedAt;
  final String? inspectionResult; // 'pending' | 'passed' | 'violated'
  final double forfeitedAmount;
  final double refundAmount;
  final String? inspectionNotes;
  final List<String> inspectionImageUrls;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? amenityName;
  final String? apartmentCode;
  final String? bookerName;
  final bool isMyBooking;
  final String? transactionCode;
  final String? paymentMethod;
  final String? paymentStatus;
  final DateTime? paidAt;

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
    this.notes,
    this.checkedInAt,
    this.checkedInBy,
    this.qrTicketToken,
    this.inspectedBy,
    this.inspectedAt,
    this.inspectionResult,
    this.forfeitedAmount = 0.0,
    this.refundAmount = 0.0,
    this.inspectionNotes,
    this.inspectionImageUrls = const [],
    required this.createdAt,
    this.updatedAt,
    this.amenityName,
    this.apartmentCode,
    this.bookerName,
    this.isMyBooking = false,
    this.transactionCode,
    this.paymentMethod,
    this.paymentStatus,
    this.paidAt,
  });

  bool get hasFee => (feeAmount > 0 || depositAmount > 0);
  double get totalPaymentAmount => feeAmount + depositAmount;

  bool get isConfirmed => status == 'confirmed';
  bool get isPendingPayment => status == 'pending_payment';
  bool get isCheckedIn => status == 'checked_in';
  bool get isWaitlist => status == 'waitlist';
  bool get isCancelled => status == 'cancelled';
  bool get isCompleted => status == 'completed';
  bool get isNoShow => status == 'no_show';

  bool get isRefunded => depositStatus == 'refunded';
  bool get isForfeited => depositStatus == 'forfeited';
  bool get isDepositReceived => depositStatus == 'received';

  String get statusDisplayName {
    switch (status) {
      case 'confirmed':
        return 'Đã xác nhận';
      case 'pending_payment':
        return 'Chờ thanh toán';
      case 'checked_in':
        return 'Đang sử dụng';
      case 'waitlist':
        return 'Danh sách chờ';
      case 'completed':
        return 'Đã hoàn thành';
      case 'no_show':
        return 'Vắng mặt';
      case 'cancelled':
        return 'Đã hủy';
      default:
        return 'Chờ duyệt';
    }
  }

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

    String? txCode = json['transaction_code'] as String?;
    String? pStatus = json['payment_status'] as String?;
    String? pMethod = json['payment_method'] as String?;
    DateTime? pPaidAt = json['paid_at'] != null ? DateTime.tryParse(json['paid_at'] as String) : null;

    if (json['payment_transactions'] != null && json['payment_transactions'] is List) {
      final txList = json['payment_transactions'] as List;
      if (txList.isNotEmpty) {
        final latestTx = txList.last as Map<String, dynamic>;
        txCode ??= latestTx['transaction_code'] as String?;
        pStatus ??= latestTx['status'] as String?;
        pMethod ??= latestTx['payment_method'] as String?;
        if (latestTx['confirmed_at'] != null) {
          pPaidAt ??= DateTime.tryParse(latestTx['confirmed_at'] as String)?.toLocal();
        } else if (latestTx['created_at'] != null) {
          pPaidAt ??= DateTime.tryParse(latestTx['created_at'] as String)?.toLocal();
        }
      }
    }

    DateTime? checkInDate;
    if (json['check_in_time'] != null) {
      checkInDate = DateTime.tryParse(json['check_in_time'] as String);
    } else if (json['checked_in_at'] != null) {
      checkInDate = DateTime.tryParse(json['checked_in_at'] as String);
    }

    List<String> imgUrls = const [];
    if (json['inspection_image_urls'] != null && json['inspection_image_urls'] is List) {
      imgUrls = (json['inspection_image_urls'] as List).map((e) => e.toString()).toList();
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
      notes: json['notes'] as String?,
      checkedInAt: checkInDate,
      checkedInBy: json['checked_in_by'] as String?,
      qrTicketToken: json['qr_ticket_token'] as String?,
      inspectedBy: json['inspected_by'] as String?,
      inspectedAt: json['inspected_at'] != null ? DateTime.tryParse(json['inspected_at'] as String) : null,
      inspectionResult: json['inspection_result'] as String?,
      forfeitedAmount: (json['forfeited_amount'] as num?)?.toDouble() ?? 0.0,
      refundAmount: (json['refund_amount'] as num?)?.toDouble() ?? 0.0,
      inspectionNotes: json['inspection_notes'] as String?,
      inspectionImageUrls: imgUrls,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      amenityName: aName,
      apartmentCode: aptCode,
      bookerName: uName,
      isMyBooking: json['is_my_booking'] as bool? ?? false,
      transactionCode: txCode,
      paymentMethod: pMethod,
      paymentStatus: pStatus,
      paidAt: pPaidAt,
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
      if (notes != null) 'notes': notes,
      if (checkedInAt != null) 'checked_in_at': checkedInAt!.toIso8601String(),
      if (qrTicketToken != null) 'qr_ticket_token': qrTicketToken,
      if (checkedInBy != null) 'checked_in_by': checkedInBy,
      if (inspectedBy != null) 'inspected_by': inspectedBy,
      if (inspectedAt != null) 'inspected_at': inspectedAt!.toIso8601String(),
      if (inspectionResult != null) 'inspection_result': inspectionResult,
      'forfeited_amount': forfeitedAmount,
      'refund_amount': refundAmount,
      if (inspectionNotes != null) 'inspection_notes': inspectionNotes,
      'inspection_image_urls': inspectionImageUrls,
    };
  }
}
