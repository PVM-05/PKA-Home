import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_card.dart';
import '../../../data/models/building_amenity_model.dart';
import '../../../data/models/amenity_booking_model.dart';
import '../../../data/providers/handbook_provider.dart';
import '../../../data/providers/amenity_booking_provider.dart';
import '../../../data/providers/auth_provider.dart';

class AmenityManagementScreen extends ConsumerStatefulWidget {
  const AmenityManagementScreen({super.key});

  @override
  ConsumerState<AmenityManagementScreen> createState() => _AmenityManagementScreenState();
}

class _AmenityManagementScreenState extends ConsumerState<AmenityManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  BuildingAmenityModel? _selectedAmenity;
  DateTime _selectedDate = DateTime.now();

  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  final DateFormat _timeFormat = DateFormat('HH:mm');
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _showAddMaintenanceDialog(String amenityId) {
    DateTime start = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 8, 0);
    DateTime end = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 12, 0);
    final reasonController = TextEditingController(text: 'Vệ sinh và bảo trì định kỳ');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Thêm Lịch Bảo Trì'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ngày: ${_dateFormat.format(_selectedDate)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Bắt đầu: '),
                  TextButton(
                    onPressed: () async {
                      final t = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(hour: start.hour, minute: start.minute),
                      );
                      if (t != null) {
                        setDialogState(() {
                          start = DateTime(start.year, start.month, start.day, t.hour, t.minute);
                        });
                      }
                    },
                    child: Text(_timeFormat.format(start)),
                  ),
                ],
              ),
              Row(
                children: [
                  const Text('Kết thúc: '),
                  TextButton(
                    onPressed: () async {
                      final t = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(hour: end.hour, minute: end.minute),
                      );
                      if (t != null) {
                        setDialogState(() {
                          end = DateTime(end.year, end.month, end.day, t.hour, t.minute);
                        });
                      }
                    },
                    child: Text(_timeFormat.format(end)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Lý do tạm ngưng phục vụ',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (end.isBefore(start) || end.isAtSameMomentAs(start)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Giờ kết thúc phải sau giờ bắt đầu.')),
                  );
                  return;
                }
                Navigator.pop(ctx);
                final user = ref.read(authProvider).valueOrNull;
                try {
                  await ref.read(amenityBookingRepositoryProvider).createMaintenanceWindow(
                        amenityId: amenityId,
                        startTime: start,
                        endTime: end,
                        reason: reasonController.text.trim(),
                        createdBy: user?.id,
                      );
                  ref.invalidate(amenityMaintenanceForDateProvider(
                    AmenityDateQuery(amenityId: amenityId, date: _selectedDate),
                  ));
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Đã tạo lịch bảo trì thành công!'),
                        backgroundColor: AppStatusColors.paid,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(formatErrorMessage(e)), backgroundColor: AppTheme.error),
                    );
                  }
                }
              },
              child: const Text('Lưu lịch'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDepositDialog(AmenityBookingModel booking) {
    String currentStatus = booking.depositStatus;
    final notesController = TextEditingController(text: booking.depositNotes ?? '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Quản Lý Tiền Đặt Cọc'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Căn hộ: ${booking.apartmentCode ?? "***"}', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('Người đặt: ${booking.bookerName ?? "***"}'),
              const SizedBox(height: 6),
              Text('Số tiền cọc: ${_currencyFormat.format(booking.depositAmount)}',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.warning)),
              const SizedBox(height: 12),
              const Text('Trạng thái cọc:', style: TextStyle(fontWeight: FontWeight.w500)),
              DropdownButton<String>(
                value: currentStatus,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'none', child: Text('Không yêu cầu cọc')),
                  DropdownMenuItem(value: 'pending', child: Text('Chưa nộp tiền cọc (Chờ thu)')),
                  DropdownMenuItem(value: 'received', child: Text('Đã nhận đủ tiền cọc')),
                  DropdownMenuItem(value: 'refunded', child: Text('Đã hoàn trả cọc cho cư dân')),
                  DropdownMenuItem(value: 'forfeited', child: Text('Tịch thu cọc (Vi phạm/Hư hỏng)')),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => currentStatus = val);
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú thu/hoàn cọc',
                  hintText: 'VD: Đã hoàn tiền mặt lúc 21h',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Đóng'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await ref.read(amenityBookingRepositoryProvider).updateDepositStatus(
                        booking.id,
                        currentStatus,
                        notes: notesController.text.trim(),
                      );
                  ref.invalidate(amenityBookingsForDateProvider(
                    AmenityDateQuery(amenityId: booking.amenityId, date: booking.bookingDate),
                  ));
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Đã cập nhật trạng thái tiền cọc!'),
                        backgroundColor: AppStatusColors.paid,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(formatErrorMessage(e)), backgroundColor: AppTheme.error),
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

  @override
  Widget build(BuildContext context) {
    final amenitiesAsync = ref.watch(buildingAmenitiesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản Trị Tiện Ích'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          indicatorColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: const [
            Tab(icon: Icon(Icons.list_alt_outlined), text: 'Lịch Đặt & Điểm Danh'),
            Tab(icon: Icon(Icons.build_outlined), text: 'Lịch Bảo Trì'),
          ],
        ),
      ),
      body: amenitiesAsync.when(
        data: (amenities) {
          if (amenities.isEmpty) {
            return const Center(child: Text('Tòa nhà chưa có tiện ích nào được tạo.'));
          }

          _selectedAmenity ??= amenities.first;

          return Column(
            children: [
              // Thanh điều khiển chọn tiện ích và ngày
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<BuildingAmenityModel>(
                        initialValue: _selectedAmenity,
                        decoration: const InputDecoration(
                          labelText: 'Chọn tiện ích',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(),
                        ),
                        items: amenities.map((a) {
                          return DropdownMenuItem(
                            value: a,
                            child: Text(a.name, overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedAmenity = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(_dateFormat.format(_selectedDate), style: const TextStyle(fontSize: 13)),
                        onPressed: _selectDate,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Nội dung Tabs
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildBookingsTab(_selectedAmenity!),
                    _buildMaintenanceTab(_selectedAmenity!),
                  ],
                ),
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
  // Tab 1: Danh sách Đặt Lịch & Điểm Danh
  // ===========================================================================
  Widget _buildBookingsTab(BuildingAmenityModel amenity) {
    final query = AmenityDateQuery(amenityId: amenity.id, date: _selectedDate);
    final bookingsAsync = ref.watch(amenityBookingsForDateProvider(query));

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(amenityBookingsForDateProvider(query)),
      child: bookingsAsync.when(
        data: (bookings) {
          if (bookings.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.event_busy_outlined, size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 8),
                  Text('Không có lượt đặt nào trong ngày ${_dateFormat.format(_selectedDate)}'),
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
                statusLabel = 'Đã sử dụng';
              } else if (b.isNoShow) {
                statusColor = AppTheme.error;
                statusLabel = 'Vắng mặt';
              }

              return AppCard(
                margin: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Căn hộ: ${b.apartmentCode ?? "***"}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: statusColor),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('Khung giờ: ${b.timeSlot} • Người đặt: ${b.bookerName ?? "***"}'),
                    if (b.guestsCount > 1) ...[
                      const SizedBox(height: 4),
                      Text('Số người: ${b.guestsCount} người', style: const TextStyle(fontWeight: FontWeight.w500)),
                    ],
                    if (b.depositAmount > 0) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.shield_outlined, size: 16, color: Colors.amber.shade800),
                          const SizedBox(width: 4),
                          Text(
                            'Tiền cọc: ${_currencyFormat.format(b.depositAmount)} (${b.depositStatus})',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: b.depositStatus == 'received' ? AppStatusColors.paid : AppTheme.warning,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => _showDepositDialog(b),
                            child: const Text('Đổi trạng thái cọc'),
                          ),
                        ],
                      ),
                    ],
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (b.isConfirmed) ...[
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.error,
                              side: const BorderSide(color: AppTheme.error),
                            ),
                            icon: const Icon(Icons.person_off_outlined, size: 16),
                            label: const Text('Vắng mặt (No-show)'),
                            onPressed: () async {
                              await ref
                                  .read(amenityBookingRepositoryProvider)
                                  .markBookingAttendance(b.id, 'no_show');
                              ref.invalidate(amenityBookingsForDateProvider(query));
                            },
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppStatusColors.paid,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.check, size: 16),
                            label: const Text('Điểm danh / Nhận chỗ'),
                            onPressed: () async {
                              await ref
                                  .read(amenityBookingRepositoryProvider)
                                  .markBookingAttendance(b.id, 'completed');
                              ref.invalidate(amenityBookingsForDateProvider(query));
                            },
                          ),
                        ],
                        if (!b.isConfirmed && b.depositAmount > 0)
                          TextButton.icon(
                            icon: const Icon(Icons.edit_note, size: 16),
                            label: const Text('Xem cọc'),
                            onPressed: () => _showDepositDialog(b),
                          ),
                      ],
                    ),
                  ],
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

  // ===========================================================================
  // Tab 2: Lịch Bảo Trì Tiện Ích
  // ===========================================================================
  Widget _buildMaintenanceTab(BuildingAmenityModel amenity) {
    final query = AmenityDateQuery(amenityId: amenity.id, date: _selectedDate);
    final maintenanceAsync = ref.watch(amenityMaintenanceForDateProvider(query));

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Tạo lịch bảo trì'),
        onPressed: () => _showAddMaintenanceDialog(amenity.id),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(amenityMaintenanceForDateProvider(query)),
        child: maintenanceAsync.when(
          data: (windows) {
            if (windows.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline, size: 48, color: Colors.green.shade300),
                    const SizedBox(height: 8),
                    Text('Tiện ích hoạt động bình thường ngày ${_dateFormat.format(_selectedDate)}'),
                    const SizedBox(height: 4),
                    const Text('Không có lịch đóng cửa bảo trì/vệ sinh nào.', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: windows.length,
              itemBuilder: (context, index) {
                final w = windows[index];
                return AppCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.build_circle, color: Colors.orange, size: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(w.reason, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(height: 4),
                            Text(
                              'Từ ${_timeFormat.format(w.startTime)} đến ${_timeFormat.format(w.endTime)}',
                              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                        onPressed: () async {
                          await ref.read(amenityBookingRepositoryProvider).deleteMaintenanceWindow(w.id);
                          ref.invalidate(amenityMaintenanceForDateProvider(query));
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: AppErrorCard(error: e)),
        ),
      ),
    );
  }
}
