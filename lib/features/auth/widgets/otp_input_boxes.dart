import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';

class OtpInputBoxes extends StatefulWidget {
  final int length;
  final ValueChanged<String> onCompleted;
  final ValueChanged<String>? onChanged;

  const OtpInputBoxes({
    super.key,
    this.length = 6,
    required this.onCompleted,
    this.onChanged,
  });

  @override
  State<OtpInputBoxes> createState() => _OtpInputBoxesState();
}

class _OtpInputBoxesState extends State<OtpInputBoxes> {
  late List<TextEditingController> _controllers;
  late List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(widget.length, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String _getCurrentCode() {
    return _controllers.map((c) => c.text).join();
  }

  void _handleChanged(int index, String value) {
    // 1. Xử lý trường hợp dán mã (Paste từ clipboard)
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'\D'), '');
      if (digits.isNotEmpty) {
        for (int i = 0; i < widget.length; i++) {
          if (i < digits.length) {
            _controllers[i].text = digits[i];
          }
        }
        final code = _getCurrentCode();
        widget.onChanged?.call(code);
        if (code.length == widget.length) {
          _focusNodes.last.unfocus();
          widget.onCompleted(code);
        } else {
          final nextIndex = digits.length < widget.length ? digits.length : widget.length - 1;
          _focusNodes[nextIndex].requestFocus();
        }
        return;
      }
    }

    // 2. Xử lý nhập 1 ký tự bình thường
    if (value.isNotEmpty) {
      if (index < widget.length - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }
    }

    final code = _getCurrentCode();
    widget.onChanged?.call(code);

    if (code.length == widget.length) {
      widget.onCompleted(code);
    }
  }

  void _handleKeyEvent(int index, KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.backspace) {
      if (_controllers[index].text.isEmpty && index > 0) {
        _controllers[index - 1].clear();
        _focusNodes[index - 1].requestFocus();
        widget.onChanged?.call(_getCurrentCode());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(widget.length, (index) {
        return SizedBox(
          width: 46,
          height: 54,
          child: KeyboardListener(
            focusNode: FocusNode(),
            onKeyEvent: (event) => _handleKeyEvent(index, event),
            child: TextField(
              controller: _controllers[index],
              focusNode: _focusNodes[index],
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              maxLength: 6, // Cho phép dán chuỗi dài để bắt trong onChanged
              buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: InputDecoration(
                contentPadding: EdgeInsets.zero,
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                ),
              ),
              onChanged: (val) => _handleChanged(index, val),
            ),
          ),
        );
      }),
    );
  }
}
