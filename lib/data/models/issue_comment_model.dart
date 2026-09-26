/// Model cho comment trên phản ánh sự cố.
/// Hỗ trợ join bảng `users` để lấy tên và vai trò người gửi.
class IssueCommentModel {
  final String id;
  final String issueReportId;
  final String userId;
  final String content;
  final DateTime createdAt;
  final String? userName;
  final String? userRole;

  const IssueCommentModel({
    required this.id,
    required this.issueReportId,
    required this.userId,
    required this.content,
    required this.createdAt,
    this.userName,
    this.userRole,
  });

  /// Kiểm tra comment có phải từ ban quản lý/kỹ thuật viên không
  bool get isManagement =>
      userRole == 'admin' ||
      userRole == 'management' ||
      userRole == 'technician' ||
      userRole == 'accountant';

  /// Tên hiển thị vai trò
  String get roleDisplayName {
    switch (userRole) {
      case 'admin':
      case 'management':
        return 'Ban Quản Lý';
      case 'technician':
        return 'Kỹ thuật viên';
      case 'accountant':
        return 'Kế toán';
      default:
        return 'Cư dân';
    }
  }

  factory IssueCommentModel.fromJson(Map<String, dynamic> json) {
    final user = json['users'] as Map<String, dynamic>?;
    return IssueCommentModel(
      id: json['id'] as String,
      issueReportId: json['issue_report_id'] as String,
      userId: json['user_id'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      userName: user?['full_name'] as String?,
      userRole: user?['role'] as String?,
    );
  }
}
