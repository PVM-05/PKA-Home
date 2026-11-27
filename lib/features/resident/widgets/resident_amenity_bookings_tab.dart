import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:vivona/core/theme/app_theme.dart';
import 'package:vivona/core/theme/app_typography.dart';
import 'package:vivona/core/utils/error_formatter.dart';
import 'package:vivona/core/widgets/app_error_card.dart';
import 'package:vivona/core/widgets/app_skeleton_shimmer.dart';
import 'package:vivona/core/widgets/app_snack_bar.dart';
import 'package:vivona/core/widgets/unified_payment_sheet.dart';
import 'package:vivona/data/models/amenity_booking_model.dart';
import 'package:vivona/data/models/building_amenity_model.dart';
import 'package:vivona/data/providers/amenity_booking_provider.dart';
import 'package:vivona/data/services/payment_service.dart';
import 'package:vivona/features/resident/widgets/amenity_qr_code_dialog.dart';
import 'package:vivona/features/resident/widgets/amenity_receipt_bottom_sheet.dart';
import 'package:vivona/features/resident/widgets/reschedule_booking_bottom_sheet.dart';

class ResidentAmenityBookingsTab extends ConsumerWidget {
  final BuildingAmenityModel amenity;
  final DateTime? activeDate;

  const ResidentAmenityBookingsTab({
    super.key,
    required this.amenity,
    this.activeDate,
  });

