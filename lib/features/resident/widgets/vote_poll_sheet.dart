import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../data/models/poll_model.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/resident_apartment_provider.dart';
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
      AppSnackBar.showWarning(
        context,
        'Vui lòng chọn ít nhất một phương án để biểu quyết',
      );
      return;
    }

    final authUser = ref.read(authProvider).valueOrNull;
    if (authUser == null) {
      if (mounted) {
        AppSnackBar.showError(
          context,
          'Vui lòng đăng nhập để tham gia biểu quyết',
        );
      }
      return;
    }
    final voterUserId = authUser.id;

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
        ref.invalidate(
          pollsProvider((status: null, apartmentId: widget.apartmentId)),
        );
        ref.invalidate(pollResultsProvider(widget.poll.id));

        if (mounted) {
          Navigator.pop(context);
          widget.onVoted?.call();
          AppSnackBar.showSuccess(
            context,
            'Lá phiếu của bạn đã được ghi nhận vào hệ thống',
          );
          // Mở kết quả hiện thời
          showDialog(
            context: context,
            builder: (ctx) => PollResultDialog(poll: widget.poll),
          );
        }
      } else {
        if (mounted) {
          AppSnackBar.showError(
            context,
            res['message'] ?? 'Bỏ phiếu thất bại',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, formatErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentApartment = ref.watch(currentSelectedApartmentProvider);
    final relationRole =
        (currentApartment?['relation_role'] as String?)?.toLowerCase() ??
        'owner';
    final isBlockedByHousingLaw =
        widget.poll.isOfficialAssembly && relationRole != 'owner';

    final colorScheme = Theme.of(context).colorScheme;
    final warningColor = AppTheme.getSemanticWarning(context);

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                  color: colorScheme.outlineVariant,
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
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.how_to_vote_rounded,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.poll.pollCode,
                        style: context.labelSmall?.copyWith(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                      Text(
                        'Phiếu Biểu Quyết Trực Tuyến',
                        style: context.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
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
              style: context.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (widget.poll.description != null &&
                widget.poll.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Text(
                  widget.poll.description!,
                  style: context.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ),
            ],
            const SizedBox(height: 12),

            // Huy hiệu loại quyền
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Cơ chế tính: ${widget.poll.voteWeightDisplayName} • ${widget.poll.choiceTypeDisplayName}',
                      style: context.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (isBlockedByHousingLaw) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: warningColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: warningColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.gavel_rounded,
                      color: warningColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Theo Điều 102 Luật Nhà ở 2023, chỉ Chủ sở hữu căn hộ mới có quyền biểu quyết tại Hội nghị nhà chung cư. Khách thuê chỉ có thể tham gia các cuộc khảo sát ý kiến cộng đồng.',
                        style: context.bodySmall?.copyWith(
                          color: warningColor,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),

            Text(
              'Chọn Phương Án Biểu Quyết Của Bạn:',
              style: context.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // Danh sách lựa chọn
            ...widget.poll.options.map((opt) {
              final isSelected = _selectedOptionIds.contains(opt.id);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colorScheme.primary.withValues(alpha: 0.12)
                      : colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? colorScheme.primary : colorScheme.outlineVariant,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: InkWell(
                  onTap: () => _toggleOption(opt.id),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isMultiple
                              ? (isSelected
                                    ? Icons.check_box
                                    : Icons.check_box_outline_blank)
                              : (isSelected
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off),
                          color: isSelected ? colorScheme.primary : colorScheme.outline,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            opt.optionText,
                            style: context.bodyMedium?.copyWith(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected
                                  ? colorScheme.primary
                                  : colorScheme.onSurface,
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
              onPressed: (isBlockedByHousingLaw || _isLoading)
                  ? null
                  : _submitVote,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.how_to_vote_rounded),
              label: Text(
                _isLoading
                    ? 'Đang gửi phiếu...'
                    : (isBlockedByHousingLaw
                          ? 'Chỉ Chủ Hộ Được Biểu Quyết'
                          : 'Xác Nhận Bỏ Phiếu Biểu Quyết'),
                style: context.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
