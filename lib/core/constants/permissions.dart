/// Nguồn sự thật duy nhất (Single Source of Truth) định nghĩa toàn bộ quyền hạn
/// trong ứng dụng Vivona theo chuẩn RBAC và nguyên tắc Least Privilege.
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

  /// Kiểm tra xem vai trò hiện tại (kèm danh sách ủy quyền tạm thời đang active
  /// và vai trò theo ngữ cảnh tòa nhà) có được phép truy cập chức năng này không.
  bool allows(
    String? role, {
    List<String> activeDelegations = const [],
    List<String> buildingRoles = const [],
  }) {
    if (role == null && buildingRoles.isEmpty) return false;
    if (role != null && allowedRoles.contains(role)) return true;
    if (activeDelegations.any((delRole) => allowedRoles.contains(delRole))) return true;
    return buildingRoles.any((bRole) => allowedRoles.contains(bRole));
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

  static const vehicleApproval = PermissionItem(
    key: 'vehicle_approval',
    name: 'Duyệt đăng ký phương tiện',
    category: 'Cư dân & Căn hộ',
    description: 'Kiểm tra và phê duyệt hoặc từ chối cấp thẻ xe cho cư dân.',
    allowedRoles: ['admin', 'management'],
  );

  static const meterReadingManagement = PermissionItem(
    key: 'meter_reading_management',
    name: 'Kiểm tra & Duyệt chỉ số đồng hồ',
    category: 'Tài chính & Hóa đơn',
    description: 'Kiểm tra chỉ số điện nước cư dân khai báo và lập hóa đơn.',
    allowedRoles: ['admin', 'management', 'accountant'],
  );

  static const equipmentManagement = PermissionItem(
    key: 'equipment_management',
    name: 'Quản lý thiết bị & Bảo trì',
    category: 'Sự cố & Kỹ thuật',
    description: 'Theo dõi tình trạng kỹ thuật thiết bị tòa nhà và lịch bảo dưỡng.',
    allowedRoles: ['admin', 'management', 'technician'],
  );

  static const paymentTransactions = PermissionItem(
    key: 'payment_transactions',
    name: 'Lịch sử giao dịch thanh toán',
    category: 'Tài chính & Hóa đơn',
    description: 'Tra cứu và đối soát toàn bộ dòng tiền, giao dịch nạp/thu tiền.',
    allowedRoles: ['admin', 'management', 'accountant'],
  );

  static const amenityManagement = PermissionItem(
    key: 'amenity_management',
    name: 'Quản lý tiện ích & Đặt chỗ',
    category: 'Tiện ích & Dịch vụ',
    description: 'Cấu hình khung giờ tiện ích, kiểm tra danh sách đặt chỗ và check-in.',
    allowedRoles: ['admin', 'management'],
  );

  static const auditTrail = PermissionItem(
    key: 'audit_trail',
    name: 'Nhật ký kiểm toán & Hoạt động',
    category: 'Hệ thống & Phân quyền',
    description: 'Theo dõi nhật ký thay đổi trạng thái hóa đơn, sự cố và phân quyền.',
    allowedRoles: ['admin', 'management'],
  );

  static const parkingManagement = PermissionItem(
    key: 'parking_management',
    name: 'Quản lý bãi đỗ xe & Ô đỗ',
    category: 'Cư dân & Căn hộ',
    description: 'Quản lý sơ đồ bãi xe, gán và thu hồi ô đỗ xe của cư dân.',
    allowedRoles: ['admin', 'management'],
  );

  static const handoverManagement = PermissionItem(
    key: 'handover_management',
    name: 'Kiểm kê & Bàn giao căn hộ',
    category: 'Sự cố & Kỹ thuật',
    description: 'Lập và ký biên bản bàn giao căn hộ, kiểm kê tài sản và công tơ.',
    allowedRoles: ['admin', 'management', 'technician'],
  );

  static const materialsManagement = PermissionItem(
    key: 'materials_management',
    name: 'Quản lý kho vật tư bảo trì',
    category: 'Sự cố & Kỹ thuật',
    description: 'Theo dõi xuất nhập tồn vật tư kỹ thuật và điều chỉnh định mức.',
    allowedRoles: ['admin', 'management', 'technician'],
  );

  static const maintenanceFundLedger = PermissionItem(
    key: 'maintenance_fund_ledger',
    name: 'Sổ cái quỹ bảo trì 2%',
    category: 'Tài chính & Hóa đơn',
    description: 'Theo dõi biến động và chứng từ chi tiêu quỹ bảo trì chung cư.',
    allowedRoles: ['admin', 'management', 'accountant'],
  );

  static const financialReport = PermissionItem(
    key: 'financial_report',
    name: 'Báo cáo tài chính & Doanh thu',
    category: 'Tài chính & Hóa đơn',
    description: 'Xem tổng quan doanh thu, tỷ lệ thu hồi công nợ và số liệu tài chính.',
    allowedRoles: ['admin', 'management', 'accountant'],
  );

  static const accountingWorkstation = PermissionItem(
    key: 'accounting_workstation',
    name: 'Trạm kế toán web chuyên sâu',
    category: 'Tài chính & Hóa đơn',
    description: 'Bảng đối soát công nợ chi tiết và khớp giao dịch ngân hàng.',
    allowedRoles: ['admin', 'management', 'accountant'],
  );

  static const batchImport = PermissionItem(
    key: 'batch_import',
    name: 'Nhập dữ liệu hàng loạt (Excel)',
    category: 'Cư dân & Căn hộ',
    description: 'Nhập danh sách căn hộ, cư dân và phương tiện từ file Excel.',
    allowedRoles: ['admin', 'management'],
  );

  static const subscriptionManagement = PermissionItem(
    key: 'subscription_management',
    name: 'Quản lý gói phần mềm SaaS',
    category: 'Hệ thống & Phân quyền',
    description: 'Quản lý thời hạn bản quyền phần mềm và hạn mức vận hành tòa nhà.',
    allowedRoles: ['admin'],
  );

  static const permissionMatrix = PermissionItem(
    key: 'permission_matrix',
    name: 'Ma trận phân quyền hệ thống',
    category: 'Hệ thống & Phân quyền',
    description: 'Cấu hình và kiểm tra chi tiết ma trận quyền hạn cho từng vai trò.',
    allowedRoles: ['admin'],
  );

  static const List<PermissionItem> all = [
    invoiceManagement,
    issueManagement,
    residentManagement,
    linkRequestManagement,
    apartmentManagement,
    handbookManagement,
    roleDelegation,
    vehicleApproval,
    meterReadingManagement,
    equipmentManagement,
    paymentTransactions,
    amenityManagement,
    auditTrail,
    parkingManagement,
    handoverManagement,
    materialsManagement,
    maintenanceFundLedger,
    financialReport,
    accountingWorkstation,
    batchImport,
    subscriptionManagement,
    permissionMatrix,
  ];
}
