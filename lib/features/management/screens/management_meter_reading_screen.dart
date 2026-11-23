import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/permissions.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_card.dart';
import '../../../core/widgets/app_skeleton_shimmer.dart';
import '../../../core/widgets/role_guard.dart';
import '../../../data/models/meter_reading_submission_model.dart';
import '../../../data/providers/meter_reading_provider.dart';
import '../widgets/meter/management_meter_dialogs.dart';
import '../widgets/meter/management_submission_card.dart';

class ManagementMeterReadingScreen extends ConsumerStatefulWidget {
  const ManagementMeterReadingScreen({super.key});

  @override
  ConsumerState<ManagementMeterReadingScreen> createState() =>
      _ManagementMeterReadingScreenState();
}

class _ManagementMeterReadingScreenState
    extends ConsumerState<ManagementMeterReadingScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refreshAll() {
    ref.invalidate(allMeterReadingsProvider);
    ref.invalidate(anomalyMeterReadingsProvider);
    ref.invalidate(pendingMeterReadingsCountProvider);
    ref.invalidate(pendingAnomalyCountProvider);
  }

  @override
  Widget build(BuildContext context) {
    final pendingCountAsync = ref.watch(pendingMeterReadingsCountProvider);
    final pendingAnomalyAsync = ref.watch(pendingAnomalyCountProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return RoleGuard(
      permission: AppPermissions.meterReadingManagement,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Duyệt Chỉ Số Điện Nước',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'Quản Lý Chỉ Số Tiện Ích',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.flash_on_outlined),
              tooltip: 'Chốt số theo tầng',
              onPressed: () => showMeterBatchRecordDialog(
                context: context,
                ref: ref,
                onSuccessRefresh: _refreshAll,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Làm mới',
              onPressed: _refreshAll,
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: colorScheme.primary,
            labelColor: colorScheme.primary,
            unselectedLabelColor: colorScheme.onSurfaceVariant,
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Chờ duyệt'),
                    AppSpacing.w6,
                    pendingCountAsync.when(
                      data: (count) => count > 0
                          ? _buildCountBadge(
                              context,
                              count: count,
                              backgroundColor: colorScheme.error,
                              foregroundColor: colorScheme.onError,
                            )
                          : const SizedBox.shrink(),
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Bất thường'),
                    AppSpacing.w6,
                    pendingAnomalyAsync.when(
                      data: (count) => count > 0
                          ? _buildCountBadge(
                              context,
                              count: count,
                              backgroundColor: AppTheme.textWarning,
                              foregroundColor: colorScheme.onPrimary,
                            )
                          : const SizedBox.shrink(),
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
              const Tab(text: 'Đã duyệt'),
              const Tab(text: 'Đã từ chối'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildSubmissionList('pending'),
            _buildAnomalyList(),
            _buildSubmissionList('approved'),
            _buildSubmissionList('rejected'),
          ],
        ),
      ),
    );
  }

  Widget _buildCountBadge(
    BuildContext context, {
    required int count,
    required Color backgroundColor,
    required Color foregroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: AppRadius.r12,
      ),
      child: Text(
        '$count',
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: foregroundColor, fontWeight: FontWeight.bold)
            .tabularFigures(),
      ),
    );
  }

  Widget _buildAnomalyList() {
    final anomaliesAsync = ref.watch(anomalyMeterReadingsProvider);

    return RefreshIndicator(
      onRefresh: () async => _refreshAll(),
      child: anomaliesAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 80),
                AppEmptyState(
                  icon: Icons.verified_outlined,
                  title: 'Không có bất thường',
                  description: 'Không có chỉ số nào bị gắn cờ bất thường.',
                ),
              ],
            );
          }

          return _buildResponsiveList(items, 'pending');
        },
        loading: () => ListView(
          padding: AppSpacing.p16,
          children: [AppSkeletonShimmer.cardList(count: 4, itemHeight: 160)],
        ),
        error: (e, _) =>
            Center(child: AppErrorCard(error: e, onRetry: _refreshAll)),
      ),
    );
  }

  Widget _buildSubmissionList(String status) {
    final submissionsAsync = ref.watch(allMeterReadingsProvider(status));

    return RefreshIndicator(
      onRefresh: () async => _refreshAll(),
      child: submissionsAsync.when(
        data: (items) {
          if (items.isEmpty) {
            String emptyMessage = 'Không có chỉ số nào đang chờ duyệt.';
            if (status == 'approved') {
              emptyMessage = 'Chưa có chỉ số nào được duyệt.';
            }
            if (status == 'rejected') {
              emptyMessage = 'Không có chỉ số nào bị từ chối.';
            }

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 80),
                AppEmptyState(
                  icon: Icons.check_circle_outline,
                  title: 'Danh sách trống',
                  description: emptyMessage,
                ),
              ],
            );
          }

          return _buildResponsiveList(items, status);
        },
        loading: () => ListView(
          padding: AppSpacing.p16,
          children: [AppSkeletonShimmer.cardList(count: 4, itemHeight: 160)],
        ),
        error: (e, _) =>
            Center(child: AppErrorCard(error: e, onRetry: _refreshAll)),
      ),
    );
  }

  Widget _buildResponsiveList(
    List<MeterReadingSubmissionModel> items,
    String currentTabStatus,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;
        final pendingCount =
            ref.watch(pendingMeterReadingsCountProvider).valueOrNull ?? 0;
        final pendingAnomaly =
            ref.watch(pendingAnomalyCountProvider).valueOrNull ?? 0;

        if (isDesktop) {
          final leftCol = <Widget>[];
          final rightCol = <Widget>[];
          for (var i = 0; i < items.length; i++) {
            if (i.isEven) {
              leftCol.add(_buildSubmissionCard(items[i], currentTabStatus));
            } else {
              rightCol.add(_buildSubmissionCard(items[i], currentTabStatus));
            }
          }

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1400),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildExecutiveKpiBar(pendingCount, pendingAnomaly),
                      AppSpacing.h20,
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: Column(children: leftCol)),
                          AppSpacing.w20,
                          Expanded(child: Column(children: rightCol)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AppSpacing.p16,
          itemCount: items.length,
          itemBuilder: (context, index) {
            return _buildSubmissionCard(items[index], currentTabStatus);
          },
        );
      },
    );
  }

  Widget _buildExecutiveKpiBar(int pendingCount, int pendingAnomaly) {
    final colorScheme = Theme.of(context).colorScheme;
    final warningColor = AppTheme.getSemanticWarning(context);
    final secondaryColor = AppTheme.getSemanticSecondary(context);

    return Container(
      padding: AppSpacing.p16,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: AppRadius.r12,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _buildKpiItem(
                icon: Icons.pending_actions,
                iconColor: colorScheme.primary,
                title: 'Chờ duyệt',
                value: '$pendingCount',
                subtitle: 'Cần xác nhận',
              ),
            ),
            VerticalDivider(
              width: 16,
              thickness: 1,
              color: colorScheme.outlineVariant,
            ),
            Expanded(
              child: _buildKpiItem(
                icon: Icons.warning_amber_rounded,
                iconColor: warningColor,
                title: 'Bất thường AI',
                value: '$pendingAnomaly',
                subtitle: 'Tăng vọt / OCR thấp',
              ),
            ),
            VerticalDivider(
              width: 16,
              thickness: 1,
              color: colorScheme.outlineVariant,
            ),
            Expanded(
              child: _buildKpiItem(
                icon: Icons.flash_on,
                iconColor: warningColor,
                title: 'Chốt số nhanh',
                value: 'Trạm tầng',
                subtitle: 'Nhập hàng loạt',
                onTap: () => showMeterBatchRecordDialog(
                  context: context,
                  ref: ref,
                  onSuccessRefresh: _refreshAll,
                ),
              ),
            ),
            VerticalDivider(
              width: 16,
              thickness: 1,
              color: colorScheme.outlineVariant,
            ),
            Expanded(
              child: _buildKpiItem(
                icon: Icons.sync,
                iconColor: secondaryColor,
                title: 'Đồng bộ hóa đơn',
                value: 'Tự động',
                subtitle: 'Sau khi duyệt',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.r8,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: AppRadius.r8,
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            AppSpacing.w12,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    value,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: iconColor,
                        )
                        .tabularFigures(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
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
    );
  }

  Widget _buildSubmissionCard(
    MeterReadingSubmissionModel item,
    String currentTabStatus,
  ) {
    return ManagementSubmissionCard(
      item: item,
      currentTabStatus: currentTabStatus,
      onShowImage: (title, url) =>
          showMeterImageDialog(context: context, title: title, imageUrl: url),
      onApprove: () => showMeterApproveDialog(
        context: context,
        ref: ref,
        item: item,
        onSuccessRefresh: _refreshAll,
      ),
      onReject: () => showMeterRejectDialog(
        context: context,
        ref: ref,
        item: item,
        onSuccessRefresh: _refreshAll,
      ),
      dateFormat: _dateFormat,
    );
  }
}