  void _confirmCancelBooking(
    BuildContext context,
    WidgetRef ref,
    AmenityBookingModel booking,
  ) {
    final fullDateFormat = DateFormat('dd/MM/yyyy');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hủy Lịch Đã Đặt'),
        content: Text(
          'Bạn có chắc muốn hủy lịch tiện ích ${booking.amenityName ?? amenity.name} vào ngày ${fullDateFormat.format(booking.bookingDate)} khung giờ ${booking.timeSlot} không?\n\n${booking.isConfirmed ? 'Chỗ này sẽ tự động được nhường cho người tiếp theo trong danh sách chờ.' : 'Bạn sẽ được rút khỏi danh sách chờ của khung giờ này.'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Không'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref
                    .read(amenityBookingRepositoryProvider)
                    .cancelBooking(booking.id);
                ref.invalidate(
                  amenityBookingsForDateProvider(
                    AmenityDateQuery(
                      amenityId: booking.amenityId,
                      date: booking.bookingDate,
                    ),
                  ),
                );
                ref.invalidate(myAmenityBookingsProvider);
                if (context.mounted) {
                  AppSnackBar.showSuccess(context, 'Đã hủy lịch đặt thành công');
                }
              } catch (e) {
                if (context.mounted) {
                  AppSnackBar.showError(context, formatErrorMessage(e));
                }
              }
            },
            child: const Text('Hủy lịch'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myBookingsAsync = ref.watch(myAmenityBookingsProvider);
    final fullDateFormat = DateFormat('dd/MM/yyyy');
    final currencyFormat = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: 'đ',
      decimalDigits: 0,
    );

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(myAmenityBookingsProvider),
      child: myBookingsAsync.when(
        data: (bookings) {
          if (bookings.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 56,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Chưa có lịch đặt tiện ích nào',
                    style: context.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              final b = bookings[index];

              Color statusColor = AppStatusColors.paid;
              String statusLabel = 'Đã xác nhận';
              if (b.isPendingPayment) {
                statusColor = AppStatusColors.pendingConfirmation;
                statusLabel = 'Chờ thanh toán';
              } else if (b.isWaitlist) {
                statusColor = Colors.purple;
                statusLabel = 'Danh sách chờ';
              } else if (b.isCancelled) {
                statusColor = Colors.grey;
                statusLabel = 'Đã hủy';
              } else if (b.isCompleted) {
                statusColor = AppTheme.primary;
                statusLabel = 'Đã hoàn thành';
              } else if (b.isNoShow) {
                statusColor = AppTheme.error;
                statusLabel = 'Vắng mặt';
              }

              final canCancel =
                  (b.isConfirmed || b.isWaitlist || b.isPendingPayment);
              final today = DateTime(
                DateTime.now().year,
                DateTime.now().month,
                DateTime.now().day,
              );
              final bookingDateOnly = DateTime(
                b.bookingDate.year,
                b.bookingDate.month,
                b.bookingDate.day,
              );
              final canReschedule =
                  (b.isConfirmed || b.isWaitlist || b.isPendingPayment) &&
                  !bookingDateOnly.isBefore(today);

              final colorScheme = Theme.of(context).colorScheme;
              final successColor = AppTheme.getSemanticSuccess(context);
              final warningColor = AppTheme.getSemanticWarning(context);
              final errorColor = AppTheme.getSemanticError(context);
              final depositLabel = switch (b.depositStatus) {
                'pending' => 'Chờ nộp cọc',
                'received' => b.isCheckedIn ? 'Chờ nghiệm thu hoàn cọc' : 'Đã nộp cọc',
                'refunded' => 'Đã hoàn cọc',
                'forfeited' => 'Khấu trừ cọc',
                _ => 'Chưa phát sinh',
              };

              return Card(
                elevation: 0,
                color: colorScheme.surface,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              b.amenityName ?? amenity.name,
                              style: context.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              statusLabel,
                              style: context.labelSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.calendar_month_outlined,
                                size: 16,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Ngày: ${fullDateFormat.format(b.bookingDate)}',
                                style: context.bodySmall,
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.schedule,
                                size: 16,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                b.timeSlot,
                                style: context.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (b.guestsCount > 1 ||
                          b.feeAmount > 0 ||
                          b.depositAmount > 0) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            if (b.guestsCount > 1)
                              Chip(
                                label: Text(
                                  '${b.guestsCount} người',
                                  style: context.labelSmall,
                                ),
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ),
                            if (b.feeAmount > 0)
                              Chip(
                                label: Text(
                                  'Phí: ${currencyFormat.format(b.feeAmount)}',
                                  style: context.labelSmall,
                                ),
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ),
                            if (b.isCheckedIn)
                              Chip(
                                avatar: Icon(
                                  Icons.check_circle_outline,
                                  size: 14,
                                  color: successColor,
                                ),
                                label: Text(
                                  'Đã vào cửa',
                                  style: context.labelSmall?.copyWith(
                                    color: successColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                backgroundColor: successColor.withValues(alpha: 0.14),
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ),
                            if (b.depositAmount > 0) ...[
                              if (b.depositStatus == 'refunded')
                                Chip(
                                  avatar: Icon(
                                    Icons.verified_outlined,
                                    size: 14,
                                    color: successColor,
                                  ),
                                  label: Text(
                                    'Đã hoàn cọc 100% (${currencyFormat.format(b.refundAmount > 0 ? b.refundAmount : b.depositAmount)})',
                                    style: context.labelSmall?.copyWith(
                                      color: successColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  backgroundColor: successColor.withValues(alpha: 0.14),
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                )
                              else if (b.depositStatus == 'forfeited')
                                Chip(
                                  avatar: Icon(
                                    Icons.warning_amber_rounded,
                                    size: 14,
                                    color: errorColor,
                                  ),
                                  label: Text(
                                    'Khấu trừ cọc: ${currencyFormat.format(b.forfeitedAmount)}',
                                    style: context.labelSmall?.copyWith(
                                      color: errorColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  backgroundColor: errorColor.withValues(alpha: 0.14),
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                )
                              else if (b.depositStatus == 'received')
                                Chip(
                                  label: Text(
                                    'Cọc: ${currencyFormat.format(b.depositAmount)} ($depositLabel)',
                                    style: context.labelSmall?.copyWith(
                                      color: b.isCheckedIn ? colorScheme.primary : warningColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  backgroundColor: (b.isCheckedIn ? colorScheme.primary : warningColor)
                                      .withValues(alpha: 0.14),
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                )
                              else
                                Chip(
                                  label: Text(
                                    'Cọc: ${currencyFormat.format(b.depositAmount)} ($depositLabel)',
                                    style: context.labelSmall,
                                  ),
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                ),
                            ],
                          ],
                        ),
                      ],
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.end,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (b.isPendingPayment) ...[
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                foregroundColor: Colors.white,
                                visualDensity: VisualDensity.compact,
                              ),
                              icon: const Icon(Icons.payment, size: 16),
                              label: Text(
                                b.transactionCode != null
                                    ? 'Thanh toán lại'
                                    : 'Thanh toán ngay',
                              ),
                              onPressed: () async {
                                final totalFee = b.feeAmount + b.depositAmount;
                                final feeItems = <Map<String, dynamic>>[];
                                if (b.feeAmount > 0) {
                                  feeItems.add({
                                    'name':
                                        '${b.amenityName ?? amenity.name} (${b.guestsCount} người)',
                                    'amount': b.feeAmount,
                                  });
                                }
                                if (b.depositAmount > 0) {
                                  feeItems.add({
                                    'name': 'Tiền đặt cọc',
                                    'amount': b.depositAmount,
                                  });
                                }

                                final codeSuffix = b.id.length >= 4
                                    ? b.id.substring(0, 4).toUpperCase()
                                    : b.id.toUpperCase();
                                final paymentRes = await showUnifiedPaymentSheet(
                                  context: context,
                                  type: PaymentType.service,
                                  referenceId: b.id,
                                  title:
                                      'Thanh toán ${b.amenityName ?? amenity.name}',
                                  referenceCode:
                                      'BK${DateFormat('yyyyMMdd').format(b.bookingDate)}$codeSuffix',
                                  amount: totalFee,
                                  feeBreakdown: feeItems,
                                );

                                if (paymentRes != null &&
                                    paymentRes.success &&
                                    context.mounted) {
                                  ref.invalidate(myAmenityBookingsProvider);
                                  if (activeDate != null) {
                                    ref.invalidate(
                                      amenityBookingsForDateProvider(
                                        AmenityDateQuery(
                                          amenityId: amenity.id,
                                          date: activeDate!,
                                        ),
                                      ),
                                    );
                                  }
                                  AppSnackBar.showSuccess(
                                    context,
                                    'Yêu cầu thanh toán đã được tiếp nhận thành công',
                                  );
                                }
                              },
                            ),
                            if (b.transactionCode != null ||
                                b.paymentStatus == 'PENDING')
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.getSemanticWarning(context),
                                  side: BorderSide(
                                    color: AppTheme.getSemanticWarning(context).withValues(alpha: 0.6),
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                                icon: const Icon(
                                  Icons.receipt_outlined,
                                  size: 16,
                                ),
                                label: const Text('Xác nhận chuyển khoản'),
                                onPressed: () => showAmenityReceiptBottomSheet(
                                  context: context,
                                  booking: b,
                                  fallbackAmenityName: amenity.name,
                                ),
                              ),
                          ],
                          if (b.isConfirmed && b.hasFee)
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.success,
                                side: const BorderSide(color: AppTheme.success),
                                visualDensity: VisualDensity.compact,
                              ),
                              icon: const Icon(
                                Icons.receipt_long_outlined,
                                size: 16,
                              ),
                              label: const Text('Biên nhận điện tử'),
                              onPressed: () => showAmenityReceiptBottomSheet(
                                context: context,
                                booking: b,
                                fallbackAmenityName: amenity.name,
                              ),
                            ),
                          if (b.isConfirmed || b.isCheckedIn)
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.primary,
                                visualDensity: VisualDensity.compact,
                              ),
                              icon: const Icon(
                                Icons.qr_code_2_rounded,
                                size: 16,
                              ),
                              label: const Text('Mã QR'),
                              onPressed: () {
                                final bCode =
                                    'BK${b.id.length >= 8 ? b.id.substring(0, 8).toUpperCase() : b.id.toUpperCase()}';
                                showAmenityQrCodeDialog(
                                  context: context,
                                  booking: b,
                                  amenityName: amenity.name,
                                  bookingCode: bCode,
                                  timeSlot: b.timeSlot,
                                );
                              },
                            ),
                          if (canReschedule)
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.primary,
                                visualDensity: VisualDensity.compact,
                              ),
                              icon: const Icon(Icons.edit_calendar, size: 16),
                              label: const Text('Đổi lịch'),
                              onPressed: () => showRescheduleBookingBottomSheet(
                                context: context,
                                booking: b,
                                amenity: amenity,
                              ),
                            ),
                          if (canCancel)
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.error,
                                visualDensity: VisualDensity.compact,
                              ),
                              icon: const Icon(Icons.cancel_outlined, size: 16),
                              label: const Text('Hủy lịch này'),
                              onPressed: () =>
                                  _confirmCancelBooking(context, ref, b),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => Padding(
          padding: const EdgeInsets.all(16),
          child: AppSkeletonShimmer.cardList(count: 3),
        ),
        error: (e, _) => Center(child: AppErrorCard(error: e)),
      ),
    );
  }
}
