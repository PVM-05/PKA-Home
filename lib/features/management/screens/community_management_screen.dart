import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_card.dart';
import '../../../core/widgets/app_skeleton_shimmer.dart';
import '../../../data/models/petition_model.dart';
import '../../../data/models/poll_model.dart';
import '../../../data/providers/community_provider.dart';
import '../widgets/create_poll_sheet.dart';
import '../widgets/poll_result_dialog.dart';
import '../widgets/respond_petition_dialog.dart';

class CommunityManagementScreen extends ConsumerStatefulWidget {
  const CommunityManagementScreen({super.key});

  @override
  ConsumerState<CommunityManagementScreen> createState() =>
      _CommunityManagementScreenState();
}

class _CommunityManagementScreenState
    extends ConsumerState<CommunityManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(_handleTabChanged);
  }

  void _handleTabChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _openCreatePollSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => const CreatePollSheet(),
    );
  }

  void _openPollResultDialog(PollModel poll) {
    showDialog(
      context: context,
      builder: (ctx) => PollResultDialog(poll: poll),
    );
  }

  void _openRespondPetitionDialog(PetitionModel petition) {
    showDialog(
      context: context,
      builder: (ctx) => RespondPetitionDialog(petition: petition),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cộng Đồng & Biểu Quyết'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: colorScheme.primary,
          indicatorWeight: 3,
          labelColor: colorScheme.primary,
          unselectedLabelColor: colorScheme.onSurfaceVariant,
          labelStyle: context.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(icon: Icon(Icons.how_to_vote_outlined), text: 'Biểu Quyết'),
            Tab(icon: Icon(Icons.feedback_outlined), text: 'Kiến Nghị Cư Dân'),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            children: [
              _buildStatsHeader(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [_buildPollsTab(), _buildPetitionsTab()],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              onPressed: _openCreatePollSheet,
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Tạo Biểu Quyết'),
            )
          : null,
    );
  }

  // ─── DẢI KPI THỜI GIAN THỰC ───
  Widget _buildStatsHeader() {
    final colorScheme = Theme.of(context).colorScheme;
    final successColor = AppTheme.getSemanticSuccess(context);
    final warningColor = AppTheme.getSemanticWarning(context);
    final secondaryColor = AppTheme.getSemanticSecondary(context);
    final statsAsync = ref.watch(communityStatsProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: statsAsync.when(
        loading: () => const SizedBox(
          height: 50,
          child: Center(child: LinearProgressIndicator()),
        ),
        error: (_, _) => const SizedBox.shrink(),
        data: (stats) {
          final items = [
            _buildStatItem(
              label: 'Đang mở',
              value: '${stats['activePolls'] ?? 0}',
              icon: Icons.how_to_vote_rounded,
              color: colorScheme.primary,
            ),
            _buildStatItem(
              label: 'Tổng biểu quyết',
              value: '${stats['totalPolls'] ?? 0}',
              icon: Icons.ballot_outlined,
              color: secondaryColor,
            ),
            _buildStatItem(
              label: 'Kiến nghị chờ',
              value: '${stats['pendingPetitions'] ?? 0}',
              icon: Icons.pending_actions_rounded,
              color: warningColor,
            ),
            _buildStatItem(
              label: 'Đã giải quyết',
              value: '${stats['resolvedPetitions'] ?? 0}',
              icon: Icons.task_alt_rounded,
              color: successColor,
            ),
          ];

          return LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 480) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: items[0]),
                        Expanded(child: items[1]),
                      ],
                    ),
                    AppSpacing.h8,
                    Row(
                      children: [
                        Expanded(child: items[2]),
                        Expanded(child: items[3]),
                      ],
                    ),
                  ],
                );
              }
              return Row(
                children: items.map((w) => Expanded(child: w)).toList(),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppRadius.r12,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color),
              AppSpacing.w4,
              Flexible(
                child: Text(
                  value,
                  style: context.titleMedium?.tabularFigures().copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: context.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ─── TAB 1: BIỂU QUYẾT & KHẢO SÁT ───
  Widget _buildPollsTab() {
    final pollsAsync = ref.watch(
      pollsProvider((status: null, apartmentId: null)),
    );

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(pollsProvider((status: null, apartmentId: null)));
        ref.invalidate(communityStatsProvider);
      },
      child: pollsAsync.when(
        loading: () => ListView(
          padding: AppSpacing.p16,
          children: [
            AppSkeletonShimmer.cardList(count: 3, itemHeight: 140),
          ],
        ),
        error: (err, _) => ListView(
          padding: AppSpacing.p16,
          children: [
            AppErrorCard(
              error: err,
              onRetry: () => ref.invalidate(
                pollsProvider((status: null, apartmentId: null)),
              ),
            ),
          ],
        ),
        data: (polls) {
          if (polls.isEmpty) {
            return ListView(
              padding: AppSpacing.p16,
              children: const [
                AppEmptyState(
                  icon: Icons.how_to_vote_outlined,
                  title: 'Chưa có cuộc biểu quyết nào',
                  description:
                      'Bấm "Tạo Biểu Quyết" để khảo sát ý kiến cư dân toàn khu.',
                ),
              ],
            );
          }

          return ListView.separated(
            padding: AppSpacing.p16,
            itemCount: polls.length,
            separatorBuilder: (_, _) => AppSpacing.h12,
            itemBuilder: (context, index) => _buildPollCard(polls[index]),
          );
        },
      ),
    );
  }

  Widget _buildPollCard(PollModel poll) {
    final colorScheme = Theme.of(context).colorScheme;
    final successColor = AppTheme.getSemanticSuccess(context);
    final statusColor = poll.isActive
        ? successColor
        : colorScheme.onSurfaceVariant;

    return AppCard(
      padding: AppSpacing.p16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: AppRadius.r6,
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Text(
                  poll.pollCode,
                  style: context.labelSmall?.tabularFigures().copyWith(
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
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: AppRadius.r12,
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  poll.statusDisplayName,
                  style: context.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.h12,
          Text(
            poll.title,
            style: context.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (poll.description != null && poll.description!.isNotEmpty) ...[
            AppSpacing.h6,
            Text(
              poll.description!,
              style: context.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          AppSpacing.h12,
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLowest,
              borderRadius: AppRadius.r8,
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 4,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.balance_rounded,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                    AppSpacing.w6,
                    Text(
                      'Quyền biểu quyết: ${poll.voteWeightDisplayName}',
                      style: context.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Hạn: ${_dateFormat.format(poll.endTime)}',
                  style: context.labelSmall?.tabularFigures().copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.h12,
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${poll.options.length} phương án lựa chọn',
                style: context.bodySmall?.tabularFigures().copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _openPollResultDialog(poll),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  minimumSize: const Size(0, 44),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.r8),
                ),
                icon: const Icon(Icons.bar_chart_rounded, size: 18),
                label: const Text('Xem Kết Quả'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── TAB 2: KIẾN NGHỊ CƯ DÂN ───
  Widget _buildPetitionsTab() {
    final petitionsAsync = ref.watch(
      petitionsProvider((status: null, category: null, apartmentId: null)),
    );

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(
          petitionsProvider((status: null, category: null, apartmentId: null)),
        );
        ref.invalidate(communityStatsProvider);
      },
      child: petitionsAsync.when(
        loading: () => ListView(
          padding: AppSpacing.p16,
          children: [
            AppSkeletonShimmer.cardList(count: 3, itemHeight: 140),
          ],
        ),
        error: (err, _) => ListView(
          padding: AppSpacing.p16,
          children: [
            AppErrorCard(
              error: err,
              onRetry: () => ref.invalidate(
                petitionsProvider((
                  status: null,
                  category: null,
                  apartmentId: null,
                )),
              ),
            ),
          ],
        ),
        data: (petitions) {
          if (petitions.isEmpty) {
            return ListView(
              padding: AppSpacing.p16,
              children: const [
                AppEmptyState(
                  icon: Icons.feedback_outlined,
                  title: 'Chưa có kiến nghị cư dân',
                  description: 'Không có kiến nghị nào từ cư dân.',
                ),
              ],
            );
          }

          return ListView.separated(
            padding: AppSpacing.p16,
            itemCount: petitions.length,
            separatorBuilder: (_, _) => AppSpacing.h12,
            itemBuilder: (context, index) =>
                _buildPetitionCard(petitions[index]),
          );
        },
      ),
    );
  }

  Widget _buildPetitionCard(PetitionModel petition) {
    final colorScheme = Theme.of(context).colorScheme;
    final successColor = AppTheme.getSemanticSuccess(context);
    final warningColor = AppTheme.getSemanticWarning(context);
    final errorColor = AppTheme.getSemanticError(context);
    final secondaryColor = AppTheme.getSemanticSecondary(context);

    final Color statusColor;
    switch (petition.status) {
      case 'resolved':
        statusColor = successColor;
        break;
      case 'in_progress':
        statusColor = warningColor;
        break;
      case 'rejected':
        statusColor = errorColor;
        break;
      case 'acknowledged':
        statusColor = colorScheme.primary;
        break;
      case 'pending':
      default:
        statusColor = secondaryColor;
        break;
    }

    return AppCard(
      padding: AppSpacing.p16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: AppRadius.r6,
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: Text(
                      petition.petitionCode,
                      style: context.labelSmall?.tabularFigures().copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  AppSpacing.w8,
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: AppRadius.r6,
                    ),
                    child: Text(
                      petition.apartmentCode ?? 'Căn hộ',
                      style: context.labelSmall?.tabularFigures().copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: AppRadius.r12,
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  petition.statusDisplayName,
                  style: context.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.h12,
          Text(
            petition.title,
            style: context.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          AppSpacing.h6,
          Text(
            petition.content,
            style: context.bodyMedium?.copyWith(color: colorScheme.onSurface),
          ),
          AppSpacing.h12,

          // Dải đồng thuận & Chuyên mục
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: AppRadius.r6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.thumb_up_alt_outlined,
                      size: 14,
                      color: colorScheme.primary,
                    ),
                    AppSpacing.w4,
                    Text(
                      '${petition.endorsementCount} đồng thuận',
                      style: context.labelSmall?.tabularFigures().copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '• ${petition.categoryDisplayName}',
                style: context.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),

          // Phản hồi của BQL (nếu có)
          if (petition.officialResponse != null &&
              petition.officialResponse!.isNotEmpty) ...[
            AppSpacing.h12,
            Container(
              padding: AppSpacing.p12,
              decoration: BoxDecoration(
                color: successColor.withValues(alpha: 0.08),
                borderRadius: AppRadius.r8,
                border: Border.all(
                  color: successColor.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.verified_outlined,
                        size: 16,
                        color: successColor,
                      ),
                      AppSpacing.w6,
                      Expanded(
                        child: Text(
                          'Phản hồi chính thức từ Ban Quản Lý:',
                          style: context.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: successColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.h4,
                  Text(
                    petition.officialResponse!,
                    style: context.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
          AppSpacing.h12,

          // Nút xử lý
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () => _openRespondPetitionDialog(petition),
              icon: const Icon(Icons.edit_note_rounded, size: 18),
              label: const Text('Phản Hồi & Xử Lý'),
              style: OutlinedButton.styleFrom(
                foregroundColor: colorScheme.primary,
                minimumSize: const Size(0, 44),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.r8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
