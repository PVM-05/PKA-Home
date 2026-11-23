import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_storage_image.dart';
import '../../../../core/widgets/photo_viewer_screen.dart';
import '../../../../data/models/issue_model.dart';

class ManagementIssueMobileCard extends StatelessWidget {
  final IssueModel issue;
  final VoidCallback onOpenDetail;
  final VoidCallback onAutoAssignAi;
  final VoidCallback onAssignStaff;
  final VoidCallback onResolve;

  const ManagementIssueMobileCard({
    super.key,
    required this.issue,
    required this.onOpenDetail,
    required this.onAutoAssignAi,
    required this.onAssignStaff,
    required this.onResolve,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final isHighPriority = issue.priority == 'high';
    final isMediumPriority = issue.priority == 'medium';
    final highPriorityColor = AppStatusColors.getPriorityHigh(context);
    final priorityColor = isHighPriority
        ? highPriorityColor
        : (isMediumPriority
              ? AppStatusColors.getPriorityMedium(context)
              : AppStatusColors.getPriorityLow(context));
    final paidColor = AppStatusColors.getPaid(context);
    final errorColor = AppTheme.getSemanticError(context);
    final warningColor = AppTheme.getSemanticWarning(context);
    final secondaryColor = AppTheme.getSemanticSecondary(context);

    final slaColor = issue.isSlaBreached
        ? errorColor
        : (issue.isSlaWarning ? warningColor : colorScheme.primary);

    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final isNew = DateTime.now().difference(issue.createdAt).inMinutes < 15;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      borderRadius: 16,
      borderColor: isHighPriority
          ? highPriorityColor.withValues(alpha: isDark ? 0.65 : 0.55)
          : null,
      onTap: onOpenDetail,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Semantics(
                      label: 'Mức độ ưu tiên: ${issue.priorityDisplayName}',
                      child: Icon(
                        isHighPriority ? Icons.warning : Icons.info_outline,
                        color: priorityColor,
                        size: 18,
                      ),
                    ),
                    AppSpacing.w6,
                    Flexible(
                      child: Text(
                        'Căn hộ ${issue.apartment?.code ?? 'N/A'}',
                        style: context.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isHighPriority
                              ? highPriorityColor
                              : colorScheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
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
              AppSpacing.w6,
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  dateFormat.format(issue.createdAt),
                  style: context.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.h8,
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(
                    alpha: isDark ? 0.18 : 0.08,
                  ),
                  borderRadius: AppRadius.r8,
                  border: Border.all(
                    color: colorScheme.primary.withValues(
                      alpha: isDark ? 0.4 : 0.22,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.handyman_outlined,
                      size: 12,
                      color: colorScheme.primary,
                    ),
                    AppSpacing.w4,
                    Text(
                      issue.categoryDisplayName,
                      style: context.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              if (issue.hasAiTriage)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: secondaryColor.withValues(
                      alpha: isDark ? 0.18 : 0.08,
                    ),
                    borderRadius: AppRadius.r8,
                    border: Border.all(
                      color: secondaryColor.withValues(
                        alpha: isDark ? 0.45 : 0.30,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, size: 12, color: secondaryColor),
                      AppSpacing.w4,
                      Text(
                        'AI: ${issue.aiSuggestedCategoryDisplayName} (${(issue.aiCategoryConfidence * 100).toInt()}%)',
                        style: context.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: secondaryColor,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              if (issue.slaDeadline != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: slaColor.withValues(alpha: isDark ? 0.18 : 0.10),
                    borderRadius: AppRadius.r8,
                    border: Border.all(
                      color: slaColor.withValues(alpha: isDark ? 0.45 : 0.28),
                    ),
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
                        size: 12,
                        color: slaColor,
                      ),
                      AppSpacing.w4,
                      Text(
                        issue.slaRemainingFormatted,
                        style: context.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: slaColor,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          AppSpacing.h12,
          Text(issue.description, style: theme.textTheme.bodyMedium),
          if (issue.reportImages.isNotEmpty) ...[
            AppSpacing.h12,
            Text(
              'Ảnh báo cáo sự cố (Trước khi sửa):',
              style: context.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            AppSpacing.h4,
            ClipRRect(
              borderRadius: AppRadius.r8,
              child: GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PhotoViewerScreen(
                        imageUrls: issue.reportImages,
                        initialIndex: 0,
                      ),
                    ),
                  );
                },
                child: AppStorageImage(
                  imageUrl: issue.reportImages.first,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ],
          if (issue.resolutionProofImages.isNotEmpty) ...[
            AppSpacing.h12,
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: paidColor.withValues(alpha: isDark ? 0.14 : 0.08),
                borderRadius: AppRadius.r8,
                border: Border.all(
                  color: paidColor.withValues(alpha: isDark ? 0.42 : 0.30),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.verified, size: 16, color: paidColor),
                      AppSpacing.w6,
                      Expanded(
                        child: Text(
                          'Ảnh nghiệm thu hoàn thành (Sau khi sửa):',
                          style: context.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: paidColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.h8,
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: issue.resolutionProofImages.length,
                      itemBuilder: (ctx, i) => Container(
                        margin: const EdgeInsets.only(right: 8),
                        child: ClipRRect(
                          borderRadius: AppRadius.r8,
                          child: GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => PhotoViewerScreen(
                                    imageUrls: issue.resolutionProofImages,
                                    initialIndex: i,
                                  ),
                                ),
                              );
                            },
                            child: AppStorageImage(
                              imageUrl: issue.resolutionProofImages[i],
                              width: 100,
                              height: 80,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (issue.reporter != null) ...[
            AppSpacing.h8,
            Text(
              'Người gửi: ${issue.reporter!.fullName}',
              style: context.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (issue.assignedStaff != null) ...[
            AppSpacing.h6,
            Row(
              children: [
                Icon(
                  Icons.engineering_outlined,
                  size: 16,
                  color: colorScheme.primary,
                ),
                AppSpacing.w6,
                Expanded(
                  child: Text(
                    'Phụ trách: ${issue.assignedStaff!.fullName}',
                    style: context.labelSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          AppSpacing.h12,
          if (issue.status == 'pending')
            LayoutBuilder(
              builder: (context, cardConstraints) {
                final aiBtn = OutlinedButton.icon(
                  onPressed: onAutoAssignAi,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: secondaryColor,
                    side: BorderSide(
                      color: secondaryColor.withValues(alpha: 0.6),
                    ),
                    minimumSize: const Size(0, 48),
                  ),
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: Text('Gán theo AI', style: context.labelSmall),
                );
                final assignBtn = ElevatedButton.icon(
                  onPressed: onAssignStaff,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    minimumSize: const Size(0, 48),
                  ),
                  icon: const Icon(Icons.person_add_outlined, size: 16),
                  label: Text(
                    'Phân công',
                    style: context.labelSmall?.copyWith(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );

                if (cardConstraints.maxWidth < 340) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [aiBtn, AppSpacing.h8, assignBtn],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: aiBtn),
                    AppSpacing.w8,
                    Expanded(child: assignBtn),
                  ],
                );
              },
            )
          else if (issue.status == 'in_progress')
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onResolve,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.textSuccess,
                  foregroundColor: colorScheme.onPrimary,
                  minimumSize: const Size(double.infinity, 48),
                ),
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: Text(
                  'Nghiệm thu & Kê khai vật tư',
                  style: context.labelSmall?.copyWith(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          AppSpacing.h6,
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: onOpenDetail,
              icon: const Icon(Icons.forum_outlined, size: 18),
              label: Text('Chi tiết & Trao đổi', style: context.bodySmall),
            ),
          ),
        ],
      ),
    );
  }
}
