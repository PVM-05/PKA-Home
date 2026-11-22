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
import '../../../core/widgets/app_snack_bar.dart';
import '../../../data/models/petition_model.dart';
import '../../../data/models/poll_model.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/community_provider.dart';
import '../../../data/providers/resident_apartment_provider.dart';
import '../../management/widgets/poll_result_dialog.dart';
import '../widgets/create_petition_sheet.dart';
import '../widgets/vote_poll_sheet.dart';

class ResidentCommunityScreen extends ConsumerStatefulWidget {
  const ResidentCommunityScreen({super.key});

  @override
  ConsumerState<ResidentCommunityScreen> createState() =>
      _ResidentCommunityScreenState();
}

class _ResidentCommunityScreenState
    extends ConsumerState<ResidentCommunityScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  String? _getEffectiveApartmentId() {
    final selectedId = ref.watch(selectedApartmentIdProvider);
    if (selectedId != null && selectedId.isNotEmpty) {
      return selectedId;
    }
    final apartmentsAsync = ref.watch(residentApartmentsProvider);
    final list = apartmentsAsync.valueOrNull ?? [];
    if (list.isNotEmpty) {
      final first = list.first;
      final id =
          (first['apartment_id'] as String?) ??
          ((first['apartments'] as Map?)?['id'] as String?);
      if (id != null && id.isNotEmpty) return id;
    }
    return null;
  }

  void _openVoteSheet(PollModel poll, String apartmentId) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => VotePollSheet(poll: poll, apartmentId: apartmentId),
    );
  }

  void _openPollResultDialog(PollModel poll) {
    showDialog<void>(
      context: context,
      builder: (ctx) => PollResultDialog(poll: poll),
    );
  }

  void _openCreatePetitionSheet(String apartmentId) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CreatePetitionSheet(apartmentId: apartmentId),
    );
  }

  Future<void> _endorse(PetitionModel petition, String apartmentId) async {
    final authUser = ref.read(authProvider).valueOrNull;
    if (authUser == null) {
      if (mounted) {
        AppSnackBar.showError(
          context,
          'Vui lòng đăng nhập để đồng thuận kiến nghị',
        );
      }
      return;
    }

    try {
      final repo = ref.read(communityRepositoryProvider);
      final res = await repo.endorsePetition(
        petitionId: petition.id,
        apartmentId: apartmentId,
        userId: authUser.id,
      );

      if (res['success'] == true) {
        ref.invalidate(
          petitionsProvider((
            status: null,
            category: null,
            apartmentId: apartmentId,
          )),
        );
        if (mounted) {
          AppSnackBar.showSuccess(
            context,
            'Đã ghi nhận sự đồng thuận của căn hộ bạn',
          );
        }
      } else if (mounted) {
        AppSnackBar.showError(
          context,
          res['message'] ?? 'Thao tác không thành công',
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, 'Lỗi: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final apartmentId = _getEffectiveApartmentId();

    if (apartmentId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Biểu Quyết & Cộng Đồng')),
        body: const Center(
          child: Padding(
            padding: AppSpacing.p24,
            child: AppEmptyState(
              icon: Icons.how_to_vote_outlined,
              title: 'Chưa chọn căn hộ',
              description:
                  'Vui lòng chọn hoặc liên kết căn hộ để tham gia biểu quyết và gửi kiến nghị.',
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Biểu Quyết & Cộng Đồng'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: colorScheme.primary,
          indicatorWeight: 3,
          labelColor: colorScheme.primary,
          unselectedLabelColor: colorScheme.onSurfaceVariant,
          labelStyle: context.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(
              icon: Icon(Icons.how_to_vote_outlined),
              text: 'Biểu Quyết & Khảo Sát',
            ),
            Tab(
              icon: Icon(Icons.chat_bubble_outline_rounded),
              text: 'Ý Kiến & Kiến Nghị',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPollsTab(apartmentId),
          _buildPetitionsTab(apartmentId),
        ],
      ),
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton.extended(
              onPressed: () => _openCreatePetitionSheet(apartmentId),
              backgroundColor: AppTheme.primary,
              foregroundColor: colorScheme.onPrimary,
              icon: const Icon(Icons.edit_note_rounded),
              label: const Text('Gửi Kiến Nghị'),
            )
          : null,
    );
  }

  // ─── TAB 1: BIỂU QUYẾT ───
  Widget _buildPollsTab(String apartmentId) {
    final pollsAsync = ref.watch(
      pollsProvider((status: null, apartmentId: apartmentId)),
    );

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(pollsProvider((status: null, apartmentId: apartmentId)));
      },
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: pollsAsync.when(
            loading: () => ListView(
              padding: AppSpacing.p16,
              children: [
                AppSkeletonShimmer.cardList(count: 3, itemHeight: 160),
              ],
            ),
            error: (err, _) => Center(
              child: Padding(
                padding: AppSpacing.p24,
                child: AppErrorCard(
                  error: err,
                  onRetry: () => ref.invalidate(
                    pollsProvider((status: null, apartmentId: apartmentId)),
                  ),
                ),
              ),
            ),
            data: (polls) {
              if (polls.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 64,
                  ),
                  children: const [
                    AppEmptyState(
                      icon: Icons.how_to_vote_outlined,
                      title: 'Hiện không có cuộc biểu quyết hoặc khảo sát nào',
                      description:
                          'Khi Ban Quản Lý mở đợt lấy ý kiến hoặc Hội nghị nhà chung cư, thông tin sẽ hiển thị tại đây.',
                    ),
                  ],
                );
              }

              return ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: AppSpacing.p16,
                itemCount: polls.length,
                separatorBuilder: (_, _) => AppSpacing.h12,
                itemBuilder: (context, index) =>
                    _buildPollCard(context, polls[index], apartmentId),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPollCard(
    BuildContext context,
    PollModel poll,
    String apartmentId,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final successColor = AppTheme.getSemanticSuccess(context);
    final typeAccent = poll.isOfficialAssembly
        ? AppTheme.getSemanticSecondary(context)
        : colorScheme.primary;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: AppRadius.r8,
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Text(
                  poll.pollCode,
                  style: context.labelSmall?.copyWith(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: typeAccent.withValues(alpha: isDark ? 0.18 : 0.10),
                  borderRadius: AppRadius.r8,
                  border: Border.all(
                    color: typeAccent.withValues(alpha: isDark ? 0.45 : 0.30),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      poll.isOfficialAssembly
                          ? Icons.gavel_rounded
                          : Icons.poll_outlined,
                      size: 14,
                      color: typeAccent,
                    ),
                    AppSpacing.w4,
                    Flexible(
                      child: Text(
                        poll.isOfficialAssembly
                            ? 'Nghị quyết chính thức (Hội nghị nhà chung cư)'
                            : 'Khảo sát ý kiến',
                        style: context.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: typeAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (poll.hasVoted)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: successColor.withValues(alpha: isDark ? 0.18 : 0.10),
                    borderRadius: AppRadius.r12,
                    border: Border.all(
                      color: successColor.withValues(
                        alpha: isDark ? 0.45 : 0.30,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 14,
                        color: successColor,
                      ),
                      AppSpacing.w4,
                      Text(
                        'Đã biểu quyết',
                        style: context.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: successColor,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(
                      alpha: isDark ? 0.18 : 0.10,
                    ),
                    borderRadius: AppRadius.r12,
                  ),
                  child: Text(
                    poll.statusDisplayName,
                    style: context.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
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
            width: double.infinity,
            padding: AppSpacing.p12,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: AppRadius.r8,
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 6,
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
                      poll.voteWeightDisplayName,
                      style: context.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Hạn chót: ${_dateFormat.format(poll.endTime)}',
                  style: context.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.h12,
          Align(
            alignment: Alignment.centerRight,
            child: poll.hasVoted || poll.isClosed
                ? OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: () => _openPollResultDialog(poll),
                    icon: const Icon(Icons.bar_chart_rounded, size: 18),
                    label: const Text('Xem Kết Quả'),
                  )
                : ElevatedButton.icon(
                    onPressed: () => _openVoteSheet(poll, apartmentId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.r12,
                      ),
                    ),
                    icon: const Icon(Icons.how_to_vote_rounded, size: 18),
                    label: const Text('Tham Gia Biểu Quyết'),
                  ),
          ),
        ],
      ),
    );
  }

  // ─── TAB 2: KIẾN NGHỊ CƯ DÂN ───
  Widget _buildPetitionsTab(String apartmentId) {
    final petitionsAsync = ref.watch(
      petitionsProvider((
        status: null,
        category: null,
        apartmentId: apartmentId,
      )),
    );

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(
          petitionsProvider((
            status: null,
            category: null,
            apartmentId: apartmentId,
          )),
        );
      },
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: petitionsAsync.when(
            loading: () => ListView(
              padding: AppSpacing.p16,
              children: [
                AppSkeletonShimmer.cardList(count: 3, itemHeight: 150),
              ],
            ),
            error: (err, _) => Center(
              child: Padding(
                padding: AppSpacing.p24,
                child: AppErrorCard(
                  error: err,
                  onRetry: () => ref.invalidate(
                    petitionsProvider((
                      status: null,
                      category: null,
                      apartmentId: apartmentId,
                    )),
                  ),
                ),
              ),
            ),
            data: (petitions) {
              if (petitions.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 64,
                  ),
                  children: const [
                    AppEmptyState(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'Chưa có kiến nghị nào từ cộng đồng cư dân',
                      description:
                          'Bạn có thể gửi đề xuất cải thiện dịch vụ hoặc đồng thuận với kiến nghị của cư dân khác.',
                    ),
                  ],
                );
              }

              return ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                itemCount: petitions.length,
                separatorBuilder: (_, _) => AppSpacing.h12,
                itemBuilder: (context, index) =>
                    _buildPetitionCard(context, petitions[index], apartmentId),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPetitionCard(
    BuildContext context,
    PetitionModel petition,
    String apartmentId,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final successColor = AppTheme.getSemanticSuccess(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: AppRadius.r8,
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Text(
                  petition.petitionCode,
                  style: context.labelSmall?.copyWith(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                    fontFeatures: const [FontFeature.tabularFigures()],
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
                    alpha: isDark ? 0.18 : 0.10,
                  ),
                  borderRadius: AppRadius.r12,
                ),
                child: Text(
                  petition.statusDisplayName,
                  style: context.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.h12,
          Text(
            petition.title,
            style: context.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          AppSpacing.h6,
          Text(
            petition.content,
            style: context.bodyMedium?.copyWith(color: colorScheme.onSurface),
          ),
          AppSpacing.h12,
          if (petition.officialResponse != null &&
              petition.officialResponse!.isNotEmpty) ...[
            Container(
              padding: AppSpacing.p12,
              decoration: BoxDecoration(
                color: successColor.withValues(alpha: isDark ? 0.14 : 0.08),
                borderRadius: AppRadius.r8,
                border: Border.all(
                  color: successColor.withValues(alpha: isDark ? 0.45 : 0.30),
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
                          'Phản hồi từ Ban Quản Lý:',
                          style: context.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: successColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.h4,
                  Text(petition.officialResponse!, style: context.bodyMedium),
                ],
              ),
            ),
            AppSpacing.h12,
          ],
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Text(
                petition.categoryDisplayName,
                style: context.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              ElevatedButton.icon(
                onPressed: petition.isEndorsedByMe
                    ? null
                    : () => _endorse(petition, apartmentId),
                style: ElevatedButton.styleFrom(
                  backgroundColor: petition.isEndorsedByMe
                      ? colorScheme.surfaceContainerHighest
                      : AppTheme.primary,
                  foregroundColor: petition.isEndorsedByMe
                      ? colorScheme.onSurfaceVariant
                      : colorScheme.onPrimary,
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                icon: Icon(
                  petition.isEndorsedByMe
                      ? Icons.thumb_up_alt_rounded
                      : Icons.thumb_up_alt_outlined,
                  size: 18,
                ),
                label: Text(
                  petition.isEndorsedByMe
                      ? 'Đã đồng thuận (${petition.endorsementCount})'
                      : 'Đồng thuận (${petition.endorsementCount})',
                  style: context.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: petition.isEndorsedByMe
                        ? colorScheme.onSurfaceVariant
                        : colorScheme.onPrimary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
