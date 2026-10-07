import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../data/models/resident_model.dart';
import '../../../data/providers/management_provider.dart';


class Resident360DetailSheet extends ConsumerStatefulWidget {
  final ResidentModel resident;

  const Resident360DetailSheet({
    super.key,
    required this.resident,
  });

  @override
  ConsumerState<Resident360DetailSheet> createState() => _Resident360DetailSheetState();
}

class _Resident360DetailSheetState extends ConsumerState<Resident360DetailSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late bool _isLocked;
  bool _isToggling = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _isLocked = widget.resident.isLocked;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _toggleLock() async {
    setState(() => _isToggling = true);
    final newLockedState = !_isLocked;
    try {
      await ref.read(managementRepositoryProvider).toggleUserLock(widget.resident.id, newLockedState);
      ref.invalidate(residentsProvider);
      setState(() {
        _isLocked = newLockedState;
        _isToggling = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newLockedState ? 'Đã khóa tài khoản thành công.' : 'Đã mở khóa tài khoản.'),
            backgroundColor: newLockedState ? AppTheme.error : AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isToggling = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi cập nhật: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final resident = widget.resident;
    final apt = resident.apartment;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header Profile
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                  child: Text(
                    resident.fullName.isNotEmpty ? resident.fullName[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primary),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        resident.fullName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Căn hộ: ${apt?.code ?? 'Chưa liên kết'} • ${resident.roleDisplayName}',
                        style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            _isLocked ? Icons.lock : Icons.check_circle,
                            size: 14,
                            color: _isLocked ? AppTheme.error : AppTheme.success,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isLocked ? 'Tài khoản bị khóa' : 'Đang hoạt động',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _isLocked ? AppTheme.error : AppTheme.success,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _isToggling ? null : _toggleLock,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _isLocked ? AppTheme.success : AppTheme.error,
                    side: BorderSide(color: _isLocked ? AppTheme.success : AppTheme.error),
                  ),
                  icon: Icon(_isLocked ? Icons.lock_open : Icons.lock_outline, size: 16),
                  label: Text(_isLocked ? 'Mở khóa' : 'Khóa tài khoản'),
                ),
              ],
            ),
          ),

          const Divider(),

          // Tabs: Phương tiện | Hóa đơn | Dịch vụ
          TabBar(
            controller: _tabController,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textSecondary,
            indicatorColor: AppTheme.primary,
            tabs: const [
              Tab(icon: Icon(Icons.two_wheeler_outlined), text: 'Phương tiện'),
              Tab(icon: Icon(Icons.receipt_long_outlined), text: 'Hóa đơn'),
              Tab(icon: Icon(Icons.pool_outlined), text: 'Dịch vụ'),
            ],
          ),

          SizedBox(
            height: 260,
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Phương tiện
                _buildVehiclesTab(apt?.id, apt?.code),

                // Tab 2: Hóa đơn
                _buildInvoicesTab(apt?.id, apt?.code),

                // Tab 3: Dịch vụ
                _buildServicesTab(widget.resident.id, apt?.code),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildVehiclesTab(String? apartmentId, String? aptCode) {
    final vehiclesAsync = ref.watch(residentVehiclesProvider(apartmentId));
    return vehiclesAsync.when(
      data: (vehicles) {
        if (vehicles.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.two_wheeler_outlined, size: 40, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                const SizedBox(height: 8),
                const Text('Chưa có phương tiện nào đăng ký', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: vehicles.length,
          itemBuilder: (context, index) {
            final v = vehicles[index];
            final typeStr = v['vehicle_type'] == 'car' ? 'Ô tô' : (v['vehicle_type'] == 'electric_bicycle' ? 'Xe đạp điện' : 'Xe máy');
            final plate = v['license_plate'] ?? v['plate_number'] ?? 'Chưa rõ';
            final brand = v['brand_model'] ?? typeStr;
            final status = v['status'] as String? ?? 'pending';
            final isApproved = status == 'approved';
            final isRejected = status == 'rejected';

            return AppCard(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(v['vehicle_type'] == 'car' ? Icons.directions_car : Icons.two_wheeler, color: AppTheme.primary, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$brand ($typeStr)', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('Biển số: $plate • Căn hộ ${aptCode ?? "N/A"}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isApproved ? AppTheme.success.withValues(alpha: 0.1) : (isRejected ? AppTheme.error.withValues(alpha: 0.1) : AppTheme.warning.withValues(alpha: 0.1)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isApproved ? 'Đã duyệt' : (isRejected ? 'Bị từ chối' : 'Chờ duyệt'),
                      style: TextStyle(
                        fontSize: 11,
                        color: isApproved ? AppTheme.success : (isRejected ? AppTheme.error : AppTheme.warning),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const Center(child: Text('Lỗi tải danh sách xe', style: TextStyle(color: AppTheme.error))),
    );
  }

  Widget _buildInvoicesTab(String? apartmentId, String? aptCode) {
    final invoicesAsync = ref.watch(residentInvoicesProvider(apartmentId));
    final currencyFmt = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    return invoicesAsync.when(
      data: (invoices) {
        if (invoices.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long_outlined, size: 40, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                const SizedBox(height: 8),
                const Text('Chưa có hóa đơn nào', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: invoices.length,
          itemBuilder: (context, index) {
            final inv = invoices[index];
            final isPaid = inv.status == 'paid';
            return AppCard(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long, color: AppTheme.primary, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Hóa đơn kỳ ${inv.period}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('Tổng tiền: ${currencyFmt.format(inv.totalAmount)} • Căn hộ ${aptCode ?? "N/A"}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isPaid ? AppTheme.success.withValues(alpha: 0.1) : AppTheme.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isPaid ? 'Đã thanh toán' : 'Chưa thanh toán',
                      style: TextStyle(fontSize: 11, color: isPaid ? AppTheme.success : AppTheme.error, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const Center(child: Text('Lỗi tải hóa đơn', style: TextStyle(color: AppTheme.error))),
    );
  }

  Widget _buildServicesTab(String userId, String? aptCode) {
    final bookingsAsync = ref.watch(residentBookingsProvider(userId));
    return bookingsAsync.when(
      data: (bookings) {
        if (bookings.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.sports_tennis_outlined, size: 40, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                const SizedBox(height: 8),
                const Text('Chưa có lịch đặt tiện ích / dịch vụ nào', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: bookings.length,
          itemBuilder: (context, index) {
            final b = bookings[index];
            final amenityName = (b['amenities'] as Map?)?['name'] ?? 'Tiện ích';
            final date = b['booking_date'] ?? '';
            final slot = b['time_slot'] ?? '';
            final status = b['status'] as String? ?? 'confirmed';
            final isConfirmed = status == 'confirmed';
            final isWaitlist = status == 'waitlist';

            return AppCard(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.fitness_center, color: AppTheme.primary, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$amenityName', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('Lịch: $slot ngày $date • Căn hộ ${aptCode ?? "N/A"}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isConfirmed ? AppTheme.primary.withValues(alpha: 0.1) : (isWaitlist ? AppTheme.warning.withValues(alpha: 0.1) : AppTheme.error.withValues(alpha: 0.1)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isConfirmed ? 'Đã đặt' : (isWaitlist ? 'Chờ slot' : 'Đã hủy'),
                      style: TextStyle(
                        fontSize: 11,
                        color: isConfirmed ? AppTheme.primary : (isWaitlist ? AppTheme.warning : AppTheme.error),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const Center(child: Text('Lỗi tải lịch tiện ích', style: TextStyle(color: AppTheme.error))),
    );
  }
}

