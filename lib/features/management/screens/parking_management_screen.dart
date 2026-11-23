import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/constants/permissions.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/action_runner.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_card.dart';
import '../../../core/widgets/app_skeleton_shimmer.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/role_guard.dart';
import '../../../data/models/apartment_model.dart';
import '../../../data/models/parking_slot_model.dart';
import '../../../data/models/vehicle_model.dart';
import '../../../data/models/visitor_parking_ticket_model.dart';
import '../../../data/providers/management_provider.dart';
import '../../../data/providers/parking_provider.dart';
import '../../../data/providers/vehicle_provider.dart';

class ParkingManagementScreen extends ConsumerStatefulWidget {
  const ParkingManagementScreen({super.key});

  @override
  ConsumerState<ParkingManagementScreen> createState() =>
      _ParkingManagementScreenState();
}

class _ParkingManagementScreenState
    extends ConsumerState<ParkingManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _refreshAll() {
    ref.invalidate(parkingSlotsProvider);
    ref.invalidate(parkingCapacityStatsProvider);
    ref.invalidate(activeVisitorTicketsProvider);
  }

  void _showCheckInDialog() {
    final plateController = TextEditingController();
    final noteController = TextEditingController();
    String selectedType = 'motorcycle';

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final colorScheme = Theme.of(dialogCtx).colorScheme;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: AppRadius.r16),
            title: Row(
              children: [
                Icon(Icons.login_rounded, color: colorScheme.primary),
                AppSpacing.w8,
                const Expanded(child: Text('Check-in Xe Vãng Lai')),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: plateController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Biển số xe',
                      hintText: 'Ví dụ: 30A-999.88',
                      prefixIcon: Icon(Icons.pin_outlined),
                    ),
                  ),
                  AppSpacing.h16,
                  Text(
                    'Loại phương tiện:',
                    style: dialogCtx.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  AppSpacing.h8,
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.two_wheeler, size: 16),
                              SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Xe máy',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          selected: selectedType == 'motorcycle',
                          onSelected: (val) {
                            if (val) {
                              setDialogState(() => selectedType = 'motorcycle');
                            }
                          },
                        ),
                      ),
                      AppSpacing.w8,
                      Expanded(
                        child: ChoiceChip(
                          label: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.directions_car, size: 16),
                              SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Ô tô',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          selected: selectedType == 'car',
                          onSelected: (val) {
                            if (val) {
                              setDialogState(() => selectedType = 'car');
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.h16,
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(
                      labelText: 'Ghi chú / Khách phòng nào',
                      hintText: 'Ví dụ: Khách thăm phòng A0110...',
                      prefixIcon: Icon(Icons.note_alt_outlined),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  minimumSize: const Size(0, 48),
                ),
                onPressed: () async {
                  final plate = plateController.text.trim().toUpperCase();
                  if (plate.isEmpty) return;
                  Navigator.pop(dialogCtx);

                  final repo = ref.read(parkingRepositoryProvider);
                  final res = await repo.createVisitorTicket(
                    licensePlate: plate,
                    vehicleType: selectedType,
                    note: noteController.text.trim(),
                  );

                  if (mounted) {
                    ref.invalidate(activeVisitorTicketsProvider);
                    ref.invalidate(parkingCapacityStatsProvider);
                    if (res['success'] == true &&
                        res['ticket'] is VisitorParkingTicketModel) {
                      _showTicketDetailModal(
                        res['ticket'] as VisitorParkingTicketModel,
                      );
                    }
                  }
                },
                child: const Text('Tạo Vé Xe'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showTicketDetailModal(VisitorParkingTicketModel ticket) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: SingleChildScrollView(
            padding: AppSpacing.p24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Vé Xe Điện Tử: ${ticket.ticketCode}',
                  style: ctx.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)
                      .tabularFigures(),
                  textAlign: TextAlign.center,
                ),
                AppSpacing.h8,
                Text(
                  'Biển số: ${ticket.licensePlate} (${ticket.displayVehicleType})',
                  style: ctx.titleSmall
                      ?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      )
                      .tabularFigures(),
                ),
                AppSpacing.h16,
                Container(
                  padding: AppSpacing.p12,
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: AppRadius.r12,
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: SizedBox(
                    height: 180,
                    width: 180,
                    child: QrImageView(
                      data: ticket.qrPayload,
                      version: QrVersions.auto,
                      size: 180,
                    ),
                  ),
                ),
                AppSpacing.h12,
                Text(
                  'Giờ vào: ${DateFormat('dd/MM/yyyy HH:mm').format(ticket.checkInAt)}',
                  style: ctx.bodySmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant)
                      .tabularFigures(),
                ),
                AppSpacing.h20,
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Đóng'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showCheckoutDialog(VisitorParkingTicketModel ticket) async {
    final repo = ref.read(parkingRepositoryProvider);
    final feeRes = await repo.calculateVisitorFee(ticket.id);
    final fee = (feeRes['fee_amount'] as num?)?.toDouble() ?? ticket.feeAmount;
    final hours = (feeRes['total_hours'] as num?)?.toInt() ?? 1;

    final format = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    final formattedFee = format.format(fee).trim();

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: AppRadius.r16),
          title: Row(
            children: [
              Icon(Icons.receipt_long, color: colorScheme.primary),
              AppSpacing.w8,
              const Expanded(child: Text('Check-out & Thu Phí')),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Biển số: ${ticket.licensePlate}',
                  style: ctx.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)
                      .tabularFigures(),
                ),
                AppSpacing.h6,
                Text('Loại xe: ${ticket.displayVehicleType}'),
                Text('Thời gian đã đỗ: $hours giờ'),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Tổng tiền thu:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      formattedFee,
                      style: ctx.titleLarge
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          )
                          .tabularFigures(),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: () async {
                Navigator.pop(ctx);
                await repo.checkoutVisitorTicket(
                  ticketId: ticket.id,
                  paymentMethod: 'cash',
                );
                ref.invalidate(activeVisitorTicketsProvider);
                ref.invalidate(parkingCapacityStatsProvider);
              },
              child: const Text('Thu Tiền Mặt'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                minimumSize: const Size(0, 48),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                await repo.checkoutVisitorTicket(
                  ticketId: ticket.id,
                  paymentMethod: 'vietqr',
                );
                ref.invalidate(activeVisitorTicketsProvider);
                ref.invalidate(parkingCapacityStatsProvider);
              },
              child: const Text('Quét VietQR'),
            ),
          ],
        );
      },
    );
  }

  void _showAssignSlotDialog(ParkingSlotModel slot) {
    VehicleModel? selectedVehicle;
    ApartmentModel? selectedApartment;
    final plateController = TextEditingController();
    final customAptCodeController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final approvedVehiclesAsync = ref.watch(
            allVehiclesProvider('approved'),
          );
          final apartmentsAsync = ref.watch(apartmentsProvider);
          final colorScheme = Theme.of(dialogCtx).colorScheme;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: AppRadius.r16),
            title: Text('Gán Ô Đỗ ${slot.slotNumber}'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Loại ô đỗ: ${slot.slotType == 'car' ? 'Ô tô' : 'Xe máy'} | Khu vực: ${slot.zone}',
                      style: dialogCtx.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    AppSpacing.h16,

                    // 1. Chọn từ danh sách xe đã phê duyệt
                    approvedVehiclesAsync.when(
                      data: (vehicles) {
                        final matchedVehicles = vehicles.where((v) {
                          if (slot.slotType == 'car') {
                            return v.vehicleType == 'car';
                          }
                          return v.vehicleType != 'car';
                        }).toList();

                        return DropdownButtonFormField<VehicleModel>(
                          initialValue: selectedVehicle,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Chọn xe đã duyệt (Khuyến nghị)',
                            prefixIcon: Icon(Icons.directions_car),
                          ),
                          hint: const Text('-- Hoặc chọn xe từ danh sách --'),
                          items: [
                            const DropdownMenuItem<VehicleModel>(
                              value: null,
                              child: Text('Tự nhập biển số / gắn căn hộ'),
                            ),
                            ...matchedVehicles.map(
                              (v) => DropdownMenuItem(
                                value: v,
                                child: Text(
                                  '${v.licensePlate} (${v.brandModel ?? v.vehicleType})',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            setDialogState(() {
                              selectedVehicle = val;
                              if (val != null) {
                                plateController.text = val.licensePlate;
                                final apartments =
                                    apartmentsAsync.valueOrNull ?? [];
                                final aptMatch = apartments
                                    .where((a) => a.id == val.apartmentId)
                                    .firstOrNull;
                                if (aptMatch != null) {
                                  selectedApartment = aptMatch;
                                  customAptCodeController.text = aptMatch.code;
                                }
                              }
                            });
                          },
                        );
                      },
                      loading: () => const LinearProgressIndicator(),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                    AppSpacing.h12,

                    // 2. Chọn căn hộ sở hữu từ danh mục thực tế
                    apartmentsAsync.when(
                      data: (apartments) {
                        return DropdownButtonFormField<ApartmentModel>(
                          initialValue: selectedApartment,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Căn hộ sở hữu *',
                            prefixIcon: Icon(Icons.apartment),
                          ),
                          hint: const Text('Chọn căn hộ...'),
                          items: apartments.map((apt) {
                            return DropdownMenuItem(
                              value: apt,
                              child: Text(
                                'Căn hộ ${apt.code} (${apt.buildingCode})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: selectedVehicle != null
                              ? null
                              : (apt) {
                                  setDialogState(() {
                                    selectedApartment = apt;
                                    if (apt != null) {
                                      customAptCodeController.text = apt.code;
                                    }
                                  });
                                },
                        );
                      },
                      loading: () => const LinearProgressIndicator(),
                      error: (_, _) => TextField(
                        controller: customAptCodeController,
                        decoration: const InputDecoration(
                          labelText: 'Mã căn hộ *',
                          hintText: 'Ví dụ: A0110',
                        ),
                        textCapitalization: TextCapitalization.characters,
                      ),
                    ),
                    AppSpacing.h12,

                    // 3. Biển số xe
                    TextField(
                      controller: plateController,
                      readOnly: selectedVehicle != null,
                      decoration: InputDecoration(
                        labelText: 'Biển số xe *',
                        hintText: 'Ví dụ: 30A-123.45',
                        prefixIcon: const Icon(Icons.pin),
                        suffixIcon: selectedVehicle != null
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                tooltip: 'Bỏ chọn xe mẫu để tự nhập',
                                onPressed: () {
                                  setDialogState(() {
                                    selectedVehicle = null;
                                    plateController.clear();
                                  });
                                },
                              )
                            : null,
                      ),
                      textCapitalization: TextCapitalization.characters,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  minimumSize: const Size(0, 48),
                ),
                onPressed: () async {
                  final plate = plateController.text.trim().toUpperCase();
                  final aptCode =
                      selectedApartment?.code ??
                      customAptCodeController.text.trim().toUpperCase();
                  final aptId = selectedApartment?.id ?? '';

                  if (plate.isEmpty || aptCode.isEmpty) {
                    AppSnackBar.showError(
                      context,
                      'Vui lòng nhập đầy đủ biển số xe và chọn căn hộ!',
                    );
                    return;
                  }

                  Navigator.pop(dialogCtx);

                  final vehicleId = selectedVehicle?.id ?? '';
                  final targetApartmentId = aptId.isNotEmpty ? aptId : aptCode;

                  final repo = ref.read(parkingRepositoryProvider);
                  await runAction(
                    context,
                    () async {
                      await repo.assignSlot(
                        slotId: slot.id,
                        vehicleId: vehicleId,
                        apartmentId: targetApartmentId,
                        slotNumber: slot.slotNumber,
                        licensePlate: plate,
                        apartmentCode: aptCode,
                      );
                      return 'Đã gán ô đỗ ${slot.slotNumber} cho xe $plate (Căn $aptCode) thành công!';
                    },
                    actionName: 'Gán ô đỗ xe',
                  );

                  ref.invalidate(parkingSlotsProvider);
                  ref.invalidate(parkingCapacityStatsProvider);
                },
                child: const Text('Xác nhận gán'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(parkingCapacityStatsProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final secondaryColor = AppTheme.getSemanticSecondary(context);
    final warningColor = AppTheme.getSemanticWarning(context);

    return RoleGuard(
      permission: AppPermissions.parkingManagement,
      child: Scaffold(
        appBar: AppBar(
          title: const FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text('Quản Lý Bãi Xe & Ô Đỗ'),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Làm mới',
              onPressed: _refreshAll,
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            labelColor: colorScheme.primary,
            unselectedLabelColor: colorScheme.onSurfaceVariant,
            indicatorColor: colorScheme.primary,
            tabs: const [
              Tab(icon: Icon(Icons.grid_view_rounded), text: 'Sơ đồ Ô đỗ'),
              Tab(
                icon: Icon(Icons.local_parking_rounded),
                text: 'Trạm soát vé cổng',
              ),
            ],
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1400),
            child: Column(
              children: [
                // KPI strip sức chứa
                statsAsync.when(
                  data: (stats) => Container(
                    color: colorScheme.surfaceContainerLowest,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 420;
                        if (isNarrow) {
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 140,
                                  child: _buildKpiBox(
                                    icon: Icons.directions_car,
                                    label: 'Ô tô hầm',
                                    value:
                                        '${stats.carOccupied}/${stats.carTotal}',
                                    subtext: 'Trống ${stats.carAvailable}',
                                    color: colorScheme.primary,
                                  ),
                                ),
                                AppSpacing.w8,
                                SizedBox(
                                  width: 140,
                                  child: _buildKpiBox(
                                    icon: Icons.two_wheeler,
                                    label: 'Xe máy hầm',
                                    value:
                                        '${stats.motoOccupied}/${stats.motoTotal}',
                                    subtext: 'Trống ${stats.motoAvailable}',
                                    color: secondaryColor,
                                  ),
                                ),
                                AppSpacing.w8,
                                SizedBox(
                                  width: 140,
                                  child: _buildKpiBox(
                                    icon: Icons.confirmation_number_outlined,
                                    label: 'Xe vãng lai',
                                    value: '${stats.visitorCount}',
                                    subtext: 'Đang gửi',
                                    color: warningColor,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildKpiBox(
                                  icon: Icons.directions_car,
                                  label: 'Ô tô hầm',
                                  value:
                                      '${stats.carOccupied}/${stats.carTotal}',
                                  subtext: 'Trống ${stats.carAvailable}',
                                  color: colorScheme.primary,
                                ),
                              ),
                              AppSpacing.w10,
                              Expanded(
                                child: _buildKpiBox(
                                  icon: Icons.two_wheeler,
                                  label: 'Xe máy hầm',
                                  value:
                                      '${stats.motoOccupied}/${stats.motoTotal}',
                                  subtext: 'Trống ${stats.motoAvailable}',
                                  color: secondaryColor,
                                ),
                              ),
                              AppSpacing.w10,
                              Expanded(
                                child: _buildKpiBox(
                                  icon: Icons.confirmation_number_outlined,
                                  label: 'Xe vãng lai',
                                  value: '${stats.visitorCount}',
                                  subtext: 'Đang gửi',
                                  color: warningColor,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  loading: () => const SizedBox(
                    height: 76,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (_, _) => const SizedBox.shrink(),
                ),

                // Nội dung 2 tabs
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [_buildSlotsTab(), _buildGateWorkstationTab()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKpiBox({
    required IconData icon,
    required String label,
    required String value,
    required String subtext,
    required Color color,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: AppSpacing.p12,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: AppRadius.r12,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              AppSpacing.w4,
              Expanded(
                child: Text(
                  label,
                  style: context.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          AppSpacing.h4,
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
          Text(
            subtext,
            style: context.labelSmall
                ?.copyWith(color: colorScheme.onSurfaceVariant)
                .tabularFigures(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSlotsTab() {
    final slotsAsync = ref.watch(parkingSlotsProvider);
    final filter = ref.watch(parkingFilterProvider);

    return Column(
      children: [
        // Thanh bộ lọc
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Tìm số ô, biển số, mã căn...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      tooltip: 'Xóa tìm kiếm',
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        ref.read(parkingFilterProvider.notifier).state = filter
                            .copyWith(searchQuery: '');
                        setState(() {});
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            onChanged: (val) {
              ref.read(parkingFilterProvider.notifier).state = filter.copyWith(
                searchQuery: val,
              );
              setState(() {});
            },
          ),
        ),

        // Chips lọc nhanh
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              FilterChip(
                label: const Text('Tất cả'),
                selected: filter.zone == null && filter.type == null,
                onSelected: (_) {
                  ref.read(parkingFilterProvider.notifier).state =
                      const ParkingFilter();
                },
              ),
              AppSpacing.w6,
              FilterChip(
                label: const Text('Tầng B1'),
                selected: filter.zone == 'B1',
                onSelected: (val) {
                  ref.read(parkingFilterProvider.notifier).state = filter
                      .copyWith(zone: val ? 'B1' : null);
                },
              ),
              AppSpacing.w6,
              FilterChip(
                label: const Text('Tầng B2'),
                selected: filter.zone == 'B2',
                onSelected: (val) {
                  ref.read(parkingFilterProvider.notifier).state = filter
                      .copyWith(zone: val ? 'B2' : null);
                },
              ),
              AppSpacing.w6,
              FilterChip(
                label: const Text('Ô tô'),
                selected: filter.type == 'car',
                onSelected: (val) {
                  ref.read(parkingFilterProvider.notifier).state = filter
                      .copyWith(type: val ? 'car' : null);
                },
              ),
              AppSpacing.w6,
              FilterChip(
                label: const Text('Xe máy'),
                selected: filter.type == 'motorcycle',
                onSelected: (val) {
                  ref.read(parkingFilterProvider.notifier).state = filter
                      .copyWith(type: val ? 'motorcycle' : null);
                },
              ),
            ],
          ),
        ),

        // Lưới các ô đỗ
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => _refreshAll(),
            child: slotsAsync.when(
              loading: () => ListView(
                padding: AppSpacing.p16,
                children: [
                  AppSkeletonShimmer.cardList(count: 4, itemHeight: 110),
                ],
              ),
              error: (err, _) => Center(
                child: AppErrorCard(error: err, onRetry: _refreshAll),
              ),
              data: (slots) {
                if (slots.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 60),
                      AppEmptyState(
                        icon: Icons.local_parking_outlined,
                        title: 'Không có ô đỗ phù hợp',
                        description:
                            'Không có ô đỗ nào phù hợp tiêu chí tìm kiếm',
                      ),
                    ],
                  );
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 420;
                    return GridView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: AppSpacing.p16,
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 250,
                        mainAxisExtent: isNarrow ? 168 : 156,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: slots.length,
                      itemBuilder: (context, index) =>
                          _buildSlotCard(slots[index]),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSlotCard(ParkingSlotModel slot) {
    final colorScheme = Theme.of(context).colorScheme;
    final successColor = AppTheme.getSemanticSuccess(context);
    final warningColor = AppTheme.getSemanticWarning(context);
    final errorColor = AppTheme.getSemanticError(context);

    final Color accentColor;
    if (slot.isOccupied) {
      accentColor = colorScheme.primary;
    } else if (slot.isMaintenance) {
      accentColor = warningColor;
    } else {
      accentColor = successColor;
    }

    return Container(
      padding: AppSpacing.p12,
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.06),
        borderRadius: AppRadius.r12,
        border: Border.all(color: accentColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  slot.slotNumber,
                  style: context.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold)
                      .tabularFigures(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              AppSpacing.w4,
              Icon(
                slot.isCar ? Icons.directions_car : Icons.two_wheeler,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
          if (slot.isOccupied) ...[
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                slot.licensePlate ?? 'Đã có xe',
                style: context.bodySmall
                    ?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    )
                    .tabularFigures(),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    slot.apartmentCode ?? 'Căn hộ',
                    style: context.labelSmall
                        ?.copyWith(color: colorScheme.onSurfaceVariant)
                        .tabularFigures(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                AppSpacing.w4,
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 72),
                  child: InkWell(
                    borderRadius: AppRadius.r6,
                    onTap: () async {
                      final repo = ref.read(parkingRepositoryProvider);
                      await repo.releaseSlot(slot.id);
                      ref.invalidate(parkingSlotsProvider);
                      ref.invalidate(parkingCapacityStatsProvider);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 6,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Giải phóng',
                          style: context.labelSmall?.copyWith(
                            color: errorColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            Text(
              slot.displayStatus,
              style: context.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: slot.isAvailable ? successColor : warningColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: InkWell(
                borderRadius: AppRadius.r6,
                onTap: () => _showAssignSlotDialog(slot),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 6,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Gán xe',
                      style: context.labelSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGateWorkstationTab() {
    final ticketsAsync = ref.watch(activeVisitorTicketsProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final warningColor = AppTheme.getSemanticWarning(context);

    return Column(
      children: [
        // Thanh tác vụ gác cổng
        Padding(
          padding: AppSpacing.p16,
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showCheckInDialog,
              icon: const Icon(Icons.add_circle_outline),
              label: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('Check-in Xe Vào'),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                minimumSize: const Size(0, 48),
              ),
            ),
          ),
        ),

        // Danh sách xe đang gửi
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => _refreshAll(),
            child: ticketsAsync.when(
              loading: () => ListView(
                padding: AppSpacing.p16,
                children: [
                  AppSkeletonShimmer.cardList(count: 3, itemHeight: 130),
                ],
              ),
              error: (err, _) => Center(
                child: AppErrorCard(error: err, onRetry: _refreshAll),
              ),
              data: (tickets) {
                if (tickets.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 60),
                      AppEmptyState(
                        icon: Icons.directions_car_outlined,
                        title: 'Chưa có xe vãng lai',
                        description:
                            'Hiện không có xe vãng lai nào đang gửi trong bãi',
                      ),
                    ],
                  );
                }

                return ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: tickets.length,
                  separatorBuilder: (_, _) => AppSpacing.h12,
                  itemBuilder: (context, index) {
                    final ticket = tickets[index];
                    return AppCard(
                      padding: AppSpacing.p16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Icon(
                                      ticket.isCar
                                          ? Icons.directions_car
                                          : Icons.two_wheeler,
                                      color: colorScheme.primary,
                                    ),
                                    AppSpacing.w8,
                                    Expanded(
                                      child: Text(
                                        ticket.licensePlate,
                                        style: context.titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            )
                                            .tabularFigures(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              AppSpacing.w8,
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 96),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: warningColor.withValues(alpha: 0.12),
                                    borderRadius: AppRadius.r6,
                                  ),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      ticket.displayStatus,
                                      style: context.labelSmall?.copyWith(
                                        color: warningColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
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
                              Text(
                                'Loại xe: ${ticket.displayVehicleType}',
                                style: context.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              Text(
                                'Mã vé: ${ticket.ticketCode}',
                                style: context.bodySmall
                                    ?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    )
                                    .tabularFigures(),
                              ),
                            ],
                          ),
                          AppSpacing.h4,
                          Text(
                            'Vào lúc: ${DateFormat('dd/MM/yyyy HH:mm').format(ticket.checkInAt)}',
                            style: context.bodySmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant)
                                .tabularFigures(),
                          ),
                          if (ticket.note != null &&
                              ticket.note!.isNotEmpty) ...[
                            AppSpacing.h4,
                            Text(
                              'Ghi chú: ${ticket.note}',
                              style: context.bodySmall?.copyWith(
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                          const Divider(height: 20),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(0, 48),
                                ),
                                onPressed: () => _showTicketDetailModal(ticket),
                                icon: const Icon(Icons.qr_code, size: 18),
                                label: const FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text('Xem mã QR vé'),
                                ),
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colorScheme.primary,
                                  foregroundColor: colorScheme.onPrimary,
                                  minimumSize: const Size(0, 48),
                                ),
                                onPressed: () => _showCheckoutDialog(ticket),
                                icon: const Icon(Icons.payment, size: 18),
                                label: const FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text('Check-out & Thu tiền'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
