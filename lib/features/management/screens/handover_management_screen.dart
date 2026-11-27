import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import '../../../core/constants/permissions.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../core/utils/handover_pdf_builder.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_card.dart';
import '../../../core/widgets/app_skeleton_shimmer.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/role_guard.dart';
import '../../../data/models/apartment_handover_model.dart';
import '../../../data/models/apartment_model.dart';
import '../../../data/providers/building_provider.dart';
import '../../../data/providers/handover_provider.dart';
import '../../../data/providers/management_provider.dart';
import 'inspection_workstation_screen.dart';

class HandoverManagementScreen extends ConsumerStatefulWidget {
  final String buildingId;

  const HandoverManagementScreen({
    super.key,
    this.buildingId = 'bld-01',
  });

  @override
  ConsumerState<HandoverManagementScreen> createState() =>
      _HandoverManagementScreenState();
}

class _HandoverManagementScreenState
    extends ConsumerState<HandoverManagementScreen> {
  String _selectedType = 'all'; // all, move_in, move_out
  String _selectedStatus =
      'all'; // all, draft, pending_resident, confirmed, disputed

  Color _getStatusColor(BuildContext context, String status) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (status) {
      case 'confirmed':
        return AppStatusColors.getPaid(context);
      case 'pending_resident':
        return AppTheme.getSemanticWarning(context);
      case 'disputed':
        return AppTheme.getSemanticError(context);
      case 'draft':
      default:
        return colorScheme.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final activeBuilding = ref.watch(activeBuildingProvider).valueOrNull;
    final effectiveBuildingId =
        (activeBuilding?.id != null && activeBuilding!.id.isNotEmpty)
        ? activeBuilding.id
        : widget.buildingId;
    final handoversAsync = ref.watch(
      buildingHandoversProvider(effectiveBuildingId),
    );
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;

    return RoleGuard(
      permission: AppPermissions.handoverManagement,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Quản lý bàn giao & kiểm kê'),
          elevation: 0.5,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Làm mới',
              onPressed: () =>
                  ref.refresh(buildingHandoversProvider(effectiveBuildingId)),
            ),
          ],
        ),
        body: handoversAsync.when(
          data: (handovers) {
            final totalCount = handovers.length;
            final pendingCount = handovers
                .where((h) => h.status == 'pending_resident')
                .length;
            final confirmedCount = handovers
                .where((h) => h.status == 'confirmed')
                .length;
            final disputedCount = handovers
                .where((h) => h.status == 'disputed')
                .length;

            final filtered = handovers.where((h) {
              if (_selectedType != 'all' && h.handoverType != _selectedType) {
                return false;
              }
              if (_selectedStatus != 'all' && h.status != _selectedStatus) {
                return false;
              }
              return true;
            }).toList();

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1400),
                child: Column(
                  children: [
                    // 1. Dải KPI Header bọc LayoutBuilder chống tràn
                    _buildKpiHeader(
                      totalCount: totalCount,
                      pendingCount: pendingCount,
                      confirmedCount: confirmedCount,
                      disputedCount: disputedCount,
                    ),

                    // 2. Dải bộ lọc
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          FilterChip(
                            selected: _selectedType == 'all',
                            label: const Text('Tất cả loại'),
                            onSelected: (_) =>
                                setState(() => _selectedType = 'all'),
                          ),
                          AppSpacing.w8,
                          FilterChip(
                            selected: _selectedType == 'move_in',
                            label: const Text('Nhận nhà'),
                            onSelected: (_) =>
                                setState(() => _selectedType = 'move_in'),
                          ),
                          AppSpacing.w8,
                          FilterChip(
                            selected: _selectedType == 'move_out',
                            label: const Text('Trả nhà'),
                            onSelected: (_) =>
                                setState(() => _selectedType = 'move_out'),
                          ),
                          const VerticalDivider(width: 24),
                          FilterChip(
                            selected: _selectedStatus == 'all',
                            label: const Text('Mọi trạng thái'),
                            onSelected: (_) =>
                                setState(() => _selectedStatus = 'all'),
                          ),
                          AppSpacing.w8,
                          FilterChip(
                            selected: _selectedStatus == 'pending_resident',
                            label: const Text('Chờ ký'),
                            onSelected: (_) => setState(
                              () => _selectedStatus = 'pending_resident',
                            ),
                          ),
                          AppSpacing.w8,
                          FilterChip(
                            selected: _selectedStatus == 'confirmed',
                            label: const Text('Đã xác nhận'),
                            onSelected: (_) =>
                                setState(() => _selectedStatus = 'confirmed'),
                          ),
                        ],
                      ),
                    ),

                    AppSpacing.h8,

                    // 3. Danh sách biên bản (GridView trên desktop, ListView trên mobile)
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () async => ref.refresh(
                          buildingHandoversProvider(effectiveBuildingId).future,
                        ),
                        child: filtered.isEmpty
                            ? ListView(
                                padding: AppSpacing.p16,
                                children: const [
                                  AppEmptyState(
                                    icon: Icons.inventory_2_outlined,
                                    title: 'Chưa có biên bản bàn giao',
                                    description:
                                        'Chưa có biên bản bàn giao nào phù hợp bộ lọc.',
                                  ),
                                ],
                              )
                            : isDesktop
                            ? GridView.builder(
                                padding: AppSpacing.p16,
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 16,
                                      mainAxisSpacing: 16,
                                      mainAxisExtent: 268,
                                    ),
                                itemCount: filtered.length,
                                itemBuilder: (context, index) =>
                                    _buildHandoverCard(
                                      filtered[index],
                                      effectiveBuildingId,
                                    ),
                              )
                            : ListView.separated(
                                padding: AppSpacing.p16,
                                itemCount: filtered.length,
                                separatorBuilder: (_, _) => AppSpacing.h12,
                                itemBuilder: (context, index) =>
                                    _buildHandoverCard(
                                      filtered[index],
                                      effectiveBuildingId,
                                    ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          loading: () => ListView(
            padding: AppSpacing.p16,
            children: [
              AppSkeletonShimmer.cardList(count: 3, itemHeight: 140),
            ],
          ),
          error: (err, _) => ListView(
            padding: AppSpacing.p16,
            children: [
              AppErrorCard(
                error: err,
                onRetry: () =>
                    ref.refresh(buildingHandoversProvider(effectiveBuildingId)),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            _showCreateHandoverDialog(context, effectiveBuildingId);
          },
          icon: const Icon(Icons.add),
          label: const Text('Tạo biên bản mới'),
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
        ),
      ),
    );
  }

  Widget _buildKpiHeader({
    required int totalCount,
    required int pendingCount,
    required int confirmedCount,
    required int disputedCount,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final warningColor = AppTheme.getSemanticWarning(context);
    final paidColor = AppStatusColors.getPaid(context);
    final errorColor = AppTheme.getSemanticError(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 460;
        if (isNarrow) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: AppSpacing.p16,
            child: Row(
              children: [
                SizedBox(
                  width: 108,
                  child: _buildKpiCard(
                    'Tổng số',
                    totalCount.toString(),
                    Icons.assignment,
                    colorScheme.primary,
                  ),
                ),
                AppSpacing.w8,
                SizedBox(
                  width: 108,
                  child: _buildKpiCard(
                    'Chờ cư dân',
                    pendingCount.toString(),
                    Icons.pending_actions,
                    warningColor,
                  ),
                ),
                AppSpacing.w8,
                SizedBox(
                  width: 108,
                  child: _buildKpiCard(
                    'Đã duyệt',
                    confirmedCount.toString(),
                    Icons.verified,
                    paidColor,
                  ),
                ),
                AppSpacing.w8,
                SizedBox(
                  width: 108,
                  child: _buildKpiCard(
                    'Khiếu nại',
                    disputedCount.toString(),
                    Icons.warning_amber,
                    errorColor,
                  ),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: AppSpacing.p16,
          child: Row(
            children: [
              Expanded(
                child: _buildKpiCard(
                  'Tổng số',
                  totalCount.toString(),
                  Icons.assignment,
                  colorScheme.primary,
                ),
              ),
              AppSpacing.w8,
              Expanded(
                child: _buildKpiCard(
                  'Chờ cư dân',
                  pendingCount.toString(),
                  Icons.pending_actions,
                  warningColor,
                ),
              ),
              AppSpacing.w8,
              Expanded(
                child: _buildKpiCard(
                  'Đã duyệt',
                  confirmedCount.toString(),
                  Icons.verified,
                  paidColor,
                ),
              ),
              AppSpacing.w8,
              Expanded(
                child: _buildKpiCard(
                  'Khiếu nại',
                  disputedCount.toString(),
                  Icons.warning_amber,
                  errorColor,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildKpiCard(String label, String value, IconData icon, Color color) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppRadius.r12,
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          AppSpacing.h4,
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: context.titleMedium?.tabularFigures().copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
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
    );
  }

  Widget _buildHandoverCard(
    ApartmentHandoverModel item,
    String effectiveBuildingId,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusColor = _getStatusColor(context, item.status);
    final isConfirmed = item.status == 'confirmed' || item.status == 'completed';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: AppRadius.r8,
                    ),
                    child: Text(
                      item.reportCode,
                      style: context.bodyMedium?.tabularFigures().copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              AppSpacing.w8,
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: AppRadius.r6,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      item.statusDisplayName,
                      style: context.labelSmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.h8,
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Căn hộ: ${item.apartmentCode ?? 'A0110'}',
                style: context.titleMedium?.tabularFigures().copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Chip(
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                label: Text(
                  item.handoverTypeDisplayName,
                  style: context.labelSmall,
                ),
              ),
            ],
          ),
          AppSpacing.h6,
          Text(
            'Cư dân: ${item.residentName ?? 'Chưa gán'} • Người kiểm kê: ${item.staffName ?? 'BQL'}',
            style: context.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (item.handoverType == 'move_out') ...[
            AppSpacing.h4,
            Text(
              'Tiền cọc: ${_formatCurrency(item.depositHeld)} | Khấu trừ: ${_formatCurrency(item.totalDeduction)} | Hoàn trả: ${_formatCurrency(item.depositRefund)}',
              style: context.bodySmall?.tabularFigures().copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          AppSpacing.h8,
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.picture_as_pdf,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  tooltip: 'Xuất biên bản PDF',
                  onPressed: () async {
                    try {
                      final pdfBytes =
                          await HandoverPdfBuilder.buildHandoverReportPdf(
                            handover: item,
                            items: item.items,
                          );
                      await Printing.layoutPdf(
                        onLayout: (_) async => pdfBytes,
                        name: 'Bien_ban_ban_giao_${item.reportCode}.pdf',
                      );
                    } catch (e) {
                      if (mounted) {
                        AppSnackBar.showError(context, formatErrorMessage(e));
                      }
                    }
                  },
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => InspectionWorkstationScreen(
                          buildingId: item.buildingId.isNotEmpty
                              ? item.buildingId
                              : effectiveBuildingId,
                          apartmentId: item.apartmentId,
                          apartmentCode: item.apartmentCode ?? 'A0110',
                          existingHandoverId: item.id,
                          isReadOnly: isConfirmed,
                        ),
                      ),
                    );
                  },
                  icon: Icon(
                    isConfirmed
                        ? Icons.verified_user_outlined
                        : Icons.edit_note,
                    size: 18,
                  ),
                  label: Text(
                    isConfirmed ? 'Xem biên bản đã ký' : 'Mở trạm kiểm kê',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateHandoverDialog(
    BuildContext context,
    String effectiveBuildingId,
  ) {
    final apartmentsAsync = ref.read(apartmentsProvider);
    final apartments = apartmentsAsync.valueOrNull ?? [];
    ApartmentModel? selectedApartment = apartments.isNotEmpty
        ? apartments.first
        : null;
    final fallbackCodeController = TextEditingController(
      text: selectedApartment?.code ?? 'A0110',
    );
    String type = 'move_in';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Khởi tạo biên bản bàn giao'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (apartments.isNotEmpty) ...[
                  DropdownButtonFormField<ApartmentModel>(
                    initialValue: selectedApartment,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Chọn căn hộ bàn giao *',
                      prefixIcon: Icon(Icons.home),
                    ),
                    items: apartments.map((apt) {
                      return DropdownMenuItem<ApartmentModel>(
                        value: apt,
                        child: Text('${apt.code} (Tầng ${apt.floorNumber})'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          selectedApartment = val;
                          fallbackCodeController.text = val.code;
                        });
                      }
                    },
                  ),
                ] else ...[
                  TextField(
                    controller: fallbackCodeController,
                    decoration: const InputDecoration(
                      labelText: 'Mã căn hộ (VD: A0110) *',
                      prefixIcon: Icon(Icons.home),
                    ),
                  ),
                ],
                AppSpacing.h16,
                DropdownButtonFormField<String>(
                  initialValue: type,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Loại bàn giao',
                    prefixIcon: Icon(Icons.swap_horiz),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'move_in',
                      child: Text('Nhận nhà'),
                    ),
                    DropdownMenuItem(
                      value: 'move_out',
                      child: Text('Trả nhà'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => type = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 44),
              ),
              onPressed: () {
                final aptId =
                    selectedApartment?.id ??
                    'apt-${fallbackCodeController.text.trim()}';
                final aptCode =
                    selectedApartment?.code ??
                    fallbackCodeController.text.trim();
                final bldId =
                    selectedApartment?.buildingId ?? effectiveBuildingId;
                if (aptCode.isEmpty) return;

                Navigator.of(ctx).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => InspectionWorkstationScreen(
                      buildingId: bldId,
                      apartmentId: aptId,
                      apartmentCode: aptCode,
                      initialType: type,
                    ),
                  ),
                );
              },
              child: const Text('Tiếp tục'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(double amount) {
    return '${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} đ';
  }
}
