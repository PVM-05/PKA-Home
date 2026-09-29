/// Model dữ liệu ánh xạ bảng `issue_ratings`
/// Lưu trữ đánh giá dịch vụ sự cố đa tiêu chí và điểm trung bình
class IssueRatingModel {
  final String id;
  final String issueReportId;
  final String reporterId;
  final int speedRating;
  final int attitudeRating;
  final int qualityRating;
  final double overallRating;
  final String? comment;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? reporterName;
  final String? apartmentCode;

  const IssueRatingModel({
    required this.id,
    required this.issueReportId,
    required this.reporterId,
    required this.speedRating,
    required this.attitudeRating,
    required this.qualityRating,
    required this.overallRating,
    this.comment,
    required this.createdAt,
    this.updatedAt,
    this.reporterName,
    this.apartmentCode,
  });

  /// Tính điểm trung bình cục bộ nếu CSDL chưa tính hoặc đang ở trạng thái draft
  static double calculateOverall(int speed, int attitude, int quality) {
    final avg = (speed + attitude + quality) / 3.0;
    return (avg * 10).round() / 10.0;
  }

  /// Trả về nhãn cảm nghĩ bằng tiếng Việt chuẩn mực
  static String getSatisfactionLabel(double rating) {
    if (rating >= 4.5) return 'Rất hài lòng';
    if (rating >= 3.5) return 'Hài lòng';
    if (rating >= 2.5) return 'Bình thường';
    if (rating >= 1.5) return 'Chưa hài lòng';
    return 'Rất thất vọng';
  }

  factory IssueRatingModel.fromJson(Map<String, dynamic> json) {
    final speed = (json['speed_rating'] as num?)?.toInt() ?? 5;
    final attitude = (json['attitude_rating'] as num?)?.toInt() ?? 5;
    final quality = (json['quality_rating'] as num?)?.toInt() ?? 5;

    final dynamic overallRaw = json['overall_rating'];
    final double overall = overallRaw != null
        ? (overallRaw as num).toDouble()
        : calculateOverall(speed, attitude, quality);

    String? parsedReporterName;
    if (json['users'] is Map<String, dynamic>) {
      parsedReporterName = json['users']['full_name'] as String?;
    }

    String? parsedApartmentCode;
    if (json['apartments'] is Map<String, dynamic>) {
      parsedApartmentCode = json['apartments']['code'] as String?;
    }

    return IssueRatingModel(
      id: json['id'] as String? ?? '',
      issueReportId: json['issue_report_id'] as String? ?? '',
      reporterId: json['reporter_id'] as String? ?? '',
      speedRating: speed,
      attitudeRating: attitude,
      qualityRating: quality,
      overallRating: overall,
      comment: json['comment'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      reporterName: parsedReporterName,
      apartmentCode: parsedApartmentCode,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'issue_report_id': issueReportId,
      'reporter_id': reporterId,
      'speed_rating': speedRating,
      'attitude_rating': attitudeRating,
      'quality_rating': qualityRating,
      if (comment != null && comment!.trim().isNotEmpty) 'comment': comment!.trim(),
    };
  }

  IssueRatingModel copyWith({
    String? id,
    String? issueReportId,
    String? reporterId,
    int? speedRating,
    int? attitudeRating,
    int? qualityRating,
    double? overallRating,
    String? comment,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? reporterName,
    String? apartmentCode,
  }) {
    return IssueRatingModel(
      id: id ?? this.id,
      issueReportId: issueReportId ?? this.issueReportId,
      reporterId: reporterId ?? this.reporterId,
      speedRating: speedRating ?? this.speedRating,
      attitudeRating: attitudeRating ?? this.attitudeRating,
      qualityRating: qualityRating ?? this.qualityRating,
      overallRating: overallRating ?? this.overallRating,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      reporterName: reporterName ?? this.reporterName,
      apartmentCode: apartmentCode ?? this.apartmentCode,
    );
  }
}
