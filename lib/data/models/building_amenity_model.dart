class BuildingAmenityModel {
  final String id;
  final String name;
  final String? description;
  final String? openHours;
  final int displayOrder;
  final DateTime? createdAt;

  BuildingAmenityModel({
    required this.id,
    required this.name,
    this.description,
    this.openHours,
    required this.displayOrder,
    this.createdAt,
  });

  factory BuildingAmenityModel.fromJson(Map<String, dynamic> json) {
    return BuildingAmenityModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      openHours: json['open_hours'] as String?,
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'open_hours': openHours,
    'display_order': displayOrder,
  };
}
