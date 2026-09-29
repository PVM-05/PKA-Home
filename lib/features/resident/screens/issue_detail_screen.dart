import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/photo_viewer_screen.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../data/models/issue_model.dart';
import '../../../data/models/issue_comment_model.dart';
import '../../../data/models/issue_rating_model.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/issue_comment_provider.dart';
import '../../../data/providers/issue_rating_provider.dart';
import '../../../data/repositories/issue_repository.dart';
import '../widgets/issue_rating_bottom_sheet.dart';

/// Màn hình chi tiết phản ánh sự cố với timeline trạng thái và hệ thống comment.
class IssueDetailScreen extends ConsumerStatefulWidget {
  final IssueModel issue;

  const IssueDetailScreen({super.key, required this.issue});

  @override
  ConsumerState<IssueDetailScreen> createState() => _IssueDetailScreenState();
}

class _IssueDetailScreenState extends ConsumerState<IssueDetailScreen> {
  final _commentController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    final user = ref.read(authProvider).valueOrNull;
    if (user == null) return;

    setState(() => _isSending = true);

    try {
      await ref.read(issueRepositoryProvider).addComment(
            issueReportId: widget.issue.id,
            userId: user.id,
            content: content,
          );
      _commentController.clear();
      // Scroll xuống cuối sau khi gửi comment
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi gửi bình luận: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(issueCommentsProvider(widget.issue.id));
    final ratingAsync = ref.watch(issueRatingProvider(widget.issue.id));
    final currentUser = ref.watch(authProvider).valueOrNull;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết phản ánh'),
      ),
      body: Column(
        children: [
          // Phần nội dung scrollable
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                // ─── Header: Thông tin sự cố ───
                _buildIssueHeader(isDark),
                const SizedBox(height: 16),

                // ─── Ảnh đính kèm ───
                if (widget.issue.reportImages.isNotEmpty) ...[
                  _buildImageSection('Ảnh phản ánh', widget.issue.reportImages),
                  const SizedBox(height: 12),
                ],
                if (widget.issue.resolutionProofImages.isNotEmpty) ...[
                  _buildImageSection(
                      'Ảnh nghiệm thu', widget.issue.resolutionProofImages),
                  const SizedBox(height: 12),
                ],

                const SizedBox(height: 16),

                // ─── Timeline trạng thái ───
                _buildStatusTimeline(),
                const SizedBox(height: 16),

                // ─── Đánh giá dịch vụ (khi đã giải quyết) ───
                _buildRatingSection(ratingAsync, currentUser, isDark),
                const SizedBox(height: 24),

                // ─── Khu vực comment ───
                Row(
                  children: [
                    const Icon(Icons.forum_outlined,
                        size: 20, color: AppTheme.primary),
                    const SizedBox(width: 8),
                    const Text(
                      'Trao đổi',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    commentsAsync.whenOrNull(
                      data: (comments) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${comments.length}',
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ].whereType<Widget>().toList(),
                ),
                const SizedBox(height: 12),

                commentsAsync.when(
                  data: (comments) {
                    if (comments.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.chat_bubble_outline,
                                size: 40,
                                color: isDark
                                    ? Colors.white38
                                    : AppTheme.textSecondary),
                            const SizedBox(height: 8),
                            Text(
                              'Chưa có trao đổi nào.\nHãy gửi tin nhắn đầu tiên!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: isDark
                                      ? Colors.white60
                                      : AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      );
                    }
                    return Column(
                      children: comments.map((comment) {
                        final isMe = comment.userId == currentUser?.id;
                        return _buildCommentBubble(comment, isMe, isDark);
                      }).toList(),
                    );
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text('Lỗi tải bình luận: $e',
                        style: const TextStyle(color: AppTheme.error)),
                  ),
                ),
                const SizedBox(height: 80), // Padding cho input bar
              ],
            ),
          ),

