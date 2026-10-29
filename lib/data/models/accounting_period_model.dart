class AccountingPeriodModel {
  final String id;
  final String buildingId;
  final String period;
  final String status;
  final DateTime? openedAt;
  final DateTime? closedAt;
  final String? closedBy;
  final String? notes;

  const AccountingPeriodModel({
    required this.id,
    required this.buildingId,
    required this.period,
    required this.status,
    this.openedAt,
    this.closedAt,
    this.closedBy,
    this.notes,
  });

  factory AccountingPeriodModel.fromJson(Map<String, dynamic> json) {
    return AccountingPeriodModel(
      id: json['id'] as String? ?? '',
      buildingId: json['building_id'] as String? ?? '',
      period: json['period'] as String? ?? '',
      status: json['status'] as String? ?? 'OPEN',
      openedAt: json['opened_at'] != null
          ? DateTime.tryParse(json['opened_at'].toString())
          : null,
      closedAt: json['closed_at'] != null
          ? DateTime.tryParse(json['closed_at'].toString())
          : null,
      closedBy: json['closed_by'] as String?,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'building_id': buildingId,
      'period': period,
      'status': status,
      'opened_at': openedAt?.toIso8601String(),
      'closed_at': closedAt?.toIso8601String(),
      'closed_by': closedBy,
      'notes': notes,
    };
  }

  bool get isClosed => status == 'CLOSED';

  String get statusVietnamese => isClosed ? 'Đã khóa sổ' : 'Đang mở';

  String get formattedPeriod {
    if (period.contains('-')) {
      final parts = period.split('-');
      if (parts.length == 2) {
        return 'Tháng ${parts[1]}/${parts[0]}';
      }
    }
    return period;
  }
}
