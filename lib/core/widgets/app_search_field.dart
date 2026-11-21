import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_radius.dart';

/// Ô tìm kiếm chuẩn hóa toàn hệ thống Vivona:
/// - Kích thước cảm ứng tối thiểu đạt chuẩn Accessibility (>= 48dp).
/// - Tự động debounce 300ms giảm tải việc kích hoạt callback tìm kiếm liên tục.
/// - Tích hợp nút xóa (clear) nhanh tiện lợi với vùng bấm >= 48dp.
/// - Đồng bộ màu sắc chuẩn ColorScheme Material 3 (surfaceContainerHighest & outlineVariant), triệt tiêu sắc tím.
class AppSearchField extends StatefulWidget {
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final VoidCallback? onSubmitted;
  final String hintText;
  final bool autofocus;
  final Duration debounceDuration;
  final FocusNode? focusNode;
  final EdgeInsetsGeometry padding;

  const AppSearchField({
    super.key,
    this.controller,
    this.onChanged,
    this.onClear,
    this.onSubmitted,
    this.hintText = 'Tìm kiếm...',
    this.autofocus = false,
    this.debounceDuration = const Duration(milliseconds: 300),
    this.focusNode,
    this.padding = EdgeInsets.zero,
  });

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  late TextEditingController _controller;
  Timer? _debounceTimer;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _hasText = _controller.text.isNotEmpty;
    _controller.addListener(_handleTextChanged);
  }

  @override
  void didUpdateWidget(AppSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.removeListener(_handleTextChanged);
      _controller = widget.controller ?? TextEditingController();
      _hasText = _controller.text.isNotEmpty;
      _controller.addListener(_handleTextChanged);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    if (widget.controller == null) {
      _controller.removeListener(_handleTextChanged);
      _controller.dispose();
    } else {
      _controller.removeListener(_handleTextChanged);
    }
    super.dispose();
  }

  void _handleTextChanged() {
    final hasText = _controller.text.isNotEmpty;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
  }

  void _onChanged(String val) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(widget.debounceDuration, () {
      widget.onChanged?.call(val);
    });
  }

  void _clear() {
    _controller.clear();
    _debounceTimer?.cancel();
    widget.onClear?.call();
    widget.onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: widget.padding,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Semantics(
          label: 'Ô tìm kiếm',
          textField: true,
          child: TextField(
            controller: _controller,
            focusNode: widget.focusNode,
            autofocus: widget.autofocus,
            textInputAction: TextInputAction.search,
            onChanged: _onChanged,
            onSubmitted: (_) {
              _debounceTimer?.cancel();
              widget.onSubmitted?.call();
            },
            decoration: InputDecoration(
              hintText: widget.hintText,
              prefixIcon: const Icon(Icons.search_rounded, size: 22),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 44,
                minHeight: 48,
              ),
              suffixIcon: _hasText
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      tooltip: 'Xóa nội dung tìm kiếm',
                      onPressed: _clear,
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppRadius.r12,
                borderSide: BorderSide(
                  color: colorScheme.outlineVariant,
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppRadius.r12,
                borderSide: BorderSide(
                  color: colorScheme.primary,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

