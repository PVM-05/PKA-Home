import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Chuyển đổi các ngoại lệ kỹ thuật (PostgrestException, AuthException, SocketException...)
/// thành thông báo tiếng Việt chuẩn mực, thân thiện và dễ hiểu cho người dùng cuối.
String formatErrorMessage(Object? error, {String fallback = 'Đã xảy ra lỗi, vui lòng thử lại sau.'}) {
  if (error == null) return fallback;

  if (error is PostgrestException) {
    switch (error.code) {
      case '23505':
        return 'Dữ liệu đã tồn tại trong hệ thống, vui lòng kiểm tra lại.';
      case '42501':
        return 'Bạn không có quyền thực hiện thao tác này.';
      case '23503':
        return 'Dữ liệu đang được liên kết với bản ghi khác, không thể xóa hoặc thay đổi.';
      case 'PGRST116':
        return 'Không tìm thấy dữ liệu yêu cầu.';
      default:
        final msg = error.message.toLowerCase();
        if (msg.contains('violates row-level security policy')) {
          return 'Bạn không có quyền truy cập hoặc chỉnh sửa dữ liệu này.';
        }
        if (msg.contains('foreign key constraint')) {
          return 'Dữ liệu đang được liên kết, không thể thực hiện thao tác.';
        }
        return fallback;
    }
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
    return 'Lỗi xác thực: Vui lòng kiểm tra lại thông tin đăng nhập.';
  }

  if (error is SocketException) {
    return 'Không thể kết nối đến máy chủ. Vui lòng kiểm tra lại kết nối mạng Internet.';
  }

  final errorStr = error.toString().toLowerCase();
  if (errorStr.contains('socketexception') ||
      errorStr.contains('failed host lookup') ||
      errorStr.contains('network is unreachable') ||
      errorStr.contains('clientexception')) {
    return 'Không thể kết nối mạng. Vui lòng kiểm tra lại kết nối Wifi hoặc Internet.';
  }

  return fallback;
}
