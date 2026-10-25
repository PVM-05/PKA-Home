import 'dart:async';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../errors/app_exception.dart';

/// Bộ phân loại và chuẩn hóa thông điệp lỗi mạng & cơ sở dữ liệu
/// Đảm bảo không để lộ ngoại lệ kỹ thuật thô cho người dùng
class NetworkErrorHandler {
  const NetworkErrorHandler._();

  /// Chuyển đổi ngoại lệ thành thông điệp tiếng Việt thân thiện
  static String getMessage(Object? error, {String fallback = 'Đã xảy ra lỗi. Vui lòng thử lại.'}) {
    if (error == null) return fallback;

    if (error is AppException) {
      return error.message;
    }

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
          return 'Khung giờ vừa được người khác đặt hoặc Dữ liệu đã tồn tại trong hệ thống. Vui lòng kiểm tra lại.';
        case '23503':
          return 'Dữ liệu đang được liên kết. Không thể xóa dữ liệu này vì đang được liên kết với dữ liệu khác.';
        case '42501':
          return 'Bạn không có quyền thực hiện thao tác này.';
        case 'PGRST116':
          return 'Không tìm thấy dữ liệu yêu cầu.';
        case 'P0001':
        case '0A000':
          return error.message;
      }

      final msg = error.message.toLowerCase();
      if (msg.contains('violates row-level security policy') || msg.contains('permission denied')) {
        return 'Bạn không có quyền thực hiện thao tác này.';
      }
      if (msg.contains('foreign key constraint')) {
        return 'Dữ liệu đang được liên kết. Không thể xóa dữ liệu này vì đang được liên kết với dữ liệu khác.';
      }

      // Nếu là thông báo tiếng Việt có chủ đích từ RAISE EXCEPTION trong trigger/RPC
      final isVietnamese = RegExp(r'[àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ]', caseSensitive: false).hasMatch(error.message);
      if (isVietnamese &&
          !msg.contains('syntax') &&
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
      if (msg.contains('database error') || msg.contains('unexpected_failure')) {
        return 'Không thể tạo tài khoản trên hệ thống. Vui lòng liên hệ Ban Quản Lý.';
      }
      if (msg.contains('over_email_send_rate_limit') || msg.contains('rate limit')) {
        return 'Bạn đã gửi yêu cầu quá nhiều lần. Vui lòng thử lại sau.';
      }
      if (error.message.isNotEmpty &&
          !msg.contains('syntax') &&
          !msg.contains('exception') &&
          !msg.startsWith('{')) {
        return error.message;
      }
      return 'Lỗi xác thực: Vui lòng kiểm tra lại thông tin đăng nhập.';
    }

    final rawMsg = error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
    final errStr = error.toString().toLowerCase();

    // Bắt trường hợp lỗi trả về chuỗi JSON thô dạng {"code":"...", "message":"..."}
    if (rawMsg.startsWith('{') && rawMsg.endsWith('}')) {
      if (errStr.contains('database error saving new user') || errStr.contains('unexpected_failure')) {
        return 'Không thể tạo tài khoản trên hệ thống. Vui lòng liên hệ Ban Quản Lý.';
      }
      if (errStr.contains('user already registered') || errStr.contains('user_already_exists')) {
        return 'Email này đã được đăng ký tài khoản.';
      }
    }

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

    if (errStr.contains('realtimesubscribeexception') ||
        errStr.contains('realtimecloseevent') ||
        errStr.contains('channelerror') ||
        errStr.contains('code: 1002')) {
      return 'Kết nối máy chủ bị gián đoạn. Đang kết nối lại...';
    }

    // Nếu là Exception mang thông báo tiếng Việt có chủ đích
    final isVietnamese = RegExp(r'[àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ]', caseSensitive: false).hasMatch(rawMsg);
    if (isVietnamese &&
        !errStr.contains('syntax') &&
        !errStr.contains('relation') &&
        !errStr.contains('column') &&
        !errStr.contains('null value') &&
        !errStr.contains('stacktrace')) {
      return rawMsg;
    }

    return fallback;
  }
}
