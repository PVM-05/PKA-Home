import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vivona/core/theme/app_radius.dart';
import 'package:vivona/core/theme/app_spacing.dart';
import 'package:vivona/core/theme/app_theme.dart';
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

    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      color: Theme.of(context).cardColor,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.r16,
        side: BorderSide(
          color: vehicle.isRejected
              ? AppTheme.error.withValues(alpha: 0.3)
              : Theme.of(context).dividerColor,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hàng 1: Icon xe + Biển số + Badge trạng thái + Nút thao tác
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: vehicle.isMotorbike
                        ? Colors.orange.shade50
                        : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    vehicle.isMotorbike
                        ? Icons.two_wheeler_outlined
                        : Icons.directions_car_outlined,
                    color: vehicle.isMotorbike
                        ? Colors.orange.shade700
                        : AppTheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          border: Border.all(
                            color: Colors.grey.shade400,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          vehicle.plateNumber,
                          style: textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: vehicle.isApproved
                              ? AppStatusColors.paid.withValues(alpha: 0.12)
                              : vehicle.isRejected
                              ? AppTheme.error.withValues(alpha: 0.12)
                              : AppStatusColors.pending.withValues(
                                  alpha: 0.12,
                                ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          vehicle.statusDisplayName,
                          style: textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: vehicle.isApproved
                                ? AppStatusColors.paid
                                : vehicle.isRejected
                                ? AppTheme.error
                                : AppStatusColors.pending,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (vehicle.isPending) ...[
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(
                          Icons.edit_outlined,
                          color: AppTheme.primary,
                          size: 20,
                        ),
                        tooltip: 'Sửa thông tin xe',
                        onPressed: onEdit,
                      ),
                      AppSpacing.w8,
                    ],
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        vehicle.isRejected
                            ? Icons.delete_forever_outlined
                            : Icons.delete_outline,
                        color: AppTheme.error,
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
            const SizedBox(height: 10),
            // Hàng 2: Tên xe & Model
            Row(
              children: [
                Text(
                  vehicle.vehicleTypeName,
                  style: textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (vehicle.brandModel != null &&
                    vehicle.brandModel!.trim().isNotEmpty) ...[
                  Expanded(
                    child: Text(
                      ' • ${vehicle.brandModel!.trim()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            AppSpacing.h4,
            // Hàng 3: Biểu phí & Ngày đăng ký
            Text(
              'Biểu phí: ${_currencyFormat.format(vehicle.monthlyFee)}/tháng • Ngày đăng ký: ${_dateFormat.format(vehicle.createdAt)}',
              style: textTheme.labelSmall?.copyWith(
                color: Colors.grey.shade600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            // Hàng 4: Slot ô đỗ & Ảnh cà vẹt xe (Wrap)
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if ((slotNum != null && slotNum.isNotEmpty) ||
                    assignedSlot != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.local_parking,
                          size: 14,
                          color: AppTheme.primary,
                        ),
                        AppSpacing.w4,
                        Flexible(
                          child: Text(
                            'Vị trí ô đỗ: ${(slotNum != null && slotNum.isNotEmpty) ? slotNum : assignedSlot!.slotNumber}${assignedSlot != null ? ' (Tầng ${assignedSlot.zone})' : ''}',
                            style: textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (vehicle.hasRegistrationImage && onPhotoView != null) ...[
                  InkWell(
                    onTap: onPhotoView,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.blue.shade200,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.badge_outlined,
                            size: 13,
                            color: AppTheme.primary,
                          ),
                          AppSpacing.w4,
                          Text(
                            'Xem ảnh cà vẹt xe',
                            style: textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primary,
                            ),
                          ),
                          AppSpacing.w4,
                          const Icon(
                            Icons.open_in_new,
                            size: 11,
                            color: AppTheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            // Lý do từ chối nếu bị từ chối
            if (vehicle.isRejected) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.error.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 16,
                      color: AppTheme.error,
                    ),
                    AppSpacing.w8,
                    Expanded(
                      child: Text(
                        'Lý do từ chối: ${vehicle.hasRejectionReason ? vehicle.rejectionReason! : 'Không đủ điều kiện cấp thẻ xe theo quy chế tòa nhà.'}',
                        style: textTheme.bodySmall?.copyWith(
                          color: AppTheme.error,
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
      ),
    );
  }
}

