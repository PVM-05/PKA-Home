class RoleDelegationModel {
  final String id;
  final String delegatorId;
  final String? delegatorName;
  final String delegateId;
  final String? delegateName;
  final String delegatedRole; // 'accountant' hoặc 'technician'
  final DateTime startsAt;
  final DateTime endsAt;
  final String? note;
  final DateTime createdAt;

  const RoleDelegationModel({
    required this.id,
    required this.delegatorId,
    this.delegatorName,
    required this.delegateId,
    this.delegateName,
    required this.delegatedRole,
    required this.startsAt,
    required this.endsAt,
    this.note,
    required this.createdAt,
  });

  factory RoleDelegationModel.fromJson(Map<String, dynamic> json) {
    return RoleDelegationModel(
      id: json['id'] as String,
      delegatorId: json['delegator_id'] as String,
      delegatorName: (json['delegator'] as Map<String, dynamic>?)?['full_name'] as String?,
      delegateId: json['delegate_id'] as String,
      delegateName: (json['delegate'] as Map<String, dynamic>?)?['full_name'] as String?,
      delegatedRole: json['delegated_role'] as String,
      startsAt: DateTime.parse(json['starts_at'] as String).toLocal(),
      endsAt: DateTime.parse(json['ends_at'] as String).toLocal(),
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'delegator_id': delegatorId,
      'delegate_id': delegateId,
      'delegated_role': delegatedRole,
      'starts_at': startsAt.toUtc().toIso8601String(),
      'ends_at': endsAt.toUtc().toIso8601String(),
      'note': note,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  /// Kiểm tra xem ủy quyền có đang có hiệu lực tại thời điểm truyền vào (mặc định DateTime.now())
  bool isActiveAt([DateTime? target]) {
    final now = target ?? DateTime.now();
    return now.isAfter(startsAt) && now.isBefore(endsAt);
  }

  bool get isActive => isActiveAt();
  bool get isExpired => DateTime.now().isAfter(endsAt);
  bool get isUpcoming => DateTime.now().isBefore(startsAt);

  String get roleDisplayName {
    switch (delegatedRole) {
      case 'accountant':
        return 'Kế toán';
      case 'technician':
        return 'Kỹ thuật viên';
      default:
        return delegatedRole;
    }
  }
}
