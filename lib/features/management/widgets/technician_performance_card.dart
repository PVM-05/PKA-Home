import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/issue_model.dart';
import '../../../data/providers/management_provider.dart';

class TechnicianStatItem {
  final String staffId;
  final String staffName;
  final int totalAssigned;
  final int resolvedCount;
  final int inProgressCount;
  final double avgResolutionHours;

  const TechnicianStatItem({
    required this.staffId,
    required this.staffName,
    required this.totalAssigned,
    required this.resolvedCount,
    required this.inProgressCount,
    required this.avgResolutionHours,
  });
}

class TechnicianPerformanceCard extends ConsumerWidget {
  const TechnicianPerformanceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final issuesAsync = ref.watch(allIssuesProvider);
    final residentsAsync = ref.watch(residentsProvider);

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

          stats.add(TechnicianStatItem(
            staffId: staffId,
            staffName: staffMap[staffId] ?? 'Kỹ thuật viên',
            totalAssigned: staffIssues.length,
            resolvedCount: resolved.length,
            inProgressCount: inProgress,
            avgResolutionHours: avgHours,
          ));
        });

        // Sắp xếp theo số sự cố giải quyết giảm dần
        stats.sort((a, b) => b.resolvedCount.compareTo(a.resolvedCount));

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
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
                height: 110,
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
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
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
