/// Model biểu diễn Hồ sơ thiết bị kỹ thuật toàn tòa nhà (Building Equipment)
class BuildingEquipmentModel {
  final String id;
  final String code;
  final String name;
  final String category;
  final String building;
  final String location;
  final DateTime? installationDate;
  final DateTime? warrantyUntil;
  final int maintenanceIntervalDays;
  final DateTime? lastMaintenanceDate;
  final DateTime? nextMaintenanceDate;
  final String status;
  final String? specifications;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const BuildingEquipmentModel({
    required this.id,
    required this.code,
    required this.name,
    required this.category,
    this.building = 'Toàn khu',
    required this.location,
    this.installationDate,
    this.warrantyUntil,
    this.maintenanceIntervalDays = 30,
    this.lastMaintenanceDate,
    this.nextMaintenanceDate,
    this.status = 'operational',
    this.specifications,
    this.createdAt,
    this.updatedAt,
  });

  factory BuildingEquipmentModel.fromJson(Map<String, dynamic> json) {
    return BuildingEquipmentModel(
      id: json['id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      category: json['category'] as String? ?? 'other',
      building: json['building'] as String? ?? 'Toàn khu',
      location: json['location'] as String? ?? '',
      installationDate: json['installation_date'] != null
          ? DateTime.tryParse(json['installation_date'].toString())
          : null,
      warrantyUntil: json['warranty_until'] != null
          ? DateTime.tryParse(json['warranty_until'].toString())
          : null,
      maintenanceIntervalDays: (json['maintenance_interval_days'] as num?)?.toInt() ?? 30,
      lastMaintenanceDate: json['last_maintenance_date'] != null
          ? DateTime.tryParse(json['last_maintenance_date'].toString())
          : null,
      nextMaintenanceDate: json['next_maintenance_date'] != null
          ? DateTime.tryParse(json['next_maintenance_date'].toString())
          : null,
      status: json['status'] as String? ?? 'operational',
      specifications: json['specifications'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'category': category,
      'building': building,
      'location': location,
      'installation_date': installationDate?.toIso8601String().split('T').first,
      'warranty_until': warrantyUntil?.toIso8601String().split('T').first,
      'maintenance_interval_days': maintenanceIntervalDays,
      'last_maintenance_date': lastMaintenanceDate?.toIso8601String(),
      'next_maintenance_date': nextMaintenanceDate?.toIso8601String(),
      'status': status,
      'specifications': specifications,
    };
  }

  BuildingEquipmentModel copyWith({
    String? id,
    String? code,
    String? name,
    String? category,
    String? building,
    String? location,
    DateTime? installationDate,
    DateTime? warrantyUntil,
    int? maintenanceIntervalDays,
    DateTime? lastMaintenanceDate,
    DateTime? nextMaintenanceDate,
    String? status,
    String? specifications,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BuildingEquipmentModel(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      category: category ?? this.category,
      building: building ?? this.building,
      location: location ?? this.location,
      installationDate: installationDate ?? this.installationDate,
      warrantyUntil: warrantyUntil ?? this.warrantyUntil,
      maintenanceIntervalDays: maintenanceIntervalDays ?? this.maintenanceIntervalDays,
      lastMaintenanceDate: lastMaintenanceDate ?? this.lastMaintenanceDate,
      nextMaintenanceDate: nextMaintenanceDate ?? this.nextMaintenanceDate,
      status: status ?? this.status,
      specifications: specifications ?? this.specifications,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get categoryDisplayName {
    switch (category) {
      case 'elevator':
        return 'Thang máy';
      case 'fire_safety':
        return 'Hệ thống PCCC';
      case 'water_pump':
        return 'Máy bơm nước';
      case 'generator':
        return 'Máy phát điện';
      case 'electrical':
        return 'Hệ thống điện';
      case 'hvac':
        return 'Hệ thống thông gió / HVAC';
      default:
        return 'Thiết bị khác';
    }
  }

  String get statusDisplayName {
    switch (status) {
      case 'operational':
        return 'Hoạt động tốt';
      case 'under_maintenance':
        return 'Đang bảo dưỡng';
      case 'degraded':
        return 'Cảnh báo hư hỏng';
      case 'inactive':
        return 'Ngừng hoạt động';
      default:
        return status;
    }
  }

  bool get isUnderMaintenance => status == 'under_maintenance';

  bool get isUpcomingMaintenance {
    if (nextMaintenanceDate == null || status == 'inactive') return false;
    final now = DateTime.now();
    return nextMaintenanceDate!.isAfter(now) &&
        nextMaintenanceDate!.isBefore(now.add(const Duration(days: 7)));
  }

  bool get isOverdueMaintenance {
    if (nextMaintenanceDate == null || status == 'inactive' || status == 'under_maintenance') {
      return false;
    }
    return nextMaintenanceDate!.isBefore(DateTime.now());
  }
}
