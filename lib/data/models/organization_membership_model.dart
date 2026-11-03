class OrganizationMembershipModel {
  final String id;
  final String organizationId;
  final String userId;
  final String orgRole; // 'owner', 'admin', 'member'
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? organizationName;

  const OrganizationMembershipModel({
    required this.id,
    required this.organizationId,
    required this.userId,
    required this.orgRole,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
    this.organizationName,
  });

  bool get isOwner => orgRole.toLowerCase() == 'owner';
  bool get isAdmin => orgRole.toLowerCase() == 'admin';
  bool get isMember => orgRole.toLowerCase() == 'member';

  String get orgRoleDisplayName {
    switch (orgRole.toLowerCase()) {
      case 'owner':
        return 'Chủ sở hữu tổ chức';
      case 'admin':
        return 'Quản trị viên tổ chức';
      case 'member':
      default:
        return 'Thành viên tổ chức';
    }
  }

  factory OrganizationMembershipModel.fromJson(Map<String, dynamic> json) {
    return OrganizationMembershipModel(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      userId: json['user_id'] as String,
      orgRole: json['org_role'] as String? ?? 'member',
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
      organizationName: json['organization_name'] as String? ?? json['organizations']?['name'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'organization_id': organizationId,
        'user_id': userId,
        'org_role': orgRole,
        'is_active': isActive,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
        if (organizationName != null) 'organization_name': organizationName,
      };

  OrganizationMembershipModel copyWith({
    String? id,
    String? organizationId,
    String? userId,
    String? orgRole,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? organizationName,
  }) {
    return OrganizationMembershipModel(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      userId: userId ?? this.userId,
      orgRole: orgRole ?? this.orgRole,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      organizationName: organizationName ?? this.organizationName,
    );
  }
}
