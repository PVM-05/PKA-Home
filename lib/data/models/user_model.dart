class UserModel {
  final String id;
  final String fullName;
  final String role; // 'resident' or 'management'
  final String? phone;
  final bool isLocked;

  UserModel({
    required this.id,
    required this.fullName,
    required this.role,
    this.phone,
    this.isLocked = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      role: json['role'] as String,
      phone: json['phone'] as String?,
      isLocked: json['is_locked'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'role': role,
      'phone': phone,
      'is_locked': isLocked,
    };
  }

  UserModel copyWith({
    String? id,
    String? fullName,
    String? role,
    String? phone,
    bool? isLocked,
  }) {
    return UserModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      isLocked: isLocked ?? this.isLocked,
    );
  }

  bool get isAdmin => role == 'admin' || role == 'management';
  bool get isAccountant => role == 'accountant';
  bool get isTechnician => role == 'technician';
  bool get isResident => role == 'resident';
  bool get isManagement => isAdmin || isAccountant || isTechnician;

  String get roleDisplayName => roleToDisplayName(role);

  static String roleToDisplayName(String? role) {
    switch (role) {
      case 'admin':
      case 'management':
        return 'Quản trị viên';
      case 'accountant':
        return 'Kế toán';
      case 'technician':
        return 'Kỹ thuật viên';
      case 'resident':
        return 'Cư dân';
      default:
        return role ?? 'Không xác định';
    }
  }
}

