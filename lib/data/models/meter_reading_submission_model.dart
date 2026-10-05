class MeterReadingSubmissionModel {
  final String id;
  final String apartmentId;
  final String? apartmentCode;
  final String submittedBy;
  final String? submitterName;
  final String period; // '10/2026'
  final double electricReading;
  final double waterReading;
  final String? electricImageUrl;
  final String? waterImageUrl;
  final String status; // 'pending', 'approved', 'rejected'
  final String? rejectReason;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final DateTime createdAt;
  final DateTime? updatedAt;

  MeterReadingSubmissionModel({
    required this.id,
    required this.apartmentId,
    this.apartmentCode,
    required this.submittedBy,
    this.submitterName,
    required this.period,
    required this.electricReading,
    required this.waterReading,
    this.electricImageUrl,
    this.waterImageUrl,
    this.status = 'pending',
    this.rejectReason,
    this.reviewedBy,
    this.reviewedAt,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

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

  factory MeterReadingSubmissionModel.fromJson(Map<String, dynamic> json) {
    String? aptCode = json['apartment_code'] as String?;
    if (aptCode == null && json['apartments'] != null) {
      aptCode = json['apartments']['code'] as String?;
    }

    String? subName = json['submitter_name'] as String?;
    if (subName == null && json['users'] != null) {
      subName = json['users']['full_name'] as String?;
    }

    return MeterReadingSubmissionModel(
      id: json['id'] as String? ?? '',
      apartmentId: json['apartment_id'] as String? ?? '',
      apartmentCode: aptCode,
      submittedBy: json['submitted_by'] as String? ?? '',
      submitterName: subName,
      period: json['period'] as String? ?? '',
      electricReading: (json['electric_reading'] as num?)?.toDouble() ?? 0.0,
      waterReading: (json['water_reading'] as num?)?.toDouble() ?? 0.0,
      electricImageUrl: json['electric_image_url'] as String?,
      waterImageUrl: json['water_image_url'] as String?,
      status: json['status'] as String? ?? 'pending',
      rejectReason: json['reject_reason'] as String?,
      reviewedBy: json['reviewed_by'] as String?,
      reviewedAt: json['reviewed_at'] != null ? DateTime.parse(json['reviewed_at'] as String) : null,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'apartment_id': apartmentId,
      if (apartmentCode != null) 'apartment_code': apartmentCode,
      'submitted_by': submittedBy,
      if (submitterName != null) 'submitter_name': submitterName,
      'period': period,
      'electric_reading': electricReading,
      'water_reading': waterReading,
      if (electricImageUrl != null) 'electric_image_url': electricImageUrl,
      if (waterImageUrl != null) 'water_image_url': waterImageUrl,
      'status': status,
      if (rejectReason != null) 'reject_reason': rejectReason,
      if (reviewedBy != null) 'reviewed_by': reviewedBy,
      if (reviewedAt != null) 'reviewed_at': reviewedAt!.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  MeterReadingSubmissionModel copyWith({
    String? id,
    String? apartmentId,
    String? apartmentCode,
    String? submittedBy,
    String? submitterName,
    String? period,
    double? electricReading,
    double? waterReading,
    String? electricImageUrl,
    String? waterImageUrl,
    String? status,
    String? rejectReason,
    String? reviewedBy,
    DateTime? reviewedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MeterReadingSubmissionModel(
      id: id ?? this.id,
      apartmentId: apartmentId ?? this.apartmentId,
      apartmentCode: apartmentCode ?? this.apartmentCode,
      submittedBy: submittedBy ?? this.submittedBy,
      submitterName: submitterName ?? this.submitterName,
      period: period ?? this.period,
      electricReading: electricReading ?? this.electricReading,
      waterReading: waterReading ?? this.waterReading,
      electricImageUrl: electricImageUrl ?? this.electricImageUrl,
      waterImageUrl: waterImageUrl ?? this.waterImageUrl,
      status: status ?? this.status,
      rejectReason: rejectReason ?? this.rejectReason,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
