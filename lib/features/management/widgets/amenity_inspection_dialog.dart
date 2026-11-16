import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pka_home/core/theme/app_theme.dart';
import 'package:pka_home/core/utils/error_formatter.dart';
import 'package:pka_home/data/models/amenity_booking_model.dart';
import 'package:pka_home/data/models/amenity_inspection_model.dart';
import 'package:pka_home/data/providers/amenity_booking_provider.dart';

void showAmenityInspectionDialog({
  required BuildContext context,
  required WidgetRef ref,
  required AmenityBookingModel booking,
}) {
  String inspectionResult = 'passed';
  final notesController = TextEditingController();
  final forfeitedController = TextEditingController(text: '0');
  final currencyFormat = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: 'đ',
    decimalDigits: 0,
  );

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        final isPassed = inspectionResult == 'passed';
        final deposit = booking.depositAmount;

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Nghiệm Thu & Quyết Toán Cọc'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tiện ích: ${booking.amenityName ?? "Dịch vụ"}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Căn hộ: ${booking.apartmentCode ?? booking.apartmentId} • Ca: ${booking.timeSlot}',
                ),
                Text(
                  'Tiền cọc giữ: ${currencyFormat.format(deposit)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppStatusColors.paid,
                  ),
                ),
                const Divider(height: 20),
                const Text(
                  'Kết quả kiểm tra hiện trường:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 10),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'passed',
                      label: Text('Đạt tiêu chuẩn (Hoàn 100%)'),
                      icon: Icon(Icons.check_circle_outline),
                    ),
                    ButtonSegment(
                      value: 'violated',
                      label: Text('Vi phạm / Khấu trừ'),
                      icon: Icon(Icons.warning_amber_rounded),
                    ),
                  ],
                  selected: {inspectionResult},
                  onSelectionChanged: (Set<String> newSelection) {
                    setDialogState(() {
                      inspectionResult = newSelection.first;
                      if (inspectionResult == 'passed') {
                        forfeitedController.text = '0';
                      }
                    });
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  isPassed
                      ? '• Hoàn trả ${currencyFormat.format(deposit)} cho cư dân'
                      : '• Khấu trừ một phần hoặc toàn bộ tiền cọc để đền bù',
                  style: TextStyle(
                    fontSize: 12,
                    color: isPassed ? Colors.teal.shade800 : AppTheme.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (!isPassed) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: forfeitedController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Số tiền khấu trừ đền bù (VNĐ)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.money_off),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Ghi chú nghiệm thu',
                    hintText:
                        'Hiện trạng vệ sinh, tài sản, biên bản bàn giao...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Đóng'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final forfeited =
                    double.tryParse(forfeitedController.text.trim()) ?? 0.0;
                final inspection = AmenityInspectionModel(
                  bookingId: booking.id,
                  inspectionResult: inspectionResult,
                  forfeitedAmount: isPassed ? 0.0 : forfeited,
                  notes: notesController.text.trim(),
                );

                Navigator.pop(ctx);

                try {
                  await ref
                      .read(amenityBookingRepositoryProvider)
                      .inspectAndSettleDeposit(inspection);

                  ref.invalidate(pendingAmenityInspectionsProvider);
                  ref.invalidate(allAmenityBookingsProvider);

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isPassed
                              ? 'Nghiệm thu đạt! Đã chuyển lệnh hoàn cọc ${currencyFormat.format(deposit)}.'
                              : 'Đã ghi nhận vi phạm và khấu trừ ${currencyFormat.format(forfeited)}.',
                        ),
                        backgroundColor: isPassed
                            ? AppStatusColors.paid
                            : AppTheme.warning,
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
              child: const Text('Xác Nhận Quyết Toán'),
            ),
          ],
        );
      },
    ),
  );
}
