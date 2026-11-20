import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:vivona/core/theme/app_theme.dart';
import 'package:vivona/core/theme/app_typography.dart';
import 'package:vivona/core/utils/error_formatter.dart';
import 'package:vivona/data/models/amenity_booking_model.dart';
import 'package:vivona/data/providers/amenity_booking_provider.dart';
import 'package:vivona/features/management/widgets/amenity_management_receipt_sheet.dart';

Future<void> showAmenityConfirmPaymentDialog({
  required BuildContext context,
  required WidgetRef ref,
  required AmenityBookingModel booking,
  String? selectedAmenityId,
  required DateTime selectedDate,
}) async {
  String selectedMethod = 'CASH';
  final totalFee = booking.feeAmount + booking.depositAmount;
  final currencyFormat = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: 'đ',
    decimalDigits: 0,
  );

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: AppTheme.success),
            SizedBox(width: 8),
            Expanded(child: Text('Thu phí dịch vụ tiện ích')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Xác nhận đã nhận đủ tiền phí/tiền cọc từ cư dân:'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• Căn hộ: ${booking.apartmentCode ?? "Chưa rõ"}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '• Tiện ích: ${booking.amenityName ?? "Dịch vụ"} (${booking.timeSlot})',
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '• Tổng thu: ${currencyFormat.format(totalFee)}',
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Hình thức thanh toán thực thu:',
                style: context.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'CASH',
                    label: Text('Tiền mặt'),
                    icon: Icon(Icons.payments_outlined),
                  ),
                  ButtonSegment(
                    value: 'BANK_TRANSFER',
                    label: Text('Chuyển khoản'),
                    icon: Icon(Icons.account_balance_outlined),
                  ),
                ],
                selected: {selectedMethod},
                onSelectionChanged: (newSelection) {
                  setDialogState(() => selectedMethod = newSelection.first);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.success,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xác nhận đã thu'),
          ),
        ],
      ),
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    final methodTitle = selectedMethod == 'CASH'
        ? 'Tiền mặt'
        : 'Chuyển khoản';
    await ref
        .read(amenityBookingRepositoryProvider)
        .recordManualAmenityPayment(
          bookingId: booking.id,
          paymentMethod: selectedMethod,
          notes:
              'Thu phí dịch vụ tiện ích ${booking.amenityName ?? ""} ($methodTitle)',
        );
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
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Xác nhận thu phí ($methodTitle) thành công cho căn hộ ${booking.apartmentCode ?? ""}!',
          ),
          backgroundColor: AppTheme.success,
          action: SnackBarAction(
            label: 'Biên nhận',
            textColor: Colors.white,
            onPressed: () => showAmenityManagementReceiptSheet(
              context: context,
              booking: booking,
            ),
          ),
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
}

