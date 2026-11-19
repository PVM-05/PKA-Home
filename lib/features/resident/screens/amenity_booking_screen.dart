import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../core/utils/amenity_slot_helper.dart';
import '../../../core/widgets/app_error_card.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/unified_payment_sheet.dart';
import '../../../data/models/building_amenity_model.dart';
import '../../../data/models/amenity_booking_model.dart';
import '../../../data/providers/amenity_booking_provider.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/vehicle_provider.dart';
import '../../../data/services/payment_service.dart';
import '../../../core/utils/network_error_handler.dart';
import '../widgets/amenity_qr_code_dialog.dart';
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

  void _confirmAndBookSlot({
    required String slot,
    required String apartmentId,
    required String userId,
    required bool isWaitlist,
    required int guestsCount,
  }) {
    int dialogGuestsCount = guestsCount;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
            isWaitlist ? 'Gia Nhập Danh Sách Chờ' : 'Xác Nhận Đặt Lịch',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tiện ích: ${widget.amenity.name}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text('Ngày sử dụng: ${_fullDateFormat.format(_selectedDate)}'),
                const SizedBox(height: 6),
                Text(
                  'Khung giờ: $slot',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                if (widget.amenity.isShared) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Số người tham gia:'),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.remove_circle_outline,
                              size: 20,
                            ),
                            onPressed: dialogGuestsCount > 1
                                ? () =>
                                      setDialogState(() => dialogGuestsCount--)
                                : null,
                          ),
                          Text(
                            '$dialogGuestsCount',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.add_circle_outline,
                              size: 20,
                            ),
                            onPressed:
                                dialogGuestsCount < widget.amenity.maxCapacity
                                ? () =>
                                      setDialogState(() => dialogGuestsCount++)
                                : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
                if (widget.amenity.feeAmount > 0) ...[
                  Text(
                    'Phí sử dụng: ${_currencyFormat.format(widget.amenity.feeAmount * dialogGuestsCount)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                ],
                if (widget.amenity.requiresDeposit &&
                    widget.amenity.depositAmount > 0) ...[
                  Text(
                    'Tiền đặt cọc: ${_currencyFormat.format(widget.amenity.depositAmount)}',
                    style: const TextStyle(
                      color: AppTheme.warning,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isWaitlist
                        ? Colors.purple.shade50
                        : Colors.amber.shade50,
                    border: Border.all(
                      color: isWaitlist
                          ? Colors.purple.shade200
                          : Colors.amber.shade300,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isWaitlist
                            ? Icons.hourglass_top_outlined
                            : Icons.info_outline,
                        size: 18,
                        color: isWaitlist
                            ? Colors.purple
                            : Colors.amber.shade800,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isWaitlist
                              ? 'Khung giờ này đã hết chỗ. Khi có người hủy lịch, hệ thống sẽ tự động xác nhận cho bạn và gửi thông báo.'
                              : 'Vui lòng có mặt đúng giờ. Nếu có đặt cọc, vui lòng hoàn tất tại quầy lễ tân/BQL.',
                          style: ctx.labelSmall?.copyWith(
                            color: isWaitlist
                                ? Colors.purple.shade900
                                : Colors.black87,
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
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy bỏ'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isWaitlist ? Colors.purple : AppTheme.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: _isSubmitting
                  ? null
                  : () async {
                      if (_isSubmitting) return;
                      setState(() => _isSubmitting = true);
                      Navigator.pop(ctx);

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
                            AmenityDateQuery(
                              amenityId: widget.amenity.id,
                              date: _selectedDate,
                            ),
                          ),
                        );
                        ref.invalidate(myAmenityBookingsProvider);

                        setState(() {
                          _isSubmitting = false;
                          _selectedSlot = null;
                        });

                        final totalFee =
                            (widget.amenity.feeAmount * dialogGuestsCount) +
                            (widget.amenity.requiresDeposit
                                ? widget.amenity.depositAmount
                                : 0);

                        if (!isWaitlist && totalFee > 0 && mounted) {
                          final feeItems = <Map<String, dynamic>>[];
                          if (widget.amenity.feeAmount > 0) {
                            feeItems.add({
                              'name':
                                  '${widget.amenity.name} ($dialogGuestsCount người)',
                              'amount':
                                  widget.amenity.feeAmount * dialogGuestsCount,
                            });
                          }
                          if (widget.amenity.requiresDeposit &&
                              widget.amenity.depositAmount > 0) {
                            feeItems.add({
                              'name': 'Tiền đặt cọc',
                              'amount': widget.amenity.depositAmount,
                            });
                          }

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

                          if (paymentRes != null &&
                              paymentRes.success &&
                              mounted) {
                            ref.invalidate(myAmenityBookingsProvider);
                            final updatedBooking = AmenityBookingModel(
                              id: result.id,
                              amenityId: result.amenityId,
                              apartmentId: result.apartmentId,
                              bookedBy: result.bookedBy,
                              bookingDate: result.bookingDate,
                              timeSlot: result.timeSlot,
                              status:
                                  (paymentRes.isPending ||
                                      paymentRes.status == 'PENDING')
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

                            if (paymentRes.isPending ||
                                paymentRes.status == 'PENDING') {
                              AppSnackBar.showInfo(
                                context,
                                'Đã gửi thông báo thanh toán (${paymentRes.transactionCode}). Vui lòng chờ BQL xác nhận.',
                                action: SnackBarAction(
                                  label: 'Biên nhận',
                                  textColor: Colors.white,
                                  onPressed: () =>
                                      showAmenityReceiptBottomSheet(
                                        context: context,
                                        booking: updatedBooking,
                                        fallbackAmenityName:
                                            widget.amenity.name,
                                      ),
                                ),
                              );
                            } else {
                              _showBookingSuccessDialog(
                                context,
                                updatedBooking,
                                slot,
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
                        // Tự động làm mới slot khi lỗi (đặc biệt khi có người vừa đặt trước 23505)
                        ref.invalidate(
                          amenityBookingsForDateProvider(
                            AmenityDateQuery(
                              amenityId: widget.amenity.id,
                              date: _selectedDate,
                            ),
                          ),
                        );
                        ref.invalidate(myAmenityBookingsProvider);

                        if (mounted) {
                          AppSnackBar.showError(
                            context,
                            NetworkErrorHandler.getMessage(e),
                          );
                        }
                      } finally {
                        if (mounted) {
                          setState(() => _isSubmitting = false);
                        }
                      }
                    },
              child: Text(
                isWaitlist ? 'Xác nhận vào hàng chờ' : 'Xác nhận đặt',
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmCancelBooking(AmenityBookingModel booking) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hủy Lịch Đã Đặt'),
        content: Text(
          'Bạn có chắc muốn hủy lịch tiện ích ${booking.amenityName ?? widget.amenity.name} vào ngày ${_fullDateFormat.format(booking.bookingDate)} khung giờ ${booking.timeSlot} không?\n\n${booking.isConfirmed ? 'Chỗ này sẽ tự động được nhường cho người tiếp theo trong danh sách chờ.' : 'Bạn sẽ được rút khỏi danh sách chờ của khung giờ này.'}',
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
            },
            child: const Text('Hủy lịch'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).valueOrNull;
    final aptIdAsync = ref.watch(residentApartmentIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Đặt Lịch ${widget.amenity.name}'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          indicatorColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
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
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  'Bạn cần được Ban Quản Lý phê duyệt liên kết căn hộ trước khi đặt lịch tiện ích.',
                  textAlign: TextAlign.center,
                  style: context.bodyMedium,
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: AppErrorCard(error: e)),
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
        // Thông tin tiện ích
        Container(
          width: double.infinity,
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.access_time,
                    size: 16,
                    color: AppTheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Thời gian mở cửa: ${widget.amenity.openHours ?? "06:00 - 22:00"} (${widget.amenity.slotDurationMinutes} phút/lượt)',
                      style: context.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    widget.amenity.isShared
                        ? Icons.groups_outlined
                        : Icons.lock_outline,
                    size: 16,
                    color: Colors.grey.shade700,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.amenity.isShared
                          ? 'Tiện ích dùng chung — Sức chứa: ${widget.amenity.maxCapacity} người/khung giờ'
                          : 'Tiện ích trọn gói — 1 căn hộ/khung giờ',
                      style: context.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              if (widget.amenity.feeAmount > 0 ||
                  widget.amenity.requiresDeposit) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.payments_outlined,
                      size: 16,
                      color: AppStatusColors.paid,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Phí: ${_currencyFormat.format(widget.amenity.feeAmount)}${widget.amenity.requiresDeposit ? ' • Cọc: ${_currencyFormat.format(widget.amenity.depositAmount)}' : ''}',
                        style: context.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppStatusColors.paid,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (widget.amenity.maxSlotsPerWeek > 0) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.event_repeat_rounded,
                      size: 16,
                      color: AppTheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Hạn mức: Tối đa ${widget.amenity.maxSlotsPerWeek} lượt/tuần / căn hộ',
                        style: context.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (widget.amenity.rulesAndRegulations != null &&
                  widget.amenity.rulesAndRegulations!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.rule_folder_outlined,
                        size: 16,
                        color: Colors.blue.shade700,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Quy định & Hoàn cọc:',
                              style: context.labelSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.amenity.rulesAndRegulations!,
                              style: context.labelSmall?.copyWith(
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),

        // Chọn ngày (7 ngày tiếp theo)
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: SizedBox(
            height: 84,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: 7,
              itemBuilder: (context, index) {
                final date = _getNext7Days()[index];
                final isSelected =
                    date.year == _selectedDate.year &&
                    date.month == _selectedDate.month &&
                    date.day == _selectedDate.day;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDate = date;
                      _selectedSlot = null;
                    });
                  },
                  child: Container(
                    width: 64,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primary
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primary
                            : Colors.grey.shade200,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          index == 0
                              ? 'Hôm nay'
                              : _dayOfWeekFormat.format(date),
                          style: context.labelSmall?.copyWith(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? Colors.white70
                                : Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _dateDisplayFormat.format(date),
                          style: context.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? Colors.white
                                : Colors.grey.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const Divider(height: 1),

        // Danh sách khung giờ
        Expanded(
          child: bookingsAsync.when(
            data: (existingBookings) {
              final maintenanceList = maintenanceAsync.valueOrNull ?? [];

              return ListView.builder(
                padding: const EdgeInsets.all(16),
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

                  // Đếm confirmed bookings
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

                  // Kiểm tra xem người dùng hiện tại đã có lịch ở khung giờ này chưa
                  final myBookingInSlot = existingBookings.where((b) {
                    final isMyId =
                        (b.bookedBy != null && b.bookedBy == userId) ||
                        b.isMyBooking;
                    return b.timeSlot == slot &&
                        isMyId &&
                        (b.isConfirmed || b.isPendingPayment || b.isWaitlist);
                  }).firstOrNull;

                  Color cardBg = Colors.white;
                  BorderSide cardBorder = BorderSide(
                    color: Colors.grey.shade200,
                  );
                  Widget trailingWidget = Icon(
                    isSelected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: isSelected ? AppTheme.primary : Colors.grey.shade400,
                  );
                  String subtitleText = 'Còn trống: $availableCapacity chỗ';
                  Color subtitleColor = AppStatusColors.paid;

                  if (myBookingInSlot != null) {
                    cardBg = isSelected
                        ? Colors.red.shade50
                        : Colors.green.shade50;
                    cardBorder = BorderSide(
                      color: isSelected
                          ? AppTheme.error
                          : Colors.green.shade400,
                      width: isSelected ? 2 : 1.5,
                    );
                    subtitleText =
                        'Lịch của bạn (${myBookingInSlot.statusDisplayName}) • Chạm để xem hoặc hủy lịch';
                    subtitleColor = isSelected
                        ? AppTheme.error
                        : Colors.green.shade800;
                    trailingWidget = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 14,
                                color: Colors.green.shade800,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                myBookingInSlot.statusDisplayName,
                                style: context.labelSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: 'Hủy lịch này',
                          icon: const Icon(
                            Icons.cancel_outlined,
                            color: AppTheme.error,
                            size: 20,
                          ),
                          onPressed: () =>
                              _confirmCancelBooking(myBookingInSlot),
                        ),
                      ],
                    );
                  } else if (isMaintenance) {
                    cardBg = Colors.orange.shade50;
                    cardBorder = BorderSide(color: Colors.orange.shade200);
                    subtitleText = 'Đang bảo trì / vệ sinh định kỳ';
                    subtitleColor = AppTheme.warning;
                    trailingWidget = Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Bảo trì',
                        style: context.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.deepOrange,
                        ),
                      ),
                    );
                  } else if (isPast) {
                    cardBg = Colors.grey.shade100;
                    cardBorder = BorderSide(color: Colors.grey.shade300);
                    subtitleText = 'Khung giờ này đã trôi qua';
                    subtitleColor = Colors.grey;
                    trailingWidget = Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Đã qua',
                        style: context.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    );
                  } else if (isFullyBooked) {
                    cardBg = isSelected
                        ? Colors.purple.shade50
                        : Colors.grey.shade50;
                    cardBorder = BorderSide(
                      color: isSelected ? Colors.purple : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    );
                    subtitleText = 'Đã hết chỗ — Bấm để tham gia Danh sách chờ';
                    subtitleColor = Colors.purple;
                    trailingWidget = Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.purple
                            : Colors.purple.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isSelected ? 'Chờ duyệt' : 'Vào Waitlist',
                        style: context.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? Colors.white
                              : Colors.purple.shade800,
                        ),
                      ),
                    );
                  } else if (isSelected) {
                    cardBg = AppTheme.primary.withValues(alpha: 0.08);
                    cardBorder = const BorderSide(
                      color: AppTheme.primary,
                      width: 2,
                    );
                  }

                  return Card(
                    elevation: 0,
                    color: cardBg,
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: cardBorder,
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      leading: Icon(
                        isMaintenance
                            ? Icons.build_circle_outlined
                            : (isPast
                                  ? Icons.history_outlined
                                  : (isFullyBooked
                                        ? Icons.hourglass_top_outlined
                                        : Icons.schedule_outlined)),
                        color: isMaintenance
                            ? Colors.orange
                            : (isPast
                                  ? Colors.grey
                                  : (isFullyBooked
                                        ? Colors.purple
                                        : (isSelected
                                              ? AppTheme.primary
                                              : Colors.grey.shade700))),
                      ),
                      title: Text(
                        slot,
                        style: context.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: (isPast || isMaintenance)
                              ? Colors.grey.shade600
                              : Colors.black87,
                        ),
                      ),
                      subtitle: Text(
                        subtitleText,
                        style: context.labelSmall?.copyWith(
                          color: subtitleColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      trailing: trailingWidget,
                      onTap: (isPast || isMaintenance)
                          ? null
                          : () {
                              setState(() {
                                _selectedSlot = slot;
                                _isWaitlistSelection =
                                    isWaitlistChoice &&
                                    (myBookingInSlot == null);
                              });
                            },
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: AppErrorCard(error: e)),
          ),
        ),

        // Nút bấm đặt lịch / hủy lịch / vào hàng chờ
        Builder(
          builder: (context) {
            final allBookings = bookingsAsync.valueOrNull ?? [];
            final mySelectedBooking = allBookings.where((b) {
              final isMyId =
                  (b.bookedBy != null && b.bookedBy == userId) || b.isMyBooking;
              return b.timeSlot == _selectedSlot &&
                  isMyId &&
                  (b.isConfirmed || b.isPendingPayment || b.isWaitlist);
            }).firstOrNull;

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
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
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 18,
                              color: Colors.orange.shade800,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Bạn đã có lịch (${mySelectedBooking.statusDisplayName}) ở khung giờ này. Để đặt lại hoặc thay đổi, vui lòng hủy lịch hiện tại trước.',
                                style: context.labelSmall?.copyWith(
                                  color: Colors.orange.shade900,
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
                            backgroundColor: AppTheme.error,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.cancel_outlined),
                          label: Text(
                            'Hủy lịch khung giờ $_selectedSlot',
                            style: context.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: () =>
                              _confirmCancelBooking(mySelectedBooking),
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
                                  icon: const Icon(
                                    Icons.remove_circle_outline,
                                    size: 20,
                                  ),
                                  onPressed: _guestsCount > 1
                                      ? () => setState(() => _guestsCount--)
                                      : null,
                                ),
                                Text(
                                  '$_guestsCount',
                                  style: context.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.add_circle_outline,
                                    size: 20,
                                  ),
                                  onPressed:
                                      _guestsCount < widget.amenity.maxCapacity
                                      ? () => setState(() => _guestsCount++)
                                      : null,
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isWaitlistSelection
                                ? Colors.purple
                                : AppTheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: _isSubmitting
                              ? const SizedBox.shrink()
                              : Icon(
                                  _isWaitlistSelection
                                      ? Icons.hourglass_top_outlined
                                      : Icons.check_circle_outline,
                                ),
                          label: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
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
          },
        ),
      ],
    );
  }

  void _showBookingSuccessDialog(
    BuildContext context,
    AmenityBookingModel booking,
    String slot,
  ) {
    final bookingCode =
        'BK${booking.id.length >= 8 ? booking.id.substring(0, 8).toUpperCase() : booking.id.toUpperCase()}';

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 56),
            const SizedBox(height: 12),
            Text(
              'Đặt Dịch Vụ Thành Công!',
              style: dialogCtx.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.amenity.name,
                style: dialogCtx.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                '${_fullDateFormat.format(_selectedDate)} • $slot',
                style: dialogCtx.bodySmall?.copyWith(color: AppTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Mã đặt chỗ:',
                      style: dialogCtx.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    Text(
                      bookingCode,
                      style: dialogCtx.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
                    amenityName: widget.amenity.name,
                    bookingCode: bookingCode,
                    timeSlot: slot,
                  );
                },
              ),
              if (booking.hasFee) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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
                      fallbackAmenityName: widget.amenity.name,
                    );
                  },
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }
}
