/// DTO phục vụ gửi kết quả nghiệm thu tiện ích và xử lý tiền cọc
class AmenityInspectionModel {
  final String bookingId;
  final String inspectionResult; // 'passed' | 'violated'
  final double forfeitedAmount;
  final String? notes;
  final List<String> imageUrls;

  const AmenityInspectionModel({
    required this.bookingId,
    required this.inspectionResult,
    this.forfeitedAmount = 0.0,
    this.notes,
    this.imageUrls = const [],
  });

  bool get isPassed => inspectionResult == 'passed';
  bool get isViolated => inspectionResult == 'violated';

  Map<String, dynamic> toRpcParams() {
    return {
      'p_booking_id': bookingId,
      'p_inspection_result': inspectionResult,
      'p_forfeited_amount': forfeitedAmount,
      'p_notes': notes,
      'p_image_urls': imageUrls,
    };
  }

  factory AmenityInspectionModel.fromJson(Map<String, dynamic> json) {
    return AmenityInspectionModel(
      bookingId: json['booking_id'] as String? ?? '',
      inspectionResult: json['inspection_result'] as String? ?? 'passed',
      forfeitedAmount: (json['forfeited_amount'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes'] as String?,
      imageUrls: (json['image_urls'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}
