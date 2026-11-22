import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/amenity_slot_helper.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../core/utils/network_error_handler.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_card.dart';
import '../../../core/widgets/app_skeleton_shimmer.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/unified_payment_sheet.dart';
import '../../../data/models/amenity_booking_model.dart';
import '../../../data/models/building_amenity_model.dart';
import '../../../data/providers/amenity_booking_provider.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/vehicle_provider.dart';
import '../../../data/services/payment_service.dart';
import '../widgets/amenity/amenity_booking_dialogs.dart';
import '../widgets/amenity/amenity_info_and_date_strip.dart';
import '../widgets/amenity/amenity_slot_card.dart';
import '../widgets/amenity_receipt_bottom_sheet.dart';
import '../widgets/resident_amenity_bookings_tab.dart';

class AmenityBookingScreen extends ConsumerStatefulWidget {
  final BuildingAmenityModel amenity;

  const AmenityBookingScreen({super.key, required this.amenity});

  @override
  ConsumerState<AmenityBookingScreen> createState() =>
      _AmenityBookingScreenState();
}

class _AmenityBookingScreenState extends ConsumerState<AmenityBookingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late DateTime _selectedDate;
  String? _selectedSlot;
  bool _isSubmitting = false;
  int _guestsCount = 1;
  bool _isWaitlistSelection = false;

  final DateFormat _dayOfWeekFormat = DateFormat('EEE', 'vi');
  final DateFormat _dateDisplayFormat = DateFormat('dd/MM');
  final DateFormat _fullDateFormat = DateFormat('dd/MM/yyyy');
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: 'đ',
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<DateTime> _getNext7Days() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return List.generate(7, (i) => today.add(Duration(days: i)));
  }

  List<String> _getSlots() {
    return AmenitySlotHelper.generateSlots(
      widget.amenity.openHours,
      widget.amenity.slotDurationMinutes,
    );
  }

  Future<void> _confirmAndBookSlot({
    required String slot,
    required String apartmentId,
    required String userId,
    required bool isWaitlist,
    required int guestsCount,
  }) async {
    if (_isSubmitting) return;

    final confirmResult = await showAmenityConfirmBookingDialog(
      context: context,
      amenity: widget.amenity,
      selectedDate: _selectedDate,
      slot: slot,
      isWaitlist: isWaitlist,
      initialGuestsCount: guestsCount,
      fullDateFormat: _fullDateFormat,
      currencyFormat: _currencyFormat,
    );

    if (!confirmResult.confirmed || !mounted) return;
    final dialogGuestsCount = confirmResult.guestsCount;

    setState(() => _isSubmitting = true);

    try {
      final result = await ref
          .read(amenityBookingRepositoryProvider)
          .createBooking(
            amenityId: widget.amenity.id,
            apartmentId: apartmentId,
            userId: userId,
            date: _selectedDate,
            timeSlot: slot,
            guestsCount: dialogGuestsCount,
            allowWaitlist: isWaitlist,
          );

      ref.invalidate(
        amenityBookingsForDateProvider(
          AmenityDateQuery(amenityId: widget.amenity.id, date: _selectedDate),
        ),
      );
      ref.invalidate(myAmenityBookingsProvider);

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _selectedSlot = null;
        });
      }

      final totalFee =
          (widget.amenity.feeAmount * dialogGuestsCount) +
          (widget.amenity.requiresDeposit ? widget.amenity.depositAmount : 0);

      if (!isWaitlist && totalFee > 0 && mounted) {
        final feeItems = <Map<String, dynamic>>[
          if (widget.amenity.feeAmount > 0)
            {
              'name': '${widget.amenity.name} ($dialogGuestsCount người)',
              'amount': widget.amenity.feeAmount * dialogGuestsCount,
            },
          if (widget.amenity.requiresDeposit &&
              widget.amenity.depositAmount > 0)
            {
              'name': 'Tiền đặt cọc',
              'amount': widget.amenity.depositAmount,
            },
        ];

        final codeSuffix = result.id.length >= 4
            ? result.id.substring(0, 4).toUpperCase()
            : result.id.toUpperCase();
        final paymentRes = await showUnifiedPaymentSheet(
          context: context,
          type: PaymentType.service,
          referenceId: result.id,
          title: 'Đăng ký ${widget.amenity.name}',
          referenceCode:
              'BK${DateFormat('yyyyMMdd').format(_selectedDate)}$codeSuffix',
          amount: totalFee,
          feeBreakdown: feeItems,
        );

        if (paymentRes != null && paymentRes.success && mounted) {
          ref.invalidate(myAmenityBookingsProvider);
          final updatedBooking = AmenityBookingModel(
            id: result.id,
            amenityId: result.amenityId,
            apartmentId: result.apartmentId,
            bookedBy: result.bookedBy,
            bookingDate: result.bookingDate,
            timeSlot: result.timeSlot,
            status: (paymentRes.isPending || paymentRes.status == 'PENDING')
                ? 'pending_payment'
                : 'confirmed',
            guestsCount: result.guestsCount,
            feeAmount: result.feeAmount,
            depositAmount: result.depositAmount,
            depositStatus: result.depositStatus,
            createdAt: result.createdAt,
            amenityName: widget.amenity.name,
            transactionCode: paymentRes.transactionCode,
            paymentStatus: paymentRes.status,
            paymentMethod: 'bank_transfer',
            paidAt: paymentRes.paidAt,
          );

          if (paymentRes.isPending || paymentRes.status == 'PENDING') {
            AppSnackBar.showInfo(
              context,
              'Đã gửi thông báo thanh toán (${paymentRes.transactionCode}). Vui lòng chờ BQL xác nhận.',
              action: SnackBarAction(
                label: 'Biên nhận',
                textColor: Theme.of(context).colorScheme.onPrimary,
                onPressed: () => showAmenityReceiptBottomSheet(
                  context: context,
                  booking: updatedBooking,
                  fallbackAmenityName: widget.amenity.name,
                ),
              ),
            );
          } else {
            await showAmenityBookingSuccessDialog(
              context: context,
              amenity: widget.amenity,
              booking: updatedBooking,
              selectedDate: _selectedDate,
              slot: slot,
              fullDateFormat: _fullDateFormat,
            );
          }
          return;
        }

        if (mounted) {
          AppSnackBar.showInfo(
            context,
            'Lịch đặt đã được ghi nhận ở trạng thái Chờ thanh toán. Vui lòng liên hệ Ban Quản Lý để hoàn tất thanh toán trước giờ sử dụng.',
          );
          return;
        }
      }

      if (mounted) {
        AppSnackBar.showSuccess(
          context,
          result.isWaitlist
              ? 'Đã thêm vào danh sách chờ thành công!'
              : 'Đặt lịch tiện ích thành công!',
        );
      }
    } catch (e) {
      ref.invalidate(
        amenityBookingsForDateProvider(
          AmenityDateQuery(amenityId: widget.amenity.id, date: _selectedDate),
        ),
      );
      ref.invalidate(myAmenityBookingsProvider);

      if (mounted) {
        AppSnackBar.showError(context, NetworkErrorHandler.getMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _confirmCancelBooking(AmenityBookingModel booking) async {
    final confirmed = await showAmenityCancelConfirmDialog(
      context: context,
      booking: booking,
      fallbackAmenityName: widget.amenity.name,
      fullDateFormat: _fullDateFormat,
    );
    if (!confirmed || !mounted) return;

    try {
      await ref.read(amenityBookingRepositoryProvider).cancelBooking(booking.id);
      ref.invalidate(
        amenityBookingsForDateProvider(
          AmenityDateQuery(
            amenityId: booking.amenityId,
            date: booking.bookingDate,
          ),
        ),
      );
      ref.invalidate(myAmenityBookingsProvider);

      if (mounted) {
        setState(() {
          if (_selectedSlot == booking.timeSlot) {
            _isWaitlistSelection = false;
          }
        });
        AppSnackBar.showSuccess(
          context,
          'Đã hủy lịch thành công. Khung giờ đã được giải phóng để bạn có thể đặt lại.',
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, formatErrorMessage(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final user = ref.watch(authProvider).valueOrNull;
    final aptIdAsync = ref.watch(residentApartmentIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Đặt Lịch ${widget.amenity.name}'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: colorScheme.primary,
          indicatorColor: colorScheme.primary,
          unselectedLabelColor: colorScheme.onSurfaceVariant,
          tabs: const [
            Tab(
              icon: Icon(Icons.event_available_outlined),
              text: 'Chọn Khung Giờ',
            ),
            Tab(icon: Icon(Icons.bookmark_outline), text: 'Lịch Đã Đặt'),
          ],
        ),
      ),
      body: aptIdAsync.when(
        data: (apartmentId) {
          if (apartmentId == null || user == null) {
            return const Center(
              child: Padding(
                padding: AppSpacing.p24,
                child: AppEmptyState(
                  icon: Icons.apartment_outlined,
                  title: 'Chưa liên kết căn hộ',
                  description:
                      'Bạn cần được Ban Quản Lý phê duyệt liên kết căn hộ trước khi đặt lịch tiện ích.',
                ),
              ),
            );
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildBookingTab(apartmentId, user.id),
              ResidentAmenityBookingsTab(
                amenity: widget.amenity,
                activeDate: _selectedDate,
              ),
            ],
          );
        },
        loading: () => ListView(
          padding: AppSpacing.p16,
          children: [AppSkeletonShimmer.cardList(count: 3, itemHeight: 100)],
        ),
        error: (e, _) => Center(
          child: AppErrorCard(
            error: e,
            onRetry: () => ref.invalidate(residentApartmentIdProvider),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // Tab 1: Chọn Khung Giờ Đặt Lịch
  // ===========================================================================
  Widget _buildBookingTab(String apartmentId, String userId) {
    final query = AmenityDateQuery(
      amenityId: widget.amenity.id,
      date: _selectedDate,
    );
    final bookingsAsync = ref.watch(amenityBookingsForDateProvider(query));
    final maintenanceAsync = ref.watch(
      amenityMaintenanceForDateProvider(query),
    );
    final slots = _getSlots();

    return Column(
      children: [
        AmenityInfoHeader(
          amenity: widget.amenity,
          currencyFormat: _currencyFormat,
        ),
        const Divider(height: 1),
        AmenityDateStrip(
          dates: _getNext7Days(),
          selectedDate: _selectedDate,
          dayOfWeekFormat: _dayOfWeekFormat,
          dateDisplayFormat: _dateDisplayFormat,
          onDateSelected: (date) {
            setState(() {
              _selectedDate = date;
              _selectedSlot = null;
            });
          },
        ),
        const Divider(height: 1),
        Expanded(
          child: bookingsAsync.when(
            data: (existingBookings) {
              final maintenanceList = maintenanceAsync.valueOrNull ?? [];

              return ListView.builder(
                padding: AppSpacing.p16,
                itemCount: slots.length,
                itemBuilder: (context, index) {
                  final slot = slots[index];
                  final isPast = AmenitySlotHelper.isSlotInPast(
                    _selectedDate,
                    slot,
                  );
                  final isMaintenance = AmenitySlotHelper.isSlotInMaintenance(
                    _selectedDate,
                    slot,
                    maintenanceList,
                  );

                  final confirmedList = existingBookings
                      .where((b) => b.timeSlot == slot && b.isConfirmed)
                      .toList();
                  final confirmedGuests = widget.amenity.isShared
                      ? confirmedList.fold<int>(
                          0,
                          (sum, b) => sum + b.guestsCount,
                        )
                      : confirmedList.length;

                  final availableCapacity =
                      widget.amenity.maxCapacity - confirmedGuests;
                  final isFullyBooked = availableCapacity <= 0;
                  final isSelected = _selectedSlot == slot;
                  final isWaitlistChoice =
                      isFullyBooked && !isPast && !isMaintenance;

                  final myBookingInSlot = existingBookings.where((b) {
                    final isMyId =
                        (b.bookedBy != null && b.bookedBy == userId) ||
                        b.isMyBooking;
                    return b.timeSlot == slot &&
                        isMyId &&
                        (b.isConfirmed || b.isPendingPayment || b.isWaitlist);
                  }).firstOrNull;

                  return AmenitySlotCard(
                    slot: slot,
                    isPast: isPast,
                    isMaintenance: isMaintenance,
                    isFullyBooked: isFullyBooked,
                    isSelected: isSelected,
                    availableCapacity: availableCapacity,
                    myBookingInSlot: myBookingInSlot,
                    onTap: (isPast || isMaintenance)
                        ? null
                        : () {
                            setState(() {
                              _selectedSlot = slot;
                              _isWaitlistSelection =
                                  isWaitlistChoice && (myBookingInSlot == null);
                            });
                          },
                    onCancelMyBooking: myBookingInSlot != null
                        ? () => _confirmCancelBooking(myBookingInSlot)
                        : null,
                  );
                },
              );
            },
            loading: () => ListView(
              padding: AppSpacing.p16,
              children: [
                AppSkeletonShimmer.cardList(count: 4, itemHeight: 72),
              ],
            ),
            error: (e, _) => Center(
              child: AppErrorCard(
                error: e,
                onRetry: () =>
                    ref.invalidate(amenityBookingsForDateProvider(query)),
              ),
            ),
          ),
        ),
        _buildBottomActionBar(
          context: context,
          bookingsAsync: bookingsAsync,
          apartmentId: apartmentId,
          userId: userId,
        ),
      ],
    );
  }

  Widget _buildBottomActionBar({
    required BuildContext context,
    required AsyncValue<List<AmenityBookingModel>> bookingsAsync,
    required String apartmentId,
    required String userId,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final warningColor = AppTheme.getSemanticWarning(context);

    final allBookings = bookingsAsync.valueOrNull ?? [];
    final mySelectedBooking = allBookings.where((b) {
      final isMyId =
          (b.bookedBy != null && b.bookedBy == userId) || b.isMyBooking;
      return b.timeSlot == _selectedSlot &&
          isMyId &&
          (b.isConfirmed || b.isPendingPayment || b.isWaitlist);
    }).firstOrNull;

    return Container(
      padding: AppSpacing.p16,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: isDark ? 0.25 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (mySelectedBooking != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: warningColor.withValues(alpha: isDark ? 0.14 : 0.10),
                  borderRadius: AppRadius.r12,
                  border: Border.all(
                    color: warningColor.withValues(alpha: isDark ? 0.45 : 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: warningColor),
                    AppSpacing.w8,
                    Expanded(
                      child: Text(
                        'Bạn đã có lịch (${mySelectedBooking.statusDisplayName}) ở khung giờ này. Để đặt lại hoặc thay đổi, vui lòng hủy lịch hiện tại trước.',
                        style: context.labelSmall?.copyWith(
                          color: warningColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.textError,
                    foregroundColor: colorScheme.onError,
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.r12),
                  ),
                  icon: const Icon(Icons.cancel_outlined),
                  label: Text(
                    'Hủy lịch khung giờ $_selectedSlot',
                    style: context.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onError,
                    ),
                  ),
                  onPressed: () => _confirmCancelBooking(mySelectedBooking),
                ),
              ),
            ] else ...[
              if (widget.amenity.isShared &&
                  _selectedSlot != null &&
                  !_isWaitlistSelection) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Số người tham gia:',
                      style: context.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Row(
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
                          onPressed: _guestsCount > 1
                              ? () => setState(() => _guestsCount--)
                              : null,
                        ),
                        Text(
                          '$_guestsCount',
                          style: context.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        IconButton(
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          tooltip: 'Tăng số người',
                          icon: const Icon(Icons.add_circle_outline, size: 22),
                          onPressed: _guestsCount < widget.amenity.maxCapacity
                              ? () => setState(() => _guestsCount++)
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
                AppSpacing.h8,
              ],
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isWaitlistSelection
                        ? AppTheme.secondary
                        : AppTheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.r12),
                  ),
                  icon: _isSubmitting
                      ? const SizedBox.shrink()
                      : Icon(
                          _isWaitlistSelection
                              ? Icons.hourglass_top_outlined
                              : Icons.check_circle_outline,
                        ),
                  label: _isSubmitting
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: colorScheme.onPrimary,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          _selectedSlot == null
                              ? 'Vui lòng chọn 1 khung giờ'
                              : (_isWaitlistSelection
                                    ? 'Vào danh sách chờ khung giờ $_selectedSlot'
                                    : 'Đặt lịch khung giờ $_selectedSlot'),
                          style: context.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: _selectedSlot == null
                                ? null
                                : colorScheme.onPrimary,
                          ),
                        ),
                  onPressed: _selectedSlot == null || _isSubmitting
                      ? null
                      : () => _confirmAndBookSlot(
                          slot: _selectedSlot!,
                          apartmentId: apartmentId,
                          userId: userId,
                          isWaitlist: _isWaitlistSelection,
                          guestsCount: _guestsCount,
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
