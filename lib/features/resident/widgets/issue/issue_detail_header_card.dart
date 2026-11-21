import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_storage_image.dart';
import '../../../../core/widgets/photo_viewer_screen.dart';
import '../../../../data/models/issue_model.dart';

class IssueDetailHeaderCard extends StatelessWidget {
  final IssueModel issue;

  const IssueDetailHeaderCard({super.key, required this.issue});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final statusInfo = _getStatusInfo(context, issue.status);
    final priorityInfo = _getPriorityInfo(context, issue.priority);
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final semanticError = AppTheme.getSemanticError(context);
    final semanticWarning = AppTheme.getSemanticWarning(context);
    final semanticSecondary = AppTheme.getSemanticSecondary(context);

    final slaColor = issue.isSlaBreached
        ? semanticError
        : (issue.isSlaWarning ? semanticWarning : semanticSecondary);

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusInfo.color.withValues(
                    alpha: isDark ? 0.2 : 0.1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: statusInfo.color.withValues(
                      alpha: isDark ? 0.45 : 0.35,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusInfo.icon, size: 14, color: statusInfo.color),
                    const SizedBox(width: 4),
                    Text(
                      statusInfo.label,
                      style: context.labelSmall?.copyWith(
                        color: statusInfo.color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: priorityInfo.color.withValues(
                    alpha: isDark ? 0.2 : 0.1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  priorityInfo.label,
                  style: context.labelSmall?.copyWith(
                    color: priorityInfo.color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(
                    alpha: isDark ? 0.18 : 0.08,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.primary.withValues(
                      alpha: isDark ? 0.4 : 0.3,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.handyman_outlined,
                      size: 13,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      issue.categoryDisplayName,
                      style: context.labelSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              if (issue.slaDeadline != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: slaColor.withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: slaColor.withValues(alpha: isDark ? 0.45 : 0.3),
                    ),
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 240),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            issue.isSlaBreached
                                ? Icons.timer_off_outlined
                                : (issue.isSlaWarning
                                      ? Icons.warning_amber_rounded
                                      : Icons.access_time),
                            size: 13,
                            color: slaColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            issue.slaRemainingFormatted,
                            maxLines: 1,
                            style: context.labelSmall?.copyWith(
                              color: slaColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            issue.description,
            style: (context.bodyLarge ?? const TextStyle()).copyWith(
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _InfoChip(
                icon: Icons.apartment_outlined,
                text: 'Căn hộ ${issue.apartment?.code ?? 'N/A'}',
              ),
              _InfoChip(
                icon: Icons.calendar_today_outlined,
                text: dateFormat.format(issue.createdAt),
              ),
              if (issue.reporter != null)
                _InfoChip(
                  icon: Icons.person_outline,
                  text: issue.reporter!.fullName,
                ),
              if (issue.assignedStaff != null)
                _InfoChip(
                  icon: Icons.engineering_outlined,
                  text: 'Phụ trách: ${issue.assignedStaff!.fullName}',
                ),
            ],
          ),
        ],
      ),
    );
  }

  _StatusInfo _getStatusInfo(BuildContext context, String status) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (status) {
      case 'resolved':
        return _StatusInfo(
          'Đã xử lý',
          Icons.check_circle,
          AppStatusColors.getPaid(context),
        );
      case 'in_progress':
        return _StatusInfo(
          'Đang xử lý',
          Icons.engineering,
          colorScheme.primary,
        );
      default:
        return _StatusInfo(
          'Chờ tiếp nhận',
          Icons.pending_actions,
          AppStatusColors.getPending(context),
        );
    }
  }

  _PriorityInfo _getPriorityInfo(BuildContext context, String priority) {
    switch (priority) {
      case 'high':
        return _PriorityInfo(
          'Khẩn cấp',
          AppStatusColors.getPriorityHigh(context),
        );
      case 'low':
        return _PriorityInfo('Thấp', AppStatusColors.getPriorityLow(context));
      default:
        return _PriorityInfo(
          'Trung bình',
          AppStatusColors.getPriorityMedium(context),
        );
    }
  }
}

class IssueDetailImagesSection extends StatelessWidget {
  final String title;
  final List<String> imageUrls;

  const IssueDetailImagesSection({
    super.key,
    required this.title,
    required this.imageUrls,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: context.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 84,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: imageUrls.length,
            separatorBuilder: (_, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              return Semantics(
                button: true,
                label: 'Xem $title số ${index + 1}',
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PhotoViewerScreen(
                          imageUrls: imageUrls,
                          initialIndex: index,
                        ),
                      ),
                    );
                  },
                  child: AppStorageImage(
                    imageUrl: imageUrls[index],
                    width: 84,
                    height: 84,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              text,
              style: context.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusInfo {
  final String label;
  final IconData icon;
  final Color color;
  const _StatusInfo(this.label, this.icon, this.color);
}

class _PriorityInfo {
  final String label;
  final Color color;
  const _PriorityInfo(this.label, this.color);
}
