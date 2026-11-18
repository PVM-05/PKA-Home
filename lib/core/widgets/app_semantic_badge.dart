import 'package:flutter/material.dart';

/// Widget bọc các huy hiệu trạng thái (status badges, chips, labels)
/// Giúp trình đọc màn hình (TalkBack/VoiceOver) diễn giải chính xác ngữ cảnh
/// Tuân thủ tiêu chuẩn trợ năng quốc tế WCAG 2.2 AA.
class AppSemanticBadge extends StatelessWidget {
  final Widget child;
  final String label;
  final String? tooltip;

  const AppSemanticBadge({
    super.key,
    required this.child,
    required this.label,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    Widget badge = Semantics(
      label: label,
      readOnly: true,
      container: true,
      child: child,
    );

    if (tooltip != null && tooltip!.isNotEmpty) {
      badge = Tooltip(
        message: tooltip!,
        child: badge,
      );
    }

    return badge;
  }
}

