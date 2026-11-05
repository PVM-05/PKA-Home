import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/poll_model.dart';
import '../../../data/models/petition_model.dart';
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
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openCreatePollSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cộng Đồng & Biểu Quyết'),
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
            Tab(icon: Icon(Icons.how_to_vote_outlined), text: 'Biểu Quyết'),
            Tab(icon: Icon(Icons.feedback_outlined), text: 'Kiến Nghị Cư Dân'),
          ],
        ),
      ),
      body: Column(
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
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              onPressed: _openCreatePollSheet,
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Tạo Biểu Quyết'),
            )
          : null,
    );
  }

  // ─── DẢI KPI THỜI GIAN THỰC ───
  Widget _buildStatsHeader() {
    final statsAsync = ref.watch(communityStatsProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: statsAsync.when(
        loading: () => const SizedBox(
          height: 50,
          child: Center(child: LinearProgressIndicator()),
        ),
        error: (_, _) => const SizedBox.shrink(),
        data: (stats) {
          return Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  label: 'Đang mở',
                  value: '${stats['activePolls'] ?? 0}',
                  icon: Icons.how_to_vote_rounded,
                  color: AppTheme.primary,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  label: 'Tổng biểu quyết',
                  value: '${stats['totalPolls'] ?? 0}',
                  icon: Icons.ballot_outlined,
                  color: Colors.blueGrey,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  label: 'Kiến nghị chờ',
                  value: '${stats['pendingPetitions'] ?? 0}',
                  icon: Icons.pending_actions_rounded,
                  color: Colors.orange,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  label: 'Đã giải quyết',
                  value: '${stats['resolvedPetitions'] ?? 0}',
                  icon: Icons.task_alt_rounded,
                  color: Colors.green,
                ),
              ),
            ],
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey[700]),
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Lỗi: $err')),
        data: (polls) {
          if (polls.isEmpty) {
            return const Center(child: Text('Chưa có cuộc biểu quyết nào'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: polls.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final poll = polls[index];
              return _buildPollCard(poll);
            },
          );
        },
      ),
    );
  }

  Widget _buildPollCard(PollModel poll) {
    Color statusColor = poll.isActive ? Colors.green : Colors.grey;

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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    poll.statusDisplayName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
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
                    'Quyền biểu quyết: ${poll.voteWeightDisplayName}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Hạn: ${_dateFormat.format(poll.endTime)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${poll.options.length} phương án lựa chọn',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                ElevatedButton.icon(
                  onPressed: () => _openPollResultDialog(poll),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.bar_chart_rounded, size: 18),
                  label: const Text('Xem Kết Quả'),
                ),
              ],
            ),
          ],
        ),
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Lỗi: $err')),
        data: (petitions) {
          if (petitions.isEmpty) {
            return const Center(
              child: Text('Không có kiến nghị nào từ cư dân'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: petitions.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final pet = petitions[index];
              return _buildPetitionCard(pet);
            },
          );
        },
      ),
    );
  }

  Widget _buildPetitionCard(PetitionModel petition) {
    Color statusColor;
    switch (petition.status) {
      case 'resolved':
        statusColor = Colors.green;
        break;
      case 'in_progress':
        statusColor = Colors.orange;
        break;
      case 'rejected':
        statusColor = AppTheme.error;
        break;
      case 'acknowledged':
        statusColor = Colors.blue;
        break;
      case 'pending':
      default:
        statusColor = Colors.purple;
        break;
    }

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
                Row(
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
                        petition.petitionCode,
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
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        petition.apartmentCode ?? 'Căn hộ',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: AppTheme.primary,
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
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    petition.statusDisplayName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              petition.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              petition.content,
              style: TextStyle(fontSize: 13, color: Colors.grey[800]),
            ),
            const SizedBox(height: 12),

            // Dải đồng thuận & Chuyên mục
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.thumb_up_alt_outlined,
                        size: 14,
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${petition.endorsementCount} đồng thuận',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '• ${petition.categoryDisplayName}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),

            // Phản hồi của BQL (nếu có)
            if (petition.officialResponse != null &&
                petition.officialResponse!.isNotEmpty) ...[
              const SizedBox(height: 12),
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
                    Row(
                      children: [
                        const Icon(
                          Icons.verified_outlined,
                          size: 16,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Phản hồi chính thức từ Ban Quản Lý:',
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
            ],
            const SizedBox(height: 12),

            // Nút xử lý
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _openRespondPetitionDialog(petition),
                  icon: const Icon(Icons.edit_note_rounded, size: 18),
                  label: const Text('Phản Hồi & Xử Lý'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
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
