import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/router/route_names.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_skeleton_shimmer.dart';
import '../../../data/models/issue_model.dart';
import '../../../data/providers/resident_issue_provider.dart';
import '../../../data/repositories/issue_repository.dart';
import '../../../core/widgets/photo_viewer_screen.dart';
import '../../../core/widgets/app_storage_image.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../core/widgets/app_error_card.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/adaptive_master_detail_layout.dart';
import '../../../core/utils/app_haptics.dart';
import 'issue_detail_screen.dart';

class ResidentIssueScreen extends ConsumerStatefulWidget {
  const ResidentIssueScreen({super.key});

  @override
  ConsumerState<ResidentIssueScreen> createState() => _ResidentIssueScreenState();
}

class _ResidentIssueScreenState extends ConsumerState<ResidentIssueScreen> {
  IssueModel? _selectedIssue;

  @override
  Widget build(BuildContext context) {
    final issueState = ref.watch(residentIssueProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Phản ánh sự cố')),
      body: issueState.when(
        data: (issues) {
          return AdaptiveMasterDetailLayout<IssueModel>(
            selectedItem: _selectedIssue,
            masterWidth: 420.0,
            emptyDetailBuilder: (ctx) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Theme.of(ctx).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.engineering_outlined,
                        size: 48,
                        color: Theme.of(ctx).colorScheme.primary.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Chưa chọn sự cố nào',
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Chọn một phản ánh từ danh sách bên trái để theo dõi tiến độ xử lý và trao đổi với kỹ thuật viên.',
                      textAlign: TextAlign.center,
                      style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            detailBuilder: (ctx, item) => IssueDetailScreen(
              issue: item,
              isEmbedded: true,
            ),
            masterBuilder: (ctx, isMasterOnly) {
              if (issues.isEmpty) {
                return RefreshIndicator(
                  color: AppTheme.primary,
                  onRefresh: () async {
                    HapticFeedback.lightImpact();
                    ref.invalidate(residentIssuePaginatedProvider);
                    ref.invalidate(residentIssueProvider);
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: MediaQuery.of(ctx).size.height * 0.6,
                        child: _buildEmptyState(ctx),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                color: AppTheme.primary,
                onRefresh: () async {
                  HapticFeedback.lightImpact();
                  ref.invalidate(residentIssuePaginatedProvider);
                  ref.invalidate(residentIssueProvider);
                },
                child: NotificationListener<ScrollNotification>(
                  onNotification: (scrollInfo) {
                    if (scrollInfo.metrics.pixels >=
                        scrollInfo.metrics.maxScrollExtent - 200) {
                      try {
                        ref.read(residentIssuePaginatedProvider.notifier).loadMore();
                      } catch (_) {}
                    }
                    return false;
                  },
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                    itemCount: issues.length,
                    itemBuilder: (context, index) {
                      final issue = issues[index];
                      final isSelected = !isMasterOnly && issue.id == _selectedIssue?.id;
                      return _buildIssueCard(
                        context,
                        ref,
                        issue,
                        isMasterOnly: isMasterOnly,
                        isSelected: isSelected,
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
        loading: () => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppSkeletonShimmer.cardList(count: 3, itemHeight: 120),
          ],
        ),
        error: (error, stack) => Center(
          child: AppErrorCard(
            error: error,
            onRetry: () {
              ref.invalidate(residentIssuePaginatedProvider);
              ref.invalidate(residentIssueProvider);
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'resident_issue_fab',
        tooltip: 'Tạo phản ánh sự cố mới',
        onPressed: () {
          context.push(AppRoutes.residentCreateIssue);
        },
        icon: const Icon(Icons.add),
        label: const Text('Tạo phản ánh'),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: AppEmptyState(
        icon: Icons.chat_bubble_outline,
        title: 'Bạn chưa gửi phản ánh nào',
        description:
            'Khi căn hộ gặp sự cố (điện, nước, cơ sở vật chất), hãy gửi phản ánh để Ban Quản Lý hỗ trợ xử lý kịp thời.',
        actionLabel: 'Gửi phản ánh ngay',
        onAction: () => context.push(AppRoutes.residentCreateIssue),
      ),
    );
  }

  Future<void> _confirmDeleteIssue(
    BuildContext context,
    WidgetRef ref,
    IssueModel issue,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.error),
            SizedBox(width: 8),
            Expanded(child: Text('Xác nhận xóa')),
          ],
        ),
        content: const Text(
          'Bạn có chắc chắn muốn xóa phản ánh sự cố này? Dữ liệu và hình ảnh đính kèm sẽ bị xóa hoàn toàn khỏi hệ thống.',
          style: TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xóa phản ánh'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final issueRepo = ref.read(issueRepositoryProvider);
        await issueRepo.deleteIssue(
          issueId: issue.id,
          imageUrls: issue.imageUrls,
        );

        ref.invalidate(residentIssueProvider);
        ref.invalidate(residentIssuePaginatedProvider);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã xóa phản ánh sự cố thành công'),
              backgroundColor: AppTheme.success,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(formatErrorMessage(e)),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    }
  }

  Widget _buildIssueCard(
    BuildContext context,
    WidgetRef ref,
    IssueModel issue, {
    bool isMasterOnly = true,
    bool isSelected = false,
  }) {
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

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      label: 'Phản ánh sự cố: ${issue.description}, trạng thái $statusText, mức độ ưu tiên $priorityText, ngày tạo ${formatDate.format(issue.createdAt)}',
      button: true,
      child: AppCard(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        borderColor: isSelected ? AppTheme.primary : null,
        child: InkWell(
          onTap: () {
            if (isMasterOnly) {
              context.push(AppRoutes.residentIssueDetail, extra: issue);
            } else {
              AppHaptics.selection();
              setState(() {
                _selectedIssue = issue;
              });
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.access_time,
                    size: 14,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      formatDate.format(issue.createdAt),
                      style: context.labelSmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Semantics(
                      label: 'Trạng thái: $statusText',
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: isDark ? 0.2 : 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          statusText,
                          style: context.labelSmall?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                  if (issue.status == 'pending') ...[
                    const SizedBox(width: 2),
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: PopupMenuButton<String>(
                            tooltip: 'Thao tác phản ánh',
                            padding: EdgeInsets.zero,
                            iconSize: 18,
                            icon: const Icon(
                              Icons.more_vert,
                              size: 18,
                              color: AppTheme.textSecondary,
                            ),
                          onSelected: (value) {
                            if (value == 'edit') {
                              context.push(
                                AppRoutes.residentEditIssue,
                                extra: issue,
                              );
                            } else if (value == 'delete') {
                              _confirmDeleteIssue(context, ref, issue);
                            }
                          },
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                    color: AppTheme.primary,
                                  ),
                                  SizedBox(width: 8),
                                  Text('Chỉnh sửa'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color: AppTheme.error,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Xóa phản ánh',
                                    style: TextStyle(color: AppTheme.error),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Text(issue.description, style: context.bodyMedium),

              if (issue.reportImages.isNotEmpty) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    children: [
                      GestureDetector(
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
                          height: 140,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Ảnh lúc báo cáo',
                            style: context.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      if (issue.reportImages.length > 1)
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.photo_library_outlined,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '+${issue.reportImages.length - 1} ảnh',
                                  style: context.labelSmall?.copyWith(
                                    color: Colors.white,
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

              if (issue.resolutionProofImages.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppStatusColors.paid.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppStatusColors.paid.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.verified,
                            size: 16,
                            color: AppStatusColors.paid,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Ảnh minh chứng đã khắc phục (Sau khi sửa)',
                            style: context.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppStatusColors.paid,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 100,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: issue.resolutionProofImages.length,
                          itemBuilder: (ctx, i) {
                            return Container(
                              margin: const EdgeInsets.only(right: 8),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => PhotoViewerScreen(
                                          imageUrls:
                                              issue.resolutionProofImages,
                                          initialIndex: i,
                                        ),
                                      ),
                                    );
                                  },
                                  child: AppStorageImage(
                                    imageUrl: issue.resolutionProofImages[i],
                                    width: 120,
                                    height: 100,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      label: 'Mức độ ưu tiên: $priorityText',
                      child: Text.rich(
                        TextSpan(
                          text: 'Mức độ: ',
                          style: context.labelSmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                          children: [
                            TextSpan(
                              text: priorityText,
                              style: context.labelSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: priorityColor,
                              ),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.forum_outlined,
                        size: 14,
                        color: AppTheme.primary.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Chi tiết',
                        style: context.labelSmall?.copyWith(
                          color: AppTheme.primary.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: AppTheme.primary.withValues(alpha: 0.7),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  }
