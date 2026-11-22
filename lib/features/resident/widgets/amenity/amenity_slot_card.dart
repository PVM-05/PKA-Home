import 'package:flutter/material.dart';
import 'package:vivona/core/theme/app_radius.dart';
import 'package:vivona/core/theme/app_spacing.dart';
import 'package:vivona/core/theme/app_theme.dart';
import 'package:vivona/core/theme/app_typography.dart';
import 'package:vivona/data/models/amenity_booking_model.dart';

class AmenitySlotCard extends StatelessWidget {
  final String slot;
  final bool isPast;
  final bool isMaintenance;
  final bool isFullyBooked;
  final bool isSelected;
  final int availableCapacity;
  final AmenityBookingModel? myBookingInSlot;
  final VoidCallback? onTap;
  final VoidCallback? onCancelMyBooking;

  const AmenitySlotCard({
    super.key,
    required this.slot,
    required this.isPast,
    required this.isMaintenance,
    required this.isFullyBooked,
    required this.isSelected,
    required this.availableCapacity,
    required this.myBookingInSlot,
    required this.onTap,
    this.onCancelMyBooking,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final successColor = AppTheme.getSemanticSuccess(context);
    final warningColor = AppTheme.getSemanticWarning(context);
    final errorColor = AppTheme.getSemanticError(context);
    final secondaryColor = AppTheme.getSemanticSecondary(context);

    Color cardBg = colorScheme.surface;
    BorderSide cardBorder = BorderSide(color: colorScheme.outlineVariant);
    Widget trailingWidget = Icon(
      isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
      color: isSelected ? colorScheme.primary : colorScheme.outline,
    );
    String subtitleText = 'Còn trống: $availableCapacity chỗ';
    Color subtitleColor = successColor;

    if (myBookingInSlot != null) {
      final accent = isSelected ? errorColor : successColor;
      cardBg = accent.withValues(alpha: isDark ? 0.14 : 0.08);
      cardBorder = BorderSide(
        color: accent.withValues(alpha: isSelected ? 0.85 : 0.5),
        width: isSelected ? 2 : 1.5,
      );
      subtitleText =
          'Lịch của bạn (${myBookingInSlot!.statusDisplayName}) • Chạm để xem hoặc hủy lịch';
      subtitleColor = accent;
      trailingWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: successColor.withValues(alpha: isDark ? 0.2 : 0.14),
              borderRadius: AppRadius.r8,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, size: 14, color: successColor),
                AppSpacing.w4,
                Text(
                  myBookingInSlot!.statusDisplayName,
                  style: context.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: successColor,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Hủy lịch này',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: Icon(
              Icons.cancel_outlined,
              color: errorColor,
              size: 20,
            ),
            onPressed: onCancelMyBooking,
          ),
        ],
      );
    } else if (isMaintenance) {
      cardBg = warningColor.withValues(alpha: isDark ? 0.14 : 0.08);
      cardBorder = BorderSide(
        color: warningColor.withValues(alpha: isDark ? 0.45 : 0.35),
      );
      subtitleText = 'Đang bảo trì / vệ sinh định kỳ';
      subtitleColor = warningColor;
      trailingWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: warningColor.withValues(alpha: isDark ? 0.22 : 0.16),
          borderRadius: AppRadius.r8,
        ),
        child: Text(
          'Bảo trì',
          style: context.labelSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: warningColor,
          ),
        ),
      );
    } else if (isPast) {
      cardBg = colorScheme.surfaceContainerLow;
      cardBorder = BorderSide(color: colorScheme.outlineVariant);
      subtitleText = 'Khung giờ này đã trôi qua';
      subtitleColor = colorScheme.onSurfaceVariant;
      trailingWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: AppRadius.r8,
        ),
        child: Text(
          'Đã qua',
          style: context.labelSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    } else if (isFullyBooked) {
      cardBg = isSelected
          ? secondaryColor.withValues(alpha: isDark ? 0.18 : 0.12)
          : colorScheme.surfaceContainerLow;
      cardBorder = BorderSide(
        color: isSelected ? secondaryColor : colorScheme.outlineVariant,
        width: isSelected ? 2 : 1,
      );
      subtitleText = 'Đã hết chỗ — Bấm để tham gia Danh sách chờ';
      subtitleColor = secondaryColor;
      trailingWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.secondary
              : secondaryColor.withValues(alpha: isDark ? 0.22 : 0.15),
          borderRadius: AppRadius.r8,
        ),
        child: Text(
          isSelected ? 'Chờ duyệt' : 'Vào hàng chờ',
          style: context.labelSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: isSelected ? colorScheme.onPrimary : secondaryColor,
          ),
        ),
      );
    } else if (isSelected) {
      cardBg = colorScheme.primary.withValues(alpha: isDark ? 0.16 : 0.08);
      cardBorder = BorderSide(color: colorScheme.primary, width: 2);
    }

    final leadingIcon = isMaintenance
        ? Icons.build_circle_outlined
        : (isPast
              ? Icons.history_outlined
              : (isFullyBooked
                    ? Icons.hourglass_top_outlined
                    : Icons.schedule_outlined));

    final leadingColor = isMaintenance
        ? warningColor
        : (isPast
              ? colorScheme.onSurfaceVariant
              : (isFullyBooked
                    ? secondaryColor
                    : (isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant)));

    return Card(
      elevation: 0,
      color: cardBg,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.r12,
        side: cardBorder,
      ),
      child: ListTile(
        minVerticalPadding: 12,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(leadingIcon, color: leadingColor),
        title: Text(
          slot,
          style: context.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: (isPast || isMaintenance)
                ? colorScheme.onSurfaceVariant
                : colorScheme.onSurface,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        subtitle: Text(
          subtitleText,
          style: context.labelSmall?.copyWith(
            color: subtitleColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: trailingWidget,
        onTap: onTap,
      ),
    );
  }
}
