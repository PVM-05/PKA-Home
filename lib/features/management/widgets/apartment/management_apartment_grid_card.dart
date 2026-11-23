import 'package:flutter/material.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/apartment_model.dart';

/// Card dạng Grid hiển thị thông tin căn hộ
class ManagementApartmentGridCard extends StatelessWidget {
  final ApartmentModel apartment;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ManagementApartmentGridCard({
    super.key,
    required this.apartment,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;
    final errorColor = AppTheme.getSemanticError(context);

    final statusColor = apartment.isEmpty
        ? AppStatusColors.getPaid(context)
        : colorScheme.primary;
    final statusText = apartment.isEmpty ? 'Còn trống' : 'Đã có chủ';

    return Card(
      elevation: 0,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.r14,
        side: BorderSide(
          color: apartment.isEmpty
              ? colorScheme.outlineVariant
              : colorScheme.primary.withValues(alpha: isDark ? 0.45 : 0.28),
          width: apartment.isEmpty ? 1 : 1.5,
        ),
      ),
      child: InkWell(
        borderRadius: AppRadius.r14,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(
                        alpha: isDark ? 0.18 : 0.10,
                      ),
                      borderRadius: AppRadius.r6,
                    ),
                    child: Text(
                      apartment.code,
                      style: textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  AppSpacing.w4,
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(
                          alpha: isDark ? 0.18 : 0.10,
                        ),
                        borderRadius: AppRadius.r6,
                      ),
                      child: Text(
                        statusText,
                        style: textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.square_foot,
                        size: 13,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      AppSpacing.w4,
                      Expanded(
                        child: Text(
                          '${apartment.area ?? 0} m²',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.layers_outlined,
                        size: 13,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      AppSpacing.w4,
                      Expanded(
                        child: Text(
                          'Tòa ${apartment.buildingCode} - Tầng ${apartment.floorNumber.toString().padLeft(2, '0')}',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: 'Chỉnh sửa căn hộ',
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                    onPressed: onEdit,
                  ),
                  IconButton(
                    tooltip: 'Xóa căn hộ',
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: errorColor,
                    ),
                    onPressed: onDelete,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
