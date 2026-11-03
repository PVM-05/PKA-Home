import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/poll_model.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/community_provider.dart';
import '../../management/widgets/poll_result_dialog.dart';

class VotePollSheet extends ConsumerStatefulWidget {
  final PollModel poll;
  final String apartmentId;
  final VoidCallback? onVoted;

  const VotePollSheet({
    super.key,
    required this.poll,
    required this.apartmentId,
    this.onVoted,
  });

  @override
  ConsumerState<VotePollSheet> createState() => _VotePollSheetState();
}

class _VotePollSheetState extends ConsumerState<VotePollSheet> {
  final Set<String> _selectedOptionIds = {};
  bool _isLoading = false;

  bool get isMultiple => widget.poll.choiceType == 'multiple_choice';

  void _toggleOption(String optionId) {
    setState(() {
      if (isMultiple) {
        if (_selectedOptionIds.contains(optionId)) {
          _selectedOptionIds.remove(optionId);
        } else {
          _selectedOptionIds.add(optionId);
        }
      } else {
        _selectedOptionIds.clear();
        _selectedOptionIds.add(optionId);
      }
    });
  }

  Future<void> _submitVote() async {
    if (_selectedOptionIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn ít nhất một phương án để biểu quyết')),
      );
      return;
    }

    final authUser = ref.read(authProvider).valueOrNull;
    final voterUserId = authUser?.id ?? 'usr-resident';

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(communityRepositoryProvider);
      final res = await repo.submitPollVote(
        pollId: widget.poll.id,
        apartmentId: widget.apartmentId,
        voterUserId: voterUserId,
        selectedOptionIds: _selectedOptionIds.toList(),
      );

      if (res['success'] == true) {
        ref.invalidate(pollsProvider((status: null, apartmentId: widget.apartmentId)));
        ref.invalidate(pollResultsProvider(widget.poll.id));

        if (mounted) {
          Navigator.pop(context);
          widget.onVoted?.call();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Lá phiếu của bạn đã được ghi nhận vào hệ thống'),
              backgroundColor: Colors.green,
            ),
          );
          // Mở kết quả hiện thời
          showDialog(
            context: context,
            builder: (ctx) => PollResultDialog(poll: widget.poll),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message'] ?? 'Bỏ phiếu thất bại'),
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
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.how_to_vote_rounded, color: AppTheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.poll.pollCode,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: AppTheme.primary,
                        ),
                      ),
                      const Text(
                        'Phiếu Biểu Quyết Trực Tuyến',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Tiêu đề & Căn cứ
            Text(
              widget.poll.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            if (widget.poll.description != null && widget.poll.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Text(
                  widget.poll.description!,
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
              ),
            ],
            const SizedBox(height: 12),

            // Huy hiệu loại quyền
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Cơ chế tính: ${widget.poll.voteWeightDisplayName} • ${widget.poll.choiceTypeDisplayName}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              'Chọn Phương Án Biểu Quyết Của Bạn:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),

            // Danh sách lựa chọn
            ...widget.poll.options.map((opt) {
              final isSelected = _selectedOptionIds.contains(opt.id);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primary.withValues(alpha: 0.08) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? AppTheme.primary : Colors.grey[300]!,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: InkWell(
                  onTap: () => _toggleOption(opt.id),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Icon(
                          isMultiple
                              ? (isSelected ? Icons.check_box : Icons.check_box_outline_blank)
                              : (isSelected ? Icons.radio_button_checked : Icons.radio_button_off),
                          color: isSelected ? AppTheme.primary : Colors.grey,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            opt.optionText,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? AppTheme.primary : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),

            // Nút Xác nhận gửi phiếu
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _submitVote,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: _isLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.how_to_vote_rounded),
              label: Text(
                _isLoading ? 'Đang gửi phiếu...' : 'Xác Nhận Bỏ Phiếu Biểu Quyết',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

