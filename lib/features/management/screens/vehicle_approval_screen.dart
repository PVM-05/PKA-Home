import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_card.dart';
import '../../../core/widgets/app_skeleton_shimmer.dart';
import '../../../core/widgets/photo_viewer_screen.dart';
import '../../../data/models/parking_slot_model.dart';
import '../../../data/models/vehicle_model.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/parking_provider.dart';
import '../../../data/providers/vehicle_provider.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../core/widgets/role_guard.dart';
import '../../../core/constants/permissions.dart';

class VehicleApprovalScreen extends ConsumerStatefulWidget {
  const VehicleApprovalScreen({super.key});

  @override
  ConsumerState<VehicleApprovalScreen> createState() =>
      _VehicleApprovalScreenState();
}

class _VehicleApprovalScreenState extends ConsumerState<VehicleApprovalScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: 'đ',
  );
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String? _getStatusForTabIndex(int index) {
    switch (index) {
      case 1:
        return 'pending';
      case 2:
        return 'approved';
      case 3:
        return 'rejected';
      case 0:
      default:
        return null;
    }
  }

  Future<void> _approveVehicle(VehicleModel vehicle) async {
    List<ParkingSlotModel> availableCarSlots = [];
    if (vehicle.isCar) {
      try {
        availableCarSlots =
            await ref.read(parkingRepositoryProvider).fetchAvailableCarSlots();
      } catch (e) {
        // Fallback or ignore
      }
    }

    ParkingSlotModel? selectedSlot =
        availableCarSlots.isNotEmpty ? availableCarSlots.first : null;

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: AppStatusColors.paid),
              SizedBox(width: 8),
              Expanded(child: Text('Phê Duyệt Đăng Ký Xe')),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bạn có chắc chắn muốn phê duyệt cấp thẻ gửi xe cho phương tiện biển số:',
                ),
                const SizedBox(height: 8),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.black26),
                    ),
                    child: Text(
                      vehicle.licensePlate,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Biểu phí ${vehicle.vehicleTypeDisplayName}: ${_currencyFormat.format(vehicle.monthlyFee)}/tháng sẽ tự động được cộng vào hóa đơn căn hộ.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
                if (vehicle.isCar) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Vị trí ô đỗ tầng hầm (B1/B2):',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (availableCarSlots.isNotEmpty) ...[
                    DropdownButtonFormField<ParkingSlotModel>(
                      initialValue: selectedSlot,
                      decoration: InputDecoration(
                        labelText: 'Chọn ô đỗ ô tô còn trống',
                        prefixIcon: const Icon(
                          Icons.local_parking,
                          color: AppTheme.primary,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      items: availableCarSlots.map((s) {
                        return DropdownMenuItem(
                          value: s,
                          child: Text('${s.slotNumber} (Tầng ${s.zone})'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setDialogState(() {
                          selectedSlot = val;
                        });
                      },
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 16,
                            color: AppTheme.warning,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Hết ô đỗ ô tô trống ở hầm B1/B2. Phương tiện sẽ được duyệt nhưng chưa thể gán ô đỗ cố định.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.warning,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppStatusColors.paid,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('Xác nhận duyệt'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final user = ref.read(authProvider).valueOrNull;
        await ref.read(vehicleRepositoryProvider).approveVehicle(
              vehicle.id,
              parkingSlotId: selectedSlot?.id,
              parkingSlotNumber: selectedSlot?.slotNumber,
              approvedBy: user?.id,
            );
        ref.invalidate(parkingSlotsProvider);
        _refreshData();
        if (mounted) {
          final slotMsg = selectedSlot != null
              ? ' và đã gán ô đỗ ${selectedSlot!.slotNumber}'
              : '';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Đã phê duyệt thành công phương tiện ${vehicle.licensePlate}$slotMsg!',
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
    }
  }

  Future<void> _rejectVehicle(VehicleModel vehicle) async {
    final reasonController = TextEditingController();
    final quickReasons = [
      'Biển số không hợp lệ',
      'Vượt quá hạn mức xe máy',
      'Thiếu thông tin xác thực',
    ];

    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.cancel_outlined, color: AppTheme.error),
                SizedBox(width: 8),
                Expanded(child: Text('Từ Chối Đăng Ký')),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bạn có chắc chắn muốn từ chối đăng ký phương tiện biển số "${vehicle.licensePlate}" không?',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Lý do từ chối (tùy chọn):',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: quickReasons.map((reason) {
                      final isSelected = reasonController.text == reason;
                      return ChoiceChip(
                        label: Text(
                          reason,
                          style: const TextStyle(fontSize: 12),
                        ),
                        selected: isSelected,
                        onSelected: (selected) {
                          setDialogState(() {
                            reasonController.text = selected ? reason : '';
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: reasonController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText:
                          'Nhập lý do từ chối cụ thể để cư dân nắm thông tin...',
                      hintStyle: const TextStyle(fontSize: 13),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.all(10),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.error,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  final reasonText = reasonController.text.trim();
                  Navigator.pop(ctx, reasonText.isEmpty ? '' : reasonText);
                },
                child: const Text('Từ chối'),
              ),
            ],
          );
        },
      ),
    );

    if (result != null && mounted) {
      try {
        final reasonParam = result.isEmpty ? null : result;
        await ref
            .read(vehicleRepositoryProvider)
            .rejectVehicle(vehicle.id, reason: reasonParam);
        _refreshData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã từ chối đăng ký xe ${vehicle.licensePlate}!'),
              backgroundColor: AppTheme.error,
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
  }

  void _refreshData() {
    ref.invalidate(allVehiclesProvider(null));
    ref.invalidate(allVehiclesProvider('pending'));
    ref.invalidate(allVehiclesProvider('approved'));
    ref.invalidate(allVehiclesProvider('rejected'));
    ref.invalidate(pendingVehiclesCountProvider);
  }

  IconData _getVehicleIcon(String type) {
    switch (type) {
      case 'car':
        return Icons.directions_car;
      case 'electric_bicycle':
        return Icons.electric_bike;
      case 'motorbike':
      default:
        return Icons.two_wheeler;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingCountAsync = ref.watch(pendingVehiclesCountProvider);
    final currentStatus = _getStatusForTabIndex(_tabController.index);
    final vehiclesAsync = ref.watch(allVehiclesProvider(currentStatus));

    return RoleGuard(
      permission: AppPermissions.vehicleApproval,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              const Flexible(
                child: Text(
                  'Duyệt Đăng Ký Phương Tiện',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              pendingCountAsync.when(
                data: (count) {
                  if (count == 0) return const SizedBox.shrink();
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.warning,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (e, st) => const SizedBox.shrink(),
              ),
            ],
          ),
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textSecondary,
            indicatorColor: AppTheme.primary,
            tabs: const [
              Tab(text: 'Tất cả'),
              Tab(text: 'Chờ duyệt'),
              Tab(text: 'Đã duyệt'),
              Tab(text: 'Đã từ chối'),
            ],
          ),
        ),
        body: Column(
          children: [
            // Thanh tìm kiếm
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Tìm theo biển số xe hoặc dòng xe...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),

            // Danh sách phương tiện
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => _refreshData(),
                child: vehiclesAsync.when(
                  data: (vehicles) {
                    final keyword = _searchController.text.trim().toLowerCase();
                    final filtered = vehicles.where((v) {
                      if (keyword.isEmpty) return true;
                      final plate = v.licensePlate.toLowerCase();
                      final brand = (v.brandModel ?? '').toLowerCase();
                      final type = v.vehicleTypeDisplayName.toLowerCase();
                      return plate.contains(keyword) ||
                          brand.contains(keyword) ||
                          type.contains(keyword);
                    }).toList();

                    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
                    final pendingCount = vehicles.where((v) => v.isPending).length;

                    if (filtered.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isDesktop) ...[
                              _buildExecutiveKpiBar(
                                context,
                                vehicles,
                                pendingCount,
                              ),
                              const SizedBox(height: 32),
                            ],
                            Icon(
                              Icons.directions_car_outlined,
                              size: 56,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Không tìm thấy phương tiện nào phù hợp.',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    if (isDesktop) {
                      return Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1400),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              children: [
                                _buildExecutiveKpiBar(
                                  context,
                                  vehicles,
                                  pendingCount,
                                ),
                                const SizedBox(height: 16),
                                Expanded(
                                  child: GridView.builder(
                                    padding: const EdgeInsets.only(bottom: 24),
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 2,
                                          crossAxisSpacing: 16,
                                          mainAxisSpacing: 16,
                                          mainAxisExtent: 290,
                                        ),
                                    itemCount: filtered.length,
                                    itemBuilder: (context, index) =>
                                        _buildVehicleApprovalCard(
                                          context,
                                          filtered[index],
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 600),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) =>
                              _buildVehicleApprovalCard(
                                context,
                                filtered[index],
                              ),
                        ),
                      ),
                    );
                  },
                  loading: () => ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      AppSkeletonShimmer.cardList(count: 4, itemHeight: 110),
                    ],
                  ),
                  error: (e, _) => Center(child: AppErrorCard(error: e)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExecutiveKpiBar(
    BuildContext context,
    List<VehicleModel> vehicles,
    int pendingCount,
  ) {
    final approvedCount = vehicles.where((v) => v.isApproved).length;
    final rejectedCount = vehicles.where((v) => v.isRejected).length;
    final totalCount = vehicles.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _buildKpiItem(
                'Chờ duyệt',
                '$pendingCount xe',
                AppTheme.warning,
                Icons.pending_actions,
              ),
            ),
            const VerticalDivider(width: 24, thickness: 1),
            Expanded(
              child: _buildKpiItem(
                'Đang hoạt động',
                '$approvedCount xe',
                AppStatusColors.paid,
                Icons.check_circle_outline,
              ),
            ),
            const VerticalDivider(width: 24, thickness: 1),
            Expanded(
              child: _buildKpiItem(
                'Đã từ chối',
                '$rejectedCount xe',
                AppTheme.error,
                Icons.cancel_outlined,
              ),
            ),
            const VerticalDivider(width: 24, thickness: 1),
            Expanded(
              child: _buildKpiItem(
                'Tổng đăng ký',
                '$totalCount xe',
                AppTheme.primary,
                Icons.directions_car_outlined,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiItem(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleApprovalCard(BuildContext context, VehicleModel v) {
    Color statusColor = AppTheme.warning;
    if (v.isApproved) statusColor = AppStatusColors.paid;
    if (v.isRejected) statusColor = AppTheme.error;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getVehicleIcon(v.vehicleType),
                  color: statusColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      v.licensePlate,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${v.vehicleTypeDisplayName}${v.brandModel != null && v.brandModel!.isNotEmpty ? ' • ${v.brandModel}' : ''}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 95),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      v.statusDisplayName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.payment_outlined,
                      size: 15,
                      color: AppTheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Biểu phí: ${_currencyFormat.format(v.monthlyFee)}/tháng',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'Đăng ký: ${_dateFormat.format(v.createdAt)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          if (v.hasAssignedSlot) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.local_parking,
                    size: 14,
                    color: AppTheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Vị trí ô đỗ: ${v.parkingSlotNumber}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (v.hasRegistrationImage) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () {
                final repo = ref.read(vehicleRepositoryProvider);
                final url = repo.getRegistrationImageUrl(
                  v.registrationImageUrl,
                );
                if (url.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PhotoViewerScreen(imageUrls: [url]),
                    ),
                  );
                }
              },
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.badge_outlined,
                      size: 13,
                      color: AppTheme.primary,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Xem ảnh cà vẹt xe',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.open_in_new,
                      size: 11,
                      color: AppTheme.primary,
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (v.isRejected) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.error.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 15,
                    color: AppTheme.error,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Lý do từ chối: ${v.hasRejectionReason ? v.rejectionReason! : 'Không đủ điều kiện cấp thẻ xe.'}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (v.isPending) ...[
            const Divider(height: 16),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 6,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.error,
                    side: const BorderSide(color: AppTheme.error),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.close, size: 14),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Từ chối'),
                  ),
                  onPressed: () => _rejectVehicle(v),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppStatusColors.paid,
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.check, size: 14),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Phê duyệt'),
                  ),
                  onPressed: () => _approveVehicle(v),
                ),
              ],
            ),
          ] else if (v.isRejected) ...[
            const Divider(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: TextButton.icon(
                  icon: const Icon(Icons.refresh, size: 15),
                  label: const Text('Xem xét duyệt lại'),
                  onPressed: () => _approveVehicle(v),
                ),
              ),
            ),
          ] else if (v.isApproved) ...[
            const Divider(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.error,
                  ),
                  icon: const Icon(Icons.block, size: 15),
                  label: const Text('Thu hồi thẻ gửi xe'),
                  onPressed: () => _rejectVehicle(v),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
