import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_card.dart';
import '../../../core/constants/permissions.dart';
import '../../../core/widgets/role_guard.dart';
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
  String? _selectedAmenityId;
  DateTime _selectedDate = DateTime.now();
  String _statusFilter = 'all'; // 'all', 'pending', 'confirmed', 'completed', 'cancelled'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  final DateFormat _timeFormat = DateFormat('HH:mm');
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Thêm Lịch Bảo Trì'),
          content: SingleChildScrollView(
            child: Column(
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
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Quản Lý Tiền Đặt Cọc'),
          content: SingleChildScrollView(
            child: Column(
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
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Đóng'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
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
                  ref.invalidate(allAmenityBookingsProvider);
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

  void _showQuickCheckInDialog() {
    final codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.qr_code_scanner, color: AppTheme.primary),
            SizedBox(width: 8),
            Expanded(child: Text('Check-in Tiện Ích (QR/Mã)')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nhập mã đặt chỗ từ mã QR của cư dân để xác nhận điểm danh sử dụng dịch vụ:',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: codeController,
                decoration: const InputDecoration(
                  labelText: 'Mã đặt chỗ (Booking ID)',
                  hintText: 'Nhập UUID hoặc mã đặt chỗ',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.confirmation_number_outlined),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppStatusColors.paid,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.check, size: 16),
            label: const Text('Xác nhận Check-in'),
            onPressed: () async {
              final code = codeController.text.trim();
              if (code.isEmpty) return;
              Navigator.pop(ctx);

              try {
                final result = await ref
                    .read(amenityBookingRepositoryProvider)
                    .checkInBooking(code);
                if (_selectedAmenityId != null) {
                  ref.invalidate(amenityBookingsForDateProvider(
                    AmenityDateQuery(
                      amenityId: _selectedAmenityId!,
                      date: _selectedDate,
                    ),
                  ));
                }
                ref.invalidate(allAmenityBookingsProvider);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result['message']?.toString() ?? 'Xác nhận Check-in thành công!'),
                      backgroundColor: AppStatusColors.paid,
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
              }
            },
          ),
        ],
      ),
    );
  }

  void _showRejectBookingDialog(AmenityBookingModel b) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Từ Chối / Hủy Lịch Đặt Chỗ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(b.isWaitlist
                ? 'Hủy lượt đặt trong danh sách chờ của căn hộ ${b.apartmentCode ?? "***"} (${b.timeSlot})?'
                : 'Hủy lịch đặt của căn hộ ${b.apartmentCode ?? "***"} (${b.timeSlot})?'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Lý do từ chối / hủy (tùy chọn)',
                hintText: 'VD: Khu vực bảo trì đột xuất, trùng lịch nội bộ',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(amenityBookingRepositoryProvider).cancelBooking(b.id);
                ref.invalidate(allAmenityBookingsProvider);
                if (_selectedAmenityId != null) {
                  ref.invalidate(amenityBookingsForDateProvider(
                    AmenityDateQuery(amenityId: _selectedAmenityId!, date: _selectedDate),
                  ));
                }
                ref.invalidate(amenityBookingsForDateProvider(
                  AmenityDateQuery(amenityId: b.amenityId, date: b.bookingDate),
                ));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã từ chối / hủy lịch đặt chỗ thành công.'),
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
            child: Text(b.isWaitlist ? 'Xác nhận hủy hàng chờ' : 'Xác nhận từ chối / hủy'),
          ),
        ],
      ),
    );
  }

  Future<void> _showConfirmAmenityPaymentDialog(AmenityBookingModel b) async {
    String selectedMethod = 'CASH';
    final totalFee = b.feeAmount + b.depositAmount;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: AppTheme.success),
              SizedBox(width: 8),
              Expanded(child: Text('Thu phí dịch vụ tiện ích')),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Xác nhận đã nhận đủ tiền phí/tiền cọc từ cư dân:'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('• Căn hộ: ${b.apartmentCode ?? "Chưa rõ"}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('• Tiện ích: ${b.amenityName ?? "Dịch vụ"} (${b.timeSlot})'),
                      const SizedBox(height: 4),
                      Text('• Tổng thu: ${_currencyFormat.format(totalFee)}', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Hình thức thanh toán thực thu:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'CASH', label: Text('Tiền mặt'), icon: Icon(Icons.payments_outlined)),
                    ButtonSegment(value: 'BANK_TRANSFER', label: Text('Chuyển khoản'), icon: Icon(Icons.account_balance_outlined)),
                  ],
                  selected: {selectedMethod},
                  onSelectionChanged: (newSelection) {
                    setDialogState(() => selectedMethod = newSelection.first);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Xác nhận đã thu'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final methodTitle = selectedMethod == 'CASH' ? 'Tiền mặt' : 'Chuyển khoản';
      await ref.read(amenityBookingRepositoryProvider).recordManualAmenityPayment(
        bookingId: b.id,
        paymentMethod: selectedMethod,
        notes: 'Thu phí dịch vụ tiện ích ${b.amenityName ?? ""} ($methodTitle)',
      );
      ref.invalidate(allAmenityBookingsProvider);
      if (_selectedAmenityId != null) {
        ref.invalidate(amenityBookingsForDateProvider(
          AmenityDateQuery(amenityId: _selectedAmenityId!, date: _selectedDate),
        ));
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Xác nhận thu phí ($methodTitle) thành công cho căn hộ ${b.apartmentCode ?? ""}!'),
            backgroundColor: AppTheme.success,
            action: SnackBarAction(
              label: 'Biên nhận',
              textColor: Colors.white,
              onPressed: () => _showAmenityReceiptBottomSheet(b),
            ),
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
    }
  }

  void _showEditAmenityDialog({BuildingAmenityModel? amenity}) {
    final isEditing = amenity != null;
    final nameController = TextEditingController(text: amenity?.name ?? '');
    final hoursController = TextEditingController(text: amenity?.openHours ?? '06:00 - 22:00');
    final descController = TextEditingController(text: amenity?.description ?? '');
    final capacityController = TextEditingController(text: (amenity?.maxCapacity ?? 1).toString());
    final durationController = TextEditingController(text: (amenity?.slotDurationMinutes ?? 90).toString());
    final feeController = TextEditingController(text: (amenity?.feeAmount ?? 0.0).toStringAsFixed(0));
    final depositController = TextEditingController(text: (amenity?.depositAmount ?? 0.0).toStringAsFixed(0));
    final orderController = TextEditingController(text: (amenity?.displayOrder ?? 0).toString());

    String bookingType = amenity?.bookingType ?? 'shared';
    bool requiresDeposit = amenity?.requiresDeposit ?? false;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(isEditing ? 'Chỉnh Sửa Tiện Ích & Sức Chứa' : 'Thêm Tiện Ích Mới'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Tên tiện ích *', border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tên tiện ích' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: bookingType,
                    decoration: const InputDecoration(labelText: 'Hình thức đặt chỗ *', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'shared', child: Text('Dùng chung (Nhiều người/slot)')),
                      DropdownMenuItem(value: 'exclusive', child: Text('Trọn gói (1 căn hộ/slot)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => bookingType = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: capacityController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Sức chứa tối đa (người) *',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            final n = int.tryParse(v?.trim() ?? '');
                            if (n == null || n <= 0) return 'Nhập số > 0';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: durationController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Thời lượng (phút) *',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            final n = int.tryParse(v?.trim() ?? '');
                            if (n == null || n <= 0) return 'Nhập số > 0';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: feeController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Đơn giá lượt đặt (đ)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: depositController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Tiền đặt cọc (đ)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Yêu cầu đặt cọc trước'),
                    value: requiresDeposit,
                    onChanged: (val) => setDialogState(() => requiresDeposit = val),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: hoursController,
                    decoration: const InputDecoration(
                      labelText: 'Giờ mở cửa (VD: 06:00 - 22:00)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Mô tả & quy định sử dụng',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: orderController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Thứ tự hiển thị',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
              onPressed: () async {
                if (!(formKey.currentState?.validate() ?? false)) return;
                Navigator.pop(ctx);

                final cap = int.tryParse(capacityController.text.trim()) ?? 1;
                final duration = int.tryParse(durationController.text.trim()) ?? 90;
                final fee = double.tryParse(feeController.text.trim()) ?? 0.0;
                final deposit = double.tryParse(depositController.text.trim()) ?? 0.0;
                final order = int.tryParse(orderController.text.trim()) ?? 0;
                final repo = ref.read(handbookRepositoryProvider);

                try {
                  if (isEditing) {
                    await repo.updateBuildingAmenity(
                      id: amenity.id,
                      name: nameController.text.trim(),
                      openHours: hoursController.text.trim(),
                      description: descController.text.trim(),
                      displayOrder: order,
                      bookingType: bookingType,
                      maxCapacity: cap,
                      slotDurationMinutes: duration,
                      feeAmount: fee,
                      depositAmount: deposit,
                      requiresDeposit: requiresDeposit,
                    );
                  } else {
                    await repo.createBuildingAmenity(
                      name: nameController.text.trim(),
                      openHours: hoursController.text.trim(),
                      description: descController.text.trim(),
                      displayOrder: order,
                      bookingType: bookingType,
                      maxCapacity: cap,
                      slotDurationMinutes: duration,
                      feeAmount: fee,
                      depositAmount: deposit,
                      requiresDeposit: requiresDeposit,
                    );
                  }

                  ref.invalidate(buildingAmenitiesProvider);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isEditing ? 'Đã cập nhật cấu hình tiện ích!' : 'Đã thêm tiện ích mới!'),
                        backgroundColor: AppTheme.success,
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
              child: const Text('Lưu cấu hình'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final amenitiesAsync = ref.watch(buildingAmenitiesProvider);

    return RoleGuard(
      permission: AppPermissions.amenityManagement,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Quản Trị Tiện Ích'),
          actions: [
            IconButton(
              icon: const Icon(Icons.qr_code_scanner_outlined),
              tooltip: 'Quét / Nhập mã Check-in',
              onPressed: _showQuickCheckInDialog,
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: AppTheme.primary,
            indicatorColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textSecondary,
            tabs: const [
              Tab(icon: Icon(Icons.fact_check_outlined), text: 'Duyệt Lịch Đặt Chỗ'),
              Tab(icon: Icon(Icons.tune_outlined), text: 'Tiện Ích & Sức Chứa'),
              Tab(icon: Icon(Icons.build_outlined), text: 'Lịch Bảo Trì'),
            ],
          ),
        ),
        body: amenitiesAsync.when(
          data: (amenities) {
            return TabBarView(
              controller: _tabController,
              children: [
                _buildGlobalBookingsApprovalTab(amenities),
                _buildAmenitiesConfigTab(amenities),
                _buildMaintenanceTabWithSelector(amenities),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: AppErrorCard(error: e)),
        ),
      ),
    );
  }

  // ===========================================================================
  // Tab 1: Duyệt Lịch Đặt Chỗ Toàn Tòa Nhà (Chuẩn A7 / A8)
  // ===========================================================================
  Widget _buildGlobalBookingsApprovalTab(List<BuildingAmenityModel> amenities) {
    final allBookingsAsync = ref.watch(allAmenityBookingsProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(allAmenityBookingsProvider),
      child: Column(
        children: [
          // Bộ lọc tìm kiếm & Filter Chips
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Tìm theo căn hộ (VD: A0110) hoặc tên người đặt...',
                    prefixIcon: const Icon(Icons.search),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _searchQuery = '';
                                _searchController.clear();
                              });
                            },
                          )
                        : null,
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('all', 'Tất cả'),
                      const SizedBox(width: 8),
                      _buildFilterChip('pending', 'Chờ duyệt / thanh toán'),
                      const SizedBox(width: 8),
                      _buildFilterChip('confirmed', 'Đã xác nhận'),
                      const SizedBox(width: 8),
                      _buildFilterChip('completed', 'Đã Check-in'),
                      const SizedBox(width: 8),
                      _buildFilterChip('cancelled', 'Đã hủy'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: allBookingsAsync.when(
              data: (bookings) {
                var filtered = bookings.where((b) {
                  // Lọc theo search
                  if (_searchQuery.isNotEmpty) {
                    final code = (b.apartmentCode ?? '').toLowerCase();
                    final name = (b.bookerName ?? '').toLowerCase();
                    if (!code.contains(_searchQuery) && !name.contains(_searchQuery)) {
                      return false;
                    }
                  }
                  // Lọc theo status chip
                  if (_statusFilter == 'pending') {
                    return b.isPendingPayment || (!b.isConfirmed && !b.isCancelled && !b.isCompleted);
                  } else if (_statusFilter == 'confirmed') {
                    return b.isConfirmed;
                  } else if (_statusFilter == 'completed') {
                    return b.isCompleted;
                  } else if (_statusFilter == 'cancelled') {
                    return b.isCancelled;
                  }
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inbox_outlined, size: 56, color: Colors.grey.shade300),
                        const SizedBox(height: 10),
                        const Text('Không có lịch đặt nào phù hợp với bộ lọc.'),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, index) {
                    final b = filtered[index];
                    return _buildBookingApprovalCard(b);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: AppErrorCard(error: e)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _statusFilter == key;
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.white : Colors.black87,
      ),
      selectedColor: AppTheme.primary,
      backgroundColor: Colors.grey.shade100,
      showCheckmark: false,
      onSelected: (_) => setState(() => _statusFilter = key),
    );
  }

  Widget _buildBookingApprovalCard(AmenityBookingModel b) {
    Color statusColor = AppStatusColors.paid;
    String statusLabel = 'Đã xác nhận';
    if (b.isPendingPayment) {
      statusColor = AppTheme.warning;
      statusLabel = 'Chờ thanh toán';
    } else if (b.isWaitlist) {
      statusColor = Colors.purple;
      statusLabel = 'Danh sách chờ';
    } else if (b.isCancelled) {
      statusColor = Colors.grey;
      statusLabel = 'Đã hủy';
    } else if (b.isCompleted) {
      statusColor = AppTheme.primary;
      statusLabel = 'Đã Check-in';
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
              Expanded(
                child: Text(
                  'Căn hộ: ${b.apartmentCode ?? "***"} — ${b.amenityName ?? "Tiện ích"}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(_dateFormat.format(b.bookingDate), style: const TextStyle(fontSize: 13)),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schedule, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(b.timeSlot, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_outline, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(b.bookerName ?? 'Cư dân', style: const TextStyle(fontSize: 13)),
                ],
              ),
              if (b.guestsCount > 1)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.groups_outlined, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text('${b.guestsCount} người', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
            ],
          ),
          if (b.feeAmount > 0 || b.depositAmount > 0) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (b.feeAmount > 0)
                  Chip(
                    label: Text('Phí: ${_currencyFormat.format(b.feeAmount)} ${b.isPendingPayment ? "(Chưa thu)" : "(Đã thu)"}', style: const TextStyle(fontSize: 11)),
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
          const Divider(height: 16),

          // Action buttons in Wrap (A7 chuẩn)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (b.isPendingPayment || (!b.isConfirmed && !b.isCancelled && !b.isWaitlist && (b.feeAmount > 0 || b.depositAmount > 0))) ...[
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success, foregroundColor: Colors.white, visualDensity: VisualDensity.compact),
                  icon: const Icon(Icons.payments_outlined, size: 15),
                  label: const Text('Thu phí & Cọc'),
                  onPressed: () => _showConfirmAmenityPaymentDialog(b),
                ),
                OutlinedButton.icon(
                  style: ElevatedButton.styleFrom(foregroundColor: AppTheme.error, side: const BorderSide(color: AppTheme.error), visualDensity: VisualDensity.compact),
                  icon: const Icon(Icons.close, size: 15),
                  label: const Text('Từ chối lịch'),
                  onPressed: () => _showRejectBookingDialog(b),
                ),
              ],
              if (b.isConfirmed) ...[
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppStatusColors.paid, foregroundColor: Colors.white, visualDensity: VisualDensity.compact),
                  icon: const Icon(Icons.qr_code_scanner, size: 15),
                  label: const Text('Check-in'),
                  onPressed: () async {
                    await ref.read(amenityBookingRepositoryProvider).checkInBooking(b.id);
                    ref.invalidate(allAmenityBookingsProvider);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Check-in thành công cho căn hộ ${b.apartmentCode ?? ""}!'), backgroundColor: AppStatusColors.paid),
                      );
                    }
                  },
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: AppTheme.error, side: const BorderSide(color: AppTheme.error), visualDensity: VisualDensity.compact),
                  icon: const Icon(Icons.cancel_outlined, size: 15),
                  label: const Text('Hủy lịch'),
                  onPressed: () => _showRejectBookingDialog(b),
                ),
              ],
              if (b.isWaitlist) ...[
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.error,
                    side: const BorderSide(color: AppTheme.error),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.cancel_outlined, size: 15),
                  label: const Text('Hủy / Xóa khỏi hàng chờ'),
                  onPressed: () => _showRejectBookingDialog(b),
                ),
              ],
              if (b.depositAmount > 0)
                TextButton.icon(
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  icon: const Icon(Icons.shield_outlined, size: 15),
                  label: const Text('Quản lý cọc'),
                  onPressed: () => _showDepositDialog(b),
                ),
              if (b.hasFee || b.transactionCode != null || b.totalPaymentAmount > 0)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: const BorderSide(color: AppTheme.primary),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.receipt_long_outlined, size: 15),
                  label: const Text('Biên nhận'),
                  onPressed: () => _showAmenityReceiptBottomSheet(b),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAmenityReceiptBottomSheet(AmenityBookingModel booking) {
    final isPaid = booking.isConfirmed && !booking.isPendingPayment;
    final receiptCode = 'REC-SVC-${booking.id.length > 8 ? booking.id.substring(0, 8).toUpperCase() : booking.id.toUpperCase()}';
    final txCode = booking.transactionCode ?? 'SVC${booking.id.length > 8 ? booking.id.substring(0, 8).toUpperCase() : booking.id.toUpperCase()}';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paidTime = booking.paidAt ?? booking.updatedAt ?? booking.createdAt;

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
                      color: (isPaid ? AppTheme.success : AppTheme.warning).withValues(alpha: 0.12),
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
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                isPaid
                    ? 'Giao dịch thanh toán dịch vụ tiện ích đã được Ban Quản Lý xác thực'
                    : 'Yêu cầu thanh toán đang chờ Ban Quản Lý đối soát hoặc thu tiền',
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Theme.of(context).colorScheme.surface : const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    _buildReceiptRow(
                      label: 'Mã biên nhận',
                      value: receiptCode,
                      copyValue: receiptCode,
                    ),
                    const Divider(height: 16),
                    _buildReceiptRow(
                      label: 'Căn hộ',
                      value: booking.apartmentCode ?? 'N/A',
                    ),
                    const Divider(height: 16),
                    _buildReceiptRow(
                      label: 'Cư dân đăng ký',
                      value: booking.bookerName ?? 'Cư dân',
                    ),
                    const Divider(height: 16),
                    _buildReceiptRow(
                      label: 'Dịch vụ tiện ích',
                      value: booking.amenityName ?? 'Dịch vụ',
                    ),
                    const Divider(height: 16),
                    _buildReceiptRow(
                      label: 'Thời gian sử dụng',
                      value: '${_dateFormat.format(booking.bookingDate)} (${booking.timeSlot})',
                    ),
                    if (booking.guestsCount > 1) ...[
                      const Divider(height: 16),
                      _buildReceiptRow(
                        label: 'Số người tham gia',
                        value: '${booking.guestsCount} người',
                      ),
                    ],
                    const Divider(height: 16),
                    _buildReceiptRow(
                      label: 'Tổng tiền thực thu',
                      value: _currencyFormat.format(booking.totalPaymentAmount),
                      isHighlight: true,
                    ),
                    if (booking.feeAmount > 0) ...[
                      const Divider(height: 16),
                      _buildReceiptRow(
                        label: 'Phí sử dụng',
                        value: _currencyFormat.format(booking.feeAmount),
                      ),
                    ],
                    if (booking.depositAmount > 0) ...[
                      const Divider(height: 16),
                      _buildReceiptRow(
                        label: 'Tiền đặt cọc',
                        value: '${_currencyFormat.format(booking.depositAmount)} (${booking.depositStatus})',
                      ),
                    ],
                    const Divider(height: 16),
                    _buildReceiptRow(
                      label: 'Phương thức thanh toán',
                      value: booking.paymentMethod == 'CASH'
                          ? 'Tiền mặt tại BQL'
                          : (booking.paymentMethod == 'DEMO'
                              ? 'Demo Payment (Cổng điện tử)'
                              : (booking.paymentMethod == 'BANK_TRANSFER'
                                  ? 'Chuyển khoản (VietQR Mô Phỏng)'
                                  : 'Chuyển khoản ngân hàng')),
                    ),
                    const Divider(height: 16),
                    _buildReceiptRow(
                      label: 'Mã giao dịch đối soát',
                      value: txCode,
                      copyValue: txCode,
                    ),
                    const Divider(height: 16),
                    _buildReceiptRow(
                      label: 'Thời gian ghi nhận',
                      value: DateFormat('dd/MM/yyyy HH:mm').format(paidTime.toLocal()),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.copy, color: Colors.white, size: 18),
                label: const Text(
                  'Sao chép thông tin biên nhận',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  final summary = 'BIÊN NHẬN ĐIỆN TỬ BQL - TIỆN ÍCH PKA-HOME\n'
                      'Mã biên nhận: $receiptCode\n'
                      'Căn hộ: ${booking.apartmentCode ?? "N/A"}\n'
                      'Người đặt: ${booking.bookerName ?? "Cư dân"}\n'
                      'Dịch vụ: ${booking.amenityName ?? "Dịch vụ"}\n'
                      'Thời gian: ${_dateFormat.format(booking.bookingDate)} (${booking.timeSlot})\n'
                      'Số tiền: ${_currencyFormat.format(booking.totalPaymentAmount)}\n'
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

  Widget _buildReceiptRow({
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
          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: isHighlight ? 16 : 13,
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

  // ===========================================================================
  // Tab 2: Cấu Hình Tiện Ích & Sức Chứa Động (Admin Sửa Sức Chứa)
  // ===========================================================================
  Widget _buildAmenitiesConfigTab(List<BuildingAmenityModel> amenities) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Thêm tiện ích'),
        onPressed: () => _showEditAmenityDialog(),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        itemCount: amenities.length,
        itemBuilder: (ctx, index) {
          final a = amenities[index];
          final isShared = a.bookingType == 'shared';

          return AppCard(
            margin: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        a.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isShared ? Colors.blue.shade50 : Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isShared ? 'Dùng chung' : 'Trọn gói',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isShared ? Colors.blue.shade800 : Colors.purple.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
                if (a.description != null && a.description!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(a.description!, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    Chip(
                      avatar: const Icon(Icons.groups, size: 16),
                      label: Text('Sức chứa: ${a.maxCapacity} người', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      backgroundColor: Colors.blue.shade50,
                      visualDensity: VisualDensity.compact,
                    ),
                    Chip(
                      avatar: const Icon(Icons.timer_outlined, size: 16),
                      label: Text('${a.slotDurationMinutes} phút/slot', style: const TextStyle(fontSize: 12)),
                      backgroundColor: Colors.grey.shade100,
                      visualDensity: VisualDensity.compact,
                    ),
                    Chip(
                      avatar: const Icon(Icons.payments_outlined, size: 16),
                      label: Text('Phí: ${_currencyFormat.format(a.feeAmount)}', style: const TextStyle(fontSize: 12)),
                      backgroundColor: Colors.grey.shade100,
                      visualDensity: VisualDensity.compact,
                    ),
                    if (a.depositAmount > 0)
                      Chip(
                        avatar: const Icon(Icons.shield_outlined, size: 16),
                        label: Text('Cọc: ${_currencyFormat.format(a.depositAmount)}', style: const TextStyle(fontSize: 12)),
                        backgroundColor: Colors.amber.shade50,
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Giờ mở cửa: ${a.openHours ?? "06:00 - 22:00"}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primary, visualDensity: VisualDensity.compact),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Sửa cấu hình'),
                    onPressed: () => _showEditAmenityDialog(amenity: a),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ===========================================================================
  // Tab 3: Lịch Bảo Trì (với bộ chọn tiện ích & ngày)
  // ===========================================================================
  Widget _buildMaintenanceTabWithSelector(List<BuildingAmenityModel> amenities) {
    if (amenities.isEmpty) {
      return const Center(child: Text('Chưa có tiện ích nào.'));
    }

    if (_selectedAmenityId == null || !amenities.any((a) => a.id == _selectedAmenityId)) {
      _selectedAmenityId = amenities.first.id;
    }
    final selectedAmenity = amenities.firstWhere(
      (a) => a.id == _selectedAmenityId,
      orElse: () => amenities.first,
    );

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  key: ValueKey(_selectedAmenityId),
                  initialValue: _selectedAmenityId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Chọn tiện ích',
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(),
                  ),
                  items: amenities.map((a) {
                    return DropdownMenuItem<String>(
                      value: a.id,
                      child: Text(a.name, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedAmenityId = val);
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
                  label: Text(
                    _dateFormat.format(_selectedDate),
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  onPressed: _selectDate,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(child: _buildMaintenanceTab(selectedAmenity)),
      ],
    );
  }

  Widget _buildMaintenanceTab(BuildingAmenityModel amenity) {
    final query = AmenityDateQuery(amenityId: amenity.id, date: _selectedDate);
    final maintenanceAsync = ref.watch(amenityMaintenanceForDateProvider(query));

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Thêm Lịch Bảo Trì'),
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
                    Text('Tiện ích hoạt động bình thường trong ngày ${_dateFormat.format(_selectedDate)}'),
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
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.build, color: Colors.orange, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_timeFormat.format(w.startTime)} - ${_timeFormat.format(w.endTime)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(w.reason, style: TextStyle(color: Colors.grey.shade700)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Xóa lịch bảo trì'),
                              content: const Text('Bạn có chắc muốn mở lại tiện ích trong khung giờ này không?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white),
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Xóa'),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            try {
                              await ref.read(amenityBookingRepositoryProvider).deleteMaintenanceWindow(w.id);
                              ref.invalidate(amenityMaintenanceForDateProvider(query));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Đã gỡ bỏ lịch bảo trì!'), backgroundColor: AppStatusColors.paid),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(formatErrorMessage(e)), backgroundColor: AppTheme.error),
                                );
                              }
                            }
                          }
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
