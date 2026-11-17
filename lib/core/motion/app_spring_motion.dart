import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Bộ chuẩn chuyển động lò xo và so le (Spring & Staggered Motion) chuẩn Vivona 2026.
/// Xây dựng trên nền tảng flutter_animate với các tham số vật lý mượt mà, tự nhiên.
abstract final class AppSpringMotion {
  /// Curve lò xo đàn hồi nhẹ cho lối vào (entrance)
  static const Curve springEntranceCurve = Curves.easeOutCubic;

  /// Curve bật nhẹ (subtle bounce)
  static const Curve springBounceCurve = Curves.easeOutBack;

  /// Thời lượng chuẩn cho các chuyển động vào
  static const Duration defaultDuration = Duration(milliseconds: 450);

  /// Thời gian trễ cơ sở cho hiệu ứng so le (staggered)
  static const Duration staggeredStep = Duration(milliseconds: 40);
}

/// Tiện ích mở rộng Animation cho Widget
extension AppSpringMotionExtension on Widget {
  /// Hiệu ứng xuất hiện lò xo tự nhiên (Fade + Slide + Subtle Scale)
  Widget animateSpringEntry({
    Duration delay = Duration.zero,
    Duration duration = AppSpringMotion.defaultDuration,
    double slideOffsetY = 0.06,
  }) {
    return animate(delay: delay)
        .fadeIn(
          duration: duration,
          curve: Curves.easeOut,
        )
        .slideY(
          begin: slideOffsetY,
          end: 0,
          duration: duration,
          curve: AppSpringMotion.springEntranceCurve,
        )
        .scaleXY(
          begin: 0.98,
          end: 1.0,
          duration: duration,
          curve: AppSpringMotion.springBounceCurve,
        );
  }

  /// Hiệu ứng xuất hiện so le tuần tự cho danh sách hoặc lưới
  Widget animateStaggeredItem({
    required int index,
    Duration baseDelay = Duration.zero,
    Duration step = AppSpringMotion.staggeredStep,
    Duration duration = AppSpringMotion.defaultDuration,
  }) {
    final effectiveDelay = baseDelay + (step * index);
    return animateSpringEntry(
      delay: effectiveDelay,
      duration: duration,
      slideOffsetY: 0.05,
    );
  }

  /// Hiệu ứng nhịp đập thu hút sự chú ý (Pulse highlight cho badge hoặc CTA)
  Widget animatePulseHighlight({
    Duration duration = const Duration(milliseconds: 1200),
    bool autoPlay = true,
  }) {
    return animate(
      autoPlay: autoPlay,
      onPlay: (controller) => controller.repeat(reverse: true),
    ).scaleXY(
      begin: 1.0,
      end: 1.08,
      duration: duration,
      curve: Curves.easeInOut,
    );
  }
}
