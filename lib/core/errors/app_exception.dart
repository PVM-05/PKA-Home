/// Ngoại lệ nghiệp vụ chứa thông điệp tiếng Việt thân thiện cho người dùng cuối
class AppException implements Exception {
  final String message;
  const AppException(this.message);

  @override
  String toString() => message;
}
