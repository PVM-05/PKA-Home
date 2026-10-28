class AuditLogModel {
  final String id;
  final String? buildingId;
  final String? actorId;
  final String? actorName;
  final String action;
  final String entityName;
  final String? entityId;
  final Map<String, dynamic>? oldValues;
  final Map<String, dynamic>? newValues;
  final Map<String, dynamic>? details;
  final String? ipAddress;
  final DateTime createdAt;

  const AuditLogModel({
    required this.id,
    this.buildingId,
    this.actorId,
    this.actorName,
    required this.action,
    required this.entityName,
    this.entityId,
    this.oldValues,
    this.newValues,
    this.details,
    this.ipAddress,
    required this.createdAt,
  });

  factory AuditLogModel.fromJson(Map<String, dynamic> json) {
    return AuditLogModel(
      id: json['id'] as String,
      buildingId: json['building_id'] as String?,
      actorId: json['actor_id'] as String?,
      actorName: (json['actor'] as Map<String, dynamic>?)?['full_name'] as String?,
      action: json['action'] as String? ?? 'UNKNOWN',
      entityName: json['entity_name'] as String? ?? 'general',
      entityId: json['entity_id'] as String?,
      oldValues: json['old_values'] != null ? Map<String, dynamic>.from(json['old_values'] as Map) : null,
      newValues: json['new_values'] != null ? Map<String, dynamic>.from(json['new_values'] as Map) : null,
      details: json['details'] != null ? Map<String, dynamic>.from(json['details'] as Map) : null,
      ipAddress: json['ip_address'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String).toLocal()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (buildingId != null) 'building_id': buildingId,
      if (actorId != null) 'actor_id': actorId,
      'action': action,
      'entity_name': entityName,
      if (entityId != null) 'entity_id': entityId,
      if (oldValues != null) 'old_values': oldValues,
      if (newValues != null) 'new_values': newValues,
      if (details != null) 'details': details,
      if (ipAddress != null) 'ip_address': ipAddress,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  /// Tên hành động hiển thị tiếng Việt thân thiện
  String get actionDisplayName {
    switch (action) {
      case 'CONFIRM_PAYMENT':
        return 'Xác nhận thu tiền hóa đơn';
      case 'CREATE_INVOICE':
        return 'Phát hành hóa đơn mới';
      case 'UPDATE_INVOICE_STATUS':
        return 'Cập nhật trạng thái hóa đơn';
      case 'UPDATE_VEHICLE_STATUS':
        return 'Cập nhật phê duyệt thẻ xe';
      case 'CREATE_ROLE_DELEGATION':
        return 'Thiết lập ủy quyền vai trò';
      case 'REVOKE_ROLE_DELEGATION':
        return 'Thu hồi ủy quyền vai trò';
      case 'UPDATE_ISSUE_STATUS':
        return 'Cập nhật tiến độ sự cố';
      default:
        return action;
    }
  }

  /// Phân loại danh mục hành động
  String get category {
    if (entityName == 'invoices') return 'invoice';
    if (entityName == 'vehicles') return 'vehicle';
    if (entityName == 'role_delegations') return 'rbac';
    if (entityName == 'issue_reports') return 'issue';
    return 'general';
  }

  /// Kiểm tra xem hành động có liên quan đến tài chính hay không
  bool get isFinancialAction =>
      entityName == 'invoices' || action.contains('PAYMENT') || action.contains('INVOICE');

  /// Mô tả chi tiết biến động
  String get summaryDescription {
    if (action == 'CONFIRM_PAYMENT') {
      final method = newValues?['payment_method'] ?? 'chuyển khoản';
      return 'Đã xác nhận thu tiền thành công qua $method.';
    }
    if (action == 'UPDATE_INVOICE_STATUS') {
      final oldStatus = oldValues?['status'] ?? 'N/A';
      final newStatus = newValues?['status'] ?? 'N/A';
      return 'Trạng thái đổi từ [$oldStatus] sang [$newStatus].';
    }
    if (action == 'UPDATE_VEHICLE_STATUS') {
      final plate = newValues?['license_plate'] ?? oldValues?['license_plate'] ?? '';
      final status = newValues?['status'] == 'approved' ? 'Đã duyệt' : 'Từ chối';
      return 'Biển số $plate: $status.';
    }
    if (action == 'CREATE_ROLE_DELEGATION') {
      final role = newValues?['delegated_role'] ?? 'nhân viên';
      return 'Cấp quyền [$role] có thời hạn.';
    }
    if (action == 'REVOKE_ROLE_DELEGATION') {
      return 'Đã thu hồi ủy quyền vai trò.';
    }
    return 'Thao tác trên đối tượng $entityName.';
  }
}
