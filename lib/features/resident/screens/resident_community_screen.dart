import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../data/models/poll_model.dart';
import '../../../data/models/petition_model.dart';
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
  }

  @override
  void dispose() {
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => VotePollSheet(poll: poll, apartmentId: apartmentId),
    );
  }

  void _openPollResultDialog(PollModel poll) {
    showDialog(
      context: context,
      builder: (ctx) => PollResultDialog(poll: poll),
    );
  }

  void _openCreatePetitionSheet(String apartmentId) {
    showModalBottomSheet(
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng đăng nhập để đồng thuận kiến nghị'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
      return;
    }
    final userId = authUser.id;

    try {
      final repo = ref.read(communityRepositoryProvider);
      final res = await repo.endorsePetition(
        petitionId: petition.id,
        apartmentId: apartmentId,
        userId: userId,
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã ghi nhận sự đồng thuận của căn hộ bạn'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message'] ?? 'Thao tác không thành công'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final apartmentId = _getEffectiveApartmentId();

    if (apartmentId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Biểu Quyết & Cộng Đồng')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: AppStateView.emptyContent(
              icon: Icons.how_to_vote_outlined,
              title: 'Chưa chọn căn hộ',
              message:
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
          indicatorColor: AppTheme.primary,
          indicatorWeight: 3,
          labelColor: AppTheme.primary,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
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
              foregroundColor: Colors.white,
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
      child: pollsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Lỗi: $err')),
        data: (polls) {
          if (polls.isEmpty) {
            return const Center(
              child: Text('Hiện không có cuộc biểu quyết hoặc khảo sát nào'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: polls.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final poll = polls[index];
              return _buildPollCard(poll, apartmentId);
            },
          );
        },
      ),
    );
  }

  Widget _buildPollCard(PollModel poll, String apartmentId) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Text(
                    poll.pollCode,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: poll.isOfficialAssembly
                        ? Colors.deepPurple.withValues(alpha: 0.1)
                        : Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: poll.isOfficialAssembly
                          ? Colors.deepPurple.shade300
                          : Colors.blue.shade300,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        poll.isOfficialAssembly
                            ? Icons.gavel_rounded
                            : Icons.poll_outlined,
                        size: 13,
                        color: poll.isOfficialAssembly
                            ? Colors.deepPurple.shade700
                            : Colors.blue.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        poll.isOfficialAssembly
                            ? 'Nghị quyết chính thức (Hội nghị nhà chung cư)'
                            : 'Khảo sát ý kiến',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: poll.isOfficialAssembly
                              ? Colors.deepPurple.shade700
                              : Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (poll.hasVoted)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.green.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 14,
                          color: Colors.green,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Đã biểu quyết',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
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
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      poll.statusDisplayName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              poll.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            if (poll.description != null && poll.description!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                poll.description!,
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.balance_rounded,
                    size: 16,
                    color: AppTheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    poll.voteWeightDisplayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Hạn chót: ${_dateFormat.format(poll.endTime)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (poll.hasVoted || poll.isClosed) ...[
                  OutlinedButton.icon(
                    onPressed: () => _openPollResultDialog(poll),
                    icon: const Icon(Icons.bar_chart_rounded, size: 18),
                    label: const Text('Xem Kết Quả'),
                  ),
                ] else ...[
                  ElevatedButton.icon(
                    onPressed: () => _openVoteSheet(poll, apartmentId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.how_to_vote_rounded, size: 18),
                    label: const Text('Tham Gia Biểu Quyết'),
                  ),
                ],
              ],
            ),
          ],
        ),
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
      child: petitionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Lỗi: $err')),
        data: (petitions) {
          if (petitions.isEmpty) {
            return const Center(
              child: Text('Chưa có kiến nghị nào từ cộng đồng cư dân'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: petitions.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final pet = petitions[index];
              return _buildPetitionCard(pet, apartmentId);
            },
          );
        },
      ),
    );
  }

  Widget _buildPetitionCard(PetitionModel petition, String apartmentId) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    petition.petitionCode,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    petition.statusDisplayName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              petition.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              petition.content,
              style: TextStyle(fontSize: 13, color: Colors.grey[800]),
            ),
            const SizedBox(height: 12),

            // Phản hồi của BQL (nếu có)
            if (petition.officialResponse != null &&
                petition.officialResponse!.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.verified_outlined,
                          size: 16,
                          color: Colors.green,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Phản hồi từ Ban Quản Lý:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      petition.officialResponse!,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Nút đồng thuận
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  petition.categoryDisplayName,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                ElevatedButton.icon(
                  onPressed: petition.isEndorsedByMe
                      ? null
                      : () => _endorse(petition, apartmentId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: petition.isEndorsedByMe
                        ? Colors.grey[200]
                        : AppTheme.primary,
                    foregroundColor: petition.isEndorsedByMe
                        ? Colors.grey[700]
                        : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  icon: Icon(
                    petition.isEndorsedByMe
                        ? Icons.thumb_up_alt_rounded
                        : Icons.thumb_up_alt_outlined,
                    size: 16,
                  ),
                  label: Text(
                    petition.isEndorsedByMe
                        ? 'Đã đồng thuận (${petition.endorsementCount})'
                        : 'Đồng thuận (${petition.endorsementCount})',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
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
