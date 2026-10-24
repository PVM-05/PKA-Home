import 'apartment_model.dart';

/// Liên kết giữa người dùng và một căn hộ cụ thể
class ResidentApartmentLink {
  final String apartmentId;
  final String apartmentCode;
  final String relationRole; // 'owner' | 'tenant'
  final ApartmentModel? apartment;

  ResidentApartmentLink({
    required this.apartmentId,
    required this.apartmentCode,
    required this.relationRole,
    this.apartment,
  });

  factory ResidentApartmentLink.fromJson(Map<String, dynamic> json) {
    final aptMap = json['apartments'] as Map<String, dynamic>?;
    return ResidentApartmentLink(
      apartmentId: (json['apartment_id'] as String?) ?? (aptMap?['id'] as String? ?? ''),
      apartmentCode: (aptMap?['code'] as String?) ?? '',
      relationRole: (json['relation_role'] as String?) ?? 'owner',
      apartment: aptMap != null ? ApartmentModel.fromJson(aptMap) : null,
    );
  }

  String get relationRoleDisplayName {
    switch (relationRole) {
      case 'owner':
        return 'Chủ hộ';
      case 'tenant':
        return 'Người thuê';
      default:
        return 'Cư dân';
    }
  }
}

class ResidentModel {
  final String id;
  final String fullName;
  final String? email;
  final String? phone;
  final String role;
  final List<ResidentApartmentLink> apartments;
  final bool isLocked;
  final bool isActive;
  final ApartmentModel? apartment;

  ResidentModel({
    required this.id,
    required this.fullName,
    this.email,
    this.phone,
    required this.role,
    this.apartments = const [],
    this.isLocked = false,
    this.isActive = true,
    ApartmentModel? apartment,
  }) : apartment = apartment ?? (apartments.isNotEmpty ? apartments.first.apartment : null);

  factory ResidentModel.fromJson(Map<String, dynamic> json) {
    final aptLinks = <ResidentApartmentLink>[];
    if (json['residents_apartments'] != null && json['residents_apartments'] is List) {
      for (final item in json['residents_apartments'] as List) {
        if (item is Map<String, dynamic>) {
          aptLinks.add(ResidentApartmentLink.fromJson(item));
        }
      }
    }

    // Tương thích ngược nếu chỉ có 1 apartment object
    ApartmentModel? singleApt;
    if (aptLinks.isNotEmpty && aptLinks.first.apartment != null) {
      singleApt = aptLinks.first.apartment;
    } else if (json['apartments'] != null && json['apartments'] is Map<String, dynamic>) {
      singleApt = ApartmentModel.fromJson(json['apartments'] as Map<String, dynamic>);
    }

    return ResidentModel(
      id: json['id'] as String? ?? '',
      fullName: json['full_name'] as String? ?? 'Chưa đặt tên',
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      role: json['role'] as String? ?? 'resident',
      apartments: aptLinks,
      apartment: singleApt,
      isLocked: json['is_locked'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  ResidentModel copyWith({
    String? id,
    String? fullName,
    String? email,
    String? phone,
    String? role,
    List<ResidentApartmentLink>? apartments,
    ApartmentModel? apartment,
    bool? isLocked,
    bool? isActive,
  }) {
    return ResidentModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      apartments: apartments ?? this.apartments,
      apartment: apartment ?? this.apartment,
      isLocked: isLocked ?? this.isLocked,
      isActive: isActive ?? this.isActive,
    );
  }

  bool get isAdmin => role == 'admin' || role == 'management';
  bool get isAccountant => role == 'accountant';
  bool get isTechnician => role == 'technician';
  bool get isResident => role == 'resident';
  bool get isManagement => isAdmin || isAccountant || isTechnician;

  List<String> get apartmentCodes =>
      apartments.map((a) => a.apartmentCode).where((c) => c.isNotEmpty).toList();

  String get apartmentSummary =>
      apartmentCodes.isNotEmpty ? apartmentCodes.join(', ') : 'Chưa gắn căn hộ';

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

  String get statusDisplayName {
    if (!isActive) return 'Đã vô hiệu hóa';
    if (isLocked) return 'Đang bị khóa';
    return 'Đang hoạt động';
  }
}
