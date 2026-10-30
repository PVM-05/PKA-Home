import 'package:intl/intl.dart';

class ApartmentInvitationModel {
  final String id;
  final String apartmentId;
  final String? apartmentCode;
  final String createdBy;
  final String inviteCode;
  final String targetRole; // 'tenant', 'member'
  final int maxUses;
  final int usedCount;
  final DateTime expiresAt;
  final String status; // 'active', 'revoked', 'exhausted', 'expired'
  final DateTime createdAt;

  const ApartmentInvitationModel({
    required this.id,
    required this.apartmentId,
    this.apartmentCode,
    required this.createdBy,
    required this.inviteCode,
    required this.targetRole,
    this.maxUses = 1,
    this.usedCount = 0,
    required this.expiresAt,
    required this.status,
    required this.createdAt,
  });

  bool get isExpired => expiresAt.isBefore(DateTime.now()) || status == 'expired';

  bool get isUsable => status == 'active' && !isExpired && usedCount < maxUses;

  String get shareableUrl => 'https://pkahome.vn/invite?code=$inviteCode';

  String get formattedExpiresAt => DateFormat('dd/MM/yyyy HH:mm').format(expiresAt);

  String get displayTargetRole {
    switch (targetRole.toLowerCase()) {
      case 'tenant':
        return 'Người thuê';
      case 'member':
      default:
        return 'Thành viên ở cùng';
    }
  }

  String get displayStatus {
    if (isExpired) return 'Đã hết hạn';
    if (status == 'exhausted' || usedCount >= maxUses) return 'Đã dùng hết';
    if (status == 'revoked') return 'Đã hủy';
    return 'Còn hiệu lực';
  }

  factory ApartmentInvitationModel.fromJson(Map<String, dynamic> json) {
    return ApartmentInvitationModel(
      id: json['id'] as String? ?? '',
      apartmentId: json['apartment_id'] as String? ?? '',
      apartmentCode: json['apartment_code'] as String?,
      createdBy: json['created_by'] as String? ?? '',
      inviteCode: json['invite_code'] as String? ?? '',
      targetRole: json['target_role'] as String? ?? 'member',
      maxUses: (json['max_uses'] as num?)?.toInt() ?? 1,
      usedCount: (json['used_count'] as num?)?.toInt() ?? 0,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : DateTime.now(),
      status: json['status'] as String? ?? 'active',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'apartment_id': apartmentId,
      'apartment_code': apartmentCode,
      'created_by': createdBy,
      'invite_code': inviteCode,
      'target_role': targetRole,
      'max_uses': maxUses,
      'used_count': usedCount,
      'expires_at': expiresAt.toIso8601String(),
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
