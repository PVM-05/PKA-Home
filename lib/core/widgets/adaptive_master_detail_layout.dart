import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';

/// Bố cục thích ứng Master-Detail chuẩn 2 cột dành cho màn hình lớn (Desktop / Tablet).
/// Trên màn hình nhỏ (< breakpoint), chỉ hiển thị Master pane.
class AdaptiveMasterDetailLayout<T> extends StatelessWidget {
  const AdaptiveMasterDetailLayout({
    super.key,
    required this.masterBuilder,
    required this.detailBuilder,
    this.selectedItem,
    this.emptyDetailBuilder,
    this.breakpoint = 900.0,
    this.masterWidth = 420.0,
  });

  /// Builder cho phần danh sách chính (Master)
  /// [isMasterPaneOnly] = true nếu đang ở chế độ 1 cột (Mobile).
  final Widget Function(BuildContext context, bool isMasterPaneOnly) masterBuilder;

  /// Builder cho phần chi tiết (Detail) khi có phần tử được chọn
  final Widget Function(BuildContext context, T item) detailBuilder;

  /// Builder tùy chỉnh khi chưa có phần tử nào được chọn trên màn hình lớn
  final WidgetBuilder? emptyDetailBuilder;

  /// Phần tử đang được chọn
  final T? selectedItem;

  /// Ngưỡng chia 2 cột (mặc định 900.0 dp)
  final double breakpoint;

  /// Chiều rộng cố định của cột Master trên màn hình lớn
  final double masterWidth;

  Widget _buildDefaultEmptyPlaceholder(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Center(
      child: Padding(
        padding: AppSpacing.p24,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: AppSpacing.p24,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.touch_app_outlined,
                size: 48,
                color: colorScheme.primary.withValues(alpha: 0.6),
              ),
            ),
            AppSpacing.h16,
            Text(
              'Chưa chọn mục nào',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            AppSpacing.h8,
            Text(
              'Vui lòng chọn một mục từ danh sách bên trái để xem nội dung chi tiết.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLargeScreen = constraints.maxWidth >= breakpoint;

        if (!isLargeScreen) {
          return masterBuilder(context, true);
        }

        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cột Master (Danh sách)
            SizedBox(
              width: masterWidth,
              child: masterBuilder(context, false),
            ),

            // Đường phân cách dọc tinh tế
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),

            // Cột Detail (Chi tiết)
            Expanded(
              child: selectedItem != null
                  ? detailBuilder(context, selectedItem as T)
                  : (emptyDetailBuilder?.call(context) ??
                      _buildDefaultEmptyPlaceholder(context)),
            ),
          ],
        );
      },
    );
  }
}

