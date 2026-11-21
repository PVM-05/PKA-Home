import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_search_field.dart';
import '../../../core/widgets/app_skeleton_shimmer.dart';
import '../../../data/models/building_amenity_model.dart';
import '../../../data/models/amenity_booking_model.dart';
import '../../../data/providers/handbook_provider.dart';
import '../../../data/providers/amenity_booking_provider.dart';
import 'amenity_booking_screen.dart';

/// Màn hình Quản lý & Đặt lịch Tiện ích chung dành cho Cư dân.
/// Tách biệt độc lập khỏi Cẩm nang theo kiến trúc thông tin (IA) 2026:
/// - Tab 1: Danh mục tiện ích (Hồ bơi, BBQ, Sân tennis, Phòng gym...) kèm giờ mở cửa, sức chứa và nút đặt lịch.
/// - Tab 2: Lịch đặt của tôi (theo dõi trạng thái duyệt, mã QR check-in và ca sử dụng).
class ResidentAmenitiesScreen extends ConsumerStatefulWidget {
  const ResidentAmenitiesScreen({super.key});

  @override
  ConsumerState<ResidentAmenitiesScreen> createState() =>
      _ResidentAmenitiesScreenState();
}

class _ResidentAmenitiesScreenState extends ConsumerState<ResidentAmenitiesScreen>
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tiện Ích Tòa Nhà'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primary,
          tabs: const [
            Tab(icon: Icon(Icons.pool_outlined), text: 'Danh mục tiện ích'),
            Tab(icon: Icon(Icons.calendar_month_outlined), text: 'Lịch đặt của tôi'),
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
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: AppSearchField(
              controller: _searchCtrl,
              hintText: 'Tìm tiện ích (Hồ bơi, BBQ, Gym, Tennis)...',
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase().trim()),
              onClear: () => setState(() => _searchQuery = ''),
            ),
          ),
          Expanded(
            child: amenitiesAsync.when(
              loading: () => ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  AppSkeletonShimmer.cardList(count: 3, itemHeight: 140),
                ],
              ),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    formatErrorMessage(err),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.error),
                  ),
                ),
              ),
              data: (amenities) {
                final filtered = amenities.where((a) {
                  if (!a.isActive) return false;
                  if (_searchQuery.isEmpty) return true;
                  return a.name.toLowerCase().contains(_searchQuery) ||
                      (a.description?.toLowerCase().contains(_searchQuery) ?? false);
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
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return _buildAmenityCard(item);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmenityCard(BuildingAmenityModel amenity) {
    final feeText = amenity.feeAmount > 0
        ? _currencyFormat.format(amenity.feeAmount)
        : 'Miễn phí';

    return AppCard(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.pool_rounded,
                  color: AppTheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
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
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (amenity.openHours != null && amenity.openHours!.isNotEmpty)
                          _buildBadge(
                            icon: Icons.access_time,
                            label: amenity.openHours!,
                            color: AppStatusColors.paid,
                          ),
                        _buildBadge(
                          icon: Icons.people_outline,
                          label: 'Tối đa ${amenity.maxCapacity} người',
                          color: AppTheme.primary,
                        ),
                        _buildBadge(
                          icon: Icons.monetization_on_outlined,
                          label: feeText,
                          color: amenity.feeAmount > 0
                              ? Colors.amber.shade800
                              : AppStatusColors.paid,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (amenity.description != null && amenity.description!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              amenity.description!,
              style: context.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
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
              icon: const Icon(Icons.calendar_month_outlined, size: 20),
              label: const Text(
                'Đặt lịch sử dụng',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AmenityBookingScreen(amenity: amenity),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
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
      child: myBookingsAsync.when(
        loading: () => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppSkeletonShimmer.cardList(count: 3, itemHeight: 110),
          ],
        ),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              formatErrorMessage(err),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.error),
            ),
          ),
        ),
        data: (bookings) {
          if (bookings.isEmpty) {
            return const AppEmptyState(
              title: 'Bạn chưa có lịch đặt tiện ích nào',
              description: 'Chọn tiện ích từ danh mục bên cạnh để đặt trước ca sử dụng.',
              icon: Icons.event_available_outlined,
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              final booking = bookings[index];
              return _buildBookingCard(booking, dateFormat);
            },
          );
        },
      ),
    );
  }

  Widget _buildBookingCard(AmenityBookingModel booking, DateFormat dateFormat) {
    Color statusColor;
    String statusLabel;

    switch (booking.status) {
      case 'confirmed':
        statusColor = AppStatusColors.paid;
        statusLabel = 'Đã xác nhận';
        break;
      case 'checked_in':
        statusColor = AppTheme.primary;
        statusLabel = 'Đang sử dụng';
        break;
      case 'pending_payment':
        statusColor = Colors.amber.shade800;
        statusLabel = 'Chờ đặt cọc';
        break;
      case 'waitlist':
        statusColor = Colors.orange.shade800;
        statusLabel = 'Danh sách chờ';
        break;
      case 'cancelled':
        statusColor = AppTheme.error;
        statusLabel = 'Đã hủy';
        break;
      case 'completed':
      default:
        statusColor = AppTheme.textSecondary;
        statusLabel = 'Hoàn thành';
        break;
    }

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  booking.amenityName ?? 'Tiện ích tòa nhà',
                  style: context.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 14, color: AppTheme.textSecondary),
              const SizedBox(width: 6),
              Text(
                dateFormat.format(booking.bookingDate),
                style: context.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.access_time, size: 14, color: AppTheme.textSecondary),
              const SizedBox(width: 6),
              Text(
                booking.timeSlot,
                style: context.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          if (booking.depositAmount > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Tiền cọc: ${_currencyFormat.format(booking.depositAmount)} (${booking.depositStatus == 'received' ? 'Đã thu' : 'Chờ nộp'})',
              style: context.bodySmall?.copyWith(
                color: booking.depositStatus == 'received'
                    ? AppStatusColors.paid
                    : Colors.amber.shade800,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
