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
import '../../../core/widgets/photo_viewer_screen.dart';
import '../../../core/widgets/role_guard.dart';
import '../../../data/models/parking_slot_model.dart';
import '../../../data/models/vehicle_model.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/parking_provider.dart';
import '../../../data/providers/vehicle_provider.dart';

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
        availableCarSlots = await ref
            .read(parkingRepositoryProvider)
            .fetchAvailableCarSlots();
      } catch (_) {
        // Fallback: cho phép duyệt không gán ô đỗ nếu chưa tải được danh sách
      }
    }

    ParkingSlotModel? selectedSlot = availableCarSlots.isNotEmpty
        ? availableCarSlots.first
        : null;

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final colorScheme = Theme.of(dialogCtx).colorScheme;
          final successColor = AppTheme.getSemanticSuccess(dialogCtx);
          final warningColor = AppTheme.getSemanticWarning(dialogCtx);

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: AppRadius.r16),
            title: Row(
              children: [
                Icon(Icons.check_circle_outline, color: successColor),
                AppSpacing.w8,
                const Expanded(child: Text('Phê Duyệt Đăng Ký Xe')),
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
                  AppSpacing.h8,
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: AppRadius.r8,
                        border: Border.all(color: colorScheme.outline),
                      ),
                      child: Text(
                        vehicle.licensePlate,
                        style: dialogCtx.titleLarge
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            )
                            .tabularFigures(),
                      ),
                    ),
                  ),
                  AppSpacing.h12,
                  Text(
                    'Biểu phí ${vehicle.vehicleTypeDisplayName}: ${_currencyFormat.format(vehicle.monthlyFee)}/tháng sẽ tự động được cộng vào hóa đơn căn hộ.',
                    style: dialogCtx.bodySmall
                        ?.copyWith(color: colorScheme.onSurfaceVariant)
                        .tabularFigures(),
                  ),
                  if (vehicle.isCar) ...[
                    AppSpacing.h16,
                    Text(
                      'Vị trí ô đỗ tầng hầm (B1/B2):',
                      style: dialogCtx.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    AppSpacing.h6,
                    if (availableCarSlots.isNotEmpty) ...[
                      DropdownButtonFormField<ParkingSlotModel>(
                        initialValue: selectedSlot,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Chọn ô đỗ ô tô còn trống',
                          prefixIcon: Icon(
                            Icons.local_parking,
                            color: colorScheme.primary,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: AppRadius.r12,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items: availableCarSlots.map((s) {
                          return DropdownMenuItem(
                            value: s,
                            child: Text(
                              '${s.slotNumber} (Tầng ${s.zone})',
                              overflow: TextOverflow.ellipsis,
                            ),
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
                        padding: AppSpacing.p12,
                        decoration: BoxDecoration(
                          color: warningColor.withValues(alpha: 0.1),
                          borderRadius: AppRadius.r8,
                          border: Border.all(
                            color: warningColor.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 16,
                              color: warningColor,
                            ),
                            AppSpacing.w8,
                            Expanded(
                              child: Text(
                                'Hết ô đỗ ô tô trống ở hầm B1/B2. Phương tiện sẽ được duyệt nhưng chưa thể gán ô đỗ cố định.',
                                style: dialogCtx.labelSmall?.copyWith(
                                  color: warningColor,
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
                  backgroundColor: AppTheme.textSuccess,
                  foregroundColor: colorScheme.onPrimary,
                  minimumSize: const Size(0, 48),
                ),
                onPressed: () => Navigator.pop(dialogCtx, true),
                child: const Text('Xác nhận duyệt'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final user = ref.read(authProvider).valueOrNull;
        await ref
            .read(vehicleRepositoryProvider)
            .approveVehicle(
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
          AppSnackBar.showSuccess(
            context,
            'Đã phê duyệt thành công phương tiện ${vehicle.licensePlate}$slotMsg!',
          );
        }
      } catch (e) {
        if (mounted) {
          AppSnackBar.showError(context, formatErrorMessage(e));
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
        builder: (dialogCtx, setDialogState) {
          final colorScheme = Theme.of(dialogCtx).colorScheme;
          final errorColor = AppTheme.getSemanticError(dialogCtx);

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: AppRadius.r16),
            title: Row(
              children: [
                Icon(Icons.cancel_outlined, color: errorColor),
                AppSpacing.w8,
                const Expanded(child: Text('Từ Chối Đăng Ký')),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bạn có chắc chắn muốn từ chối đăng ký phương tiện biển số "${vehicle.licensePlate}" không?',
                    style: dialogCtx.bodyMedium,
                  ),
                  AppSpacing.h16,
                  Text(
                    'Lý do từ chối (tùy chọn):',
                    style: dialogCtx.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  AppSpacing.h8,
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: quickReasons.map((reason) {
                      final isSelected = reasonController.text == reason;
                      return ChoiceChip(
                        label: Text(reason, style: dialogCtx.labelSmall),
                        selected: isSelected,
                        onSelected: (selected) {
                          setDialogState(() {
                            reasonController.text = selected ? reason : '';
                          });
                        },
                      );
                    }).toList(),
                  ),
                  AppSpacing.h12,
                  TextField(
                    controller: reasonController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText:
                          'Nhập lý do từ chối cụ thể để cư dân nắm thông tin...',
                      hintStyle: dialogCtx.bodySmall,
                      border: OutlineInputBorder(borderRadius: AppRadius.r8),
                      contentPadding: AppSpacing.p12,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, null),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.error,
                  foregroundColor: colorScheme.onError,
                  minimumSize: const Size(0, 48),
                ),
                onPressed: () {
                  final reasonText = reasonController.text.trim();
                  Navigator.pop(dialogCtx, reasonText.isEmpty ? '' : reasonText);
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
          AppSnackBar.showError(
            context,
            'Đã từ chối đăng ký xe ${vehicle.licensePlate}!',
          );
        }
      } catch (e) {
        if (mounted) {
          AppSnackBar.showError(context, formatErrorMessage(e));
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
    final colorScheme = Theme.of(context).colorScheme;

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
              AppSpacing.w8,
              pendingCountAsync.when(
                data: (count) {
                  if (count == 0) return const SizedBox.shrink();
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.textWarning,
                      borderRadius: AppRadius.r12,
                    ),
                    child: Text(
                      '$count',
                      style: context.labelSmall
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onPrimary,
                          )
                          .tabularFigures(),
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
            ],
          ),
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: colorScheme.primary,
            unselectedLabelColor: colorScheme.onSurfaceVariant,
            indicatorColor: colorScheme.primary,
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
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1400),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Tìm theo biển số xe hoặc dòng xe...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              tooltip: 'Xóa tìm kiếm',
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
                      border: OutlineInputBorder(borderRadius: AppRadius.r12),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
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
                    final pendingCount = vehicles
                        .where((v) => v.isPending)
                        .length;

                    if (filtered.isEmpty) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: AppSpacing.p16,
                        children: [
                          if (isDesktop) ...[
                            Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 1400,
                                ),
                                child: _buildExecutiveKpiBar(
                                  context,
                                  vehicles,
                                  pendingCount,
                                ),
                              ),
                            ),
                            AppSpacing.h32,
                          ],
                          const AppEmptyState(
                            icon: Icons.directions_car_outlined,
                            title: 'Không có phương tiện',
                            description:
                                'Không tìm thấy phương tiện nào phù hợp.',
                          ),
                        ],
                      );
                    }

                    if (isDesktop) {
                      final leftCol = <Widget>[];
                      final rightCol = <Widget>[];
                      for (var i = 0; i < filtered.length; i++) {
                        final card = _buildVehicleApprovalCard(
                          context,
                          filtered[i],
                        );
                        if (i.isEven) {
                          leftCol.add(card);
                        } else {
                          rightCol.add(card);
                        }
                      }

                      return SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1400),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                8,
                                16,
                                24,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildExecutiveKpiBar(
                                    context,
                                    vehicles,
                                    pendingCount,
                                  ),
                                  AppSpacing.h16,
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(children: leftCol),
                                      ),
                                      AppSpacing.w16,
                                      Expanded(
                                        child: Column(children: rightCol),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }

                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 680),
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: AppSpacing.p16,
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
                    padding: AppSpacing.p16,
                    children: [
                      AppSkeletonShimmer.cardList(count: 4, itemHeight: 120),
                    ],
                  ),
                  error: (e, _) => Center(
                    child: AppErrorCard(error: e, onRetry: _refreshData),
                  ),
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
    final colorScheme = Theme.of(context).colorScheme;
    final warningColor = AppTheme.getSemanticWarning(context);
    final successColor = AppTheme.getSemanticSuccess(context);
    final errorColor = AppTheme.getSemanticError(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: AppRadius.r16,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _buildKpiItem(
                context,
                'Chờ duyệt',
                '$pendingCount xe',
                warningColor,
                Icons.pending_actions,
              ),
            ),
            VerticalDivider(
              width: 24,
              thickness: 1,
              color: colorScheme.outlineVariant,
            ),
            Expanded(
              child: _buildKpiItem(
                context,
                'Đang hoạt động',
                '$approvedCount xe',
                successColor,
                Icons.check_circle_outline,
              ),
            ),
            VerticalDivider(
              width: 24,
              thickness: 1,
              color: colorScheme.outlineVariant,
            ),
            Expanded(
              child: _buildKpiItem(
                context,
                'Đã từ chối',
                '$rejectedCount xe',
                errorColor,
                Icons.cancel_outlined,
              ),
            ),
            VerticalDivider(
              width: 24,
              thickness: 1,
              color: colorScheme.outlineVariant,
            ),
            Expanded(
              child: _buildKpiItem(
                context,
                'Tổng đăng ký',
                '$totalCount xe',
                colorScheme.primary,
                Icons.directions_car_outlined,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiItem(
    BuildContext context,
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          padding: AppSpacing.p8,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: AppRadius.r12,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        AppSpacing.w10,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: context.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
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
                  style: context.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold, color: color)
                      .tabularFigures(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleApprovalCard(BuildContext context, VehicleModel v) {
    final colorScheme = Theme.of(context).colorScheme;
    final warningColor = AppTheme.getSemanticWarning(context);
    final successColor = AppTheme.getSemanticSuccess(context);
    final errorColor = AppTheme.getSemanticError(context);
    final secondaryColor = AppTheme.getSemanticSecondary(context);

    Color statusColor = warningColor;
    if (v.isApproved) statusColor = successColor;
    if (v.isRejected) statusColor = errorColor;

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
                  borderRadius: AppRadius.r12,
                ),
                child: Icon(
                  _getVehicleIcon(v.vehicleType),
                  color: statusColor,
                  size: 24,
                ),
              ),
              AppSpacing.w12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      v.licensePlate,
                      style: context.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)
                          .tabularFigures(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${v.vehicleTypeDisplayName}${v.brandModel != null && v.brandModel!.isNotEmpty ? ' • ${v.brandModel}' : ''}',
                      style: context.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              AppSpacing.w6,
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 96),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: AppRadius.r8,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      v.statusDisplayName,
                      style: context.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.h12,
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 230),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.payment_outlined,
                      size: 15,
                      color: colorScheme.primary,
                    ),
                    AppSpacing.w4,
                    Flexible(
                      child: Text(
                        'Biểu phí: ${_currencyFormat.format(v.monthlyFee)}/tháng',
                        style: context.labelSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.primary,
                            )
                            .tabularFigures(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'Đăng ký: ${_dateFormat.format(v.createdAt)}',
                style: context.labelSmall
                    ?.copyWith(color: colorScheme.onSurfaceVariant)
                    .tabularFigures(),
              ),
            ],
          ),
          if (v.hasAssignedSlot) ...[
            AppSpacing.h8,
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: AppRadius.r6,
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.local_parking,
                    size: 14,
                    color: colorScheme.primary,
                  ),
                  AppSpacing.w4,
                  Flexible(
                    child: Text(
                      'Vị trí ô đỗ: ${v.parkingSlotNumber}',
                      style: context.labelSmall
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          )
                          .tabularFigures(),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (v.hasRegistrationImage) ...[
            AppSpacing.h8,
            InkWell(
              onTap: () {
                final rawUrl = v.registrationImageUrl?.trim() ?? '';
                if (rawUrl.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PhotoViewerScreen(
                        imageUrls: [rawUrl],
                        defaultBucket: 'vehicle-docs',
                      ),
                    ),
                  );
                }
              },
              borderRadius: AppRadius.r8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: secondaryColor.withValues(alpha: 0.1),
                  borderRadius: AppRadius.r8,
                  border: Border.all(
                    color: secondaryColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.badge_outlined,
                      size: 14,
                      color: secondaryColor,
                    ),
                    AppSpacing.w6,
                    Text(
                      'Xem ảnh cà vẹt xe',
                      style: context.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: secondaryColor,
                      ),
                    ),
                    AppSpacing.w4,
                    Icon(Icons.open_in_new, size: 12, color: secondaryColor),
                  ],
                ),
              ),
            ),
          ],
          if (v.isRejected) ...[
            AppSpacing.h8,
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: errorColor.withValues(alpha: 0.08),
                borderRadius: AppRadius.r8,
                border: Border.all(color: errorColor.withValues(alpha: 0.25)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline, size: 15, color: errorColor),
                  AppSpacing.w6,
                  Expanded(
                    child: Text(
                      'Lý do từ chối: ${v.hasRejectionReason ? v.rejectionReason! : 'Không đủ điều kiện cấp thẻ xe.'}',
                      style: context.labelSmall?.copyWith(
                        color: errorColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (v.isPending) ...[
            const Divider(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: errorColor,
                      side: BorderSide(color: errorColor),
                      minimumSize: const Size(0, 48),
                    ),
                    icon: const Icon(Icons.close, size: 16),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Từ chối'),
                    ),
                    onPressed: () => _rejectVehicle(v),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.textSuccess,
                      foregroundColor: colorScheme.onPrimary,
                      minimumSize: const Size(0, 48),
                    ),
                    icon: const Icon(Icons.check, size: 16),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Phê duyệt'),
                    ),
                    onPressed: () => _approveVehicle(v),
                  ),
                ],
              ),
            ),
          ] else if (v.isRejected) ...[
            const Divider(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: TextButton.icon(
                  style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Xem xét duyệt lại'),
                  onPressed: () => _approveVehicle(v),
                ),
              ),
            ),
          ] else if (v.isApproved) ...[
            const Divider(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: errorColor,
                    minimumSize: const Size(0, 48),
                  ),
                  icon: const Icon(Icons.block, size: 16),
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
