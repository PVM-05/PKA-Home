import 'network_error_handler.dart';

/// Chuyển đổi các ngoại lệ kỹ thuật (PostgrestException, AuthException, SocketException...)
/// thành thông báo tiếng Việt chuẩn mực, thân thiện và dễ hiểu cho người dùng cuối.
///
/// Chuyển giao toàn bộ cho [NetworkErrorHandler.getMessage] nhằm đảm bảo nguồn chân lý duy nhất.
String formatErrorMessage(Object? error, {String fallback = 'Đã xảy ra lỗi, vui lòng thử lại sau.'}) {
  return NetworkErrorHandler.getMessage(error, fallback: fallback);
}
