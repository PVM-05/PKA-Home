import 'package:flutter/material.dart';

/// Widget Shimmer Skeleton loading cao cấp, mượt mà.
/// Thay thế hoàn toàn vòng xoay Spinner đơn điệu bằng hiệu ứng quét sáng chuẩn mực.
class AppSkeletonShimmer extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadiusGeometry? borderRadius;
  final BoxShape shape;

  const AppSkeletonShimmer({
    super.key,
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.shape = BoxShape.rectangle,
  });

  const AppSkeletonShimmer.rectangular({
    super.key,
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  }) : shape = BoxShape.rectangle;

  const AppSkeletonShimmer.circular({
    super.key,
    required double size,
  })  : width = size,
        height = size,
        borderRadius = null,
        shape = BoxShape.circle;

  const AppSkeletonShimmer.textLine({
    super.key,
    this.width = double.infinity,
    this.height = 14,
    this.borderRadius = const BorderRadius.all(Radius.circular(4)),
  }) : shape = BoxShape.rectangle;

  /// Tạo danh sách skeleton mô phỏng thẻ dữ liệu
  static Widget cardList({
    int count = 3,
    double itemHeight = 84,
    EdgeInsetsGeometry margin = const EdgeInsets.only(bottom: 12),
    BorderRadiusGeometry borderRadius = const BorderRadius.all(Radius.circular(12)),
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        count,
        (index) => Padding(
          padding: margin,
          child: AppSkeletonShimmer.rectangular(
            width: double.infinity,
            height: itemHeight,
            borderRadius: borderRadius,
          ),
        ),
      ),
    );
  }

  @override
  State<AppSkeletonShimmer> createState() => _AppSkeletonShimmerState();
}

class _AppSkeletonShimmerState extends State<AppSkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final baseColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final highlightColor = isDark ? const Color(0xFF334155) : const Color(0xFFF8FAFC);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            shape: widget.shape,
            borderRadius: widget.shape == BoxShape.circle ? null : widget.borderRadius,
            gradient: LinearGradient(
              begin: Alignment(-1.5 + (_controller.value * 3.0), -0.3),
              end: Alignment(-0.5 + (_controller.value * 3.0), 0.3),
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: const [0.1, 0.5, 0.9],
            ),
          ),
        );
      },
    );
  }
}

