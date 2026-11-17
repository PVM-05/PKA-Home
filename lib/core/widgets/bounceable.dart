import 'package:flutter/material.dart';
import '../utils/app_haptics.dart';

/// Widget hỗ trợ phản hồi chuyển động chạm vi mô (micro-interaction bounce)
/// Co dãn lò xo nhẹ khi ấn và kích hoạt phản hồi xúc giác tinh tế.
class Bounceable extends StatefulWidget {
  const Bounceable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scaleFactor = 0.96,
    this.duration = const Duration(milliseconds: 100),
    this.reverseDuration = const Duration(milliseconds: 150),
    this.enableHaptic = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scaleFactor;
  final Duration duration;
  final Duration reverseDuration;
  final bool enableHaptic;

  @override
  State<Bounceable> createState() => _BounceableState();
}

class _BounceableState extends State<Bounceable> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails details) {
    if (widget.onTap != null || widget.onLongPress != null) {
      if (widget.enableHaptic) {
        AppHaptics.light();
      }
      setState(() => _isPressed = true);
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (_isPressed) {
      setState(() => _isPressed = false);
    }
  }

  void _handleTapCancel() {
    if (_isPressed) {
      setState(() => _isPressed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _isPressed ? widget.scaleFactor : 1.0,
        duration: _isPressed ? widget.duration : widget.reverseDuration,
        curve: _isPressed ? Curves.easeInQuad : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}
