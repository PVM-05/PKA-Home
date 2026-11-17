import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vivona/core/theme/app_radius.dart';
import 'package:vivona/core/theme/app_spacing.dart';
import 'package:vivona/core/theme/app_theme.dart';
import 'package:vivona/core/widgets/app_card.dart';
import 'package:vivona/core/widgets/app_error_card.dart';
import 'package:vivona/core/widgets/app_skeleton_shimmer.dart';
import 'package:vivona/data/models/issue_model.dart';

class ResidentHomeLatestIssueCard extends StatelessWidget {
  final AsyncValue<List<IssueModel>> issueAsync;
  final VoidCallback onNavigateToIssues;
  final VoidCallback onRetry;

  const ResidentHomeLatestIssueCard({
    super.key,
    required this.issueAsync,
    required this.onNavigateToIssues,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tiến độ phản ánh',
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        AppSpacing.h8,
        issueAsync.when(
          data: (issues) {
            if (issues.isEmpty) {
              return AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 14.0,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: AppSpacing.p8,
                      decoration: BoxDecoration(
                        color: AppTheme.success.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_outline,
                        color: AppTheme.success,
                        size: 20,
                      ),
                    ),
                    AppSpacing.w12,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Căn hộ hoạt động ổn định',
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Không có phản ánh nào gần đây.',
                            style: textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: onNavigateToIssues,
                      child: const Text('Báo mới'),
                    ),
                  ],
                ),
              );
            }
            final latestIssue = issues.first;
            Color statusColor;
            String statusText;
            IconData statusIcon;
            switch (latestIssue.status) {
              case 'resolved':
                statusColor = AppTheme.success;
                statusText = 'Đã xử lý';
                statusIcon = Icons.check_circle;
                break;
              case 'in_progress':
                statusColor = AppTheme.primary;
                statusText = 'Đang xử lý';
                statusIcon = Icons.engineering;
                break;
              default:
                statusColor = AppTheme.warning;
                statusText = 'Chờ tiếp nhận';
                statusIcon = Icons.pending_actions;
            }
            return AppCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: statusColor.withValues(
                    alpha: 0.1,
                  ),
                  child: Icon(statusIcon, color: statusColor),
                ),
                title: Text(
                  latestIssue.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: AppTheme.textSecondary,
                ),
                onTap: onNavigateToIssues,
              ),
            )
                .animate()
                .fade(duration: 400.ms, delay: 200.ms)
                .slideX(begin: 0.1, curve: Curves.easeOut);
          },
          loading: () => AppSkeletonShimmer.cardList(
            count: 1,
            itemHeight: 68,
            borderRadius: AppRadius.r16,
          ),
          error: (err, st) => AppErrorCard(
            error: err,
            onRetry: onRetry,
          ),
        ),
      ],
    );
  }
}
