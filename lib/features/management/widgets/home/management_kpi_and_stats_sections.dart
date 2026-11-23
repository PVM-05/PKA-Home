import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/shimmer_loading.dart';
import '../../../../data/models/issue_model.dart';
import '../../../../data/providers/dashboard_providers.dart';
import '../../../../data/providers/management_provider.dart';
import '../../../../data/providers/meter_reading_provider.dart';
import '../stat_card.dart';

class ManagementInteractiveKpiStrip extends ConsumerWidget {
  final AsyncValue<int> pendingInvoicesAsync;
  final AsyncValue<int> pendingIssuesAsync;
  final AsyncValue<int> pendingMeterReadingsAsync;
  final AsyncValue<int> pendingLinkReqAsync;

  const ManagementInteractiveKpiStrip({
    super.key,
    required this.pendingInvoicesAsync,
    required this.pendingIssuesAsync,
    required this.pendingMeterReadingsAsync,
    required this.pendingLinkReqAsync,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final secondaryColor = AppTheme.getSemanticSecondary(context);
    final warningColor = AppTheme.getSemanticWarning(context);
    final pendingConfirmColor = AppStatusColors.getPendingConfirmation(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Chỉ số hành động trọng tâm',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        AppSpacing.h12,
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final cols = width < 600 ? 2 : 4;
            final ratio = width < 360 ? 1.05 : (width < 600 ? 1.25 : 1.45);
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: cols,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: ratio,
              children: [
                StatCard(
                  title: 'Hóa đơn chờ thu',
                  value: pendingInvoicesAsync.when(
                    data: (count) => '$count',
                    loading: () => '...',
                    error: (_, _) => '0',
                  ),
                  subtitle: 'Bấm đối soát',
                  icon: Icons.receipt_long,
                  color: secondaryColor,
                  onTap: () => context.push(AppRoutes.managementInvoices),
                ),
                StatCard(
                  title: 'Sự cố đang mở',
                  value: pendingIssuesAsync.when(
                    data: (count) => '$count',
                    loading: () => '...',
                    error: (_, _) => '0',
                  ),
                  subtitle: 'Bấm xử lý',
                  icon: Icons.report_problem_outlined,
                  color: warningColor,
                  onTap: () => context.push(AppRoutes.managementIssues),
                ),
                StatCard(
                  title: 'Chỉ số chờ duyệt',
                  value: pendingMeterReadingsAsync.when(
                    data: (count) => '$count',
                    loading: () => '...',
                    error: (_, _) => '0',
                  ),
                  subtitle: 'Bấm duyệt số',
                  icon: Icons.speed_outlined,
                  color: pendingConfirmColor,
                  onTap: () async {
                    await context.push(AppRoutes.managementMeterReading);
                    ref.invalidate(pendingMeterReadingsCountProvider);
                  },
                ),
                StatCard(
                  title: 'Yêu cầu chờ duyệt',
                  value: pendingLinkReqAsync.when(
                    data: (count) => '$count',
                    loading: () => '...',
                    error: (_, _) => '0',
                  ),
                  subtitle: 'Bấm phê duyệt',
                  icon: Icons.person_add_alt_1,
                  color: colorScheme.primary,
                  onTap: () async {
                    await context.push(AppRoutes.managementLinkRequests);
                    ref.invalidate(pendingLinkRequestsCountProvider);
                    ref.invalidate(residentsProvider);
                  },
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class ManagementApartmentResidentStats extends ConsumerWidget {
  final bool isTechnician;
  final AsyncValue<int> pendingLinkReqAsync;

  const ManagementApartmentResidentStats({
    super.key,
    required this.isTechnician,
    required this.pendingLinkReqAsync,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final paidColor = AppStatusColors.getPaid(context);
    final secondaryColor = AppTheme.getSemanticSecondary(context);
    final warningColor = AppTheme.getSemanticWarning(context);
    final successColor = AppTheme.getSemanticSuccess(context);

    final totalAptsAsync = ref.watch(totalApartmentsProvider);
    final totalResAsync = ref.watch(totalResidentsProvider);
    final occupancyAsync = ref.watch(occupancyRateProvider);
    final emptyAptsAsync = ref.watch(emptyApartmentsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cư dân & Căn hộ — Tổng quan trạng thái',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        AppSpacing.h12,
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final cols = width < 600 ? 2 : (width < 1100 ? 3 : 4);
            final ratio = width < 360 ? 0.98 : (width < 600 ? 1.18 : 1.45);
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: cols,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: ratio,
              children: [
                totalAptsAsync.isLoading
                    ? const StatCardSkeleton()
                    : StatCard(
                        title: 'Tổng số Căn hộ',
                        value: totalAptsAsync.when(
                          data: (count) => '$count',
                          loading: () => '...',
                          error: (_, _) => 'Lỗi',
                        ),
                        icon: Icons.domain,
                        color: colorScheme.primary,
                      ),
                totalResAsync.isLoading
                    ? const StatCardSkeleton()
                    : StatCard(
                        title: 'Tổng Cư dân',
                        value: totalResAsync.when(
                          data: (count) => '$count',
                          loading: () => '...',
                          error: (_, _) => 'Lỗi',
                        ),
                        icon: Icons.groups,
                        color: paidColor,
                      ),
                occupancyAsync.isLoading
                    ? const StatCardSkeleton()
                    : StatCard(
                        title: 'Tỷ lệ lấp đầy',
                        value: occupancyAsync.when(
                          data: (rate) => '${(rate * 100).toStringAsFixed(1)}%',
                          loading: () => '...',
                          error: (_, _) => 'Lỗi',
                        ),
                        icon: Icons.pie_chart_outline,
                        color: secondaryColor,
                      ),
                if (!isTechnician)
                  pendingLinkReqAsync.isLoading
                      ? const StatCardSkeleton()
                      : StatCard(
                          title: 'Chờ liên kết',
                          value: pendingLinkReqAsync.when(
                            data: (count) => '$count',
                            loading: () => '...',
                            error: (_, _) => 'Lỗi',
                          ),
                          icon: Icons.link,
                          color: successColor,
                        )
                else
                  emptyAptsAsync.isLoading
                      ? const StatCardSkeleton()
                      : StatCard(
                          title: 'Căn hộ trống',
                          value: emptyAptsAsync.when(
                            data: (count) => '$count',
                            loading: () => '...',
                            error: (_, _) => 'Lỗi',
                          ),
                          icon: Icons.meeting_room_outlined,
                          color: warningColor,
                        ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class ManagementOpsStats extends StatelessWidget {
  final AsyncValue<int> pendingIssuesAsync;
  final AsyncValue<List<IssueModel>> allIssuesAsync;

  const ManagementOpsStats({
    super.key,
    required this.pendingIssuesAsync,
    required this.allIssuesAsync,
  });

  @override
  Widget build(BuildContext context) {
    final pendingColor = AppStatusColors.getPending(context);
    final warningColor = AppTheme.getSemanticWarning(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Vận hành & Kỹ thuật',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        AppSpacing.h12,
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final ratio = width < 360 ? 0.98 : (width < 600 ? 1.18 : 1.45);
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: ratio,
              children: [
                pendingIssuesAsync.isLoading
                    ? const StatCardSkeleton()
                    : StatCard(
                        title: 'Phản ánh mới',
                        value: pendingIssuesAsync.when(
                          data: (count) => '$count',
                          loading: () => '...',
                          error: (_, _) => 'Lỗi',
                        ),
                        icon: Icons.warning_amber_outlined,
                        color: pendingColor,
                      ),
                allIssuesAsync.isLoading
                    ? const StatCardSkeleton()
                    : StatCard(
                        title: 'Sự cố đang xử lý',
                        value: allIssuesAsync.when(
                          data: (issues) =>
                              '${issues.where((i) => i.status == 'in_progress').length}',
                          loading: () => '...',
                          error: (_, _) => 'Lỗi',
                        ),
                        icon: Icons.build_circle_outlined,
                        color: warningColor,
                      ),
              ],
            );
          },
        ),
      ],
    );
  }
}
