import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_skeleton_shimmer.dart';
import '../../../../data/models/issue_model.dart';
import '../../../../data/providers/dashboard_providers.dart';
import '../../../../data/providers/management_provider.dart';
import '../../../../data/providers/meter_reading_provider.dart';

class ManagementUrgentWorkSection extends ConsumerWidget {
  final AsyncValue<List<IssueModel>> allIssuesAsync;
  final AsyncValue<int> pendingConfirmationAsync;
  final AsyncValue<int> pendingLinkReqAsync;
  final AsyncValue<int> pendingMeterReadingsAsync;
  final bool isAdmin;
  final bool canManageInvoices;
  final bool canManageMeterReadings;

  const ManagementUrgentWorkSection({
    super.key,
    required this.allIssuesAsync,
    required this.pendingConfirmationAsync,
    required this.pendingLinkReqAsync,
    required this.pendingMeterReadingsAsync,
    required this.isAdmin,
    required this.canManageInvoices,
    required this.canManageMeterReadings,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final highPriorityColor = AppStatusColors.getPriorityHigh(context);
    final paidColor = AppStatusColors.getPaid(context);
    final secondaryColor = AppTheme.getSemanticSecondary(context);
    final pendingConfirmColor = AppStatusColors.getPendingConfirmation(context);
    final errorColor = AppTheme.getSemanticError(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Công việc cần xử lý ngay • Phản ánh cần xử lý gấp',
                style: textTheme.titleLarge?.copyWith(
                  color: highPriorityColor,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        AppSpacing.h12,
        allIssuesAsync.when(
          data: (issues) {
            final urgentIssues = issues
                .where(
                  (issue) =>
                      issue.priority == 'high' && issue.status == 'pending',
                )
                .toList();
            final pendingConfirmationCount =
                pendingConfirmationAsync.valueOrNull ?? 0;
            final pendingLinkCount =
                (isAdmin ? pendingLinkReqAsync.valueOrNull : 0) ?? 0;
            final pendingMeterCount =
                (canManageMeterReadings
                    ? pendingMeterReadingsAsync.valueOrNull
                    : 0) ??
                0;

            final allUrgentCards = <Widget>[
              for (final issue in urgentIssues)
                _UrgentActionCard(
                  icon: Icons.warning,
                  accentColor: highPriorityColor,
                  buttonColor: AppTheme.textError,
                  title:
                      'Phản ánh sự cố — Căn ${issue.apartment?.code ?? 'N/A'}',
                  subtitle: issue.description,
                  actionLabel: 'Xem ngay',
                  onAction: () => context.push(AppRoutes.managementIssues),
                ),
              if (pendingConfirmationCount > 0 && canManageInvoices)
                _UrgentActionCard(
                  icon: Icons.receipt_long,
                  accentColor: secondaryColor,
                  buttonColor: AppTheme.secondary,
                  title: 'Hóa đơn chờ đối soát ($pendingConfirmationCount)',
                  subtitle: 'Cư dân đã gửi minh chứng thanh toán',
                  actionLabel: 'Đối soát',
                  onAction: () => context.push(AppRoutes.managementInvoices),
                ),
              if (pendingLinkCount > 0 && isAdmin)
                _UrgentActionCard(
                  icon: Icons.person_add,
                  accentColor: colorScheme.primary,
                  buttonColor: AppTheme.primary,
                  title: 'Yêu cầu liên kết căn hộ ($pendingLinkCount)',
                  subtitle: 'Cư dân đăng ký thông tin căn hộ chờ duyệt',
                  actionLabel: 'Duyệt ngay',
                  onAction: () async {
                    await context.push(AppRoutes.managementLinkRequests);
                    ref.invalidate(pendingLinkRequestsCountProvider);
                    ref.invalidate(residentsProvider);
                  },
                ),
              if (pendingMeterCount > 0 && canManageMeterReadings)
                _UrgentActionCard(
                  icon: Icons.speed_outlined,
                  accentColor: pendingConfirmColor,
                  buttonColor: AppTheme.primary,
                  title: 'Chỉ số điện nước chờ duyệt ($pendingMeterCount)',
                  subtitle: 'Cần xác nhận chỉ số để chốt kỳ thanh toán',
                  actionLabel: 'Duyệt ngay',
                  onAction: () async {
                    await context.push(AppRoutes.managementMeterReading);
                    ref.invalidate(pendingMeterReadingsCountProvider);
                  },
                ),
            ];

            if (allUrgentCards.isEmpty) {
              return AppCard(
                padding: AppSpacing.p16,
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline, color: paidColor),
                    AppSpacing.w12,
                    Expanded(
                      child: Text(
                        'Không có sự cố khẩn cấp nào cần xử lý.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            final visibleCards = allUrgentCards.take(3).toList();
            final remainingCount = allUrgentCards.length - visibleCards.length;

            return Column(
              children: [
                ...visibleCards,
                if (remainingCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.r12,
                        ),
                        minimumSize: const Size.fromHeight(48),
                        side: BorderSide(color: colorScheme.outlineVariant),
                      ),
                      onPressed: () => context.push(AppRoutes.managementIssues),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              'Xem thêm $remainingCount việc cần xử lý khác',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          AppSpacing.w6,
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 18,
                            color: colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
          loading: () => AppSkeletonShimmer.cardList(
            count: 2,
            itemHeight: 56,
            borderRadius: AppRadius.r12,
          ),
          error: (e, _) => Text(
            'Lỗi tải dữ liệu',
            style: TextStyle(color: errorColor),
          ),
        ),
      ],
    );
  }
}

class _UrgentActionCard extends StatelessWidget {
  final IconData icon;
  final Color accentColor;
  final Color buttonColor;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  const _UrgentActionCard({
    required this.icon,
    required this.accentColor,
    required this.buttonColor,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      padding: AppSpacing.p12,
      margin: const EdgeInsets.only(bottom: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 360;
          final actionButton = ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor,
              foregroundColor: colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              minimumSize: const Size(88, 48),
              shape: RoundedRectangleBorder(borderRadius: AppRadius.r12),
            ),
            onPressed: onAction,
            child: Text(
              actionLabel,
              style: textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onPrimary,
              ),
            ),
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: accentColor, size: 20),
                    AppSpacing.w8,
                    Expanded(
                      child: Text(
                        title,
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: accentColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                AppSpacing.h4,
                Text(
                  subtitle,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                AppSpacing.h8,
                Align(alignment: Alignment.centerRight, child: actionButton),
              ],
            );
          }

          return Row(
            children: [
              Icon(icon, color: accentColor, size: 24),
              AppSpacing.w12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    AppSpacing.h4,
                    Text(
                      subtitle,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              AppSpacing.w8,
              actionButton,
            ],
          );
        },
      ),
    );
  }
}