          // ─── Input bar (cố định ở bottom) ───
          _buildCommentInput(isDark),
        ],
      ),
    );
  }

  Widget _buildIssueHeader(bool isDark) {
    final issue = widget.issue;
    final statusInfo = _getStatusInfo(issue.status);
    final priorityInfo = _getPriorityInfo(issue.priority);
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? Colors.white12 : Colors.grey.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Trạng thái + Ưu tiên
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusInfo.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: statusInfo.color.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusInfo.icon,
                          size: 14, color: statusInfo.color),
                      const SizedBox(width: 4),
                      Text(
                        statusInfo.label,
                        style: TextStyle(
                          color: statusInfo.color,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: priorityInfo.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    priorityInfo.label,
                    style: TextStyle(
                      color: priorityInfo.color,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Mô tả
            Text(
              issue.description,
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 12),

            // Thông tin phụ
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _buildInfoChip(
                  Icons.apartment_outlined,
                  'Căn hộ ${issue.apartment?.code ?? 'N/A'}',
                ),
                _buildInfoChip(
                  Icons.calendar_today_outlined,
                  dateFormat.format(issue.createdAt),
                ),
                if (issue.reporter != null)
                  _buildInfoChip(
                    Icons.person_outline,
                    issue.reporter!.fullName,
                  ),
                if (issue.assignedStaff != null)
                  _buildInfoChip(
                    Icons.engineering_outlined,
                    'Phụ trách: ${issue.assignedStaff!.fullName}',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppTheme.textSecondary),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style:
                const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildImageSection(String title, List<String> imageUrls) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary)),
        const SizedBox(height: 8),
        SizedBox(
          height: 80,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: imageUrls.length,
            separatorBuilder: (_, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => PhotoViewerScreen(
                      imageUrls: imageUrls,
                      initialIndex: index,
                    ),
                  ));
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    imageUrls[index],
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 80,
                      height: 80,
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.broken_image_outlined,
                          color: Colors.grey),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatusTimeline() {
    final issue = widget.issue;
    final steps = <_TimelineStep>[
      _TimelineStep(
        label: 'Đã gửi phản ánh',
        date: issue.createdAt,
        isCompleted: true,
        icon: Icons.send,
        color: AppTheme.primary,
      ),
      _TimelineStep(
        label: 'Đang xử lý',
        date: issue.status == 'in_progress' || issue.status == 'resolved'
            ? issue.updatedAt
            : null,
        isCompleted:
            issue.status == 'in_progress' || issue.status == 'resolved',
        icon: Icons.engineering,
        color: AppTheme.warning,
      ),
      _TimelineStep(
        label: 'Đã giải quyết',
        date: issue.status == 'resolved' ? issue.updatedAt : null,
        isCompleted: issue.status == 'resolved',
        icon: Icons.check_circle,
        color: AppTheme.success,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.timeline, size: 20, color: AppTheme.primary),
            SizedBox(width: 8),
            Text(
              'Tiến trình xử lý',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                // Dot + Line
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
                              : Colors.grey.shade300,
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
                                ? step.color.withValues(alpha: 0.4)
                                : Colors.grey.shade300,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.label,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: step.isCompleted
                                ? null
                                : AppTheme.textSecondary,
                          ),
                        ),
                        if (step.date != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            DateFormat('dd/MM/yyyy HH:mm')
                                .format(step.date!),
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary),
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

  Widget _buildRatingSection(
      AsyncValue<IssueRatingModel?> ratingAsync, dynamic currentUser, bool isDark) {
    if (widget.issue.status != 'resolved') return const SizedBox.shrink();

    final isReporter = currentUser?.id == widget.issue.reporterId;

    return ratingAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (e, _) => const SizedBox.shrink(),
      data: (rating) {
        if (rating == null) {
          if (!isReporter) return const SizedBox.shrink();

          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: Colors.amber.withValues(alpha: 0.4),
              ),
            ),
            color: Colors.amber.withValues(alpha: 0.05),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.star_rate_rounded,
                            color: Colors.amber, size: 22),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Đánh giá chất lượng dịch vụ',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            Text(
                              'Sự cố đã hoàn thành. Hãy chia sẻ cảm nhận của bạn!',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary),
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
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          shape: const RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          builder: (_) => IssueRatingBottomSheet(
                            issueReportId: widget.issue.id,
                            reporterId: widget.issue.reporterId,
                          ),
                        );
                      },
                      icon: const Icon(Icons.star_rate_rounded, size: 18),
                      label: const Text('Đánh giá ngay'),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Đã có đánh giá
        final label =
            IssueRatingModel.getSatisfactionLabel(rating.overallRating);

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isDark ? Colors.white12 : Colors.grey.shade200,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.verified_outlined,
                            color: AppTheme.success, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Đánh giá dịch vụ',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                    if (isReporter)
                      IconButton(
                        icon: const Icon(Icons.edit_outlined,
                            size: 18, color: AppTheme.primary),
                        tooltip: 'Chỉnh sửa đánh giá',
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            shape: const RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.vertical(top: Radius.circular(20)),
                            ),
                            builder: (_) => IssueRatingBottomSheet(
                              issueReportId: widget.issue.id,
                              reporterId: widget.issue.reporterId,
                              initialRating: rating,
                            ),
                          );
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rate_rounded,
                              size: 18, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            '${rating.overallRating.toStringAsFixed(1)} / 5.0',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.amber,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      label,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _buildRatingChip('Tốc độ', rating.speedRating, isDark),
                    _buildRatingChip('Thái độ', rating.attitudeRating, isDark),
                    _buildRatingChip('Kỹ thuật', rating.qualityRating, isDark),
                  ],
                ),
                if (rating.comment != null &&
                    rating.comment!.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '"${rating.comment}"',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        fontSize: 13,
                        color:
                            isDark ? Colors.white70 : Colors.grey.shade800,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRatingChip(String title, int stars, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: isDark ? Colors.white12 : Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$title: ',
              style: const TextStyle(
                  fontSize: 11, color: AppTheme.textSecondary)),
          Text('$stars',
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.bold)),
          const Icon(Icons.star_rate_rounded, size: 13, color: Colors.amber),
        ],
      ),
    );
  }

  Widget _buildCommentBubble(
      IssueCommentModel comment, bool isMe, bool isDark) {
    final bubbleColor = isMe
        ? AppTheme.primary.withValues(alpha: 0.1)
        : (isDark ? Colors.white10 : Colors.grey.shade100);
    final alignment = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final userName = comment.userName ?? 'Người dùng';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[
            AppAvatar(
              name: userName,
              size: 32,
              fontSize: 12,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: alignment,
              children: [
                // Tên + vai trò
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        userName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: comment.isManagement
                              ? AppTheme.primary
                              : AppTheme.textSecondary,
                        ),
                      ),
                      if (comment.isManagement) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            comment.roleDisplayName,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppTheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                // Bubble
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.72,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                  ),
                  child: Text(
                    comment.content,
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                ),
                const SizedBox(height: 2),
                // Thời gian
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    timeago.format(comment.createdAt, locale: 'vi'),
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white38 : Colors.grey.shade500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            AppAvatar(
              name: userName,
              size: 32,
              fontSize: 12,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCommentInput(bool isDark) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white12 : Colors.grey.shade200,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              decoration: InputDecoration(
                hintText: 'Nhập tin nhắn...',
                hintStyle: TextStyle(
                    color: isDark ? Colors.white38 : AppTheme.textSecondary),
                filled: true,
                fillColor: isDark ? Colors.white10 : Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide:
                      const BorderSide(color: AppTheme.primary, width: 1.5),
                ),
              ),
              maxLines: 3,
              minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendComment(),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: AppTheme.primary,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _isSending ? null : _sendComment,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  _StatusInfo _getStatusInfo(String status) {
    switch (status) {
      case 'resolved':
        return _StatusInfo('Đã xử lý', Icons.check_circle, AppTheme.success);
      case 'in_progress':
        return _StatusInfo('Đang xử lý', Icons.engineering, AppTheme.primary);
      default:
        return _StatusInfo(
            'Chờ tiếp nhận', Icons.pending_actions, AppTheme.warning);
    }
  }

  _PriorityInfo _getPriorityInfo(String priority) {
    switch (priority) {
      case 'high':
        return _PriorityInfo('Khẩn cấp', AppStatusColors.priorityHigh);
      case 'low':
        return _PriorityInfo('Thấp', AppStatusColors.priorityLow);
      default:
        return _PriorityInfo('Trung bình', AppStatusColors.priorityMedium);
    }
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
