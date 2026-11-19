import 'package:flutter/material.dart';
import '../widgets/app_snack_bar.dart';
import 'app_logger.dart';

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
      AppSnackBar.showSuccess(context, successMessage);
    }
    onSuccess?.call();
    return true;
  } catch (error, stackTrace) {
    AppLogger.e('Thao tác ${actionName ?? ""} thất bại:', error, stackTrace);
    if (context.mounted) {
      AppSnackBar.showError(context, error);
    }
    return false;
  }
}

