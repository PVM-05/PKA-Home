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
  final String status; // 'pending', 'approved', 'rejected', 'cancelled'
  final String? rejectReason;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final double ocrConfidence;
  final bool isAnomaly;
  final String anomalySeverity; // 'normal', 'info', 'warning', 'danger'
  final String? anomalyReason;
  final double? previousElectricReading;
  final double? previousWaterReading;
  final double? avgElectricUsage;
  final double? avgWaterUsage;
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
    this.ocrConfidence = 0.95,
    this.isAnomaly = false,
    this.anomalySeverity = 'normal',
    this.anomalyReason,
    this.previousElectricReading,
    this.previousWaterReading,
    this.avgElectricUsage,
    this.avgWaterUsage,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get isCancelled => status == 'cancelled';

  bool get hasAnomaly => isAnomaly;
  bool get isDangerAnomaly => isAnomaly && anomalySeverity == 'danger';
  bool get isWarningAnomaly => isAnomaly && anomalySeverity == 'warning';

  String get anomalySeverityDisplayName {
    switch (anomalySeverity) {
      case 'danger':
        return 'Báo động';
      case 'warning':
        return 'Cảnh báo';
      case 'info':
        return 'Lưu ý';
      case 'normal':
      default:
        return 'Bình thường';
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
      ocrConfidence: (json['ocr_confidence'] as num?)?.toDouble() ?? 0.95,
      isAnomaly: json['is_anomaly'] as bool? ?? false,
      anomalySeverity: json['anomaly_severity'] as String? ?? 'normal',
      anomalyReason: json['anomaly_reason'] as String?,
      previousElectricReading: (json['previous_electric_reading'] as num?)?.toDouble(),
      previousWaterReading: (json['previous_water_reading'] as num?)?.toDouble(),
      avgElectricUsage: (json['avg_electric_usage'] as num?)?.toDouble(),
      avgWaterUsage: (json['avg_water_usage'] as num?)?.toDouble(),
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
      'ocr_confidence': ocrConfidence,
      'is_anomaly': isAnomaly,
      'anomaly_severity': anomalySeverity,
      if (anomalyReason != null) 'anomaly_reason': anomalyReason,
      if (previousElectricReading != null) 'previous_electric_reading': previousElectricReading,
      if (previousWaterReading != null) 'previous_water_reading': previousWaterReading,
      if (avgElectricUsage != null) 'avg_electric_usage': avgElectricUsage,
      if (avgWaterUsage != null) 'avg_water_usage': avgWaterUsage,
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
    double? ocrConfidence,
    bool? isAnomaly,
    String? anomalySeverity,
    String? anomalyReason,
    double? previousElectricReading,
    double? previousWaterReading,
    double? avgElectricUsage,
    double? avgWaterUsage,
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
      ocrConfidence: ocrConfidence ?? this.ocrConfidence,
      isAnomaly: isAnomaly ?? this.isAnomaly,
      anomalySeverity: anomalySeverity ?? this.anomalySeverity,
      anomalyReason: anomalyReason ?? this.anomalyReason,
      previousElectricReading: previousElectricReading ?? this.previousElectricReading,
      previousWaterReading: previousWaterReading ?? this.previousWaterReading,
      avgElectricUsage: avgElectricUsage ?? this.avgElectricUsage,
      avgWaterUsage: avgWaterUsage ?? this.avgWaterUsage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
