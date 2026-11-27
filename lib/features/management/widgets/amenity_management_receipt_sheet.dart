import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:vivona/core/theme/app_theme.dart';
import 'package:vivona/core/theme/app_typography.dart';
import 'package:vivona/data/models/amenity_booking_model.dart';

void showAmenityManagementReceiptSheet({
  required BuildContext context,
  required AmenityBookingModel booking,
}) {
  final isPaid = booking.isConfirmed && !booking.isPendingPayment;
  final receiptCode =
      'REC-SVC-${booking.id.length > 8 ? booking.id.substring(0, 8).toUpperCase() : booking.id.toUpperCase()}';
  final txCode =
      booking.transactionCode ??
      'SVC${booking.id.length > 8 ? booking.id.substring(0, 8).toUpperCase() : booking.id.toUpperCase()}';
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final paidTime = booking.paidAt ?? booking.updatedAt ?? booking.createdAt;
  final dateFormat = DateFormat('dd/MM/yyyy');
  final currencyFormat = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: 'đ',
    decimalDigits: 0,
  );

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
                  isPaid ? 'BIÊN NHẬN ĐIỆN TỬ BQL' : 'GIAO DỊCH CHỜ ĐỐI SOÁT',
                  style: context.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              isPaid
                  ? 'Giao dịch thanh toán dịch vụ tiện ích đã được Ban Quản Lý xác thực'
                  : 'Yêu cầu thanh toán đang chờ Ban Quản Lý đối soát hoặc thu tiền',
              style: context.bodySmall?.copyWith(
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white12 : Colors.grey.shade200,
                ),
              ),
              child: Column(
                children: [
                  _buildReceiptRow(
                    ctx,
                    label: 'Mã biên nhận',
                    value: receiptCode,
                    copyValue: receiptCode,
                  ),
                  const Divider(height: 16),
                  _buildReceiptRow(
                    ctx,
                    label: 'Căn hộ',
                    value: booking.apartmentCode ?? 'N/A',
                  ),
                  const Divider(height: 16),
                  _buildReceiptRow(
                    ctx,
                    label: 'Cư dân đăng ký',
                    value: booking.bookerName ?? 'Cư dân',
                  ),
                  const Divider(height: 16),
                  _buildReceiptRow(
                    ctx,
                    label: 'Dịch vụ tiện ích',
                    value: booking.amenityName ?? 'Dịch vụ',
                  ),
                  const Divider(height: 16),
                  _buildReceiptRow(
                    ctx,
                    label: 'Thời gian sử dụng',
                    value:
                        '${dateFormat.format(booking.bookingDate)} (${booking.timeSlot})',
                  ),
                  if (booking.guestsCount > 1) ...[
                    const Divider(height: 16),
                    _buildReceiptRow(
                      ctx,
                      label: 'Số người tham gia',
                      value: '${booking.guestsCount} người',
                    ),
                  ],
                  const Divider(height: 16),
                  _buildReceiptRow(
                    ctx,
                    label: 'Tổng tiền thực thu',
                    value: currencyFormat.format(booking.totalPaymentAmount),
                    isHighlight: true,
                  ),
                  if (booking.feeAmount > 0) ...[
                    const Divider(height: 16),
                    _buildReceiptRow(
                      ctx,
                      label: 'Phí sử dụng',
                      value: currencyFormat.format(booking.feeAmount),
                    ),
                  ],
                  if (booking.depositAmount > 0) ...[
                    const Divider(height: 16),
                    _buildReceiptRow(
                      ctx,
                      label: 'Tiền đặt cọc',
                      value:
                          '${currencyFormat.format(booking.depositAmount)} (${booking.depositStatus})',
                    ),
                  ],
                  const Divider(height: 16),
                  _buildReceiptRow(
                    ctx,
                    label: 'Phương thức thanh toán',
                    value: booking.paymentMethod == 'CASH' ||
                            booking.paymentMethod == 'cash'
                        ? 'Tiền mặt tại BQL'
                        : 'Chuyển khoản VietQR (Napas 247)',
                  ),
                  const Divider(height: 16),
                  _buildReceiptRow(
                    ctx,
                    label: 'Mã giao dịch đối soát',
                    value: txCode,
                    copyValue: txCode,
                  ),
                  const Divider(height: 16),
                  _buildReceiptRow(
                    ctx,
                    label: 'Thời gian ghi nhận',
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
                    'BIÊN NHẬN ĐIỆN TỬ BQL - TIỆN ÍCH VIVONA\n'
                    'Mã biên nhận: $receiptCode\n'
                    'Căn hộ: ${booking.apartmentCode ?? "N/A"}\n'
                    'Người đặt: ${booking.bookerName ?? "Cư dân"}\n'
                    'Dịch vụ: ${booking.amenityName ?? "Dịch vụ"}\n'
                    'Thời gian: ${dateFormat.format(booking.bookingDate)} (${booking.timeSlot})\n'
                    'Số tiền: ${currencyFormat.format(booking.totalPaymentAmount)}\n'
                    'Trạng thái: ${isPaid ? "Đã thu tiền" : "Chờ thu / Đối soát"}\n'
                    'Mã giao dịch: $txCode';
                Clipboard.setData(ClipboardData(text: summary));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã sao chép toàn bộ thông tin biên nhận'),
                    backgroundColor: AppTheme.success,
                  ),
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
        style: context.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Đã sao chép: $copyValue'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
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
