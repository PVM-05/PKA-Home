class AmenityMaintenanceModel {
  final String id;
  final String amenityId;
  final DateTime startTime;
  final DateTime endTime;
  final String reason;
  final String? createdBy;
  final DateTime? createdAt;
  final String? amenityName;

  AmenityMaintenanceModel({
    required this.id,
    required this.amenityId,
    required this.startTime,
    required this.endTime,
    required this.reason,
    this.createdBy,
    this.createdAt,
    this.amenityName,
  });

  factory AmenityMaintenanceModel.fromJson(Map<String, dynamic> json) {
    String? aName;
    if (json['building_amenities'] != null) {
      aName = json['building_amenities']['name'] as String?;
    }

    return AmenityMaintenanceModel(
      id: json['id'] as String,
      amenityId: json['amenity_id'] as String,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: DateTime.parse(json['end_time'] as String),
      reason: json['reason'] as String? ?? '',
      createdBy: json['created_by'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      amenityName: aName,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'amenity_id': amenityId,
    'start_time': startTime.toIso8601String(),
    'end_time': endTime.toIso8601String(),
    'reason': reason,
    if (createdBy != null) 'created_by': createdBy,
  };
}
