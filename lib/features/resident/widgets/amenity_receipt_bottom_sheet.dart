import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:vivona/core/theme/app_theme.dart';
import 'package:vivona/core/theme/app_typography.dart';
import 'package:vivona/core/widgets/app_snack_bar.dart';
import 'package:vivona/data/models/amenity_booking_model.dart';

void showAmenityReceiptBottomSheet({
  required BuildContext context,
  required AmenityBookingModel booking,
  String? fallbackAmenityName,
}) {
  final isPaid = booking.isConfirmed && !booking.isPendingPayment;
  final receiptCode =
      'REC-SVC-${booking.id.length > 8 ? booking.id.substring(0, 8).toUpperCase() : booking.id.toUpperCase()}';
  final txCode =
      booking.transactionCode ??
      'SVC${booking.id.length > 8 ? booking.id.substring(0, 8).toUpperCase() : booking.id.toUpperCase()}';
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final paidTime = booking.paidAt ?? booking.updatedAt ?? booking.createdAt;
  final currencyFormat = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: 'đ',
    decimalDigits: 0,
  );
  final fullDateFormat = DateFormat('EEEE, dd/MM/yyyy', 'vi');

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 4,
              width: 40,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isPaid ? AppTheme.success : AppTheme.warning)
                        .withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPaid ? Icons.verified : Icons.hourglass_top,
                    color: isPaid ? AppTheme.success : AppTheme.warning,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  isPaid ? 'BIÊN NHẬN THANH TOÁN' : 'XÁC NHẬN CHUYỂN KHOẢN',
                  style: ctx.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              isPaid
                  ? 'Giao dịch đã được Ban Quản Lý phê duyệt hợp lệ'
                  : 'Đã gửi yêu cầu đối soát, BQL đang kiểm tra giao dịch',
              style: ctx.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? Theme.of(context).colorScheme.surface
                    : AppTheme.background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white12 : Colors.grey.shade200,
                ),
              ),
              child: Column(
                children: [
                  _buildReceiptRow(
                    context,
                    label: 'Mã biên nhận',
                    value: receiptCode,
                    copyValue: receiptCode,
                  ),
                  const Divider(height: 16),
                  _buildReceiptRow(
                    context,
                    label: 'Căn hộ',
                    value: booking.apartmentCode ?? 'N/A',
                  ),
                  const Divider(height: 16),
                  _buildReceiptRow(
                    context,
                    label: 'Dịch vụ tiện ích',
                    value: booking.amenityName ?? fallbackAmenityName ?? 'Dịch vụ',
                  ),
                  const Divider(height: 16),
                  _buildReceiptRow(
                    context,
                    label: 'Thời gian sử dụng',
                    value:
                        '${fullDateFormat.format(booking.bookingDate)} (${booking.timeSlot})',
                  ),
                  if (booking.guestsCount > 1) ...[
                    const Divider(height: 16),
                    _buildReceiptRow(
                      context,
                      label: 'Số người tham gia',
                      value: '${booking.guestsCount} người',
                    ),
                  ],
                  const Divider(height: 16),
                  _buildReceiptRow(
                    context,
                    label: 'Tổng tiền thanh toán',
                    value: currencyFormat.format(booking.totalPaymentAmount),
                    isHighlight: true,
                  ),
                  if (booking.feeAmount > 0) ...[
                    const Divider(height: 16),
                    _buildReceiptRow(
                      context,
                      label: 'Phí sử dụng',
                      value: currencyFormat.format(booking.feeAmount),
                    ),
                  ],
                  if (booking.depositAmount > 0) ...[
                    const Divider(height: 16),
                    _buildReceiptRow(
                      context,
                      label: 'Tiền đặt cọc',
                      value:
                          '${currencyFormat.format(booking.depositAmount)} (${booking.depositStatus})',
                    ),
                  ],
                  const Divider(height: 16),
                  _buildReceiptRow(
                    context,
                    label: 'Phương thức',
                    value: booking.paymentMethod == 'CASH' ||
                            booking.paymentMethod == 'cash'
                        ? 'Tiền mặt tại BQL'
                        : 'Chuyển khoản VietQR (Napas 247)',
                  ),
                  const Divider(height: 16),
                  _buildReceiptRow(
                    context,
                    label: 'Mã giao dịch',
                    value: txCode,
                    copyValue: txCode,
                  ),
                  const Divider(height: 16),
                  _buildReceiptRow(
                    context,
                    label: 'Thời gian',
                    value: DateFormat(
                      'dd/MM/yyyy HH:mm',
                    ).format(paidTime.toLocal()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: AppTheme.primary,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.copy, color: Colors.white, size: 18),
              label: const Text(
                'Sao chép thông tin biên nhận',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () {
                final summary =
                    'BIÊN NHẬN THANH TOÁN TIỆN ÍCH VIVONA\n'
                    'Mã biên nhận: $receiptCode\n'
                    'Căn hộ: ${booking.apartmentCode ?? "N/A"}\n'
                    'Dịch vụ: ${booking.amenityName ?? fallbackAmenityName ?? "Dịch vụ"}\n'
                    'Thời gian: ${fullDateFormat.format(booking.bookingDate)} (${booking.timeSlot})\n'
                    'Số tiền: ${currencyFormat.format(booking.totalPaymentAmount)}\n'
                    'Trạng thái: ${isPaid ? "Đã thanh toán" : "Chờ xác nhận"}\n'
                    'Mã giao dịch: $txCode';
                Clipboard.setData(ClipboardData(text: summary));
                Navigator.pop(ctx);
                AppSnackBar.showSuccess(
                  context,
                  'Đã sao chép toàn bộ thông tin biên nhận',
                );
              },
            ),
          ],
        ),
      );
    },
  );
}

Widget _buildReceiptRow(
  BuildContext context, {
  required String label,
  required String value,
  String? copyValue,
  bool isHighlight = false,
}) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: context.bodySmall?.copyWith(color: AppTheme.textSecondary),
      ),
      const SizedBox(width: 8),
      Flexible(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                value,
                style: (isHighlight ? context.titleMedium : context.bodySmall)?.copyWith(
                  fontWeight: isHighlight ? FontWeight.w900 : FontWeight.w600,
                  color: isHighlight ? AppTheme.primary : null,
                ),
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (copyValue != null) ...[
              const SizedBox(width: 4),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: copyValue));
                  AppSnackBar.showSuccess(context, 'Đã sao chép: $copyValue');
                },
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(Icons.copy, size: 14, color: AppTheme.primary),
                ),
              ),
            ],
          ],
        ),
      ),
    ],
  );
}

