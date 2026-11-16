import 'package:flutter/material.dart';
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
import '../widgets/add_amenity_maintenance_dialog.dart';
import '../widgets/amenity_confirm_payment_dialog.dart';
import '../widgets/amenity_deposit_dialog.dart';
import '../widgets/amenity_inspection_dialog.dart';
import '../widgets/amenity_management_receipt_sheet.dart';
import '../widgets/amenity_quick_check_in_dialog.dart';
import '../widgets/amenity_reject_dialog.dart';
import '../widgets/edit_amenity_dialog.dart';


class AmenityManagementScreen extends ConsumerStatefulWidget {
  const AmenityManagementScreen({super.key});

  @override
  ConsumerState<AmenityManagementScreen> createState() =>
      _AmenityManagementScreenState();
}

class _AmenityManagementScreenState
    extends ConsumerState<AmenityManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedAmenityId;
  DateTime _selectedDate = DateTime.now();
  String _statusFilter =
      'all'; // 'all', 'pending', 'confirmed', 'completed', 'cancelled'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  final DateFormat _timeFormat = DateFormat('HH:mm');
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: 'đ',
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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

  Widget _buildInspectionStationTab() {
    final pendingAsync = ref.watch(pendingAmenityInspectionsProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(pendingAmenityInspectionsProvider),
      child: pendingAsync.when(
        data: (bookings) {
          if (bookings.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.assignment_turned_in_outlined,
                    size: 64,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Không có ca nào cần nghiệm thu hoặc xử lý cọc',
                    style: TextStyle(color: Colors.grey, fontSize: 15),
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
              return AppCard(
                margin: const EdgeInsets.only(bottom: 12),
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
                              b.amenityName ?? 'Tiện ích',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: b.isCheckedIn
                                  ? Colors.green.shade50
                                  : Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: b.isCheckedIn
                                    ? Colors.green.shade200
                                    : Colors.amber.shade200,
                              ),
                            ),
                            child: Text(
                              b.isCheckedIn ? 'Đã check-in' : 'Chờ nghiệm thu',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: b.isCheckedIn
                                    ? Colors.green.shade800
                                    : Colors.amber.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Căn hộ: ${b.apartmentCode ?? b.apartmentId} • Người đặt: ${b.bookerName ?? "Cư dân"}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Ngày: ${_dateFormat.format(b.bookingDate)} • Ca: ${b.timeSlot}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tiền cọc đã nộp: ${_currencyFormat.format(b.depositAmount)} (${b.depositStatus})',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppStatusColors.paid,
                        ),
                      ),
                      if (b.qrTicketToken != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Mã vé: ${b.qrTicketToken}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.fact_check, size: 16),
                            label: const Text('Nghiệm Thu Mặt Bằng'),
                            onPressed: () => showAmenityInspectionDialog(context: context, ref: ref, booking: b),
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
              onPressed: () => showAmenityQuickCheckInDialog(context: context, ref: ref, selectedAmenityId: _selectedAmenityId, selectedDate: _selectedDate),
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: AppTheme.primary,
            indicatorColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textSecondary,
            tabs: const [
              Tab(
                icon: Icon(Icons.fact_check_outlined),
                text: 'Duyệt Lịch Đặt Chỗ',
              ),
              Tab(icon: Icon(Icons.tune_outlined), text: 'Tiện Ích & Sức Chứa'),
              Tab(icon: Icon(Icons.build_outlined), text: 'Lịch Bảo Trì'),
              Tab(
                icon: Icon(Icons.assignment_turned_in_outlined),
                text: 'Nghiệm Thu Cọc',
              ),
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
                _buildInspectionStationTab(),
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
                    hintText:
                        'Tìm theo căn hộ (VD: A0110) hoặc tên người đặt...',
                    prefixIcon: const Icon(Icons.search),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
                  onChanged: (val) =>
                      setState(() => _searchQuery = val.trim().toLowerCase()),
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
                    if (!code.contains(_searchQuery) &&
                        !name.contains(_searchQuery)) {
                      return false;
                    }
                  }
                  // Lọc theo status chip
                  if (_statusFilter == 'pending') {
                    return b.isPendingPayment ||
                        (!b.isConfirmed && !b.isCancelled && !b.isCompleted);
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
                        Icon(
                          Icons.inbox_outlined,
                          size: 56,
                          color: Colors.grey.shade300,
                        ),
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
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
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
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _dateFormat.format(b.bookingDate),
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schedule, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    b.timeSlot,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 14,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    b.bookerName ?? 'Cư dân',
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
              if (b.guestsCount > 1)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.groups_outlined,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${b.guestsCount} người',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
                    label: Text(
                      'Phí: ${_currencyFormat.format(b.feeAmount)} ${b.isPendingPayment ? "(Chưa thu)" : "(Đã thu)"}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                if (b.depositAmount > 0)
                  Chip(
                    label: Text(
                      'Cọc: ${_currencyFormat.format(b.depositAmount)} (${b.depositStatus})',
                      style: const TextStyle(fontSize: 11),
                    ),
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
              if (b.isPendingPayment ||
                  (!b.isConfirmed &&
                      !b.isCancelled &&
                      !b.isWaitlist &&
                      (b.feeAmount > 0 || b.depositAmount > 0))) ...[
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.payments_outlined, size: 15),
                  label: const Text('Thu phí & Cọc'),
                  onPressed: () => showAmenityConfirmPaymentDialog(context: context, ref: ref, booking: b, selectedAmenityId: _selectedAmenityId, selectedDate: _selectedDate),
                ),
                OutlinedButton.icon(
                  style: ElevatedButton.styleFrom(
                    foregroundColor: AppTheme.error,
                    side: const BorderSide(color: AppTheme.error),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.close, size: 15),
                  label: const Text('Từ chối lịch'),
                  onPressed: () => showAmenityRejectDialog(context: context, ref: ref, booking: b, selectedAmenityId: _selectedAmenityId, selectedDate: _selectedDate),
                ),
              ],
              if (b.isConfirmed) ...[
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppStatusColors.paid,
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.qr_code_scanner, size: 15),
                  label: const Text('Check-in'),
                  onPressed: () async {
                    try {
                      await ref
                          .read(amenityBookingRepositoryProvider)
                          .checkInBooking(b.id);
                      ref.invalidate(allAmenityBookingsProvider);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Check-in thành công cho căn hộ ${b.apartmentCode ?? ""}!',
                            ),
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
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.error,
                    side: const BorderSide(color: AppTheme.error),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.cancel_outlined, size: 15),
                  label: const Text('Hủy lịch'),
                  onPressed: () => showAmenityRejectDialog(context: context, ref: ref, booking: b, selectedAmenityId: _selectedAmenityId, selectedDate: _selectedDate),
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
                  onPressed: () => showAmenityRejectDialog(context: context, ref: ref, booking: b, selectedAmenityId: _selectedAmenityId, selectedDate: _selectedDate),
                ),
              ],
              if (b.depositAmount > 0)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.shield_outlined, size: 15),
                  label: const Text('Quản lý cọc'),
                  onPressed: () => showAmenityDepositDialog(context: context, ref: ref, booking: b),
                ),
              if (b.hasFee ||
                  b.transactionCode != null ||
                  b.totalPaymentAmount > 0)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: const BorderSide(color: AppTheme.primary),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.receipt_long_outlined, size: 15),
                  label: const Text('Biên nhận'),
                  onPressed: () => showAmenityManagementReceiptSheet(context: context, booking: b),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // Tab 2: Cấu Hình Tiện Ích & Sức Chứa Động (Admin Sửa Sức Chứa)
  // ===========================================================================
  Widget _buildAmenitiesConfigTab(List<BuildingAmenityModel> amenities) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Thêm tiện ích'),
        onPressed: () => showEditAmenityDialog(context: context, ref: ref),
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
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isShared
                            ? Colors.blue.shade50
                            : Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isShared ? 'Dùng chung' : 'Trọn gói',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isShared
                              ? Colors.blue.shade800
                              : Colors.purple.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
                if (a.description != null && a.description!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    a.description!,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    Chip(
                      avatar: const Icon(Icons.groups, size: 16),
                      label: Text(
                        'Sức chứa: ${a.maxCapacity} người',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      backgroundColor: Colors.blue.shade50,
                      visualDensity: VisualDensity.compact,
                    ),
                    Chip(
                      avatar: const Icon(Icons.timer_outlined, size: 16),
                      label: Text(
                        '${a.slotDurationMinutes} phút/slot',
                        style: const TextStyle(fontSize: 12),
                      ),
                      backgroundColor: Colors.grey.shade100,
                      visualDensity: VisualDensity.compact,
                    ),
                    Chip(
                      avatar: const Icon(Icons.payments_outlined, size: 16),
                      label: Text(
                        'Phí: ${_currencyFormat.format(a.feeAmount)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      backgroundColor: Colors.grey.shade100,
                      visualDensity: VisualDensity.compact,
                    ),
                    if (a.depositAmount > 0)
                      Chip(
                        avatar: const Icon(Icons.shield_outlined, size: 16),
                        label: Text(
                          'Cọc: ${_currencyFormat.format(a.depositAmount)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        backgroundColor: Colors.amber.shade50,
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Giờ mở cửa: ${a.openHours ?? "06:00 - 22:00"}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Sửa cấu hình'),
                    onPressed: () => showEditAmenityDialog(context: context, ref: ref, amenity: a),
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
  Widget _buildMaintenanceTabWithSelector(
    List<BuildingAmenityModel> amenities,
  ) {
    if (amenities.isEmpty) {
      return const Center(child: Text('Chưa có tiện ích nào.'));
    }

    if (_selectedAmenityId == null ||
        !amenities.any((a) => a.id == _selectedAmenityId)) {
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
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
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
    final maintenanceAsync = ref.watch(
      amenityMaintenanceForDateProvider(query),
    );

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Thêm Lịch Bảo Trì'),
        onPressed: () => showAddAmenityMaintenanceDialog(context: context, ref: ref, amenityId: amenity.id, selectedDate: _selectedDate),
      ),
      body: RefreshIndicator(
        onRefresh: () async =>
            ref.invalidate(amenityMaintenanceForDateProvider(query)),
        child: maintenanceAsync.when(
          data: (windows) {
            if (windows.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 48,
                      color: Colors.green.shade300,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tiện ích hoạt động bình thường trong ngày ${_dateFormat.format(_selectedDate)}',
                    ),
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
                        child: const Icon(
                          Icons.build,
                          color: Colors.orange,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_timeFormat.format(w.startTime)} - ${_timeFormat.format(w.endTime)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              w.reason,
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: AppTheme.error,
                        ),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Xóa lịch bảo trì'),
                              content: const Text(
                                'Bạn có chắc muốn mở lại tiện ích trong khung giờ này không?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Hủy'),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.error,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Xóa'),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            try {
                              await ref
                                  .read(amenityBookingRepositoryProvider)
                                  .deleteMaintenanceWindow(w.id);
                              ref.invalidate(
                                amenityMaintenanceForDateProvider(query),
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Đã gỡ bỏ lịch bảo trì!'),
                                    backgroundColor: AppStatusColors.paid,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(formatErrorMessage(e)),
                                    backgroundColor: AppTheme.error,
                                  ),
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
