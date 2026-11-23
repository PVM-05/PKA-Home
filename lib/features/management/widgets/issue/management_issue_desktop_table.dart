import 'package:flutter/material.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../data/models/issue_model.dart';

class ManagementIssueDesktopTable extends StatelessWidget {
  final List<IssueModel> issues;
  final void Function(IssueModel issue) onAutoAssignAi;
  final void Function(IssueModel issue) onAssignStaff;
  final void Function(IssueModel issue) onResolve;
  final void Function(IssueModel issue) onOpenDetail;

  const ManagementIssueDesktopTable({
    super.key,
    required this.issues,
    required this.onAutoAssignAi,
    required this.onAssignStaff,
    required this.onResolve,
    required this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final errorColor = AppTheme.getSemanticError(context);
    final warningColor = AppTheme.getSemanticWarning(context);
    final successColor = AppTheme.getSemanticSuccess(context);
    final secondaryColor = AppTheme.getSemanticSecondary(context);

    return AppCard(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 1000),
          child: DataTable(
            columnSpacing: 16,
            horizontalMargin: 16,
            headingRowColor: WidgetStateProperty.all(
              colorScheme.surfaceContainerLow,
            ),
            columns: const [
              DataColumn(
                label: Text(
                  'Căn hộ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Phân loại & Mức độ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Mô tả sự cố',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Cam kết SLA',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Người gửi & Phụ trách',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Trạng thái',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Thao tác',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
            rows: issues.map((issue) {
              final isHighPriority = issue.priority == 'high';
              final isMediumPriority = issue.priority == 'medium';
              final priorityColor = isHighPriority
                  ? AppStatusColors.getPriorityHigh(context)
                  : (isMediumPriority
                        ? AppStatusColors.getPriorityMedium(context)
                        : AppStatusColors.getPriorityLow(context));
              final isNew =
                  DateTime.now().difference(issue.createdAt).inMinutes < 15;
              final slaColor = issue.isSlaBreached
                  ? errorColor
                  : (issue.isSlaWarning ? warningColor : colorScheme.primary);

              return DataRow(
                cells: [
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          issue.apartment?.code ?? 'N/A',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (isNew) ...[
                          AppSpacing.w4,
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.textSuccess,
                              borderRadius: AppRadius.r4,
                            ),
                            child: Text(
                              'MỚI',
                              style: context.labelSmall?.copyWith(
                                color: colorScheme.onPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                        if (issue.isHazardous) ...[
                          AppSpacing.w4,
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.textError,
                              borderRadius: AppRadius.r4,
                            ),
                            child: Text(
                              'NGUY HIỂM',
                              style: context.labelSmall?.copyWith(
                                color: colorScheme.onError,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(
                              alpha: isDark ? 0.18 : 0.08,
                            ),
                            borderRadius: AppRadius.r8,
                          ),
                          child: Text(
                            issue.categoryDisplayName,
                            style: context.labelSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                        AppSpacing.w6,
                        Semantics(
                          label: 'Mức độ ưu tiên: ${issue.priorityDisplayName}',
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: priorityColor.withValues(
                                alpha: isDark ? 0.18 : 0.10,
                              ),
                              borderRadius: AppRadius.r8,
                            ),
                            child: Text(
                              issue.priorityDisplayName,
                              style: context.labelSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: priorityColor,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  DataCell(
                    SizedBox(
                      width: 240,
                      child: Text(
                        issue.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.bodySmall,
                      ),
                    ),
                  ),
                  DataCell(
                    issue.slaDeadline != null
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: slaColor.withValues(
                                alpha: isDark ? 0.18 : 0.10,
                              ),
                              borderRadius: AppRadius.r8,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  issue.isSlaBreached
                                      ? Icons.timer_off_outlined
                                      : (issue.isSlaWarning
                                            ? Icons.warning_amber_rounded
                                            : Icons.access_time),
                                  size: 14,
                                  color: slaColor,
                                ),
                                AppSpacing.w4,
                                Text(
                                  issue.slaRemainingFormatted,
                                  style: context.labelSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: slaColor,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Text(
                            '-',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                  ),
                  DataCell(
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          issue.reporter?.fullName ?? 'Cư dân',
                          style: context.labelSmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          issue.assignedStaff != null
                              ? 'KT: ${issue.assignedStaff!.fullName}'
                              : 'Chưa phân công',
                          style: context.labelSmall?.copyWith(
                            color: issue.assignedStaff != null
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  DataCell(_buildStatusBadge(context, issue.status)),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (issue.status == 'pending') ...[
                          IconButton(
                            constraints: const BoxConstraints(
                              minWidth: 48,
                              minHeight: 48,
                            ),
                            icon: Icon(
                              Icons.auto_awesome,
                              size: 18,
                              color: secondaryColor,
                            ),
                            tooltip: 'Gán theo AI',
                            onPressed: () => onAutoAssignAi(issue),
                          ),
                          IconButton(
                            constraints: const BoxConstraints(
                              minWidth: 48,
                              minHeight: 48,
                            ),
                            icon: Icon(
                              Icons.person_add_outlined,
                              size: 18,
                              color: colorScheme.primary,
                            ),
                            tooltip: 'Phân công',
                            onPressed: () => onAssignStaff(issue),
                          ),
                        ] else if (issue.status == 'in_progress') ...[
                          IconButton(
                            constraints: const BoxConstraints(
                              minWidth: 48,
                              minHeight: 48,
                            ),
                            icon: Icon(
                              Icons.check_circle_outline,
                              size: 18,
                              color: successColor,
                            ),
                            tooltip: 'Nghiệm thu & Vật tư',
                            onPressed: () => onResolve(issue),
                          ),
                        ],
                        IconButton(
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          icon: Icon(
                            Icons.arrow_forward_ios,
                            size: 14,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          tooltip: 'Chi tiết',
                          onPressed: () => onOpenDetail(issue),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, String status) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color color;
    final String text;
    switch (status) {
      case 'resolved':
        color = AppStatusColors.getPaid(context);
        text = 'Đã xử lý';
      case 'in_progress':
        color = colorScheme.primary;
        text = 'Đang xử lý';
      default:
        color = AppStatusColors.getPending(context);
        text = 'Chờ xử lý';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.10),
        borderRadius: AppRadius.r12,
        border: Border.all(color: color.withValues(alpha: isDark ? 0.45 : 0.3)),
      ),
      child: Text(
        text,
        style: context.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
