import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../core/utils/amenity_slot_helper.dart';
import '../../../core/widgets/app_error_card.dart';
import '../../../core/widgets/unified_payment_sheet.dart';
import '../../../data/models/building_amenity_model.dart';
import '../../../data/models/amenity_booking_model.dart';
import '../../../data/providers/amenity_booking_provider.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/vehicle_provider.dart';
import '../../../data/services/payment_service.dart';
import '../../../core/utils/network_error_handler.dart';

class AmenityBookingScreen extends ConsumerStatefulWidget {
  final BuildingAmenityModel amenity;

  const AmenityBookingScreen({super.key, required this.amenity});

  @override
  ConsumerState<AmenityBookingScreen> createState() => _AmenityBookingScreenState();
}

class _AmenityBookingScreenState extends ConsumerState<AmenityBookingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late DateTime _selectedDate;
  String? _selectedSlot;
  bool _isSubmitting = false;
  final int _guestsCount = 1;
  bool _isWaitlistSelection = false;

  final DateFormat _dayOfWeekFormat = DateFormat('EEE', 'vi');
  final DateFormat _dateDisplayFormat = DateFormat('dd/MM');
  final DateFormat _fullDateFormat = DateFormat('dd/MM/yyyy');
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

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
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isWaitlist ? 'Gia Nhập Danh Sách Chờ' : 'Xác Nhận Đặt Lịch'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tiện ích: ${widget.amenity.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('Ngày sử dụng: ${_fullDateFormat.format(_selectedDate)}'),
              const SizedBox(height: 6),
              Text('Khung giờ: $slot', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              if (widget.amenity.isShared) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Số người tham gia:'),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, size: 20),
                          onPressed: guestsCount > 1
                              ? () => setDialogState(() => guestsCount--)
                              : null,
                        ),
                        Text('$guestsCount', style: const TextStyle(fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, size: 20),
                          onPressed: guestsCount < widget.amenity.maxCapacity
                              ? () => setDialogState(() => guestsCount++)
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
                  'Phí sử dụng: ${_currencyFormat.format(widget.amenity.feeAmount * guestsCount)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
              ],
              if (widget.amenity.requiresDeposit && widget.amenity.depositAmount > 0) ...[
                Text(
                  'Tiền đặt cọc: ${_currencyFormat.format(widget.amenity.depositAmount)}',
                  style: const TextStyle(color: AppTheme.warning, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
              ],
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isWaitlist ? Colors.purple.shade50 : Colors.amber.shade50,
                  border: Border.all(
                    color: isWaitlist ? Colors.purple.shade200 : Colors.amber.shade300,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      isWaitlist ? Icons.hourglass_top_outlined : Icons.info_outline,
                      size: 18,
                      color: isWaitlist ? Colors.purple : Colors.amber.shade800,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isWaitlist
                            ? 'Khung giờ này đã hết chỗ. Khi có người hủy lịch, hệ thống sẽ tự động xác nhận cho bạn và gửi thông báo.'
                            : 'Vui lòng có mặt đúng giờ. Nếu có đặt cọc, vui lòng hoàn tất tại quầy lễ tân/BQL.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isWaitlist ? Colors.purple.shade900 : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
                        final result = await ref.read(amenityBookingRepositoryProvider).createBooking(
                              amenityId: widget.amenity.id,
                              apartmentId: apartmentId,
                              userId: userId,
                              date: _selectedDate,
                              timeSlot: slot,
                              guestsCount: guestsCount,
                              allowWaitlist: isWaitlist,
                            );

                        ref.invalidate(amenityBookingsForDateProvider(
                          AmenityDateQuery(amenityId: widget.amenity.id, date: _selectedDate),
                        ));
                        ref.invalidate(myAmenityBookingsProvider);

                        setState(() {
                          _isSubmitting = false;
                          _selectedSlot = null;
                        });

                        final totalFee = (widget.amenity.feeAmount * guestsCount) +
                            (widget.amenity.requiresDeposit ? widget.amenity.depositAmount : 0);

                        if (!isWaitlist && totalFee > 0 && mounted) {
                          final feeItems = <Map<String, dynamic>>[];
                          if (widget.amenity.feeAmount > 0) {
                            feeItems.add({
                              'name': '${widget.amenity.name} ($guestsCount người)',
                              'amount': widget.amenity.feeAmount * guestsCount,
                            });
                          }
                          if (widget.amenity.requiresDeposit && widget.amenity.depositAmount > 0) {
                            feeItems.add({
                              'name': 'Tiền đặt cọc',
                              'amount': widget.amenity.depositAmount,
                            });
                          }

                          final codeSuffix = result.id.length >= 4 ? result.id.substring(0, 4).toUpperCase() : result.id.toUpperCase();
                          final paymentRes = await showUnifiedPaymentSheet(
                            context: context,
                            type: PaymentType.service,
                            referenceId: result.id,
                            title: 'Đăng ký ${widget.amenity.name}',
                            referenceCode: '#BK-${DateFormat('yyyyMMdd').format(_selectedDate)}-$codeSuffix',
                            amount: totalFee,
                            feeBreakdown: feeItems,
                          );

                          if (paymentRes != null && paymentRes.success && mounted) {
                            _showBookingSuccessDialog(context, result, slot);
                            return;
                          }
                        }

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                result.isWaitlist
                                    ? 'Đã thêm vào danh sách chờ thành công!'
                                    : 'Đặt lịch tiện ích thành công!',
                              ),
                              backgroundColor: result.isWaitlist ? Colors.purple : AppStatusColors.paid,
                            ),
                          );
                        }
                      } catch (e) {
                        // Tự động làm mới slot khi lỗi (đặc biệt khi có người vừa đặt trước 23505)
                        ref.invalidate(amenityBookingsForDateProvider(
                          AmenityDateQuery(amenityId: widget.amenity.id, date: _selectedDate),
                        ));
                        ref.invalidate(myAmenityBookingsProvider);

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(NetworkErrorHandler.getMessage(e)),
                              backgroundColor: AppTheme.error,
                            ),
                          );
                        }
                      } finally {
                        if (mounted) {
                          setState(() => _isSubmitting = false);
                        }
                      }
                    },
              child: Text(isWaitlist ? 'Xác nhận vào hàng chờ' : 'Xác nhận đặt'),
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
                await ref.read(amenityBookingRepositoryProvider).cancelBooking(booking.id);
                ref.invalidate(amenityBookingsForDateProvider(
                  AmenityDateQuery(amenityId: booking.amenityId, date: booking.bookingDate),
                ));
                ref.invalidate(myAmenityBookingsProvider);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã hủy lịch thành công.')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(formatErrorMessage(e)),
                      backgroundColor: AppTheme.error,
                    ),
                  );
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
            Tab(icon: Icon(Icons.event_available_outlined), text: 'Chọn Khung Giờ'),
            Tab(icon: Icon(Icons.bookmark_outline), text: 'Lịch Đã Đặt'),
          ],
        ),
      ),
      body: aptIdAsync.when(
        data: (apartmentId) {
          if (apartmentId == null || user == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'Bạn cần được Ban Quản Lý phê duyệt liên kết căn hộ trước khi đặt lịch tiện ích.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15),
                ),
              ),
            );
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildBookingTab(apartmentId, user.id),
              _buildMyBookingsTab(),
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
    final query = AmenityDateQuery(amenityId: widget.amenity.id, date: _selectedDate);
    final bookingsAsync = ref.watch(amenityBookingsForDateProvider(query));
    final maintenanceAsync = ref.watch(amenityMaintenanceForDateProvider(query));
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
                  const Icon(Icons.access_time, size: 16, color: AppTheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Thời gian mở cửa: ${widget.amenity.openHours ?? "06:00 - 22:00"} (${widget.amenity.slotDurationMinutes} phút/lượt)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    widget.amenity.isShared ? Icons.groups_outlined : Icons.lock_outline,
                    size: 16,
                    color: Colors.grey.shade700,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.amenity.isShared
                        ? 'Tiện ích dùng chung — Sức chứa: ${widget.amenity.maxCapacity} người/khung giờ'
                        : 'Tiện ích trọn gói — 1 căn hộ/khung giờ',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ],
              ),
              if (widget.amenity.feeAmount > 0 || widget.amenity.requiresDeposit) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.payments_outlined, size: 16, color: AppStatusColors.paid),
                    const SizedBox(width: 6),
                    Text(
                      'Phí: ${_currencyFormat.format(widget.amenity.feeAmount)}${widget.amenity.requiresDeposit ? ' • Cọc: ${_currencyFormat.format(widget.amenity.depositAmount)}' : ''}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppStatusColors.paid),
                    ),
                  ],
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
                final isSelected = date.year == _selectedDate.year &&
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
                      color: isSelected ? AppTheme.primary : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? AppTheme.primary : Colors.grey.shade200,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          index == 0 ? 'Hôm nay' : _dayOfWeekFormat.format(date),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Colors.white70 : Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _dateDisplayFormat.format(date),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : Colors.grey.shade900,
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
                  final isPast = AmenitySlotHelper.isSlotInPast(_selectedDate, slot);
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
                      ? confirmedList.fold<int>(0, (sum, b) => sum + b.guestsCount)
                      : confirmedList.length;

                  final availableCapacity = widget.amenity.maxCapacity - confirmedGuests;
                  final isFullyBooked = availableCapacity <= 0;

                  final isSelected = _selectedSlot == slot;
                  final isWaitlistChoice = isFullyBooked && !isPast && !isMaintenance;

                  Color cardBg = Colors.white;
                  BorderSide cardBorder = BorderSide(color: Colors.grey.shade200);
                  Widget trailingWidget = Icon(
                    isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: isSelected ? AppTheme.primary : Colors.grey.shade400,
                  );
                  String subtitleText = 'Còn trống: $availableCapacity chỗ';
                  Color subtitleColor = AppStatusColors.paid;

                  if (isMaintenance) {
                    cardBg = Colors.orange.shade50;
                    cardBorder = BorderSide(color: Colors.orange.shade200);
                    subtitleText = 'Đang bảo trì / vệ sinh định kỳ';
                    subtitleColor = AppTheme.warning;
                    trailingWidget = Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Bảo trì',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.deepOrange),
                      ),
                    );
                  } else if (isPast) {
                    cardBg = Colors.grey.shade100;
                    cardBorder = BorderSide(color: Colors.grey.shade300);
                    subtitleText = 'Khung giờ này đã trôi qua';
                    subtitleColor = Colors.grey;
                    trailingWidget = Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Đã qua',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                    );
                  } else if (isFullyBooked) {
                    cardBg = isSelected ? Colors.purple.shade50 : Colors.grey.shade50;
                    cardBorder = BorderSide(
                      color: isSelected ? Colors.purple : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    );
                    subtitleText = 'Đã hết chỗ — Bấm để tham gia Danh sách chờ';
                    subtitleColor = Colors.purple;
                    trailingWidget = Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.purple : Colors.purple.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isSelected ? 'Chờ duyệt' : 'Vào Waitlist',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : Colors.purple.shade800,
                        ),
                      ),
                    );
                  } else if (isSelected) {
                    cardBg = AppTheme.primary.withValues(alpha: 0.08);
                    cardBorder = const BorderSide(color: AppTheme.primary, width: 2);
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: Icon(
                        isMaintenance
                            ? Icons.build_circle_outlined
                            : (isPast
                                ? Icons.history_outlined
                                : (isFullyBooked ? Icons.hourglass_top_outlined : Icons.schedule_outlined)),
                        color: isMaintenance
                            ? Colors.orange
                            : (isPast
                                ? Colors.grey
                                : (isFullyBooked
                                    ? Colors.purple
                                    : (isSelected ? AppTheme.primary : Colors.grey.shade700))),
                      ),
                      title: Text(
                        slot,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: (isPast || isMaintenance) ? Colors.grey.shade600 : Colors.black87,
                        ),
                      ),
                      subtitle: Text(
                        subtitleText,
                        style: TextStyle(fontSize: 12, color: subtitleColor, fontWeight: FontWeight.w500),
                      ),
                      trailing: trailingWidget,
                      onTap: (isPast || isMaintenance)
                          ? null
                          : () {
                              setState(() {
                                _selectedSlot = slot;
                                _isWaitlistSelection = isWaitlistChoice;
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

        // Nút bấm đặt lịch / vào hàng chờ
        Container(
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
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isWaitlistSelection ? Colors.purple : AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: _isSubmitting
                    ? const SizedBox.shrink()
                    : Icon(_isWaitlistSelection ? Icons.hourglass_top_outlined : Icons.check_circle_outline),
                label: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        _selectedSlot == null
                            ? 'Vui lòng chọn 1 khung giờ'
                            : (_isWaitlistSelection
                                ? 'Vào danh sách chờ khung giờ $_selectedSlot'
                                : 'Đặt lịch khung giờ $_selectedSlot'),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // Tab 2: Lịch Đã Đặt Của Cư Dân
  // ===========================================================================
  Widget _buildMyBookingsTab() {
    final myBookingsAsync = ref.watch(myAmenityBookingsProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(myAmenityBookingsProvider),
      child: myBookingsAsync.when(
        data: (bookings) {
          if (bookings.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today_outlined, size: 56, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  const Text(
                    'Chưa có lịch đặt tiện ích nào',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
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
              if (b.isWaitlist) {
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

              final canCancel = (b.isConfirmed || b.isWaitlist);

              return Card(
                elevation: 0,
                color: Colors.white,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: Colors.grey.shade200),
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
                              b.amenityName ?? widget.amenity.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Icons.calendar_month_outlined, size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 6),
                          Text(
                            'Ngày: ${_fullDateFormat.format(b.bookingDate)}',
                            style: const TextStyle(fontSize: 14),
                          ),
                          const Spacer(),
                          Icon(Icons.schedule, size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 6),
                          Text(
                            b.timeSlot,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      if (b.guestsCount > 1 || b.feeAmount > 0 || b.depositAmount > 0) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            if (b.guestsCount > 1)
                              Chip(
                                label: Text('${b.guestsCount} người', style: const TextStyle(fontSize: 11)),
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ),
                            if (b.feeAmount > 0)
                              Chip(
                                label: Text('Phí: ${_currencyFormat.format(b.feeAmount)}', style: const TextStyle(fontSize: 11)),
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ),
                            if (b.depositAmount > 0)
                              Chip(
                                label: Text('Cọc: ${_currencyFormat.format(b.depositAmount)} (${b.depositStatus})', style: const TextStyle(fontSize: 11)),
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ),
                          ],
                        ),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (b.isConfirmed) ...[
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.primary,
                                visualDensity: VisualDensity.compact,
                              ),
                              icon: const Icon(Icons.qr_code_2_rounded, size: 16),
                              label: const Text('Mã QR'),
                              onPressed: () {
                                final bCode = 'BK${b.id.length >= 8 ? b.id.substring(0, 8).toUpperCase() : b.id.toUpperCase()}';
                                _showQrCodeDialog(context, b, bCode, b.timeSlot);
                              },
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (canCancel)
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.error,
                                visualDensity: VisualDensity.compact,
                              ),
                              icon: const Icon(Icons.cancel_outlined, size: 16),
                              label: const Text('Hủy lịch này'),
                              onPressed: () => _confirmCancelBooking(b),
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: AppErrorCard(error: e)),
      ),
    );
  }

  void _showBookingSuccessDialog(BuildContext context, AmenityBookingModel booking, String slot) {
    final bookingCode = 'BK${booking.id.length >= 8 ? booking.id.substring(0, 8).toUpperCase() : booking.id.toUpperCase()}';

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Column(
          children: [
            Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 56),
            SizedBox(height: 12),
            Text('Đặt Dịch Vụ Thành Công!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.amenity.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              '${_fullDateFormat.format(_selectedDate)} • $slot',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
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
                  const Text('Mã đặt chỗ:', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                  Text(
                    bookingCode,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppTheme.primary),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.qr_code_2_rounded),
              label: const Text('Xem Mã QR Check-in', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.pop(dialogCtx);
                _showQrCodeDialog(context, booking, bookingCode, slot);
              },
            ),
          ],
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

  void _showQrCodeDialog(BuildContext context, AmenityBookingModel booking, String bookingCode, String slot) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Center(
          child: Column(
            children: [
              const Text('Mã QR Check-in Dịch Vụ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(widget.amenity.name, style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            ],
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: QrImageView(
                data: 'PKA-BOOKING:$bookingCode:${widget.amenity.name}:$slot',
                version: QrVersions.auto,
                size: 200.0,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              bookingCode,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1),
            ),
            const SizedBox(height: 4),
            Text(
              'Xuất trình mã này cho lễ tân / BQL khi vào sử dụng dịch vụ',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Hoàn tất'),
          ),
        ],
      ),
    );
  }
}
