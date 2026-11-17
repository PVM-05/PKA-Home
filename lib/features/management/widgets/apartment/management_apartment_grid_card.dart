import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
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
    final statusColor =
        apartment.isEmpty ? AppStatusColors.paid : AppTheme.primary;
    final statusText = apartment.isEmpty ? 'Còn trống' : 'Đã có chủ';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.r14,
        side: BorderSide(
          color: apartment.isEmpty
              ? Colors.grey.shade200
              : AppTheme.primary.withValues(alpha: 0.25),
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
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: AppRadius.r6,
                    ),
                    child: Text(
                      apartment.code,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: statusColor,
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
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: AppRadius.r6,
                      ),
                      child: Text(
                        statusText,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
                      const Icon(
                        Icons.square_foot,
                        size: 13,
                        color: AppTheme.textSecondary,
                      ),
                      AppSpacing.w4,
                      Expanded(
                        child: Text(
                          '${apartment.area ?? 0} m²',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(
                        Icons.layers_outlined,
                        size: 13,
                        color: AppTheme.textSecondary,
                      ),
                      AppSpacing.w4,
                      Expanded(
                        child: Text(
                          'Tòa ${apartment.buildingCode} - Tầng ${apartment.floorNumber.toString().padLeft(2, '0')}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.textSecondary,
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
                  InkWell(
                    onTap: onEdit,
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.all(3.0),
                      child: Icon(
                        Icons.edit_outlined,
                        size: 17,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                  AppSpacing.w6,
                  InkWell(
                    onTap: onDelete,
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.all(3.0),
                      child: Icon(
                        Icons.delete_outline,
                        size: 17,
                        color: AppTheme.error,
                      ),
                    ),
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

