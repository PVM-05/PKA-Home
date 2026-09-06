class UserModel {
  final String id;
  final String fullName;
  final String role; // 'resident' or 'management'
  final String? phone;

  UserModel({
    required this.id,
    required this.fullName,
    required this.role,
    this.phone,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      role: json['role'] as String,
      phone: json['phone'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'role': role,
      'phone': phone,
    };
  }
}
