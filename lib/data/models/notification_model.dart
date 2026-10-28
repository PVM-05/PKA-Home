class NotificationModel {
  final String id;
  final String? buildingId;
  final String userId;
  final String? apartmentId;
  final String title;
  final String body;
  final String type;
  final Map<String, dynamic> payload;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    this.buildingId,
    required this.userId,
    this.apartmentId,
    required this.title,
    required this.body,
    this.type = 'invoice_due_reminder',
    this.payload = const {},
    this.isRead = false,
    required this.createdAt,
  });

  bool get isInvoiceReminder =>
      type == 'invoice_due_reminder' ||
      type == 'invoice_due_soon' ||
      type == 'invoice_due_today' ||
      type == 'invoice_overdue' ||
      type == 'new_invoice';

  bool get isAnnouncement => type == 'announcement';
  bool get isIssueUpdate => type == 'issue_update';

  String get typeDisplayName {
    switch (type) {
      case 'invoice_due_reminder':
      case 'invoice_due_soon':
      case 'invoice_due_today':
      case 'invoice_overdue':
      case 'new_invoice':
        return 'Hóa đơn';
      case 'equipment_maintenance':
        return 'Bảo trì';
      case 'issue_update':
        return 'Sự cố';
      case 'announcement':
      default:
        return 'Thông báo';
    }
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] ?? '',
      buildingId: json['building_id'],
      userId: json['user_id'] ?? '',
      apartmentId: json['apartment_id'],
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      type: json['type'] ?? 'invoice_due_reminder',
      payload: json['payload'] is Map ? Map<String, dynamic>.from(json['payload']) : {},
      isRead: json['is_read'] ?? false,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (buildingId != null) 'building_id': buildingId,
      'user_id': userId,
      'apartment_id': apartmentId,
      'title': title,
      'body': body,
      'type': type,
      'payload': payload,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
    };
  }

  NotificationModel copyWith({
    String? id,
    String? buildingId,
    String? userId,
    String? apartmentId,
    String? title,
    String? body,
    String? type,
    Map<String, dynamic>? payload,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      buildingId: buildingId ?? this.buildingId,
      userId: userId ?? this.userId,
      apartmentId: apartmentId ?? this.apartmentId,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      payload: payload ?? this.payload,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
