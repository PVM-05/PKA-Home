import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/poll_model.dart';
import '../../../data/providers/community_provider.dart';

class PollResultDialog extends ConsumerWidget {
  final PollModel poll;

  const PollResultDialog({super.key, required this.poll});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(pollResultsProvider(poll.id));
    final numberFormat = NumberFormat('#,##0.0');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 550, maxHeight: 650),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          poll.pollCode,
                          style: context.bodyMedium?.copyWith(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          poll.title,
                          style: context.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 20),

              // Nội dung kết quả
              Expanded(
                child: resultsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Lỗi khi tải kết quả: $err')),
                  data: (result) {
                    final isByArea = result.isByArea;

                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Thẻ tổng quan tham gia
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: result.isQuorumMet
                                  ? Colors.green.withValues(alpha: 0.08)
                                  : Colors.orange.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: result.isQuorumMet
                                    ? Colors.green.withValues(alpha: 0.3)
                                    : Colors.orange.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Tỷ lệ tham gia biểu quyết:', style: context.bodyMedium?.copyWith(color: Colors.grey)),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: result.isQuorumMet ? Colors.green : Colors.orange,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        result.isQuorumMet ? 'Đạt túc số biểu quyết' : 'Chưa đạt túc số tối thiểu',
                                        style: context.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${result.participationRate}%',
                                      style: context.headlineLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: result.isQuorumMet ? Colors.green[800] : Colors.orange[800],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        isByArea
                                            ? '(${numberFormat.format(result.votedArea)} m² / ${numberFormat.format(result.totalArea)} m²)'
                                            : '(${result.votedApartments} / ${result.totalApartments} căn hộ)',
                                        style: context.bodyMedium?.copyWith(color: Colors.grey[700]),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                LinearProgressIndicator(
                                  value: (result.participationRate / 100.0).clamp(0.0, 1.0),
                                  backgroundColor: Colors.grey[200],
                                  color: result.isQuorumMet ? Colors.green : Colors.orange,
                                  minHeight: 6,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Danh sách kết quả từng phương án
                          Text(
                            'Chi Tiết Biểu Quyết Từng Phương Án',
                            style: context.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),

                          ...result.options.map((opt) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey[200]!),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          opt.optionText,
                                          style: context.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                      Text(
                                        '${opt.percentOfVotes}%',
                                        style: context.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppTheme.primary),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  LinearProgressIndicator(
                                    value: (opt.percentOfVotes / 100.0).clamp(0.0, 1.0),
                                    backgroundColor: Colors.grey[200],
                                    color: AppTheme.primary,
                                    minHeight: 8,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('${opt.voteCount} phiếu ủng hộ', style: context.bodySmall?.copyWith(color: Colors.grey[600])),
                                      if (isByArea)
                                        Text('${numberFormat.format(opt.voteWeightSum)} m²', style: context.bodySmall?.copyWith(color: Colors.grey[600])),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),

              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Đóng'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

