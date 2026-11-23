import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/permissions.dart';
import '../../../core/security/visitor_pass_token_service.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_card.dart';
import '../../../core/widgets/app_qr_scanner_sheet.dart';
import '../../../core/widgets/app_search_field.dart';
import '../../../core/widgets/app_skeleton_shimmer.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/role_guard.dart';
import '../../../data/providers/front_desk_provider.dart';
import '../widgets/handover_parcel_dialog.dart';
import '../widgets/receive_parcel_sheet.dart';

class FrontDeskWorkstationScreen extends ConsumerStatefulWidget {
  const FrontDeskWorkstationScreen({super.key});

  @override
  ConsumerState<FrontDeskWorkstationScreen> createState() =>
      _FrontDeskWorkstationScreenState();
}

class _FrontDeskWorkstationScreenState
    extends ConsumerState<FrontDeskWorkstationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchVisitorCtrl = TextEditingController();
  final _searchParcelCtrl = TextEditingController();
  String _visitorSearch = '';
  String _parcelSearch = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchVisitorCtrl.dispose();
    _searchParcelCtrl.dispose();
    super.dispose();
  }

  Future<void> _showScanVisitorDialog() async {
    final scannedCode = await AppQrScannerSheet.show(
      context,
      title: 'Quét vé khách vào/ra',
      hintText: 'Căn chỉnh mã QR vé khách trong khung hình',
      manualInputHint: 'VD: VP-202611-00001 hoặc mã token PKAPASS',
    );
    if (scannedCode != null && scannedCode.isNotEmpty) {
      await _processVisitorCode(scannedCode);
    }
  }

  Future<void> _processVisitorCode(String rawCode) async {
    final trimmed = rawCode.trim();
    String code = trimmed;
    String? qrPayload;

    if (trimmed.startsWith('PKAPASS')) {
      final parseResult = VisitorPassTokenService.verifyAndParseQrPayload(
        trimmed,
      );
      if (!parseResult.isValid) {
        if (mounted) {
          AppSnackBar.showError(
            context,
            parseResult.errorMessage ?? 'Mã QR vé khách không hợp lệ',
          );
        }
        return;
      }
      code = parseResult.passCode ?? trimmed;
      qrPayload = trimmed;
    }

    try {
      final repo = ref.read(frontDeskRepositoryProvider);
      final res = await repo.checkInVisitor(
        passCode: code,
        qrPayload: qrPayload,
      );

      ref.invalidate(visitorPassesProvider);
      ref.invalidate(frontDeskStatsProvider);

      if (mounted) {
        final message = res['message'] as String? ?? 'Xử lý vé thành công';
        if (res['success'] == true) {
          AppSnackBar.showSuccess(context, message);
        } else {
          AppSnackBar.showError(context, message);
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, formatErrorMessage(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final statsAsync = ref.watch(frontDeskStatsProvider);

    return RoleGuard(
      permission: AppPermissions.residentManagement,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Trạm Lễ Tân & An Ninh'),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: colorScheme.primary,
            labelColor: colorScheme.primary,
            unselectedLabelColor: colorScheme.onSurfaceVariant,
            tabs: const [
              Tab(icon: Icon(Icons.badge_outlined), text: 'Khách vào ra'),
              Tab(
                icon: Icon(Icons.inventory_2_outlined),
                text: 'Bưu kiện sảnh',
              ),
            ],
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              children: [
                statsAsync.when(
                  data: (stats) => _buildKpiHeader(
                    context,
                    expectedVisitorsToday: stats.expectedVisitorsToday,
                    visitorsInBuilding: stats.visitorsInBuilding,
                    pendingParcels: stats.pendingParcels,
                    overdueParcels: stats.overdueParcels,
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [_buildVisitorsTab(), _buildParcelsTab()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKpiHeader(
    BuildContext context, {
    required int expectedVisitorsToday,
    required int visitorsInBuilding,
    required int pendingParcels,
    required int overdueParcels,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final successColor = AppTheme.getSemanticSuccess(context);
    final warningColor = AppTheme.getSemanticWarning(context);
    final errorColor = AppTheme.getSemanticError(context);
    final hasOverdue = overdueParcels > 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: _FrontDeskKpiTile(
              label: 'Khách hôm nay',
              value: '$expectedVisitorsToday lượt',
              accentColor: colorScheme.primary,
            ),
          ),
          AppSpacing.w8,
          Expanded(
            child: _FrontDeskKpiTile(
              label: 'Trong tòa nhà',
              value: '$visitorsInBuilding người',
              accentColor: successColor,
            ),
          ),
          AppSpacing.w8,
          Expanded(
            child: _FrontDeskKpiTile(
              label: hasOverdue ? 'Tồn quá 3 ngày' : 'Bưu kiện kệ',
              value: '$pendingParcels kiện',
              accentColor: hasOverdue ? errorColor : warningColor,
            ),
          ),
        ],
      ),
    );
  }

  // ─── TAB 1: KHÁCH VÀO RA ───
  Widget _buildVisitorsTab() {
    final visitorsAsync = ref.watch(
      visitorPassesProvider((status: null, apartmentId: null)),
    );
    final dateFormat = DateFormat('dd/MM HH:mm');
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: AppSearchField(
                  controller: _searchVisitorCtrl,
                  hintText: 'Tìm theo mã vé, tên khách, căn hộ...',
                  onChanged: (val) =>
                      setState(() => _visitorSearch = val.toLowerCase().trim()),
                  onClear: () => setState(() => _visitorSearch = ''),
                ),
              ),
              AppSpacing.w8,
              ElevatedButton.icon(
                onPressed: _showScanVisitorDialog,
                icon: const Icon(Icons.qr_code_scanner, size: 20),
                label: const Text('Quét vé'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.r12),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(visitorPassesProvider);
              ref.invalidate(frontDeskStatsProvider);
            },
            child: visitorsAsync.when(
              loading: () => ListView(
                padding: AppSpacing.p16,
                children: [
                  AppSkeletonShimmer.cardList(count: 3, itemHeight: 130),
                ],
              ),
              error: (err, _) => Center(
                child: Padding(
                  padding: AppSpacing.p24,
                  child: AppErrorCard(
                    error: err,
                    onRetry: () => ref.invalidate(visitorPassesProvider),
                  ),
                ),
              ),
              data: (passes) {
                final filtered = passes.where((p) {
                  if (_visitorSearch.isEmpty) return true;
                  return p.passCode.toLowerCase().contains(_visitorSearch) ||
                      p.visitorName.toLowerCase().contains(_visitorSearch) ||
                      (p.apartmentCode?.toLowerCase().contains(
                            _visitorSearch,
                          ) ??
                          false) ||
                      (p.licensePlate?.toLowerCase().contains(_visitorSearch) ??
                          false);
                }).toList();

                if (filtered.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 48,
                    ),
                    children: const [
                      AppEmptyState(
                        icon: Icons.badge_outlined,
                        title: 'Không có dữ liệu vé khách viếng thăm',
                        description:
                            'Các vé QR đón khách của cư dân hoặc khách vừa quét qua cổng sẽ hiển thị tại đây.',
                      ),
                    ],
                  );
                }

                return ListView.builder(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final pass = filtered[index];
                    final theme = Theme.of(context);
                    final cs = theme.colorScheme;
                    final isDark = theme.brightness == Brightness.dark;
                    final isCheckedIn = pass.status == 'checked_in';
                    final warningColor = AppTheme.getSemanticWarning(context);
                    final statusColor = isCheckedIn
                        ? AppTheme.getSemanticSuccess(context)
                        : (pass.status == 'pending'
                              ? cs.primary
                              : cs.onSurfaceVariant);

                    return AppCard(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      borderRadius: 14,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  pass.passCode,
                                  style: context.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: cs.primary,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              AppSpacing.w8,
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(
                                    alpha: isDark ? 0.18 : 0.10,
                                  ),
                                  borderRadius: AppRadius.r8,
                                ),
                                child: Text(
                                  pass.statusDisplayName,
                                  style: context.labelSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          AppSpacing.h8,
                          Text(
                            pass.visitorName,
                            style: context.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          AppSpacing.h4,
                          Wrap(
                            spacing: 12,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.apartment,
                                    size: 14,
                                    color: cs.onSurfaceVariant,
                                  ),
                                  AppSpacing.w4,
                                  Text(
                                    'Căn hộ ${pass.apartmentCode ?? pass.apartmentId}',
                                    style: context.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.directions_car_outlined,
                                    size: 14,
                                    color: cs.onSurfaceVariant,
                                  ),
                                  AppSpacing.w4,
                                  Text(
                                    pass.vehicleDisplayName,
                                    style: context.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          AppSpacing.h8,
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 14,
                                    color: cs.onSurfaceVariant,
                                  ),
                                  AppSpacing.w4,
                                  Text(
                                    'Dự kiến: ${dateFormat.format(pass.expectedArrival)}',
                                    style: context.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (pass.isCheckInAllowed)
                                ElevatedButton(
                                  onPressed: () =>
                                      _processVisitorCode(pass.passCode),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.textSuccess,
                                    foregroundColor: cs.onPrimary,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    minimumSize: const Size(76, 48),
                                  ),
                                  child: Text(
                                    'Vào',
                                    style: context.labelMedium?.copyWith(
                                      color: cs.onPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              if (pass.isCheckOutAllowed)
                                OutlinedButton(
                                  onPressed: () async {
                                    final repo = ref.read(
                                      frontDeskRepositoryProvider,
                                    );
                                    await repo.checkOutVisitor(
                                      passCode: pass.passCode,
                                    );
                                    ref.invalidate(visitorPassesProvider);
                                    ref.invalidate(frontDeskStatsProvider);
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: warningColor,
                                    side: BorderSide(color: warningColor),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    minimumSize: const Size(76, 48),
                                  ),
                                  child: Text(
                                    'Rời tòa',
                                    style: context.labelMedium?.copyWith(
                                      color: warningColor,
                                      fontWeight: FontWeight.bold,
                                    ),
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

  // ─── TAB 2: BƯU KIỆN SẢNH ───
  Widget _buildParcelsTab() {
    final parcelsAsync = ref.watch(
      parcelsProvider((status: null, apartmentId: null)),
    );
    final dateFormat = DateFormat('dd/MM HH:mm');
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: AppSearchField(
                  controller: _searchParcelCtrl,
                  hintText: 'Tìm kiện hàng, căn hộ, mã vận đơn...',
                  onChanged: (val) =>
                      setState(() => _parcelSearch = val.toLowerCase().trim()),
                  onClear: () => setState(() => _parcelSearch = ''),
                ),
              ),
              AppSpacing.w8,
              ElevatedButton.icon(
                onPressed: () => ReceiveParcelSheet.show(context),
                icon: const Icon(Icons.add_box_outlined, size: 20),
                label: const Text('Nhận kiện'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.r12),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(parcelsProvider);
              ref.invalidate(frontDeskStatsProvider);
            },
            child: parcelsAsync.when(
              loading: () => ListView(
                padding: AppSpacing.p16,
                children: [
                  AppSkeletonShimmer.cardList(count: 3, itemHeight: 135),
                ],
              ),
              error: (err, _) => Center(
                child: Padding(
                  padding: AppSpacing.p24,
                  child: AppErrorCard(
                    error: err,
                    onRetry: () => ref.invalidate(parcelsProvider),
                  ),
                ),
              ),
              data: (parcels) {
                final filtered = parcels.where((p) {
                  if (_parcelSearch.isEmpty) return true;
                  return p.parcelCode.toLowerCase().contains(_parcelSearch) ||
                      (p.apartmentCode?.toLowerCase().contains(_parcelSearch) ??
                          false) ||
                      (p.trackingNumber?.toLowerCase().contains(
                            _parcelSearch,
                          ) ??
                          false) ||
                      (p.recipientName?.toLowerCase().contains(_parcelSearch) ??
                          false);
                }).toList();

                if (filtered.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 48,
                    ),
                    children: const [
                      AppEmptyState(
                        icon: Icons.inventory_2_outlined,
                        title: 'Không có kiện hàng nào tại quầy',
                        description:
                            'Bấm "Nhận kiện" khi tiếp nhận bưu phẩm từ đơn vị giao hàng để cấp mã PIN tự động cho cư dân.',
                      ),
                    ],
                  );
                }

                return ListView.builder(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final parcel = filtered[index];
                    final theme = Theme.of(context);
                    final cs = theme.colorScheme;
                    final isDark = theme.brightness == Brightness.dark;
                    final isArrived = parcel.status == 'arrived';
                    final errorColor = AppTheme.getSemanticError(context);
                    final warningColor = AppTheme.getSemanticWarning(context);
                    final successColor = AppTheme.getSemanticSuccess(context);
                    final statusColor = isArrived
                        ? (parcel.isOverdueStorage ? errorColor : warningColor)
                        : successColor;

                    return AppCard(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      borderRadius: 14,
                      borderColor: parcel.isOverdueStorage
                          ? errorColor.withValues(alpha: isDark ? 0.65 : 0.55)
                          : null,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  parcel.parcelCode,
                                  style: context.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: cs.primary,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              AppSpacing.w8,
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(
                                    alpha: isDark ? 0.18 : 0.10,
                                  ),
                                  borderRadius: AppRadius.r8,
                                ),
                                child: Text(
                                  parcel.isOverdueStorage
                                      ? 'Tồn quá 3 ngày'
                                      : parcel.statusDisplayName,
                                  style: context.labelSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          AppSpacing.h8,
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: AppSpacing.p8,
                                decoration: BoxDecoration(
                                  color: cs.surfaceContainerLow,
                                  borderRadius: AppRadius.r8,
                                  border: Border.all(color: cs.outlineVariant),
                                ),
                                child: Icon(
                                  Icons.local_shipping_outlined,
                                  color: cs.primary,
                                  size: 24,
                                ),
                              ),
                              AppSpacing.w12,
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      parcel.description ??
                                          'Bưu phẩm tiêu chuẩn',
                                      style: context.titleSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    AppSpacing.h4,
                                    Text(
                                      'Căn hộ: ${parcel.apartmentCode ?? parcel.apartmentId}${parcel.recipientName != null ? " (${parcel.recipientName})" : ""}',
                                      style: context.bodySmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    AppSpacing.h4,
                                    Text(
                                      '${parcel.carrierDisplayName} - ${parcel.shelfLocation}',
                                      style: context.bodySmall?.copyWith(
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          AppSpacing.h8,
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              Text(
                                'Đến: ${dateFormat.format(parcel.arrivedAt)}',
                                style: context.labelSmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                              if (isArrived)
                                ElevatedButton.icon(
                                  onPressed: () =>
                                      HandoverParcelDialog.show(context, parcel),
                                  icon: const Icon(Icons.outbox, size: 16),
                                  label: const Text('Bàn giao'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primary,
                                    foregroundColor: cs.onPrimary,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    minimumSize: const Size(76, 48),
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

class _FrontDeskKpiTile extends StatelessWidget {
  final String label;
  final String value;
  final Color accentColor;

  const _FrontDeskKpiTile({
    required this.label,
    required this.value,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: isDark ? 0.16 : 0.08),
        borderRadius: AppRadius.r12,
        border: Border.all(
          color: accentColor.withValues(alpha: isDark ? 0.45 : 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: context.labelSmall?.copyWith(
              color: accentColor,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          AppSpacing.h4,
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: context.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
