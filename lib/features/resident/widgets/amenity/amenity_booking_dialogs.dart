import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vivona/core/theme/app_radius.dart';
import 'package:vivona/core/theme/app_spacing.dart';
import 'package:vivona/core/theme/app_theme.dart';
import 'package:vivona/core/theme/app_typography.dart';
import 'package:vivona/data/models/amenity_booking_model.dart';
import 'package:vivona/data/models/building_amenity_model.dart';
import 'package:vivona/features/resident/widgets/amenity_qr_code_dialog.dart';
import 'package:vivona/features/resident/widgets/amenity_receipt_bottom_sheet.dart';

class AmenityConfirmDialogResult {
  final bool confirmed;
  final int guestsCount;

  const AmenityConfirmDialogResult({
    required this.confirmed,
    required this.guestsCount,
  });
}

Future<AmenityConfirmDialogResult> showAmenityConfirmBookingDialog({
  required BuildContext context,
  required BuildingAmenityModel amenity,
  required DateTime selectedDate,
  required String slot,
  required bool isWaitlist,
  required int initialGuestsCount,
  required DateFormat fullDateFormat,
  required NumberFormat currencyFormat,
}) async {
  int dialogGuestsCount = initialGuestsCount;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        final theme = Theme.of(ctx);
        final colorScheme = theme.colorScheme;
        final isDark = theme.brightness == Brightness.dark;
        final warningColor = AppTheme.getSemanticWarning(ctx);
        final secondaryColor = AppTheme.getSemanticSecondary(ctx);
        final calloutAccent = isWaitlist ? secondaryColor : warningColor;

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: AppRadius.r16),
          title: Text(
            isWaitlist ? 'Gia Nhập Danh Sách Chờ' : 'Xác Nhận Đặt Lịch',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tiện ích: ${amenity.name}',
                  style: ctx.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                AppSpacing.h6,
                Text(
                  'Ngày sử dụng: ${fullDateFormat.format(selectedDate)}',
                  style: ctx.bodyMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                AppSpacing.h6,
                Text(
                  'Khung giờ: $slot',
                  style: ctx.bodyMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                AppSpacing.h6,
                if (amenity.isShared) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Flexible(child: Text('Số người tham gia:')),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            constraints: const BoxConstraints(
                              minWidth: 48,
                              minHeight: 48,
                            ),
                            tooltip: 'Giảm số người',
                            icon: const Icon(
                              Icons.remove_circle_outline,
                              size: 22,
                            ),
                            onPressed: dialogGuestsCount > 1
                                ? () => setDialogState(() => dialogGuestsCount--)
                                : null,
                          ),
                          Text(
                            '$dialogGuestsCount',
                            style: ctx.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          IconButton(
                            constraints: const BoxConstraints(
                              minWidth: 48,
                              minHeight: 48,
                            ),
                            tooltip: 'Tăng số người',
                            icon: const Icon(
                              Icons.add_circle_outline,
                              size: 22,
                            ),
                            onPressed: dialogGuestsCount < amenity.maxCapacity
                                ? () => setDialogState(() => dialogGuestsCount++)
                                : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                  AppSpacing.h6,
                ],
                if (amenity.feeAmount > 0) ...[
                  Text(
                    'Phí sử dụng: ${currencyFormat.format(amenity.feeAmount * dialogGuestsCount)}',
                    style: ctx.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  AppSpacing.h4,
                ],
                if (amenity.requiresDeposit && amenity.depositAmount > 0) ...[
                  Text(
                    'Tiền đặt cọc: ${currencyFormat.format(amenity.depositAmount)}',
                    style: ctx.bodyMedium?.copyWith(
                      color: warningColor,
                      fontWeight: FontWeight.bold,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  AppSpacing.h6,
                ],
                AppSpacing.h8,
                Container(
                  padding: AppSpacing.p12,
                  decoration: BoxDecoration(
                    color: calloutAccent.withValues(
                      alpha: isDark ? 0.14 : 0.08,
                    ),
                    border: Border.all(
                      color: calloutAccent.withValues(
                        alpha: isDark ? 0.45 : 0.35,
                      ),
                    ),
                    borderRadius: AppRadius.r8,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        isWaitlist
                            ? Icons.hourglass_top_outlined
                            : Icons.info_outline,
                        size: 18,
                        color: calloutAccent,
                      ),
                      AppSpacing.w8,
                      Expanded(
                        child: Text(
                          isWaitlist
                              ? 'Khung giờ này đã hết chỗ. Khi có người hủy lịch, hệ thống sẽ tự động xác nhận cho bạn và gửi thông báo.'
                              : 'Vui lòng có mặt đúng giờ. Nếu có đặt cọc, vui lòng hoàn tất tại quầy lễ tân/BQL.',
                          style: ctx.labelSmall?.copyWith(
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy bỏ'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isWaitlist
                    ? AppTheme.secondary
                    : AppTheme.primary,
                foregroundColor: colorScheme.onPrimary,
                minimumSize: const Size(0, 48),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                isWaitlist ? 'Xác nhận vào hàng chờ' : 'Xác nhận đặt',
              ),
            ),
          ],
        );
      },
    ),
  );

  return AmenityConfirmDialogResult(
    confirmed: confirmed == true,
    guestsCount: dialogGuestsCount,
  );
}

Future<bool> showAmenityCancelConfirmDialog({
  required BuildContext context,
  required AmenityBookingModel booking,
  required String fallbackAmenityName,
  required DateFormat fullDateFormat,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final colorScheme = Theme.of(ctx).colorScheme;
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.r16),
        title: const Text('Hủy Lịch Đã Đặt'),
        content: Text(
          'Bạn có chắc muốn hủy lịch tiện ích ${booking.amenityName ?? fallbackAmenityName} vào ngày ${fullDateFormat.format(booking.bookingDate)} khung giờ ${booking.timeSlot} không?\n\n${booking.isConfirmed ? 'Chỗ này sẽ tự động được nhường cho người tiếp theo trong danh sách chờ.' : 'Bạn sẽ được rút khỏi danh sách chờ của khung giờ này.'}',
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Không'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.textError,
              foregroundColor: colorScheme.onError,
              minimumSize: const Size(0, 48),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hủy lịch'),
          ),
        ],
      );
    },
  );
  return confirmed == true;
}

