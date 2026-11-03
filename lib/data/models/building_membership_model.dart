class BuildingMembershipModel {
  final String id;
  final String buildingId;
  final String userId;
  final String buildingRole;
  final String? apartmentId;
  final bool isActive;
  final DateTime? expiresAt;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? buildingName;
  final String? buildingCode;
  final String? apartmentCode;

  const BuildingMembershipModel({
    required this.id,
    required this.buildingId,
    required this.userId,
    required this.buildingRole,
    this.apartmentId,
    this.isActive = true,
    this.expiresAt,
    required this.createdAt,
    this.updatedAt,
    this.buildingName,
    this.buildingCode,
    this.apartmentCode,
  });

  bool get isManager => buildingRole.toLowerCase() == 'manager';
  bool get isAccountant => buildingRole.toLowerCase() == 'accountant';
  bool get isTechnician => buildingRole.toLowerCase() == 'technician';
  bool get isSecurity => buildingRole.toLowerCase() == 'security';
  bool get isReceptionist => buildingRole.toLowerCase() == 'receptionist';
  bool get isBoardMember => buildingRole.toLowerCase() == 'board_member';
  bool get isResident => buildingRole.toLowerCase() == 'resident';

  /// Nhân viên quản lý vận hành tòa nhà
  bool get isManagementStaff {
    final role = buildingRole.toLowerCase();
    return role == 'manager' ||
        role == 'accountant' ||
        role == 'technician' ||
        role == 'security' ||
        role == 'receptionist' ||
        role == 'admin' ||
        role == 'staff';
  }

  /// Kiểm tra xem ủy quyền / quyền thành viên đã hết hạn chưa
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Tên vai trò hiển thị tiếng Việt chuẩn mực
  String get roleDisplayName {
    switch (buildingRole.toLowerCase()) {
      case 'manager':
        return 'Trưởng ban quản lý';
      case 'accountant':
        return 'Kế toán tòa nhà';
      case 'technician':
        return 'Kỹ thuật viên';
      case 'security':
        return 'Nhân viên an ninh';
      case 'receptionist':
        return 'Lễ tân sảnh';
      case 'board_member':
        return 'Thành viên Ban quản trị';
      case 'resident':
        return 'Cư dân căn hộ';
      case 'admin':
        return 'Quản trị viên';
      default:
        return 'Thành viên tòa nhà';
    }
  }

  factory BuildingMembershipModel.fromJson(Map<String, dynamic> json) {
    return BuildingMembershipModel(
      id: json['id'] as String,
      buildingId: json['building_id'] as String,
      userId: json['user_id'] as String,
      buildingRole: json['building_role'] as String? ?? 'resident',
      apartmentId: json['apartment_id'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      expiresAt: json['expires_at'] != null ? DateTime.parse(json['expires_at'] as String) : null,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
      buildingName: json['building_name'] as String? ?? json['buildings']?['name'] as String?,
      buildingCode: json['building_code'] as String? ?? json['buildings']?['code'] as String?,
      apartmentCode: json['apartment_code'] as String? ?? json['apartments']?['code'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'building_id': buildingId,
        'user_id': userId,
        'building_role': buildingRole,
        if (apartmentId != null) 'apartment_id': apartmentId,
        'is_active': isActive,
        if (expiresAt != null) 'expires_at': expiresAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
        if (buildingName != null) 'building_name': buildingName,
        if (buildingCode != null) 'building_code': buildingCode,
        if (apartmentCode != null) 'apartment_code': apartmentCode,
      };

  BuildingMembershipModel copyWith({
    String? id,
    String? buildingId,
    String? userId,
    String? buildingRole,
    String? apartmentId,
    bool? isActive,
    DateTime? expiresAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? buildingName,
    String? buildingCode,
    String? apartmentCode,
  }) {
    return BuildingMembershipModel(
      id: id ?? this.id,
      buildingId: buildingId ?? this.buildingId,
      userId: userId ?? this.userId,
      buildingRole: buildingRole ?? this.buildingRole,
      apartmentId: apartmentId ?? this.apartmentId,
      isActive: isActive ?? this.isActive,
      expiresAt: expiresAt ?? this.expiresAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      buildingName: buildingName ?? this.buildingName,
      buildingCode: buildingCode ?? this.buildingCode,
      apartmentCode: apartmentCode ?? this.apartmentCode,
    );
  }
}
