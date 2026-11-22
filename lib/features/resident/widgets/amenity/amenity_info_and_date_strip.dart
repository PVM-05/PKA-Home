import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vivona/core/theme/app_radius.dart';
import 'package:vivona/core/theme/app_spacing.dart';
import 'package:vivona/core/theme/app_theme.dart';
import 'package:vivona/core/theme/app_typography.dart';
import 'package:vivona/data/models/building_amenity_model.dart';

class AmenityInfoHeader extends StatelessWidget {
  final BuildingAmenityModel amenity;
  final NumberFormat currencyFormat;

  const AmenityInfoHeader({
    super.key,
    required this.amenity,
    required this.currencyFormat,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final successColor = AppTheme.getSemanticSuccess(context);

    return Container(
      width: double.infinity,
      color: colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.access_time,
                size: 16,
                color: colorScheme.primary,
              ),
              AppSpacing.w6,
              Expanded(
                child: Text(
                  'Thời gian mở cửa: ${amenity.openHours ?? "06:00 - 22:00"} (${amenity.slotDurationMinutes} phút/lượt)',
                  style: context.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.h4,
          Row(
            children: [
              Icon(
                amenity.isShared ? Icons.groups_outlined : Icons.lock_outline,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
              AppSpacing.w6,
              Expanded(
                child: Text(
                  amenity.isShared
                      ? 'Tiện ích dùng chung — Sức chứa: ${amenity.maxCapacity} người/khung giờ'
                      : 'Tiện ích trọn gói — 1 căn hộ/khung giờ',
                  style: context.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          if (amenity.feeAmount > 0 || amenity.requiresDeposit) ...[
            AppSpacing.h4,
            Row(
              children: [
                Icon(
                  Icons.payments_outlined,
                  size: 16,
                  color: successColor,
                ),
                AppSpacing.w6,
                Expanded(
                  child: Text(
                    'Phí: ${currencyFormat.format(amenity.feeAmount)}${amenity.requiresDeposit ? ' • Cọc: ${currencyFormat.format(amenity.depositAmount)}' : ''}',
                    style: context.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: successColor,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (amenity.maxSlotsPerWeek > 0) ...[
            AppSpacing.h4,
            Row(
              children: [
                Icon(
                  Icons.event_repeat_rounded,
                  size: 16,
                  color: colorScheme.primary,
                ),
                AppSpacing.w6,
                Expanded(
                  child: Text(
                    'Hạn mức: Tối đa ${amenity.maxSlotsPerWeek} lượt/tuần / căn hộ',
                    style: context.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurface,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (amenity.rulesAndRegulations != null &&
              amenity.rulesAndRegulations!.isNotEmpty) ...[
            AppSpacing.h8,
            Container(
              padding: AppSpacing.p8,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(
                  alpha: isDark ? 0.14 : 0.08,
                ),
                borderRadius: AppRadius.r8,
                border: Border.all(
                  color: colorScheme.primary.withValues(
                    alpha: isDark ? 0.35 : 0.25,
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.rule_folder_outlined,
                    size: 16,
                    color: colorScheme.primary,
                  ),
                  AppSpacing.w6,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quy định & Hoàn cọc:',
                          style: context.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                        AppSpacing.h4,
                        Text(
                          amenity.rulesAndRegulations!,
                          style: context.labelSmall?.copyWith(
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class AmenityDateStrip extends StatelessWidget {
  final List<DateTime> dates;
  final DateTime selectedDate;
  final DateFormat dayOfWeekFormat;
  final DateFormat dateDisplayFormat;
  final ValueChanged<DateTime> onDateSelected;

  const AmenityDateStrip({
    super.key,
    required this.dates,
    required this.selectedDate,
    required this.dayOfWeekFormat,
    required this.dateDisplayFormat,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      color: colorScheme.surface,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SizedBox(
        height: 84,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: dates.length,
          itemBuilder: (context, index) {
            final date = dates[index];
            final isSelected =
                date.year == selectedDate.year &&
                date.month == selectedDate.month &&
                date.day == selectedDate.day;

            return GestureDetector(
              onTap: () => onDateSelected(date),
              child: Container(
                width: 68,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primary
                      : colorScheme.surfaceContainerLow,
                  borderRadius: AppRadius.r12,
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primary
                        : colorScheme.outlineVariant,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      index == 0 ? 'Hôm nay' : dayOfWeekFormat.format(date),
                      style: context.labelSmall?.copyWith(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected
                            ? colorScheme.onPrimary.withValues(alpha: 0.85)
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                    AppSpacing.h4,
                    Text(
                      dateDisplayFormat.format(date),
                      style: context.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? colorScheme.onPrimary
                            : colorScheme.onSurface,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