Future<void> showAmenityBookingSuccessDialog({
  required BuildContext context,
  required BuildingAmenityModel amenity,
  required AmenityBookingModel booking,
  required DateTime selectedDate,
  required String slot,
  required DateFormat fullDateFormat,
}) async {
  final bookingCode =
      'BK${booking.id.length >= 8 ? booking.id.substring(0, 8).toUpperCase() : booking.id.toUpperCase()}';

  await showDialog<void>(
    context: context,
    builder: (dialogCtx) {
      final theme = Theme.of(dialogCtx);
      final colorScheme = theme.colorScheme;
      final isDark = theme.brightness == Brightness.dark;
      final successColor = AppTheme.getSemanticSuccess(dialogCtx);

      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.r20),
        title: Column(
          children: [
            Icon(Icons.check_circle_rounded, color: successColor, size: 56),
            AppSpacing.h12,
            Text(
              'Đặt Dịch Vụ Thành Công!',
              style: dialogCtx.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                amenity.name,
                style: dialogCtx.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              AppSpacing.h4,
              Text(
                '${fullDateFormat.format(selectedDate)} • $slot',
                style: dialogCtx.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                textAlign: TextAlign.center,
              ),
              AppSpacing.h16,
              Container(
                padding: AppSpacing.p12,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(
                    alpha: isDark ? 0.16 : 0.08,
                  ),
                  borderRadius: AppRadius.r12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Mã đặt chỗ:',
                      style: dialogCtx.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      bookingCode,
                      style: dialogCtx.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: colorScheme.primary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              AppSpacing.h16,
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.r12),
                  ),
                  icon: const Icon(Icons.qr_code_2_rounded),
                  label: const Text(
                    'Xem Mã QR Check-in',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    Navigator.pop(dialogCtx);
                    showAmenityQrCodeDialog(
                      context: context,
                      booking: booking,
                      amenityName: amenity.name,
                      bookingCode: bookingCode,
                      timeSlot: slot,
                    );
                  },
                ),
              ),
              if (booking.hasFee) ...[
                AppSpacing.h12,
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.r12,
                      ),
                    ),
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text(
                      'Xem Biên Nhận Điện Tử',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      Navigator.pop(dialogCtx);
                      showAmenityReceiptBottomSheet(
                        context: context,
                        booking: booking,
                        fallbackAmenityName: amenity.name,
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Đóng'),
          ),
        ],
      );
    },
  );
}
