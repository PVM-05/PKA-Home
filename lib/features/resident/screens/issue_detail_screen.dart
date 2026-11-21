import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../../data/models/issue_comment_model.dart';
import '../../../data/models/issue_model.dart';
import '../../../data/models/issue_rating_model.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/issue_comment_provider.dart';
import '../../../data/providers/issue_rating_provider.dart';
import '../../../data/repositories/issue_repository.dart';
import '../widgets/issue/issue_comment_section.dart';
import '../widgets/issue/issue_detail_header_card.dart';
import '../widgets/issue/issue_materials_card.dart';
import '../widgets/issue/issue_rating_section.dart';
import '../widgets/issue/issue_status_timeline.dart';

/// Màn hình chi tiết phản ánh sự cố với timeline trạng thái và hệ thống trao đổi.
/// - Desktop (>= 900dp): Split-Screen 2 cột (Cột trái: Thông tin & Tiến trình; Cột phải: Hộp trao đổi).
/// - Mobile (< 900dp): Bố cục dọc tối ưu chống tràn 100% trên 320dp (Text Zoom 1.3x).
class IssueDetailScreen extends ConsumerStatefulWidget {
  final IssueModel issue;
  final bool isEmbedded;

  const IssueDetailScreen({
    super.key,
    required this.issue,
    this.isEmbedded = false,
  });

  @override
  ConsumerState<IssueDetailScreen> createState() => _IssueDetailScreenState();
}

class _IssueDetailScreenState extends ConsumerState<IssueDetailScreen> {
  final _commentController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    try {
      timeago.setLocaleMessages('vi', timeago.ViMessages());
    } catch (_) {}
  }

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
      await ref
          .read(issueRepositoryProvider)
          .addComment(
            issueReportId: widget.issue.id,
            userId: user.id,
            content: content,
          );
      _commentController.clear();
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
            content: Text(formatErrorMessage(e)),
            backgroundColor: AppTheme.textError,
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = !widget.isEmbedded && screenWidth >= 900;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.isEmbedded,
        title: const Text('Chi tiết phản ánh'),
      ),
      body: isDesktop
          ? _buildDesktopLayout(commentsAsync, ratingAsync, currentUser?.id)
          : _buildMobileLayout(commentsAsync, ratingAsync, currentUser?.id),
    );
  }

  Widget _buildDesktopLayout(
    AsyncValue<List<IssueCommentModel>> commentsAsync,
    AsyncValue<IssueRatingModel?> ratingAsync,
    String? currentUserId,
  ) {
    final isReporter = currentUserId == widget.issue.reporterId;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cột trái: Thông tin sự cố, ảnh, timeline, vật tư, đánh giá
              SizedBox(
                width: 520,
                child: ListView(
                  children: [
                    IssueDetailHeaderCard(issue: widget.issue),
                    const SizedBox(height: 16),
                    if (widget.issue.reportImages.isNotEmpty) ...[
                      IssueDetailImagesSection(
                        title: 'Ảnh phản ánh',
                        imageUrls: widget.issue.reportImages,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (widget.issue.resolutionProofImages.isNotEmpty) ...[
                      IssueDetailImagesSection(
                        title: 'Ảnh nghiệm thu',
                        imageUrls: widget.issue.resolutionProofImages,
                      ),
                      const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 16),
                    IssueStatusTimeline(issue: widget.issue),
                    IssueMaterialsCard(issueId: widget.issue.id),
                    const SizedBox(height: 16),
                    IssueRatingSection(
                      issue: widget.issue,
                      ratingAsync: ratingAsync,
                      isReporter: isReporter,
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // Cột phải: Khu vực trao đổi comments
              Expanded(
                child: AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: IssueCommentHeader(commentsAsync: commentsAsync),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: ListView(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          children: [
                            IssueCommentList(
                              commentsAsync: commentsAsync,
                              currentUserId: currentUserId,
                              isDesktop: true,
                              onRetry: () => ref.invalidate(
                                issueCommentsProvider(widget.issue.id),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IssueCommentInputBar(
                        controller: _commentController,
                        isSending: _isSending,
                        onSend: _sendComment,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(
    AsyncValue<List<IssueCommentModel>> commentsAsync,
    AsyncValue<IssueRatingModel?> ratingAsync,
    String? currentUserId,
  ) {
    final isReporter = currentUserId == widget.issue.reporterId;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  IssueDetailHeaderCard(issue: widget.issue),
                  const SizedBox(height: 16),
                  if (widget.issue.reportImages.isNotEmpty) ...[
                    IssueDetailImagesSection(
                      title: 'Ảnh phản ánh',
                      imageUrls: widget.issue.reportImages,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (widget.issue.resolutionProofImages.isNotEmpty) ...[
                    IssueDetailImagesSection(
                      title: 'Ảnh nghiệm thu',
                      imageUrls: widget.issue.resolutionProofImages,
                    ),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 16),
                  IssueStatusTimeline(issue: widget.issue),
                  IssueMaterialsCard(issueId: widget.issue.id),
                  const SizedBox(height: 16),
                  IssueRatingSection(
                    issue: widget.issue,
                    ratingAsync: ratingAsync,
                    isReporter: isReporter,
                  ),
                  const SizedBox(height: 24),
                  IssueCommentHeader(commentsAsync: commentsAsync),
                  const SizedBox(height: 12),
                  IssueCommentList(
                    commentsAsync: commentsAsync,
                    currentUserId: currentUserId,
                    isDesktop: false,
                    onRetry: () => ref.invalidate(
                      issueCommentsProvider(widget.issue.id),
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
            IssueCommentInputBar(
              controller: _commentController,
              isSending: _isSending,
              onSend: _sendComment,
            ),
          ],
        ),
      ),
    );
  }
}
