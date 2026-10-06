import 'dart:async';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Bộ phân loại và chuẩn hóa thông điệp lỗi mạng & cơ sở dữ liệu
/// Đảm bảo không để lộ ngoại lệ kỹ thuật thô cho người dùng
class NetworkErrorHandler {
  const NetworkErrorHandler._();

  /// Chuyển đổi ngoại lệ thành thông điệp tiếng Việt thân thiện
  static String getMessage(Object error) {
    if (error is SocketException) {
      return 'Không có kết nối mạng. Vui lòng kiểm tra Internet và thử lại.';
    }

    if (error is TimeoutException) {
      return 'Kết nối máy chủ quá lâu. Vui lòng thử lại sau.';
    }

    if (error is PostgrestException) {
      switch (error.code) {
        case '08006':
        case '08001':
          return 'Không thể kết nối đến hệ thống. Vui lòng thử lại.';
        case '23505':
          return 'Khung giờ vừa được người khác đặt hoặc dữ liệu đã tồn tại. Vui lòng chọn khung giờ khác.';
        case '23503':
          return 'Không thể xóa dữ liệu này vì đang được liên kết với dữ liệu khác.';
      }
      // Nếu là thông báo tiếng Việt có chủ đích từ RAISE EXCEPTION trong trigger/RPC
      if (error.message.isNotEmpty &&
          !error.message.toLowerCase().contains('syntax error') &&
          !error.message.toLowerCase().contains('relation') &&
          !error.message.toLowerCase().contains('column') &&
          !error.message.toLowerCase().contains('null value')) {
        return error.message;
      }
    }

    if (error is AuthException) {
      return error.message;
    }

    final errStr = error.toString().toLowerCase();
    if (errStr.contains('socketexception') ||
        errStr.contains('failed host lookup') ||
        errStr.contains('clientexception') ||
        errStr.contains('network is unreachable')) {
      return 'Không có kết nối mạng. Vui lòng kiểm tra Internet và thử lại.';
    }

    if (errStr.contains('timeoutexception') ||
        errStr.contains('timed out') ||
        errStr.contains('connection timeout')) {
      return 'Kết nối máy chủ quá lâu. Vui lòng thử lại sau.';
    }

    return 'Đã xảy ra lỗi. Vui lòng thử lại.';
  }
}
