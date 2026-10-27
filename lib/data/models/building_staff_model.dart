class BuildingStaffModel {
  final String id;
  final String userId;
  final String buildingId;
  final String assignedRole;
  final bool isPrimary;
  final DateTime? createdAt;

  BuildingStaffModel({
    required this.id,
    required this.userId,
    required this.buildingId,
    this.assignedRole = 'staff',
    this.isPrimary = false,
    this.createdAt,
  });

  factory BuildingStaffModel.fromJson(Map<String, dynamic> json) {
    return BuildingStaffModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      buildingId: json['building_id'] as String,
      assignedRole: json['assigned_role'] as String? ?? 'staff',
      isPrimary: json['is_primary'] as bool? ?? false,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'building_id': buildingId,
    'assigned_role': assignedRole,
    'is_primary': isPrimary,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BuildingStaffModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
