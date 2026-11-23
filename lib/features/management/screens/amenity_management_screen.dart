import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/permissions.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_card.dart';
import '../../../core/widgets/app_skeleton_shimmer.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/role_guard.dart';
import '../../../data/models/amenity_booking_model.dart';
import '../../../data/models/building_amenity_model.dart';
import '../../../data/providers/amenity_booking_provider.dart';
import '../../../data/providers/handbook_provider.dart';
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
    final colorScheme = Theme.of(context).colorScheme;
    final successColor = AppTheme.getSemanticSuccess(context);
    final warningColor = AppTheme.getSemanticWarning(context);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(pendingAmenityInspectionsProvider),
      child: pendingAsync.when(
        data: (bookings) {
          if (bookings.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 80),
                AppEmptyState(
                  icon: Icons.assignment_turned_in_outlined,
                  title: 'Không có ca chờ nghiệm thu',
                  description: 'Không có ca nào cần nghiệm thu hoặc xử lý cọc',
                ),
              ],
            );
          }

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: AppSpacing.p16,
                itemCount: bookings.length,
                itemBuilder: (context, index) {
                  final b = bookings[index];
                  final badgeColor = b.isCheckedIn
                      ? successColor
                      : warningColor;

                  return AppCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: AppSpacing.p4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  b.amenityName ?? 'Tiện ích',
                                  style: context.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              AppSpacing.w8,
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: badgeColor.withValues(alpha: 0.12),
                                  borderRadius: AppRadius.r8,
                                  border: Border.all(
                                    color: badgeColor.withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Text(
                                  b.isCheckedIn
                                      ? 'Đã check-in'
                                      : 'Chờ nghiệm thu',
                                  style: context.labelSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: badgeColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          AppSpacing.h8,
                          Text(
                            'Căn hộ: ${b.apartmentCode ?? b.apartmentId} • Người đặt: ${b.bookerName ?? "Cư dân"}',
                            style: context.bodySmall
                                ?.copyWith(fontWeight: FontWeight.w500)
                                .tabularFigures(),
                          ),
                          AppSpacing.h4,
                          Text(
                            'Ngày: ${_dateFormat.format(b.bookingDate)} • Ca: ${b.timeSlot}',
                            style: context.bodySmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant)
                                .tabularFigures(),
                          ),
                          AppSpacing.h4,
                          Text(
                            'Tiền cọc đã nộp: ${_currencyFormat.format(b.depositAmount)} (${b.depositStatus})',
                            style: context.bodySmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: successColor,
                                )
                                .tabularFigures(),
                          ),
                          if (b.qrTicketToken != null) ...[
                            AppSpacing.h4,
                            Text(
                              'Mã vé: ${b.qrTicketToken}',
                              style: context.labelSmall
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  )
                                  .tabularFigures(),
                            ),
                          ],
                          AppSpacing.h12,
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorScheme.primary,
                                foregroundColor: colorScheme.onPrimary,
                                minimumSize: const Size(0, 48),
                              ),
                              icon: const Icon(Icons.fact_check, size: 16),
                              label: const Text('Nghiệm Thu Mặt Bằng'),
                              onPressed: () => showAmenityInspectionDialog(
                                context: context,
                                ref: ref,
                                booking: b,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
        loading: () => ListView(
          padding: AppSpacing.p16,
          children: [AppSkeletonShimmer.cardList(count: 3, itemHeight: 150)],
        ),
        error: (e, _) => Center(
          child: AppErrorCard(
            error: e,
            onRetry: () => ref.invalidate(pendingAmenityInspectionsProvider),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final amenitiesAsync = ref.watch(buildingAmenitiesProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return RoleGuard(
      permission: AppPermissions.amenityManagement,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Quản Trị Tiện Ích'),
          actions: [
            IconButton(
              icon: const Icon(Icons.qr_code_scanner_outlined),
              tooltip: 'Quét / Nhập mã Check-in',
              onPressed: () => showAmenityQuickCheckInDialog(
                context: context,
                ref: ref,
                selectedAmenityId: _selectedAmenityId,
                selectedDate: _selectedDate,
              ),
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: colorScheme.primary,
            indicatorColor: colorScheme.primary,
            unselectedLabelColor: colorScheme.onSurfaceVariant,
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
          loading: () => ListView(
            padding: AppSpacing.p16,
            children: [AppSkeletonShimmer.cardList(count: 4, itemHeight: 140)],
          ),
          error: (e, _) => Center(
            child: AppErrorCard(
              error: e,
              onRetry: () => ref.invalidate(buildingAmenitiesProvider),
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // Tab 1: Duyệt Lịch Đặt Chỗ Toàn Tòa Nhà
  // ===========================================================================
  Widget _buildGlobalBookingsApprovalTab(List<BuildingAmenityModel> amenities) {
    final allBookingsAsync = ref.watch(allAmenityBookingsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(allAmenityBookingsProvider),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            children: [
              // Bộ lọc tìm kiếm & Filter Chips
              Container(
                color: colorScheme.surface,
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
                        border: OutlineInputBorder(borderRadius: AppRadius.r12),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                tooltip: 'Xóa tìm kiếm',
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
                      onChanged: (val) => setState(
                        () => _searchQuery = val.trim().toLowerCase(),
                      ),
                    ),
                    AppSpacing.h8,
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('all', 'Tất cả'),
                          AppSpacing.w8,
                          _buildFilterChip(
                            'pending',
                            'Chờ duyệt / thanh toán',
                          ),
                          AppSpacing.w8,
                          _buildFilterChip('confirmed', 'Đã xác nhận'),
                          AppSpacing.w8,
                          _buildFilterChip('completed', 'Đã Check-in'),
                          AppSpacing.w8,
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
                    final filtered = bookings.where((b) {
                      if (_searchQuery.isNotEmpty) {
                        final code = (b.apartmentCode ?? '').toLowerCase();
                        final name = (b.bookerName ?? '').toLowerCase();
                        if (!code.contains(_searchQuery) &&
                            !name.contains(_searchQuery)) {
                          return false;
                        }
                      }
                      if (_statusFilter == 'pending') {
                        return b.isPendingPayment ||
                            (!b.isConfirmed &&
                                !b.isCancelled &&
                                !b.isCompleted);
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
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 60),
                          AppEmptyState(
                            icon: Icons.inbox_outlined,
                            title: 'Chưa có lịch đặt chỗ',
                            description:
                                'Không có lịch đặt nào phù hợp với bộ lọc.',
                          ),
                        ],
                      );
                    }

                    return ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: AppSpacing.p16,
                      itemCount: filtered.length,
                      itemBuilder: (ctx, index) =>
                          _buildBookingApprovalCard(filtered[index]),
                    );
                  },
                  loading: () => ListView(
                    padding: AppSpacing.p16,
                    children: [
                      AppSkeletonShimmer.cardList(count: 4, itemHeight: 150),
                    ],
                  ),
                  error: (e, _) => Center(
                    child: AppErrorCard(
                      error: e,
                      onRetry: () => ref.invalidate(allAmenityBookingsProvider),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _statusFilter == key;
    final colorScheme = Theme.of(context).colorScheme;

    return FilterChip(
      selected: isSelected,
      label: Text(label),
      labelStyle: context.labelSmall?.copyWith(
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
      ),
      selectedColor: colorScheme.primary,
      backgroundColor: colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.5,
      ),
      showCheckmark: false,
      onSelected: (_) => setState(() => _statusFilter = key),
    );
  }

  Widget _buildBookingApprovalCard(AmenityBookingModel b) {
    final colorScheme = Theme.of(context).colorScheme;
    final successColor = AppTheme.getSemanticSuccess(context);
    final warningColor = AppTheme.getSemanticWarning(context);
    final errorColor = AppTheme.getSemanticError(context);
    final secondaryColor = AppTheme.getSemanticSecondary(context);

    Color statusColor = successColor;
    String statusLabel = 'Đã xác nhận';
    if (b.isPendingPayment) {
      statusColor = warningColor;
      statusLabel = 'Chờ thanh toán';
    } else if (b.isWaitlist) {
      statusColor = secondaryColor;
      statusLabel = 'Danh sách chờ';
    } else if (b.isCancelled) {
      statusColor = colorScheme.onSurfaceVariant;
      statusLabel = 'Đã hủy';
    } else if (b.isCompleted) {
      statusColor = colorScheme.primary;
      statusLabel = 'Đã Check-in';
    } else if (b.isNoShow) {
      statusColor = errorColor;
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
                  style: context.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)
                      .tabularFigures(),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              AppSpacing.w8,
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: AppRadius.r8,
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
          AppSpacing.h8,
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
                    color: colorScheme.onSurfaceVariant,
                  ),
                  AppSpacing.w4,
                  Text(
                    _dateFormat.format(b.bookingDate),
                    style: context.bodySmall?.tabularFigures(),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.schedule,
                    size: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  AppSpacing.w4,
                  Text(
                    b.timeSlot,
                    style: context.bodySmall
                        ?.copyWith(fontWeight: FontWeight.w600)
                        .tabularFigures(),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  AppSpacing.w4,
                  Text(b.bookerName ?? 'Cư dân', style: context.bodySmall),
                ],
              ),
              if (b.guestsCount > 1)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.groups_outlined,
                      size: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    AppSpacing.w4,
                    Text(
                      '${b.guestsCount} người',
                      style: context.bodySmall
                          ?.copyWith(fontWeight: FontWeight.w600)
                          .tabularFigures(),
                    ),
                  ],
                ),
            ],
          ),
          if (b.feeAmount > 0 || b.depositAmount > 0) ...[
            AppSpacing.h8,
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (b.feeAmount > 0)
                  Chip(
                    label: Text(
                      'Phí: ${_currencyFormat.format(b.feeAmount)} ${b.isPendingPayment ? "(Chưa thu)" : "(Đã thu)"}',
                      style: context.labelSmall?.tabularFigures(),
                    ),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                if (b.depositAmount > 0)
                  Chip(
                    label: Text(
                      'Cọc: ${_currencyFormat.format(b.depositAmount)} (${b.depositStatus})',
                      style: context.labelSmall?.tabularFigures(),
                    ),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
          const Divider(height: 16),

          // Action buttons in Wrap
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
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
                      backgroundColor: AppTheme.textSuccess,
                      foregroundColor: colorScheme.onPrimary,
                      minimumSize: const Size(0, 48),
                    ),
                    icon: const Icon(Icons.payments_outlined, size: 16),
                    label: const Text('Thu phí & Cọc'),
                    onPressed: () => showAmenityConfirmPaymentDialog(
                      context: context,
                      ref: ref,
                      booking: b,
                      selectedAmenityId: _selectedAmenityId,
                      selectedDate: _selectedDate,
                    ),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: errorColor,
                      side: BorderSide(color: errorColor),
                      minimumSize: const Size(0, 48),
                    ),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Từ chối lịch'),
                    onPressed: () => showAmenityRejectDialog(
                      context: context,
                      ref: ref,
                      booking: b,
                      selectedAmenityId: _selectedAmenityId,
                      selectedDate: _selectedDate,
                    ),
                  ),
                ],
                if (b.isConfirmed) ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.textSuccess,
                      foregroundColor: colorScheme.onPrimary,
                      minimumSize: const Size(0, 48),
                    ),
                    icon: const Icon(Icons.qr_code_scanner, size: 16),
                    label: const Text('Check-in'),
                    onPressed: () async {
                      try {
                        await ref
                            .read(amenityBookingRepositoryProvider)
                            .checkInBooking(b.id);
                        ref.invalidate(allAmenityBookingsProvider);
                        if (mounted) {
                          AppSnackBar.showSuccess(
                            context,
                            'Check-in thành công cho căn hộ ${b.apartmentCode ?? ""}!',
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          AppSnackBar.showError(context, formatErrorMessage(e));
                        }
                      }
                    },
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: errorColor,
                      side: BorderSide(color: errorColor),
                      minimumSize: const Size(0, 48),
                    ),
                    icon: const Icon(Icons.cancel_outlined, size: 16),
                    label: const Text('Hủy lịch'),
                    onPressed: () => showAmenityRejectDialog(
                      context: context,
                      ref: ref,
                      booking: b,
                      selectedAmenityId: _selectedAmenityId,
                      selectedDate: _selectedDate,
                    ),
                  ),
                ],
                if (b.isWaitlist) ...[
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: errorColor,
                      side: BorderSide(color: errorColor),
                      minimumSize: const Size(0, 48),
                    ),
                    icon: const Icon(Icons.cancel_outlined, size: 16),
                    label: const Text('Hủy / Xóa khỏi hàng chờ'),
                    onPressed: () => showAmenityRejectDialog(
                      context: context,
                      ref: ref,
                      booking: b,
                      selectedAmenityId: _selectedAmenityId,
                      selectedDate: _selectedDate,
                    ),
                  ),
                ],
                if (b.depositAmount > 0)
                  TextButton.icon(
                    style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                    icon: const Icon(Icons.shield_outlined, size: 16),
                    label: const Text('Quản lý cọc'),
                    onPressed: () => showAmenityDepositDialog(
                      context: context,
                      ref: ref,
                      booking: b,
                    ),
                  ),
                if (b.hasFee ||
                    b.transactionCode != null ||
                    b.totalPaymentAmount > 0)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.primary,
                      side: BorderSide(color: colorScheme.primary),
                      minimumSize: const Size(0, 48),
                    ),
                    icon: const Icon(Icons.receipt_long_outlined, size: 16),
                    label: const Text('Biên nhận'),
                    onPressed: () => showAmenityManagementReceiptSheet(
                      context: context,
                      booking: b,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Tab 2: Cấu Hình Tiện Ích & Sức Chứa Động
  // ===========================================================================
  Widget _buildAmenitiesConfigTab(List<BuildingAmenityModel> amenities) {
    final colorScheme = Theme.of(context).colorScheme;
    final secondaryColor = AppTheme.getSemanticSecondary(context);
    final warningColor = AppTheme.getSemanticWarning(context);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        icon: const Icon(Icons.add),
        label: const Text('Thêm tiện ích'),
        onPressed: () => showEditAmenityDialog(context: context, ref: ref),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: amenities.isEmpty
              ? const AppEmptyState(
                  icon: Icons.tune_outlined,
                  title: 'Chưa có tiện ích nào',
                  description:
                      'Nhấn "Thêm tiện ích" để cấu hình tiện ích chung cho tòa nhà.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                  itemCount: amenities.length,
                  itemBuilder: (ctx, index) {
                    final a = amenities[index];
                    final isShared = a.bookingType == 'shared';
                    final typeColor = isShared
                        ? colorScheme.primary
                        : secondaryColor;

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
                                  style: context.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              AppSpacing.w8,
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: typeColor.withValues(alpha: 0.12),
                                  borderRadius: AppRadius.r8,
                                ),
                                child: Text(
                                  isShared ? 'Dùng chung' : 'Trọn gói',
                                  style: context.labelSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: typeColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (a.description != null &&
                              a.description!.isNotEmpty) ...[
                            AppSpacing.h6,
                            Text(
                              a.description!,
                              style: context.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                          AppSpacing.h12,
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              Chip(
                                avatar: Icon(
                                  Icons.groups,
                                  size: 16,
                                  color: colorScheme.primary,
                                ),
                                label: Text(
                                  'Sức chứa: ${a.maxCapacity} người',
                                  style: context.labelSmall
                                      ?.copyWith(fontWeight: FontWeight.bold)
                                      .tabularFigures(),
                                ),
                                backgroundColor: colorScheme.primary.withValues(
                                  alpha: 0.1,
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                              Chip(
                                avatar: const Icon(
                                  Icons.timer_outlined,
                                  size: 16,
                                ),
                                label: Text(
                                  '${a.slotDurationMinutes} phút/slot',
                                  style: context.labelSmall?.tabularFigures(),
                                ),
                                backgroundColor: colorScheme
                                    .surfaceContainerHighest
                                    .withValues(alpha: 0.6),
                                visualDensity: VisualDensity.compact,
                              ),
                              Chip(
                                avatar: const Icon(
                                  Icons.payments_outlined,
                                  size: 16,
                                ),
                                label: Text(
                                  'Phí: ${_currencyFormat.format(a.feeAmount)}',
                                  style: context.labelSmall?.tabularFigures(),
                                ),
                                backgroundColor: colorScheme
                                    .surfaceContainerHighest
                                    .withValues(alpha: 0.6),
                                visualDensity: VisualDensity.compact,
                              ),
                              if (a.depositAmount > 0)
                                Chip(
                                  avatar: Icon(
                                    Icons.shield_outlined,
                                    size: 16,
                                    color: warningColor,
                                  ),
                                  label: Text(
                                    'Cọc: ${_currencyFormat.format(a.depositAmount)}',
                                    style: context.labelSmall?.tabularFigures(),
                                  ),
                                  backgroundColor: warningColor.withValues(
                                    alpha: 0.12,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                            ],
                          ),
                          AppSpacing.h8,
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 14,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              AppSpacing.w4,
                              Expanded(
                                child: Text(
                                  'Giờ mở cửa: ${a.openHours ?? "06:00 - 22:00"}',
                                  style: context.labelSmall
                                      ?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      )
                                      .tabularFigures(),
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
                                foregroundColor: colorScheme.primary,
                                minimumSize: const Size(0, 48),
                              ),
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              label: const Text('Sửa cấu hình'),
                              onPressed: () => showEditAmenityDialog(
                                context: context,
                                ref: ref,
                                amenity: a,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  // ===========================================================================
  // Tab 3: Lịch Bảo Trì (với bộ chọn tiện ích & ngày)
  // ===========================================================================
  Widget _buildMaintenanceTabWithSelector(
    List<BuildingAmenityModel> amenities,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    if (amenities.isEmpty) {
      return const AppEmptyState(
        icon: Icons.build_outlined,
        title: 'Chưa có tiện ích nào',
        description: 'Vui lòng cấu hình tiện ích trước khi lập lịch bảo trì.',
      );
    }

    if (_selectedAmenityId == null ||
        !amenities.any((a) => a.id == _selectedAmenityId)) {
      _selectedAmenityId = amenities.first.id;
    }
    final selectedAmenity = amenities.firstWhere(
      (a) => a.id == _selectedAmenityId,
      orElse: () => amenities.first,
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Column(
          children: [
            Container(
              color: colorScheme.surface,
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
                        if (val != null) {
                          setState(() => _selectedAmenityId = val);
                        }
                      },
                    ),
                  ),
                  AppSpacing.w12,
                  Expanded(
                    flex: 2,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        shape: AppRadius.shapeSm,
                      ),
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(
                        _dateFormat.format(_selectedDate),
                        style: context.bodySmall?.tabularFigures(),
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
        ),
      ),
    );
  }

  Widget _buildMaintenanceTab(BuildingAmenityModel amenity) {
    final query = AmenityDateQuery(amenityId: amenity.id, date: _selectedDate);
    final maintenanceAsync = ref.watch(
      amenityMaintenanceForDateProvider(query),
    );
    final colorScheme = Theme.of(context).colorScheme;
    final warningColor = AppTheme.getSemanticWarning(context);
    final errorColor = AppTheme.getSemanticError(context);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.textWarning,
        foregroundColor: colorScheme.onPrimary,
        icon: const Icon(Icons.add),
        label: const Text('Thêm Lịch Bảo Trì'),
        onPressed: () => showAddAmenityMaintenanceDialog(
          context: context,
          ref: ref,
          amenityId: amenity.id,
          selectedDate: _selectedDate,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async =>
            ref.invalidate(amenityMaintenanceForDateProvider(query)),
        child: maintenanceAsync.when(
          data: (windows) {
            if (windows.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 60),
                  AppEmptyState(
                    icon: Icons.check_circle_outline,
                    title: 'Không có lịch bảo trì',
                    description:
                        'Tiện ích hoạt động bình thường trong ngày ${_dateFormat.format(_selectedDate)}',
                  ),
                ],
              );
            }

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              itemCount: windows.length,
              itemBuilder: (context, index) {
                final w = windows[index];
                return AppCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: AppSpacing.p12,
                        decoration: BoxDecoration(
                          color: warningColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.build, color: warningColor, size: 22),
                      ),
                      AppSpacing.w12,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_timeFormat.format(w.startTime)} - ${_timeFormat.format(w.endTime)}',
                              style: context.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold)
                                  .tabularFigures(),
                            ),
                            AppSpacing.h4,
                            Text(
                              w.reason,
                              style: context.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Xóa lịch bảo trì',
                        icon: Icon(Icons.delete_outline, color: errorColor),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) {
                              final dialogScheme = Theme.of(ctx).colorScheme;
                              return AlertDialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: AppRadius.r16,
                                ),
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
                                      backgroundColor: dialogScheme.error,
                                      foregroundColor: dialogScheme.onError,
                                      minimumSize: const Size(0, 48),
                                    ),
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Xóa'),
                                  ),
                                ],
                              );
                            },
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
                                AppSnackBar.showSuccess(
                                  context,
                                  'Đã gỡ bỏ lịch bảo trì!',
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                AppSnackBar.showError(
                                  context,
                                  formatErrorMessage(e),
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
          loading: () => ListView(
            padding: AppSpacing.p16,
            children: [AppSkeletonShimmer.cardList(count: 3, itemHeight: 96)],
          ),
          error: (e, _) => Center(
            child: AppErrorCard(
              error: e,
              onRetry: () =>
                  ref.invalidate(amenityMaintenanceForDateProvider(query)),
            ),
          ),
        ),
      ),
    );
  }
}
