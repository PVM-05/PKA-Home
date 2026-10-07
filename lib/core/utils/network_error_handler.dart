import 'dart:async';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Bộ phân loại và chuẩn hóa thông điệp lỗi mạng & cơ sở dữ liệu
/// Đảm bảo không để lộ ngoại lệ kỹ thuật thô cho người dùng
class NetworkErrorHandler {
  const NetworkErrorHandler._();

  /// Chuyển đổi ngoại lệ thành thông điệp tiếng Việt thân thiện
  static String getMessage(Object? error, {String fallback = 'Đã xảy ra lỗi. Vui lòng thử lại.'}) {
    if (error == null) return fallback;

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
          return 'Dữ liệu đã tồn tại trong hệ thống hoặc khung giờ vừa được người khác đặt. Vui lòng kiểm tra lại.';
        case '23503':
          return 'Dữ liệu đang được liên kết. Không thể xóa dữ liệu này vì đang được liên kết với dữ liệu khác.';
        case '42501':
          return 'Bạn không có quyền thực hiện thao tác này.';
        case 'PGRST116':
          return 'Không tìm thấy dữ liệu yêu cầu.';
      }

      final msg = error.message.toLowerCase();
      if (msg.contains('violates row-level security policy') || msg.contains('permission denied')) {
        return 'Bạn không có quyền thực hiện thao tác này.';
      }
      if (msg.contains('foreign key constraint')) {
        return 'Dữ liệu đang được liên kết. Không thể xóa dữ liệu này vì đang được liên kết với dữ liệu khác.';
      }

      // Nếu là thông báo tiếng Việt có chủ đích từ RAISE EXCEPTION trong trigger/RPC
      if (error.message.isNotEmpty &&
          !msg.contains('syntax error') &&
          !msg.contains('relation') &&
          !msg.contains('column') &&
          !msg.contains('null value')) {
        return error.message;
      }

      return fallback;
    }

    if (error is AuthException) {
      final msg = error.message.toLowerCase();
      if (msg.contains('invalid login credentials') || msg.contains('invalid_credentials')) {
        return 'Email hoặc mật khẩu không chính xác.';
      }
      if (msg.contains('user already registered') || msg.contains('user_already_exists')) {
        return 'Email này đã được đăng ký tài khoản.';
      }
      if (msg.contains('email not confirmed')) {
        return 'Tài khoản chưa được xác thực Email. Vui lòng kiểm tra hộp thư đến.';
      }
      if (msg.contains('password should be at least')) {
        return 'Mật khẩu phải có độ dài tối thiểu 6 ký tự.';
      }
      if (error.message.isNotEmpty && !msg.contains('syntax') && !msg.contains('exception')) {
        return error.message;
      }
      return 'Lỗi xác thực: Vui lòng kiểm tra lại thông tin đăng nhập.';
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

    return fallback;
  }
}
