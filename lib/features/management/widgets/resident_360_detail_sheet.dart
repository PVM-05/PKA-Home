import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                _buildVehiclesTab(apt?.code),

                // Tab 2: Hóa đơn
                _buildInvoicesTab(apt?.code),

                // Tab 3: Dịch vụ
                _buildServicesTab(apt?.code),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildVehiclesTab(String? aptCode) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AppCard(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.two_wheeler, color: AppTheme.primary, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Honda Vision (Xe máy)', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Biển số: 29A1-12345 • Căn hộ $aptCode', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Đã duyệt', style: TextStyle(fontSize: 11, color: AppTheme.success, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInvoicesTab(String? aptCode) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AppCard(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.receipt_long, color: AppTheme.primary, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Hóa đơn tháng 10/2026', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Tổng tiền: 1.480.000 đ • Căn hộ $aptCode', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Đã thanh toán', style: TextStyle(fontSize: 11, color: AppTheme.success, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildServicesTab(String? aptCode) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AppCard(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.fitness_center, color: AppTheme.primary, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Gói Gym Tháng', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Hạn dùng: 31/10/2026 • Căn hộ $aptCode', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Đang dùng', style: TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
