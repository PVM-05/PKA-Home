import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../data/models/issue_model.dart';

class IssueStatusTimeline extends StatelessWidget {
  final IssueModel issue;

  const IssueStatusTimeline({super.key, required this.issue});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final steps = <_TimelineStep>[
      _TimelineStep(
        label: 'Đã gửi phản ánh',
        date: issue.createdAt,
        isCompleted: true,
        icon: Icons.send,
        color: colorScheme.primary,
      ),
      _TimelineStep(
        label: 'Đang xử lý',
        date: issue.status == 'in_progress' || issue.status == 'resolved'
            ? issue.updatedAt
            : null,
        isCompleted:
            issue.status == 'in_progress' || issue.status == 'resolved',
        icon: Icons.engineering,
        color: AppStatusColors.getPending(context),
      ),
      _TimelineStep(
        label: 'Đã giải quyết',
        date: issue.status == 'resolved' ? issue.updatedAt : null,
        isCompleted: issue.status == 'resolved',
        icon: Icons.check_circle,
        color: AppStatusColors.getPaid(context),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.timeline, size: 20, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Tiến trình xử lý',
              style: context.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...steps.asMap().entries.map((entry) {
          final index = entry.key;
          final step = entry.value;
          final isLast = index == steps.length - 1;

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  child: Column(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: step.isCompleted
                              ? step.color
                              : colorScheme.outlineVariant,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          step.isCompleted ? step.icon : Icons.circle,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 2,
                            color: step.isCompleted
                                ? step.color.withValues(alpha: 0.45)
                                : colorScheme.outlineVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.label,
                          style: context.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: step.isCompleted
                                ? colorScheme.onSurface
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (step.date != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            DateFormat('dd/MM/yyyy HH:mm').format(step.date!),
                            style: context.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _TimelineStep {
  final String label;
  final DateTime? date;
  final bool isCompleted;
  final IconData icon;
  final Color color;

  const _TimelineStep({
    required this.label,
    this.date,
    required this.isCompleted,
    required this.icon,
    required this.color,
  });
}
