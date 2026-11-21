import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_skeleton_shimmer.dart';
import '../../../../data/models/issue_model.dart';
import '../../../../data/models/issue_rating_model.dart';
import '../issue_rating_bottom_sheet.dart';

class IssueRatingSection extends StatelessWidget {
  final IssueModel issue;
  final AsyncValue<IssueRatingModel?> ratingAsync;
  final bool isReporter;

  const IssueRatingSection({
    super.key,
    required this.issue,
    required this.ratingAsync,
    required this.isReporter,
  });

  @override
  Widget build(BuildContext context) {
    if (issue.status != 'resolved') return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final warningColor = AppTheme.getSemanticWarning(context);
    final successColor = AppStatusColors.getPaid(context);

    return ratingAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: AppSkeletonShimmer.rectangular(
          height: 72,
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      error: (e, _) => const SizedBox.shrink(),
      data: (rating) {
        if (rating == null) {
          if (!isReporter) return const SizedBox.shrink();

          return AppCard(
            borderColor: warningColor.withValues(alpha: isDark ? 0.5 : 0.4),
            color: warningColor.withValues(alpha: isDark ? 0.1 : 0.05),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: warningColor.withValues(
                          alpha: isDark ? 0.25 : 0.16,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.star_rate_rounded,
                        color: warningColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Đánh giá chất lượng dịch vụ',
                            style: context.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Sự cố đã hoàn thành. Hãy chia sẻ cảm nhận của bạn!',
                            style: context.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                        ),
                        builder: (_) => IssueRatingBottomSheet(
                          issueReportId: issue.id,
                          reporterId: issue.reporterId,
                        ),
                      );
                    },
                    icon: const Icon(Icons.star_rate_rounded, size: 18),
                    label: const Text('Đánh giá ngay'),
                  ),
                ),
              ],
            ),
          );
        }

        final label = IssueRatingModel.getSatisfactionLabel(
          rating.overallRating,
        );

        return AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.verified_outlined,
                          color: successColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Đánh giá dịch vụ',
                            style: context.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isReporter)
                    IconButton(
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      icon: Icon(
                        Icons.edit_outlined,
                        size: 20,
                        color: colorScheme.primary,
                      ),
                      tooltip: 'Chỉnh sửa đánh giá',
                      onPressed: () {
                        showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(20),
                            ),
                          ),
                          builder: (_) => IssueRatingBottomSheet(
                            issueReportId: issue.id,
                            reporterId: issue.reporterId,
                            initialRating: rating,
                          ),
                        );
                      },
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: warningColor.withValues(
                        alpha: isDark ? 0.2 : 0.14,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star_rate_rounded,
                          size: 18,
                          color: warningColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${rating.overallRating.toStringAsFixed(1)} / 5.0',
                          style: context.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: warningColor,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    label,
                    style: context.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _RatingChip(title: 'Tốc độ', stars: rating.speedRating),
                  _RatingChip(title: 'Thái độ', stars: rating.attitudeRating),
                  _RatingChip(title: 'Kỹ thuật', stars: rating.qualityRating),
                ],
              ),
              if (rating.comment != null &&
                  rating.comment!.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.35,
                          )
                        : colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '"${rating.comment}"',
                    style: (context.bodySmall ?? const TextStyle()).copyWith(
                      fontStyle: FontStyle.italic,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _RatingChip extends StatelessWidget {
  final String title;
  final int stars;

  const _RatingChip({required this.title, required this.stars});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final warningColor = AppTheme.getSemanticWarning(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.35)
            : colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$title: ',
            style: context.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            '$stars',
            style: context.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Icon(Icons.star_rate_rounded, size: 13, color: warningColor),
        ],
      ),
    );
  }
}
