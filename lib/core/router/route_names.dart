/// Định nghĩa tất cả route paths trong app.
/// Sử dụng constants thay vì hardcode string để tránh lỗi typo.
class AppRoutes {
  AppRoutes._();

  // Auth
  static const String login = '/login';
  static const String register = '/register';
  static const String changePassword = '/change-password';
  static const String forgotPassword = '/forgot-password';
  static const String verifyOtp = '/verify-otp';
  static const String resetPassword = '/reset-password';

  // Resident
  static const String residentHome = '/resident';
  static const String residentInvoices = '/resident/invoices';
  static const String residentInvoiceDetail = '/resident/invoices/detail';
  static const String residentIssues = '/resident/issues';
  static const String residentCreateIssue = '/resident/issues/create';
  static const String residentEditIssue = '/resident/issues/edit';
  static const String residentIssueDetail = '/resident/issues/detail';
  static const String residentProfile = '/resident/profile';
  static const String residentLinkRequest = '/resident/link-request';
  static const String residentHandbook = '/resident/handbook';
  static const String residentNotifications = '/resident/notifications';
  static const String residentVehicles = '/resident/vehicles';
  static const String residentAmenityBooking = '/resident/amenity-booking';
  static const String residentAnnouncementDetail = '/resident/announcement';
  static const String residentPaymentHistory = '/resident/payment-history';

  // Management
  static const String managementHome = '/management';
  static const String managementResidents = '/management/residents';
  static const String managementInvoices = '/management/invoices';
  static const String managementCreateInvoice = '/management/invoices/create';
  static const String managementEditInvoice = '/management/invoices/edit';
  static const String managementInvoiceDetail = '/management/invoices/detail';
  static const String managementIssues = '/management/issues';
  static const String managementIssueDetail = '/management/issues/detail';
  static const String managementAnnouncements = '/management/announcements';
  static const String managementApartments = '/management/apartments';
  static const String managementLinkRequests = '/management/link-requests';
  static const String managementHandbook = '/management/handbook';
  static const String managementAuditTrail = '/management/audit-trail';
  static const String managementRoleDelegation = '/management/role-delegation';
  static const String managementPermissionMatrix = '/management/permission-matrix';
  static const String managementServiceRatings = '/management/service-ratings';
  static const String managementAmenities = '/management/amenities';
  static const String managementEquipment = '/management/equipment';
  static const String managementEquipmentDetail = '/management/equipment/detail';
}
