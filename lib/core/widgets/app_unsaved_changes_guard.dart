import 'package:flutter/material.dart';

/// Widget bảo vệ dữ liệu chưa lưu khi người dùng vuốt back hoặc bấm nút quay lại.
/// Sử dụng PopScope chuẩn Flutter 3.44+ tự động hiển thị hộp thoại cảnh báo trước khi hủy dữ liệu.
class AppUnsavedChangesGuard extends StatelessWidget {
  final Widget child;
  final bool hasUnsavedChanges;
  final String title;
  final String message;
  final String stayButtonLabel;
  final String leaveButtonLabel;

  const AppUnsavedChangesGuard({
    super.key,
    required this.child,
    required this.hasUnsavedChanges,
    this.title = 'Rời khỏi biểu mẫu?',
    this.message = 'Những thông tin bạn vừa nhập chưa được lưu và sẽ bị mất nếu rời khỏi.',
    this.stayButtonLabel = 'Tiếp tục nhập',
    this.leaveButtonLabel = 'Rời khỏi',
  });

  Future<bool> _showConfirmDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(stayButtonLabel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(leaveButtonLabel),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldLeave = await _showConfirmDialog(context);
        if (shouldLeave && context.mounted) {
          Navigator.of(context).pop(result);
        }
      },
      child: child,
    );
  }
}

