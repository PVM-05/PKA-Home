import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_card.dart';
import '../../../core/widgets/app_skeleton_shimmer.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../data/models/parcel_model.dart';
import '../../../data/models/visitor_pass_model.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/front_desk_provider.dart';
import '../../../data/providers/resident_apartment_provider.dart';
import '../widgets/create_visitor_pass_sheet.dart';
import '../widgets/visitor_pass_qr_sheet.dart';

class ResidentVisitorParcelScreen extends ConsumerStatefulWidget {
  const ResidentVisitorParcelScreen({super.key});

  @override
  ConsumerState<ResidentVisitorParcelScreen> createState() =>
      _ResidentVisitorParcelScreenState();
}

class _ResidentVisitorParcelScreenState
    extends ConsumerState<ResidentVisitorParcelScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  String? _getEffectiveApartmentId() {
    final selectedId = ref.watch(selectedApartmentIdProvider);
    if (selectedId != null && selectedId.isNotEmpty) {
      return selectedId;
    }
    final apartmentsAsync = ref.watch(residentApartmentsProvider);
    final list = apartmentsAsync.valueOrNull ?? [];
    if (list.isNotEmpty) {
      final first = list.first;
      final id =
          (first['apartment_id'] as String?) ??
          ((first['apartments'] as Map?)?['id'] as String?);
      if (id != null && id.isNotEmpty) return id;
    }
    return null;
  }

  void _openCreateVisitorSheet(String apartmentId, String hostUserId) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CreateVisitorPassSheet(
        apartmentId: apartmentId,
        hostUserId: hostUserId,
        onPassCreated: _showQrDialog,
      ),
    );
  }

  void _showQrDialog(VisitorPassModel pass) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => VisitorPassQrSheet(pass: pass),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final apartmentId = _getEffectiveApartmentId();
    final authUser = ref.watch(authProvider).valueOrNull;

    if (apartmentId == null || authUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Đón Khách & Bưu Kiện')),
        body: const Center(
          child: Padding(
            padding: AppSpacing.p24,
            child: AppEmptyState(
              icon: Icons.apartment_outlined,
              title: 'Chưa có thông tin căn hộ',
              description:
                  'Tài khoản của bạn chưa liên kết với căn hộ nào để quản lý đón khách và bưu kiện.',
            ),
          ),
        ),
      );
    }

    final hostUserId = authUser.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Đón Khách & Bưu Kiện'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: colorScheme.primary,
          indicatorWeight: 3,
          labelColor: colorScheme.primary,
          unselectedLabelColor: colorScheme.onSurfaceVariant,
          labelStyle: context.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          tabs: const [
            Tab(icon: Icon(Icons.badge_outlined), text: 'Khách Viếng Thăm'),
            Tab(
              icon: Icon(Icons.inventory_2_outlined),
              text: 'Bưu Kiện Của Tôi',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildVisitorPassesTab(apartmentId, hostUserId),
          _buildParcelsTab(apartmentId),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              onPressed: () => _openCreateVisitorSheet(apartmentId, hostUserId),
              backgroundColor: AppTheme.primary,
              foregroundColor: colorScheme.onPrimary,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Đón Khách Mới'),
            )
          : null,
    );
  }

  // ─── TAB 1: KHÁCH VIẾNG THĂM ───
  Widget _buildVisitorPassesTab(String apartmentId, String hostUserId) {
    final passesAsync = ref.watch(residentVisitorPassesProvider(apartmentId));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(residentVisitorPassesProvider(apartmentId));
      },
      child: passesAsync.when(
        loading: () => ListView(
          padding: AppSpacing.p16,
          children: [AppSkeletonShimmer.cardList(count: 3, itemHeight: 140)],
        ),
        error: (err, _) => Center(
          child: Padding(
            padding: AppSpacing.p24,
            child: AppErrorCard(
              error: err,
              onRetry: () =>
                  ref.invalidate(residentVisitorPassesProvider(apartmentId)),
            ),
          ),
        ),
        data: (passes) {
          if (passes.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
              children: [
                AppEmptyState(
                  icon: Icons.badge_outlined,
                  title: 'Chưa có đăng ký đón khách nào',
                  description:
                      'Đăng ký đón người thân, bạn bè hoặc người giao hàng trước để ra vào thuận tiện.',
                  actionLabel: 'Tạo Thẻ Khách Đầu Tiên',
                  onAction: () =>
                      _openCreateVisitorSheet(apartmentId, hostUserId),
                ),
              ],
            );
          }

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 840),
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                itemCount: passes.length,
                separatorBuilder: (_, _) => AppSpacing.h12,
                itemBuilder: (context, index) =>
                    _buildVisitorPassCard(context, passes[index]),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVisitorPassCard(BuildContext context, VisitorPassModel pass) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final Color statusColor;
    switch (pass.status) {
      case 'checked_in':
        statusColor = AppTheme.getSemanticSuccess(context);
      case 'checked_out':
        statusColor = colorScheme.onSurfaceVariant;
      case 'cancelled':
        statusColor = AppTheme.getSemanticError(context);
      case 'expired':
        statusColor = AppTheme.getSemanticWarning(context);
      case 'pending':
      default:
        statusColor = colorScheme.primary;
    }

    return AppCard(
      onTap: () => _showQrDialog(pass),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.person,
                      color: colorScheme.primary,
                      size: 20,
                    ),
                    AppSpacing.w8,
                    Expanded(
                      child: Text(
                        pass.visitorName,
                        style: context.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              AppSpacing.w8,
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: isDark ? 0.18 : 0.10),
                  borderRadius: AppRadius.r12,
                  border: Border.all(
                    color: statusColor.withValues(alpha: isDark ? 0.45 : 0.30),
                  ),
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
          AppSpacing.h12,
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: AppRadius.r8,
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Text(
                  pass.passCode,
                  style: context.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              Text(
                '• ${pass.purposeDisplayName}',
                style: context.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          AppSpacing.h8,
          if (pass.licensePlate != null && pass.licensePlate!.isNotEmpty) ...[
            Row(
              children: [
                Icon(
                  Icons.directions_car_outlined,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                AppSpacing.w6,
                Expanded(
                  child: Text(
                    'Biển số: ${pass.licensePlate!}',
                    style: context.bodySmall?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
            AppSpacing.h4,
          ],
          Row(
            children: [
              Icon(
                Icons.access_time,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
              AppSpacing.w6,
              Expanded(
                child: Text(
                  'Dự kiến: ${_dateFormat.format(pass.expectedArrival)}',
                  style: context.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.h8,
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _showQrDialog(pass),
              icon: const Icon(Icons.qr_code_2_rounded, size: 20),
              label: const Text('Xem Mã QR'),
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.primary,
                minimumSize: const Size(0, 48),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── TAB 2: BƯU KIỆN CỦA TÔI ───
  Widget _buildParcelsTab(String apartmentId) {
    final parcelsAsync = ref.watch(residentParcelsProvider(apartmentId));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(residentParcelsProvider(apartmentId));
      },
      child: parcelsAsync.when(
        loading: () => ListView(
          padding: AppSpacing.p16,
          children: [AppSkeletonShimmer.cardList(count: 3, itemHeight: 160)],
        ),
        error: (err, _) => Center(
          child: Padding(
            padding: AppSpacing.p24,
            child: AppErrorCard(
              error: err,
              onRetry: () =>
                  ref.invalidate(residentParcelsProvider(apartmentId)),
            ),
          ),
        ),
        data: (parcels) {
          if (parcels.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
              children: const [
                AppEmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'Không có bưu kiện nào tại lễ tân',
                  description:
                      'Khi có shipper giao hàng đến sảnh lễ tân, thông tin kiện hàng và mã PIN sẽ hiển thị tại đây.',
                ),
              ],
            );
          }

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 840),
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: AppSpacing.p16,
                itemCount: parcels.length,
                separatorBuilder: (_, _) => AppSpacing.h12,
                itemBuilder: (context, index) =>
                    _buildParcelCard(context, parcels[index]),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildParcelCard(BuildContext context, ParcelModel parcel) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isArrived = parcel.status == 'arrived';

    final statusColor = isArrived
        ? AppTheme.getSemanticWarning(context)
        : AppTheme.getSemanticSuccess(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: AppSpacing.p8,
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(
                          alpha: isDark ? 0.18 : 0.10,
                        ),
                        borderRadius: AppRadius.r8,
                      ),
                      child: Icon(
                        Icons.local_shipping_outlined,
                        color: colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    AppSpacing.w10,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            parcel.carrierDisplayName,
                            style: context.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (parcel.trackingNumber != null)
                            Text(
                              'Vận đơn: ${parcel.trackingNumber}',
                              style: context.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              AppSpacing.w8,
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: isDark ? 0.18 : 0.12),
                  borderRadius: AppRadius.r12,
                  border: Border.all(
                    color: statusColor.withValues(alpha: isDark ? 0.45 : 0.35),
                  ),
                ),
                child: Text(
                  parcel.statusDisplayName,
                  style: context.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.h12,
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: AppRadius.r8,
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 6,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.shelves,
                      size: 18,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    AppSpacing.w8,
                    Flexible(
                      child: Text(
                        'Vị trí: ${parcel.shelfLocation}',
                        style: context.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Đến lúc: ${_dateFormat.format(parcel.arrivedAt)}',
                  style: context.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          if (isArrived) ...[
            AppSpacing.h12,
            Container(
              padding: AppSpacing.p16,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(
                  alpha: isDark ? 0.14 : 0.07,
                ),
                borderRadius: AppRadius.r12,
                border: Border.all(
                  color: colorScheme.primary.withValues(
                    alpha: isDark ? 0.45 : 0.30,
                  ),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                      AppSpacing.w6,
                      Flexible(
                        child: Text(
                          'MÃ PIN NHẬN HÀNG BẢO MẬT',
                          style: context.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: colorScheme.primary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.h8,
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            parcel.pickupPin,
                            style: context.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 6.0,
                              fontFamily: 'monospace',
                              color: colorScheme.primary,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                      ),
                      AppSpacing.w8,
                      IconButton(
                        tooltip: 'Sao chép mã PIN',
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        icon: Icon(
                          Icons.copy_rounded,
                          size: 20,
                          color: colorScheme.primary,
                        ),
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: parcel.pickupPin),
                          );
                          AppSnackBar.showSuccess(
                            context,
                            'Đã sao chép mã PIN nhận hàng',
                          );
                        },
                      ),
                    ],
                  ),
                  AppSpacing.h4,
                  Text(
                    'Cung cấp mã PIN 6 số này cho lễ tân tại quầy để nhận kiện hàng',
                    textAlign: TextAlign.center,
                    style: context.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            AppSpacing.h12,
            Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 18,
                  color: AppTheme.getSemanticSuccess(context),
                ),
                AppSpacing.w6,
                Expanded(
                  child: Text(
                    'Đã bàn giao lúc: ${parcel.collectedAt != null ? _dateFormat.format(parcel.collectedAt!) : 'Không rõ'}',
                    style: context.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
