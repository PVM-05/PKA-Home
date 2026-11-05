import 'dart:async';
import 'package:flutter/foundation.dart';

/// Ngoại lệ ứng dụng chuẩn phục vụ hiển thị lỗi thân thiện tới người dùng
class AppException implements Exception {
  final String message;
  final dynamic originalError;
  final StackTrace? stackTrace;

  const AppException(this.message, [this.originalError, this.stackTrace]);

  @override
  String toString() => message;
}

/// Cơ chế kiểm soát an toàn dữ liệu Fail-Closed (Không nuốt lỗi, không trả mock ngầm)
class FailClosedGuard {
  /// Cờ kiểm soát cho phép sử dụng Mock Data khi có lỗi mạng/CSDL.
  /// Mặc định: FALSE (Fail-Closed). Chỉ bật khi build kèm --dart-define=USE_MOCK=true
  static const bool useMock = bool.fromEnvironment('USE_MOCK', defaultValue: false);

  /// Bọc lời gọi repository với cơ chế bảo vệ Fail-Closed:
  /// - Thành công: Trả về kết quả thực tế.
  /// - Thất bại:
  ///   - Nếu `useMock == true` và có `mockFallback`: Trả về dữ liệu mock kèm cảnh báo debug.
  ///   - Ngược lại (Production): Ném `AppException` rõ ràng để UI hiển thị màn hình lỗi kèm nút "Thử lại".
  static Future<T> guard<T>({
    required String operation,
    required Future<T> Function() call,
    FutureOr<T> Function()? mockFallback,
    String? userFriendlyError,
  }) async {
    try {
      return await call();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[FAIL-CLOSED] Lỗi tác vụ "$operation": $e');
      }

      if (useMock && mockFallback != null) {
        if (kDebugMode) {
          debugPrint('[CẢNH BÁO MOCK]: Tác vụ "$operation" thất bại, sử dụng mockFallback vì cờ USE_MOCK=true.');
        }
        return await mockFallback();
      }

      if (e is AppException) {
        rethrow;
      }

      throw AppException(
        userFriendlyError ?? 'Không thể tải dữ liệu ($operation). Vui lòng thử lại sau.',
        e,
        st,
      );
    }
  }
}

