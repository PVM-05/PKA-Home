import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vivona/core/theme/app_radius.dart';
import 'package:vivona/core/theme/app_spacing.dart';
import 'package:vivona/core/theme/app_theme.dart';
import 'package:vivona/core/widgets/app_card.dart';
import 'package:vivona/data/models/parking_slot_model.dart';
import 'package:vivona/data/models/vehicle_model.dart';

class ResidentVehicleCard extends StatelessWidget {
  final VehicleModel vehicle;
  final List<ParkingSlotModel> allSlots;
  final int motorbikeCount;
  final String apartmentId;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onPhotoView;

  const ResidentVehicleCard({
    super.key,
    required this.vehicle,
    required this.allSlots,
    required this.motorbikeCount,
    required this.apartmentId,
    required this.onEdit,
    required this.onDelete,
    this.onPhotoView,
  });

  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  static final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: 'VNĐ',
  );

  @override
  Widget build(BuildContext context) {
    final slotNum = vehicle.parkingSlotNumber;
    final assignedSlot = allSlots
        .where(
          (s) =>
              (vehicle.parkingSlotId != null &&
                  s.id == vehicle.parkingSlotId) ||
              (s.assignedVehicleId != null &&
                  s.assignedVehicleId == vehicle.id) ||
              (slotNum != null &&
                  slotNum.isNotEmpty &&
                  s.slotNumber == slotNum) ||
              (s.licensePlate != null &&
                  s.licensePlate!.trim().toUpperCase() ==
                      vehicle.plateNumber.trim().toUpperCase()),
        )
        .firstOrNull;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;

    final warningColor = AppTheme.getSemanticWarning(context);
    final errorColor = AppTheme.getSemanticError(context);
    final vehicleAccent = vehicle.isMotorbike
        ? warningColor
        : colorScheme.primary;

    final Color statusColor;
    if (vehicle.isApproved) {
      statusColor = AppStatusColors.getPaid(context);
    } else if (vehicle.isRejected) {
      statusColor = AppStatusColors.getRejected(context);
    } else {
      statusColor = AppStatusColors.getPending(context);
    }

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      borderColor: vehicle.isRejected
          ? errorColor.withValues(alpha: isDark ? 0.5 : 0.35)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: vehicleAccent.withValues(alpha: isDark ? 0.18 : 0.10),
                  borderRadius: AppRadius.r12,
                ),
                child: Icon(
                  vehicle.isMotorbike
                      ? Icons.two_wheeler_outlined
                      : Icons.directions_car_outlined,
                  color: vehicleAccent,
                  size: 22,
                ),
              ),
              AppSpacing.w10,
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerLow,
                        border: Border.all(
                          color: colorScheme.outlineVariant,
                        ),
                        borderRadius: AppRadius.r8,
                      ),
                      child: Text(
                        vehicle.plateNumber,
                        style: textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: colorScheme.onSurface,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(
                          alpha: isDark ? 0.18 : 0.12,
                        ),
                        borderRadius: AppRadius.r8,
                      ),
                      child: Text(
                        vehicle.statusDisplayName,
                        style: textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (vehicle.isPending)
                    IconButton(
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      icon: Icon(
                        Icons.edit_outlined,
                        color: colorScheme.primary,
                        size: 20,
                      ),
                      tooltip: 'Sửa thông tin xe',
                      onPressed: onEdit,
                    ),
                  IconButton(
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    icon: Icon(
                      vehicle.isRejected
                          ? Icons.delete_forever_outlined
                          : Icons.delete_outline,
                      color: errorColor,
                      size: 20,
                    ),
                    tooltip: vehicle.isRejected
                        ? 'Xóa bản ghi xe bị từ chối'
                        : 'Hủy đăng ký xe',
                    onPressed: onDelete,
                  ),
                ],
              ),
            ],
          ),
          AppSpacing.h8,
          Row(
            children: [
              Text(
                vehicle.vehicleTypeName,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (vehicle.brandModel != null &&
                  vehicle.brandModel!.trim().isNotEmpty)
                Expanded(
                  child: Text(
                    ' • ${vehicle.brandModel!.trim()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          AppSpacing.h4,
          Text(
            'Biểu phí: ${_currencyFormat.format(vehicle.monthlyFee)}/tháng • Ngày đăng ký: ${_dateFormat.format(vehicle.createdAt)}',
            style: textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if ((slotNum != null && slotNum.isNotEmpty) ||
              assignedSlot != null ||
              (vehicle.hasRegistrationImage && onPhotoView != null)) ...[
            AppSpacing.h8,
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if ((slotNum != null && slotNum.isNotEmpty) ||
                    assignedSlot != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(
                        alpha: isDark ? 0.16 : 0.08,
                      ),
                      borderRadius: AppRadius.r8,
                      border: Border.all(
                        color: colorScheme.primary.withValues(
                          alpha: isDark ? 0.35 : 0.22,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.local_parking,
                          size: 16,
                          color: colorScheme.primary,
                        ),
                        AppSpacing.w4,
                        Flexible(
                          child: Text(
                            'Vị trí ô đỗ: ${(slotNum != null && slotNum.isNotEmpty) ? slotNum : assignedSlot!.slotNumber}${assignedSlot != null ? ' (Tầng ${assignedSlot.zone})' : ''}',
                            style: textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (vehicle.hasRegistrationImage && onPhotoView != null)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.primary,
                      side: BorderSide(
                        color: colorScheme.primary.withValues(
                          alpha: isDark ? 0.45 : 0.3,
                        ),
                      ),
                      backgroundColor: colorScheme.primary.withValues(
                        alpha: isDark ? 0.14 : 0.06,
                      ),
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    onPressed: onPhotoView,
                    icon: const Icon(Icons.badge_outlined, size: 16),
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Xem ảnh cà vẹt xe',
                          style: textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.primary,
                          ),
                        ),
                        AppSpacing.w4,
                        Icon(
                          Icons.open_in_new,
                          size: 13,
                          color: colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
          if (vehicle.isRejected) ...[
            AppSpacing.h12,
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: errorColor.withValues(alpha: isDark ? 0.14 : 0.08),
                borderRadius: AppRadius.r8,
                border: Border.all(
                  color: errorColor.withValues(alpha: isDark ? 0.4 : 0.25),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 18,
                    color: errorColor,
                  ),
                  AppSpacing.w8,
                  Expanded(
                    child: Text(
                      'Lý do từ chối: ${vehicle.hasRejectionReason ? vehicle.rejectionReason! : 'Không đủ điều kiện cấp thẻ xe theo quy chế tòa nhà.'}',
                      style: textTheme.bodySmall?.copyWith(
                        color: errorColor,
                        fontWeight: FontWeight.w500,
                      ),
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
