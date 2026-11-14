import 'package:flutter/material.dart';
import 'app_logger.dart';
import 'error_formatter.dart';

/// Trình bọc thực thi thao tác trung thực cho nghiệp vụ B2B SaaS:
/// - Chỉ thông báo thành công khi server thực sự phản hồi OK.
/// - Tự động bắt lỗi, định dạng tiếng Việt chuẩn và ghi log kiểm toán.
/// - Ngăn chặn hoàn toàn hiện tượng báo thành công giả.
Future<bool> runAction(
  BuildContext context,
  Future<String?> Function() action, {
  String? actionName,
  VoidCallback? onSuccess,
}) async {
  try {
    final successMessage = await action();
    if (context.mounted && successMessage != null && successMessage.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
          backgroundColor: Colors.green.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    onSuccess?.call();
    return true;
  } catch (error, stackTrace) {
    AppLogger.e('Thao tác ${actionName ?? ""} thất bại:', error, stackTrace);
    if (context.mounted) {
      final errorMessage = formatErrorMessage(error);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return false;
  }
}

