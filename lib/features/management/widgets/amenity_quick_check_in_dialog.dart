import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vivona/core/theme/app_theme.dart';
import 'package:vivona/core/theme/app_typography.dart';
import 'package:vivona/core/utils/error_formatter.dart';
import 'package:vivona/data/providers/amenity_booking_provider.dart';

void showAmenityQuickCheckInDialog({
  required BuildContext context,
  required WidgetRef ref,
  String? selectedAmenityId,
  required DateTime selectedDate,
}) {
  final codeController = TextEditingController();

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.qr_code_scanner_outlined, color: AppTheme.primary),
          SizedBox(width: 8),
          Expanded(child: Text('Check-in Tiện Ích (QR/Mã)')),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nhập mã đặt chỗ từ mã QR của cư dân để xác nhận điểm danh sử dụng dịch vụ:',
              style: context.bodyMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('qr_token_input_field'),
              controller: codeController,
              decoration: const InputDecoration(
                labelText: 'Mã đặt chỗ',
                hintText: 'Nhập mã đặt chỗ hoặc mã vé điện tử',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.confirmation_number_outlined),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Đóng'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(0, 48),
            backgroundColor: AppStatusColors.paid,
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.check, size: 16),
          label: const Text('Xác nhận vào cửa'),
          onPressed: () async {
            String token = codeController.text.trim();
            if (token.isEmpty) return;
            if (token.startsWith('VIVONA-TICKET:') || token.startsWith('PKA-TICKET:')) {
              final parts = token.split(':');
              if (parts.length >= 2) {
                token = parts[1];
              }
            }
            Navigator.pop(ctx);

            try {
              final Map<String, dynamic> result;
              final bool isTicketToken =
                  token.startsWith('TK-') || token.toUpperCase().startsWith('TICKET');
              if (isTicketToken) {
                result = await ref
                    .read(amenityBookingRepositoryProvider)
                    .checkInTicket(token);
              } else {
                result = await ref
                    .read(amenityBookingRepositoryProvider)
                    .checkInBooking(token);
              }

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
              ref.invalidate(allAmenityBookingsProvider);
              ref.invalidate(pendingAmenityInspectionsProvider);

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      result['message']?.toString() ??
                          'Xác nhận Check-in thành công!',
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
        ),
      ],
    ),
  );
}

