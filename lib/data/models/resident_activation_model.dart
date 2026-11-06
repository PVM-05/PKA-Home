class ResidentActivationModel {
  final String? activationId;
  final String userId;
  final String fullName;
  final String phone;
  final String apartmentCode;
  final String relationRole;
  final String activationCode;
  final String status;
  final bool isActive;
  final DateTime? createdAt;

  const ResidentActivationModel({
    this.activationId,
    required this.userId,
    required this.fullName,
    required this.phone,
    required this.apartmentCode,
    this.relationRole = 'member',
    this.activationCode = '',
    this.status = 'pending',
    this.isActive = false,
    this.createdAt,
  });

  String get relationRoleText {
    switch (relationRole.toLowerCase().trim()) {
      case 'owner':
        return 'Chủ hộ';
      case 'tenant':
        return 'Người thuê';
      case 'family_member':
        return 'Thành viên';
      default:
        return 'Cư dân';
    }
  }

  String get statusText {
    if (isActive || status == 'activated') {
      return 'Đã kích hoạt';
    }
    if (status == 'otp_sent') {
      return 'Đang chờ OTP';
    }
    if (activationCode.isNotEmpty) {
      return 'Đã cấp mã (Chưa kích hoạt)';
    }
    return 'Chưa cấp mã';
  }

  factory ResidentActivationModel.fromJson(Map<String, dynamic> json) {
    return ResidentActivationModel(
      activationId: json['activation_id']?.toString(),
      userId: json['user_id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      apartmentCode: json['apartment_code']?.toString() ?? '',
      relationRole: json['relation_role']?.toString() ?? 'member',
      activationCode: json['activation_code']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      isActive: json['is_active'] == true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'activation_id': activationId,
      'user_id': userId,
      'full_name': fullName,
      'phone': phone,
      'apartment_code': apartmentCode,
      'relation_role': relationRole,
      'activation_code': activationCode,
      'status': status,
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
