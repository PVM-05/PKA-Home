import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pka_home/core/theme/app_theme.dart';
import 'package:pka_home/core/utils/error_formatter.dart';
import 'package:pka_home/data/models/amenity_booking_model.dart';
import 'package:pka_home/data/providers/amenity_booking_provider.dart';

void showAmenityRejectDialog({
  required BuildContext context,
  required WidgetRef ref,
  required AmenityBookingModel booking,
  String? selectedAmenityId,
  required DateTime selectedDate,
}) {
  final reasonController = TextEditingController();
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Từ Chối / Hủy Lịch Đặt Chỗ'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            booking.isWaitlist
                ? 'Hủy lượt đặt trong danh sách chờ của căn hộ ${booking.apartmentCode ?? "***"} (${booking.timeSlot})?'
                : 'Hủy lịch đặt của căn hộ ${booking.apartmentCode ?? "***"} (${booking.timeSlot})?',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: reasonController,
            decoration: const InputDecoration(
              labelText: 'Lý do từ chối / hủy (tùy chọn)',
              hintText: 'VD: Khu vực bảo trì đột xuất, trùng lịch nội bộ',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Đóng'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.error,
            foregroundColor: Colors.white,
          ),
          onPressed: () async {
            final reason = reasonController.text.trim();
            Navigator.pop(ctx);
            try {
              await ref
                  .read(amenityBookingRepositoryProvider)
                  .cancelBooking(booking.id, reason: reason.isNotEmpty ? reason : null);
              ref.invalidate(allAmenityBookingsProvider);
              if (selectedAmenityId != null) {
                ref.invalidate(
                  amenityBookingsForDateProvider(
                    AmenityDateQuery(
                      amenityId: selectedAmenityId,
                      date: selectedDate,
                    ),
                  ),
                );
              }
              ref.invalidate(
                amenityBookingsForDateProvider(
                  AmenityDateQuery(
                    amenityId: booking.amenityId,
                    date: booking.bookingDate,
                  ),
                ),
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Đã từ chối / hủy lịch đặt chỗ thành công.',
                    ),
                    backgroundColor: AppStatusColors.paid,
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(formatErrorMessage(e)),
                    backgroundColor: AppTheme.error,
                  ),
                );
              }
            }
          },
          child: Text(
            booking.isWaitlist ? 'Xác nhận hủy hàng chờ' : 'Xác nhận từ chối / hủy',
          ),
        ),
      ],
    ),
  );
}
