import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../data/models/building_amenity_model.dart';
import '../../../data/models/amenity_booking_model.dart';
import '../../../data/providers/amenity_booking_provider.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/vehicle_provider.dart';

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

  final List<String> _defaultSlots = [
    '06:00 - 07:30',
    '07:30 - 09:00',
    '09:00 - 10:30',
    '14:00 - 15:30',
    '15:30 - 17:00',
    '17:00 - 18:30',
    '18:30 - 20:00',
    '20:00 - 21:30',
  ];

  final DateFormat _dayOfWeekFormat = DateFormat('EEE', 'vi');
  final DateFormat _dateDisplayFormat = DateFormat('dd/MM');
  final DateFormat _fullDateFormat = DateFormat('dd/MM/yyyy');

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

  void _confirmAndBookSlot(String slot, String apartmentId, String userId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác Nhận Đặt Lịch'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tiện ích: ${widget.amenity.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Ngày sử dụng: ${_fullDateFormat.format(_selectedDate)}'),
            const SizedBox(height: 6),
            Text('Khung giờ: $slot', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                border: Border.all(color: Colors.amber.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.amber),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Vui lòng có mặt đúng giờ và giữ gìn vệ sinh chung của tiện ích.',
                      style: TextStyle(fontSize: 12),
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
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isSubmitting = true);

              try {
                await ref.read(amenityBookingRepositoryProvider).createBooking(
                      amenityId: widget.amenity.id,
                      apartmentId: apartmentId,
                      userId: userId,
                      date: _selectedDate,
                      timeSlot: slot,
                    );

                // Refresh state
                ref.invalidate(amenityBookingsForDateProvider(
                  AmenityDateQuery(amenityId: widget.amenity.id, date: _selectedDate),
                ));
                ref.invalidate(myAmenityBookingsProvider);

                setState(() {
                  _isSubmitting = false;
                  _selectedSlot = null;
                });

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đặt lịch tiện ích thành công!'),
                      backgroundColor: AppStatusColors.paid,
                    ),
                  );
                }
              } catch (e) {
                setState(() => _isSubmitting = false);
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
            child: const Text('Xác nhận đặt'),
          ),
        ],
      ),
    );
  }

  void _confirmCancelBooking(AmenityBookingModel booking) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hủy Lịch Đã Đặt'),
        content: Text(
          'Bạn có chắc muốn hủy lịch tiện ích ${booking.amenityName ?? widget.amenity.name} vào ngày ${_fullDateFormat.format(booking.bookingDate)} khung giờ ${booking.timeSlot} không?\n\nKhung giờ này sẽ được mở lại cho cư dân khác.',
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
                    const SnackBar(content: Text('Đã hủy lịch đặt thành công.')),
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
        error: (e, _) => Center(child: Text('Lỗi: $e')),
      ),
    );
  }

  // ===========================================================================
  // Tab 1: Chọn Khung Giờ Đặt Lịch
  // ===========================================================================
  Widget _buildBookingTab(String apartmentId, String userId) {
    final query = AmenityDateQuery(amenityId: widget.amenity.id, date: _selectedDate);
    final bookingsAsync = ref.watch(amenityBookingsForDateProvider(query));

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
                    'Thời gian mở cửa: ${widget.amenity.openHours ?? "06:00 - 22:00"}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
              if (widget.amenity.description != null && widget.amenity.description!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  widget.amenity.description!,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
            height: 72,
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
              final bookedSlotMap = {
                for (var b in existingBookings) b.timeSlot: b
              };

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _defaultSlots.length,
                itemBuilder: (context, index) {
                  final slot = _defaultSlots[index];
                  final bookedBooking = bookedSlotMap[slot];
                  final isBooked = bookedBooking != null;
                  final isSelected = _selectedSlot == slot;

                  return Card(
                    elevation: 0,
                    color: isBooked
                        ? Colors.grey.shade100
                        : (isSelected ? AppTheme.primary.withValues(alpha: 0.08) : Colors.white),
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: isSelected
                            ? AppTheme.primary
                            : (isBooked ? Colors.grey.shade300 : Colors.grey.shade200),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: Icon(
                        isBooked ? Icons.lock_clock_outlined : Icons.schedule_outlined,
                        color: isBooked
                            ? Colors.grey.shade400
                            : (isSelected ? AppTheme.primary : Colors.grey.shade700),
                      ),
                      title: Text(
                        slot,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: isBooked ? Colors.grey.shade500 : Colors.black87,
                        ),
                      ),
                      subtitle: isBooked
                          ? Text(
                              'Đã có người đặt (Căn hộ ${bookedBooking.apartmentCode ?? "***"})',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                            )
                          : const Text(
                              'Còn trống — Có thể đặt',
                              style: TextStyle(fontSize: 12, color: AppStatusColors.paid, fontWeight: FontWeight.w500),
                            ),
                      trailing: isBooked
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Đã kín',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                              ),
                            )
                          : Icon(
                              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                              color: isSelected ? AppTheme.primary : Colors.grey.shade400,
                            ),
                      onTap: isBooked
                          ? null
                          : () {
                              setState(() => _selectedSlot = slot);
                            },
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Lỗi tải danh sách khung giờ: $e')),
          ),
        ),

        // Nút bấm đặt lịch
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
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: _isSubmitting
                    ? const SizedBox.shrink()
                    : const Icon(Icons.check_circle_outline),
                label: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        _selectedSlot == null
                            ? 'Vui lòng chọn 1 khung giờ'
                            : 'Đặt lịch khung giờ $_selectedSlot',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                onPressed: _selectedSlot == null || _isSubmitting
                    ? null
                    : () => _confirmAndBookSlot(_selectedSlot!, apartmentId, userId),
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
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Các lượt đặt tiện ích của bạn sẽ xuất hiện tại đây.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
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
              final isCancelled = b.isCancelled;

              return Card(
                elevation: 0,
                color: Colors.white,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
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
                          Text(
                            b.amenityName ?? widget.amenity.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppTheme.primary,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isCancelled
                                  ? Colors.red.shade50
                                  : AppStatusColors.paid.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isCancelled ? 'Đã hủy' : 'Đã xác nhận',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isCancelled ? AppTheme.error : AppStatusColors.paid,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Icons.calendar_month, size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 6),
                          Text(
                            'Ngày: ${_fullDateFormat.format(b.bookingDate)}',
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(width: 16),
                          Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 6),
                          Text(
                            b.timeSlot,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      if (!isCancelled) ...[
                        const Divider(height: 20),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.error,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            icon: const Icon(Icons.cancel_outlined, size: 16),
                            label: const Text('Hủy đặt lịch'),
                            onPressed: () => _confirmCancelBooking(b),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi tải lịch của bạn: $e')),
      ),
    );
  }
}
