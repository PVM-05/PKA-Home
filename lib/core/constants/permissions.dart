/// Nguồn sự thật duy nhất (Single Source of Truth) định nghĩa toàn bộ quyền hạn
/// trong ứng dụng PKA-Home theo chuẩn RBAC và nguyên tắc Least Privilege.
class PermissionItem {
  final String key;
  final String name;
  final String category;
  final String description;
  final List<String> allowedRoles;

  const PermissionItem({
    required this.key,
    required this.name,
    required this.category,
    required this.description,
    required this.allowedRoles,
  });

  /// Kiểm tra xem vai trò hiện tại (kèm danh sách ủy quyền tạm thời đang active)
  /// có được phép truy cập chức năng này không.
  bool allows(String? role, {List<String> activeDelegations = const []}) {
    if (role == null) return false;
    if (allowedRoles.contains(role)) return true;
    return activeDelegations.any((delRole) => allowedRoles.contains(delRole));
  }
}

class AppPermissions {
  static const invoiceManagement = PermissionItem(
    key: 'invoice_management',
    name: 'Quản lý & Lập hóa đơn',
    category: 'Tài chính & Hóa đơn',
    description: 'Lập hóa đơn, xác nhận thanh toán và thống kê công nợ.',
    allowedRoles: ['admin', 'management', 'accountant'],
  );

  static const issueManagement = PermissionItem(
    key: 'issue_management',
    name: 'Xử lý & Cập nhật phản ánh',
    category: 'Sự cố & Kỹ thuật',
    description: 'Tiếp nhận, xử lý và cập nhật tiến độ sự cố kỹ thuật.',
    allowedRoles: ['admin', 'management', 'technician'],
  );

  static const residentManagement = PermissionItem(
    key: 'resident_management',
    name: 'Quản lý cư dân & Phân vai trò',
    category: 'Cư dân & Căn hộ',
    description: 'Xem danh sách cư dân, đổi vai trò thành viên.',
    allowedRoles: ['admin', 'management'],
  );

  static const linkRequestManagement = PermissionItem(
    key: 'link_request_management',
    name: 'Duyệt liên kết căn hộ',
    category: 'Cư dân & Căn hộ',
    description: 'Duyệt hoặc từ chối yêu cầu liên kết căn hộ của cư dân.',
    allowedRoles: ['admin', 'management'],
  );

  static const apartmentManagement = PermissionItem(
    key: 'apartment_management',
    name: 'Quản trị căn hộ & Tòa nhà',
    category: 'Cư dân & Căn hộ',
    description: 'Quản lý danh sách phòng, tầng, sơ đồ tòa nhà.',
    allowedRoles: ['admin', 'management'],
  );

  static const handbookManagement = PermissionItem(
    key: 'handbook_management',
    name: 'Quản trị cẩm nang cư dân',
    category: 'Thông tin & Cẩm nang',
    description: 'Quản lý nội quy, tiện ích và danh bạ khẩn cấp.',
    allowedRoles: ['admin', 'management'],
  );

  static const roleDelegation = PermissionItem(
    key: 'role_delegation',
    name: 'Ủy quyền vai trò tạm thời',
    category: 'Hệ thống & Phân quyền',
    description: 'Ủy quyền vai trò Kế toán/Kỹ thuật viên có thời hạn.',
    allowedRoles: ['admin', 'management'],
  );

  static const List<PermissionItem> all = [
    invoiceManagement,
    issueManagement,
    residentManagement,
    linkRequestManagement,
    apartmentManagement,
    handbookManagement,
    roleDelegation,
  ];
}
