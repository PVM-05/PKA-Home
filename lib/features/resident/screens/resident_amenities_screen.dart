import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_card.dart';
import '../../../core/widgets/app_search_field.dart';
import '../../../core/widgets/app_skeleton_shimmer.dart';
import '../../../data/models/amenity_booking_model.dart';
import '../../../data/models/building_amenity_model.dart';
import '../../../data/providers/amenity_booking_provider.dart';
import '../../../data/providers/handbook_provider.dart';

/// Màn hình Quản lý & Đặt lịch Tiện ích chung dành cho Cư dân.
/// - Tab 1: Danh mục tiện ích (Hồ bơi, BBQ, Sân tennis, Phòng gym...) kèm giờ mở cửa, sức chứa và nút đặt lịch.
/// - Tab 2: Lịch đặt của tôi (theo dõi trạng thái duyệt, mã QR check-in và ca sử dụng).
class ResidentAmenitiesScreen extends ConsumerStatefulWidget {
  const ResidentAmenitiesScreen({super.key});

  @override
  ConsumerState<ResidentAmenitiesScreen> createState() =>
      _ResidentAmenitiesScreenState();
}

class _ResidentAmenitiesScreenState
    extends ConsumerState<ResidentAmenitiesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: 'đ',
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tiện Ích Tòa Nhà'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: colorScheme.primary,
          unselectedLabelColor: colorScheme.onSurfaceVariant,
          indicatorColor: colorScheme.primary,
          tabs: const [
            Tab(icon: Icon(Icons.pool_outlined), text: 'Danh mục tiện ích'),
            Tab(
              icon: Icon(Icons.calendar_month_outlined),
              text: 'Lịch đặt của tôi',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAmenityCatalogTab(),
          _buildMyBookingsTab(),
        ],
      ),
    );
  }

  // ─── TAB 1: DANH MỤC TIỆN ÍCH ───
  Widget _buildAmenityCatalogTab() {
    final amenitiesAsync = ref.watch(buildingAmenitiesProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(buildingAmenitiesProvider),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: AppSearchField(
                  controller: _searchCtrl,
                  hintText: 'Tìm tiện ích (Hồ bơi, BBQ, Gym, Tennis)...',
                  onChanged: (val) =>
                      setState(() => _searchQuery = val.toLowerCase().trim()),
                  onClear: () => setState(() => _searchQuery = ''),
                ),
              ),
              Expanded(
                child: amenitiesAsync.when(
                  loading: () => ListView(
                    padding: AppSpacing.p16,
                    children: [
                      AppSkeletonShimmer.cardList(count: 3, itemHeight: 140),
                    ],
                  ),
                  error: (err, _) => Center(
                    child: Padding(
                      padding: AppSpacing.p24,
                      child: AppErrorCard(
                        error: err,
                        onRetry: () =>
                            ref.invalidate(buildingAmenitiesProvider),
                      ),
                    ),
                  ),
                  data: (amenities) {
                    final filtered = amenities.where((a) {
                      if (!a.isActive) return false;
                      if (_searchQuery.isEmpty) return true;
                      return a.name.toLowerCase().contains(_searchQuery) ||
                          (a.description?.toLowerCase().contains(
                                _searchQuery,
                              ) ??
                              false);
                    }).toList();

                    if (filtered.isEmpty) {
                      return AppEmptyState(
                        title: _searchQuery.isEmpty
                            ? 'Chưa có tiện ích nào được thiết lập'
                            : 'Không tìm thấy tiện ích phù hợp',
                        description: _searchQuery.isEmpty
                            ? 'Ban Quản Lý sẽ sớm cập nhật danh mục tiện ích tòa nhà.'
                            : 'Vui lòng thử tìm kiếm với từ khóa khác.',
                        icon: Icons.pool_outlined,
                      );
                    }

                    return ListView.builder(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) =>
                          _buildAmenityCard(context, filtered[index]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAmenityCard(BuildContext context, BuildingAmenityModel amenity) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final successColor = AppTheme.getSemanticSuccess(context);
    final warningColor = AppTheme.getSemanticWarning(context);

    final feeText = amenity.feeAmount > 0
        ? _currencyFormat.format(amenity.feeAmount)
        : 'Miễn phí';

    return AppCard(
      margin: const EdgeInsets.only(bottom: 14),
      padding: AppSpacing.p16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(
                    alpha: isDark ? 0.18 : 0.10,
                  ),
                  borderRadius: AppRadius.r12,
                ),
                child: Icon(
                  Icons.pool_rounded,
                  color: colorScheme.primary,
                  size: 24,
                ),
              ),
              AppSpacing.w12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      amenity.name,
                      style: context.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    AppSpacing.h4,
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (amenity.openHours != null &&
                            amenity.openHours!.isNotEmpty)
                          _buildBadge(
                            context: context,
                            icon: Icons.access_time,
                            label: amenity.openHours!,
                            color: successColor,
                          ),
                        _buildBadge(
                          context: context,
                          icon: Icons.people_outline,
                          label: 'Tối đa ${amenity.maxCapacity} người',
                          color: colorScheme.primary,
                        ),
                        _buildBadge(
                          context: context,
                          icon: Icons.monetization_on_outlined,
                          label: feeText,
                          color: amenity.feeAmount > 0
                              ? warningColor
                              : successColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (amenity.description != null &&
              amenity.description!.isNotEmpty) ...[
            AppSpacing.h12,
            Text(
              amenity.description!,
              style: context.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          AppSpacing.h16,
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.r12,
                ),
              ),
              icon: const Icon(Icons.calendar_month_outlined, size: 20),
              label: const Text(
                'Đặt lịch sử dụng',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                context.push(AppRoutes.residentAmenityBooking, extra: amenity);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.10),
        borderRadius: AppRadius.r8,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          AppSpacing.w4,
          Text(
            label,
            style: context.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  // ─── TAB 2: LỊCH ĐẶT CỦA TÔI ───
  Widget _buildMyBookingsTab() {
    final myBookingsAsync = ref.watch(myAmenityBookingsProvider);
    final dateFormat = DateFormat('dd/MM/yyyy');

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(myAmenityBookingsProvider),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: myBookingsAsync.when(
            loading: () => ListView(
              padding: AppSpacing.p16,
              children: [
                AppSkeletonShimmer.cardList(count: 3, itemHeight: 110),
              ],
            ),
            error: (err, _) => Center(
              child: Padding(
                padding: AppSpacing.p24,
                child: AppErrorCard(
                  error: err,
                  onRetry: () => ref.invalidate(myAmenityBookingsProvider),
                ),
              ),
            ),
            data: (bookings) {
              if (bookings.isEmpty) {
                return const AppEmptyState(
                  title: 'Bạn chưa có lịch đặt tiện ích nào',
                  description:
                      'Chọn tiện ích từ danh mục bên cạnh để đặt trước ca sử dụng.',
                  icon: Icons.event_available_outlined,
                );
              }

              return ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: bookings.length,
                itemBuilder: (context, index) =>
                    _buildBookingCard(context, bookings[index], dateFormat),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBookingCard(
    BuildContext context,
    AmenityBookingModel booking,
    DateFormat dateFormat,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final Color statusColor;
    final String statusLabel;

    switch (booking.status) {
      case 'confirmed':
        statusColor = AppTheme.getSemanticSuccess(context);
        statusLabel = 'Đã xác nhận';
      case 'checked_in':
        statusColor = colorScheme.primary;
        statusLabel = 'Đang sử dụng';
      case 'pending_payment':
        statusColor = AppTheme.getSemanticWarning(context);
        statusLabel = 'Chờ đặt cọc';
      case 'waitlist':
        statusColor = AppTheme.getSemanticSecondary(context);
        statusLabel = 'Danh sách chờ';
      case 'cancelled':
        statusColor = AppTheme.getSemanticError(context);
        statusLabel = 'Đã hủy';
      case 'completed':
      default:
        statusColor = colorScheme.onSurfaceVariant;
        statusLabel = 'Hoàn thành';
    }

    final depositColor = booking.depositStatus == 'received'
        ? AppTheme.getSemanticSuccess(context)
        : AppTheme.getSemanticWarning(context);

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: AppSpacing.p16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  booking.amenityName ?? 'Tiện ích tòa nhà',
                  style: context.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              AppSpacing.w8,
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: isDark ? 0.18 : 0.12),
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
            spacing: 16,
            runSpacing: 6,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 15,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  AppSpacing.w6,
                  Text(
                    dateFormat.format(booking.bookingDate),
                    style: context.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.access_time,
                    size: 15,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  AppSpacing.w6,
                  Text(
                    booking.timeSlot,
                    style: context.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (booking.depositAmount > 0) ...[
            AppSpacing.h8,
            Text(
              'Tiền cọc: ${_currencyFormat.format(booking.depositAmount)} (${booking.depositStatus == 'received' ? 'Đã thu' : 'Chờ nộp'})',
              style: context.bodySmall?.copyWith(
                color: depositColor,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
