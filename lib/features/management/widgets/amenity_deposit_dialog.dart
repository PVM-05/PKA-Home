import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:vivona/core/theme/app_theme.dart';
import 'package:vivona/core/theme/app_typography.dart';
import 'package:vivona/core/utils/error_formatter.dart';
import 'package:vivona/data/models/amenity_booking_model.dart';
import 'package:vivona/data/providers/amenity_booking_provider.dart';

void showAmenityDepositDialog({
  required BuildContext context,
  required WidgetRef ref,
  required AmenityBookingModel booking,
}) {
  String currentStatus = booking.depositStatus;
  final notesController = TextEditingController(
    text: booking.depositNotes ?? '',
  );
  final currencyFormat = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: 'đ',
    decimalDigits: 0,
  );

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Quản Lý Tiền Đặt Cọc'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Căn hộ: ${booking.apartmentCode ?? "***"}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Người đặt: ${booking.bookerName ?? "***"}'),
              const SizedBox(height: 6),
              Text(
                'Số tiền cọc: ${currencyFormat.format(booking.depositAmount)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.warning,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Trạng thái cọc:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              DropdownButton<String>(
                value: currentStatus,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(
                    value: 'none',
                    child: Text('Không yêu cầu cọc'),
                  ),
                  DropdownMenuItem(
                    value: 'pending',
                    child: Text('Chưa nộp tiền cọc (Chờ thu)'),
                  ),
                  DropdownMenuItem(
                    value: 'received',
                    child: Text('Đã nhận đủ tiền cọc'),
                  ),
                  DropdownMenuItem(
                    value: 'refunded',
                    child: Text('Đã hoàn trả cọc cho cư dân'),
                  ),
                  DropdownMenuItem(
                    value: 'forfeited',
                    child: Text('Tịch thu cọc (Vi phạm/Hư hỏng)'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => currentStatus = val);
                },
              ),
              const SizedBox(height: 10),
              if (currentStatus == 'refunded') ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: booking.inspectionResult == 'passed'
                        ? Colors.green.shade50
                        : Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: booking.inspectionResult == 'passed'
                          ? Colors.green.shade200
                          : Colors.amber.shade300,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            booking.inspectionResult == 'passed'
                                ? Icons.verified_outlined
                                : Icons.info_outline,
                            size: 16,
                            color: booking.inspectionResult == 'passed'
                                ? Colors.green.shade800
                                : Colors.amber.shade900,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              booking.inspectionResult == 'passed'
                                  ? 'Đã có biên bản nghiệm thu: Đạt chuẩn'
                                  : (booking.inspectionResult == 'violated'
                                      ? 'Cảnh báo: Có vi phạm/khấu trừ (${currencyFormat.format(booking.forfeitedAmount)})'
                                      : 'Lưu ý: Chưa lập biên bản nghiệm thu hiện trường'),
                              style: context.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: booking.inspectionResult == 'passed'
                                    ? Colors.green.shade800
                                    : Colors.amber.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tiền cọc là quỹ ký quỹ hoàn trả, không gộp vào doanh thu tòa nhà. Bắt buộc ghi nhận chứng từ/mã giao dịch hoàn tiền.',
                        style: context.labelSmall?.copyWith(color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
              TextField(
                controller: notesController,
                decoration: InputDecoration(
                  labelText: currentStatus == 'refunded'
                      ? 'Chứng từ / Mã GD hoàn cọc / Lý do *'
                      : 'Ghi chú thu/hoàn cọc',
                  hintText: currentStatus == 'refunded'
                      ? 'VD: Chuyển khoản hoàn cọc mã FT26... sau khi kiểm tra mặt sàn'
                      : 'VD: Đã hoàn tiền mặt lúc 21h',
                  border: const OutlineInputBorder(),
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
              if (currentStatus == 'refunded' && notesController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Vui lòng nhập ghi chú chứng từ hoặc mã giao dịch hoàn cọc!'),
                    backgroundColor: AppTheme.error,
                  ),
                );
                return;
              }
              Navigator.pop(ctx);
              try {
                await ref
                    .read(amenityBookingRepositoryProvider)
                    .updateDepositStatus(
                      booking.id,
                      currentStatus,
                      notes: notesController.text.trim(),
                    );
                ref.invalidate(
                  amenityBookingsForDateProvider(
                    AmenityDateQuery(
                      amenityId: booking.amenityId,
                      date: booking.bookingDate,
                    ),
                  ),
                );
                ref.invalidate(allAmenityBookingsProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã cập nhật trạng thái tiền cọc!'),
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
            child: const Text('Cập nhật'),
          ),
        ],
      ),
    ),
  );
}

