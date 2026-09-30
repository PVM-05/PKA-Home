import 'package:flutter/material.dart';
import '../../../core/widgets/app_card.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/issue_model.dart';
import '../../../data/providers/management_provider.dart';
import '../../../data/providers/issue_rating_provider.dart';

class TechnicianStatItem {
  final String staffId;
  final String staffName;
  final int totalAssigned;
  final int resolvedCount;
  final int inProgressCount;
  final double avgResolutionHours;
  final double avgRating;
  final int ratingCount;

  const TechnicianStatItem({
    required this.staffId,
    required this.staffName,
    required this.totalAssigned,
    required this.resolvedCount,
    required this.inProgressCount,
    required this.avgResolutionHours,
    this.avgRating = 0.0,
    this.ratingCount = 0,
  });
}

class TechnicianPerformanceCard extends ConsumerWidget {
  const TechnicianPerformanceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final issuesAsync = ref.watch(allIssuesProvider);
    final residentsAsync = ref.watch(residentsProvider);
    final ratingsAsync = ref.watch(allIssueRatingsProvider);

    return issuesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (err, stack) => const SizedBox.shrink(),
      data: (issues) {
        final residents = residentsAsync.valueOrNull ?? [];
        final staffMap = {for (var r in residents) r.id: r.fullName};

        // Lọc các sự cố đã được gán kỹ thuật viên
        final assignedIssues = issues.where((i) => i.assignedStaffId != null).toList();
        if (assignedIssues.isEmpty) {
          return const SizedBox.shrink();
        }

        // Nhóm theo assignedStaffId
        final Map<String, List<IssueModel>> grouped = {};
        for (var issue in assignedIssues) {
          final id = issue.assignedStaffId!;
          grouped.putIfAbsent(id, () => []).add(issue);
        }

        final List<TechnicianStatItem> stats = [];
        grouped.forEach((staffId, staffIssues) {
          final resolved = staffIssues.where((i) => i.status == 'resolved').toList();
          final inProgress = staffIssues.where((i) => i.status == 'in_progress').length;

          double totalHours = 0;
          for (var r in resolved) {
            final finishTime = r.updatedAt ?? r.createdAt;
            final duration = finishTime.difference(r.createdAt);
            totalHours += duration.inMinutes / 60.0;
          }
          final avgHours = resolved.isNotEmpty ? totalHours / resolved.length : 0.0;

          final allRatings = ratingsAsync.valueOrNull ?? [];
          final techRatings = allRatings.where((r) {
            return staffIssues.any((issue) => issue.id == r.issueReportId);
          }).toList();

          final double avgRating = techRatings.isNotEmpty
              ? techRatings.map((r) => r.overallRating).reduce((a, b) => a + b) / techRatings.length
              : 0.0;
          final int ratingCount = techRatings.length;

          stats.add(TechnicianStatItem(
            staffId: staffId,
            staffName: staffMap[staffId] ?? 'Kỹ thuật viên',
            totalAssigned: staffIssues.length,
            resolvedCount: resolved.length,
            inProgressCount: inProgress,
            avgResolutionHours: avgHours,
            avgRating: avgRating,
            ratingCount: ratingCount,
          ));
        });

        // Sắp xếp theo số sự cố giải quyết giảm dần
        stats.sort((a, b) => b.resolvedCount.compareTo(a.resolvedCount));

        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final textScale = MediaQuery.textScalerOf(context).scale(1.0);
        final cardHeight = (118.0 * textScale).clamp(118.0, 165.0);
        final itemBgColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50;
        final itemBorderColor = isDark ? theme.dividerColor.withValues(alpha: 0.15) : Colors.grey.shade200;

        return AppCard(
          margin: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.analytics_outlined, color: Colors.orange, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Hiệu Suất Kỹ Thuật Viên',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: cardHeight,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: stats.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final item = stats[index];
                    final completionRate = item.totalAssigned > 0
                        ? (item.resolvedCount / item.totalAssigned * 100).toStringAsFixed(0)
                        : '0';

                    return Container(
                      width: 220,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: itemBgColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: itemBorderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const CircleAvatar(
                                radius: 12,
                                backgroundColor: AppTheme.primary,
                                child: Icon(Icons.person, size: 14, color: Colors.white),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item.staffName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (item.ratingCount > 0) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.star_rate_rounded, size: 12, color: Colors.amber),
                                      const SizedBox(width: 2),
                                      Text(
                                        item.avgRating.toStringAsFixed(1),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.amber,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Đã xử lý', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                  Text(
                                    '${item.resolvedCount}/${item.totalAssigned} ($completionRate%)',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.success, fontSize: 13),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('TG trung bình', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                  Text(
                                    item.avgResolutionHours < 1
                                        ? '${(item.avgResolutionHours * 60).toStringAsFixed(0)} phút'
                                        : '${item.avgResolutionHours.toStringAsFixed(1)} giờ',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 13),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
