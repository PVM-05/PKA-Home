import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pka_home/core/theme/app_theme.dart';
import 'package:pka_home/core/utils/amenity_slot_helper.dart';
import 'package:pka_home/core/utils/error_formatter.dart';
import 'package:pka_home/data/models/amenity_booking_model.dart';
import 'package:pka_home/data/models/building_amenity_model.dart';
import 'package:pka_home/data/providers/amenity_booking_provider.dart';

void showRescheduleBookingBottomSheet({
  required BuildContext context,
  required AmenityBookingModel booking,
  required BuildingAmenityModel amenity,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => RescheduleBookingBottomSheet(
      booking: booking,
      amenity: amenity,
    ),
  );
}

class RescheduleBookingBottomSheet extends ConsumerStatefulWidget {
  final AmenityBookingModel booking;
  final BuildingAmenityModel amenity;

  const RescheduleBookingBottomSheet({
    super.key,
    required this.booking,
    required this.amenity,
  });

  @override
  ConsumerState<RescheduleBookingBottomSheet> createState() =>
      _RescheduleBookingBottomSheetState();
}

class _RescheduleBookingBottomSheetState
    extends ConsumerState<RescheduleBookingBottomSheet> {
  late DateTime _selectedDate;
  String? _selectedSlot;
  late int _guestsCount;
  bool _isSubmitting = false;

  final DateFormat _dayOfWeekFormat = DateFormat('EEE', 'vi');
  final DateFormat _dateDisplayFormat = DateFormat('dd/MM');

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final bDate = DateTime(
      widget.booking.bookingDate.year,
      widget.booking.bookingDate.month,
      widget.booking.bookingDate.day,
    );
    _selectedDate = bDate.isBefore(today) ? today : bDate;
    _selectedSlot = widget.booking.timeSlot;
    _guestsCount = widget.booking.guestsCount;
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

  Future<void> _handleConfirmReschedule() async {
    if (_selectedSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn một khung giờ mới.')),
      );
      return;
    }

    final sameDate =
        _selectedDate.year == widget.booking.bookingDate.year &&
        _selectedDate.month == widget.booking.bookingDate.month &&
        _selectedDate.day == widget.booking.bookingDate.day;
    if (sameDate && _selectedSlot == widget.booking.timeSlot) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Vui lòng chọn ngày hoặc khung giờ khác với lịch hiện tại.',
          ),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final res = await ref
          .read(amenityBookingRepositoryProvider)
          .rescheduleBooking(
            bookingId: widget.booking.id,
            newDate: _selectedDate,
            newTimeSlot: _selectedSlot!,
            newGuestsCount: _guestsCount,
          );

      ref.invalidate(myAmenityBookingsProvider);
      ref.invalidate(
        amenityBookingsForDateProvider(
          AmenityDateQuery(
            amenityId: widget.amenity.id,
            date: widget.booking.bookingDate,
          ),
        ),
      );
      ref.invalidate(
        amenityBookingsForDateProvider(
          AmenityDateQuery(amenityId: widget.amenity.id, date: _selectedDate),
        ),
      );

      if (mounted) {
        Navigator.pop(context);
        final action = res['action'] as String?;
        final status = res['status'] as String?;

        String successMsg;
        if (action == 'rescheduled_pending_payment' ||
            status == 'pending_payment') {
          successMsg =
              'Đổi lịch thành công! Vui lòng hoàn tất thanh toán cho lịch đặt mới.';
        } else {
          successMsg = 'Đổi lịch đặt chỗ thành công!';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMsg),
            backgroundColor: AppTheme.success,
          ),
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
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final slots = _getSlots();
    final bookingsAsync = ref.watch(
      amenityBookingsForDateProvider(
        AmenityDateQuery(amenityId: widget.amenity.id, date: _selectedDate),
      ),
    );
    final maintenanceAsync = ref.watch(
      amenityMaintenanceForDateProvider(
        AmenityDateQuery(amenityId: widget.amenity.id, date: _selectedDate),
      ),
    );

    final isConfirmedBooking = widget.booking.isConfirmed;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Đổi Lịch Đặt Chỗ',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tiện ích: ${widget.amenity.name}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Thông báo chính sách
          if (isConfirmedBooking)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blue.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Lượt đặt đã xác nhận/thanh toán sẽ giữ nguyên số người (${widget.booking.guestsCount} người) và bảo lưu toàn bộ chi phí/tiền cọc.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Bộ chọn ngày
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: SizedBox(
              height: 74,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
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
                      width: 60,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primary
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
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
                            style: TextStyle(
                              fontSize: 11,
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
                            style: TextStyle(
                              fontSize: 13,
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

          // Tùy chọn số lượng khách (nếu shared và không phải confirmed)
          if (!isConfirmedBooking && widget.amenity.isShared) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Số người tham gia:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, size: 22),
                        onPressed: _guestsCount > 1
                            ? () => setState(() => _guestsCount--)
                            : null,
                      ),
                      Text(
                        '$_guestsCount',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, size: 22),
                        onPressed: _guestsCount < widget.amenity.maxCapacity
                            ? () => setState(() => _guestsCount++)
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
          ],

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

                    final isSameBookingSlot =
                        _selectedDate.year == widget.booking.bookingDate.year &&
                        _selectedDate.month ==
                            widget.booking.bookingDate.month &&
                        _selectedDate.day == widget.booking.bookingDate.day &&
                        slot == widget.booking.timeSlot;

                    final otherBookings = existingBookings
                        .where((b) => b.id != widget.booking.id)
                        .toList();
                    final confirmedList = otherBookings
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
                    final isFullyBooked = availableCapacity < _guestsCount;
                    final isSelected = _selectedSlot == slot;

                    Color cardBg = Colors.white;
                    BorderSide cardBorder = BorderSide(
                      color: Colors.grey.shade200,
                    );
                    String subtitleText = 'Còn trống: $availableCapacity chỗ';
                    Color subtitleColor = AppStatusColors.paid;

                    if (isSameBookingSlot) {
                      subtitleText = 'Khung giờ hiện tại của bạn';
                      subtitleColor = Colors.blue;
                    } else if (isMaintenance) {
                      cardBg = Colors.orange.shade50;
                      cardBorder = BorderSide(color: Colors.orange.shade200);
                      subtitleText = 'Đang bảo trì / vệ sinh định kỳ';
                      subtitleColor = AppTheme.warning;
                    } else if (isPast) {
                      cardBg = Colors.grey.shade100;
                      cardBorder = BorderSide(color: Colors.grey.shade300);
                      subtitleText = 'Khung giờ này đã trôi qua';
                      subtitleColor = Colors.grey;
                    } else if (isFullyBooked) {
                      cardBg = Colors.purple.shade50;
                      cardBorder = BorderSide(color: Colors.purple.shade200);
                      subtitleText = 'Hết chỗ (sẽ vào danh sách chờ)';
                      subtitleColor = Colors.purple;
                    }

                    final bool canSelect = !isPast && !isMaintenance;

                    return Card(
                      elevation: 0,
                      color: cardBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: isSelected
                            ? const BorderSide(
                                color: AppTheme.primary,
                                width: 2,
                              )
                            : cardBorder,
                      ),
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        enabled: canSelect,
                        title: Text(
                          slot,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: canSelect ? Colors.black87 : Colors.grey,
                          ),
                        ),
                        subtitle: Text(
                          subtitleText,
                          style: TextStyle(
                            fontSize: 12,
                            color: subtitleColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        trailing: Icon(
                          isSelected
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: isSelected
                              ? AppTheme.primary
                              : Colors.grey.shade400,
                        ),
                        onTap: canSelect
                            ? () {
                                setState(() {
                                  _selectedSlot = slot;
                                });
                              }
                            : null,
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(formatErrorMessage(e))),
            ),
          ),

          // Bottom Bar hành động
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check, size: 20),
                label: Text(
                  _isSubmitting ? 'Đang xử lý...' : 'Xác Nhận Đổi Lịch',
                ),
                onPressed: _isSubmitting ? null : _handleConfirmReschedule,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
