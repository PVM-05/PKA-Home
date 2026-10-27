class BuildingModel {
  final String id;
  final String organizationId;
  final String name;
  final String code;
  final String? address;
  final int totalFloors;
  final int totalUnits;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  BuildingModel({
    required this.id,
    required this.organizationId,
    required this.name,
    required this.code,
    this.address,
    this.totalFloors = 20,
    this.totalUnits = 200,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory BuildingModel.fromJson(Map<String, dynamic> json) {
    return BuildingModel(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String? ?? '',
      name: json['name'] as String,
      code: json['code'] as String,
      address: json['address'] as String?,
      totalFloors: (json['total_floors'] as num?)?.toInt() ?? 20,
      totalUnits: (json['total_units'] as num?)?.toInt() ?? 200,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'organization_id': organizationId,
    'name': name,
    'code': code,
    'address': address,
    'total_floors': totalFloors,
    'total_units': totalUnits,
    'is_active': isActive,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BuildingModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
