import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/providers/resident_issue_provider.dart';
import 'create_issue_screen.dart';

class ResidentIssueScreen extends ConsumerWidget {
  const ResidentIssueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final issueState = ref.watch(residentIssueProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Phản ánh sự cố'),
      ),
      body: issueState.when(
        data: (issues) {
          if (issues.isEmpty) {
            return _buildEmptyState(context);
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(residentIssueProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: issues.length,
              itemBuilder: (context, index) {
                return _buildIssueCard(context, issues[index]);
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Lỗi tải dữ liệu: $error')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const CreateIssueScreen(),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Tạo phản ánh'),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: AppTheme.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Bạn chưa gửi phản ánh nào',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildIssueCard(BuildContext context, dynamic issue) {
    final formatDate = DateFormat('dd/MM/yyyy HH:mm');

    Color statusColor;
    String statusText;
    switch (issue.status) {
      case 'resolved':
        statusColor = AppTheme.success;
        statusText = 'Đã xử lý';
        break;
      case 'in_progress':
        statusColor = AppTheme.primary;
        statusText = 'Đang xử lý';
        break;
      default:
        statusColor = AppTheme.warning;
        statusText = 'Chờ tiếp nhận';
    }

    Color priorityColor;
    String priorityText;
    switch (issue.priority) {
      case 'high':
        priorityColor = AppTheme.error;
        priorityText = 'Khẩn cấp';
        break;
      case 'low':
        priorityColor = AppTheme.success;
        priorityText = 'Thấp';
        break;
      default:
        priorityColor = AppTheme.warning;
        priorityText = 'Bình thường';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: AppTheme.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      formatDate.format(issue.createdAt),
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              issue.description,
              style: const TextStyle(fontSize: 14),
            ),
            
            if (issue.imageUrls.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  children: [
                    Image.network(
                      issue.imageUrls.first,
                      height: 140,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                    if (issue.imageUrls.length > 1)
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.photo_library_outlined, color: Colors.white, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                '+${issue.imageUrls.length - 1} ảnh',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 12),
            Row(
              children: [
                const Text(
                  'Mức độ: ',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                Text(
                  priorityText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: priorityColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
