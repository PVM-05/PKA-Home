import 'apartment_model.dart';

class ResidentModel {
  final String id;
  final String fullName;
  final String? phone;
  final String role;
  final ApartmentModel? apartment;

  ResidentModel({
    required this.id,
    required this.fullName,
    this.phone,
    required this.role,
    this.apartment,
  });

  factory ResidentModel.fromJson(Map<String, dynamic> json) {
    ApartmentModel? apt;
    if (json['residents_apartments'] != null && (json['residents_apartments'] as List).isNotEmpty) {
      final ra = (json['residents_apartments'] as List).first;
      if (ra['apartments'] != null) {
        apt = ApartmentModel.fromJson(ra['apartments']);
      }
    }

    return ResidentModel(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      phone: json['phone'] as String?,
      role: json['role'] as String,
      apartment: apt,
    );
  }

  bool get isAdmin => role == 'admin' || role == 'management';
  bool get isAccountant => role == 'accountant';
  bool get isTechnician => role == 'technician';
  bool get isResident => role == 'resident';
  bool get isManagement => isAdmin || isAccountant || isTechnician;

  String get roleDisplayName {
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
        return role;
    }
  }
}

