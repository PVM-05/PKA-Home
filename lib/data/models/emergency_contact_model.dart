class EmergencyContactModel {
  final String id;
  final String name;
  final String phone;
  final String contactType;
  final int displayOrder;
  final DateTime? createdAt;

  EmergencyContactModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.contactType,
    required this.displayOrder,
    this.createdAt,
  });

  factory EmergencyContactModel.fromJson(Map<String, dynamic> json) {
    return EmergencyContactModel(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      contactType: json['contact_type'] as String? ?? 'security',
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'contact_type': contactType,
    'display_order': displayOrder,
  };
}
