import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/issue_rating_model.dart';
import '../../../data/repositories/issue_repository.dart';
import '../../../data/providers/issue_rating_provider.dart';

/// Modal BottomSheet đánh giá chất lượng dịch vụ sự cố đa tiêu chí
class IssueRatingBottomSheet extends ConsumerStatefulWidget {
  final String issueReportId;
  final String reporterId;
  final IssueRatingModel? initialRating;

  const IssueRatingBottomSheet({
    super.key,
    required this.issueReportId,
    required this.reporterId,
    this.initialRating,
  });

  @override
  ConsumerState<IssueRatingBottomSheet> createState() => _IssueRatingBottomSheetState();
}

class _IssueRatingBottomSheetState extends ConsumerState<IssueRatingBottomSheet> {
  late int _speedRating;
  late int _attitudeRating;
  late int _qualityRating;
  late TextEditingController _commentController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _speedRating = widget.initialRating?.speedRating ?? 5;
    _attitudeRating = widget.initialRating?.attitudeRating ?? 5;
    _qualityRating = widget.initialRating?.qualityRating ?? 5;
    _commentController = TextEditingController(text: widget.initialRating?.comment ?? '');
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  double get _currentOverall =>
      IssueRatingModel.calculateOverall(_speedRating, _attitudeRating, _qualityRating);

  Future<void> _handleSubmit() async {
    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    try {
      final repo = ref.read(issueRepositoryProvider);
      IssueRatingModel result;

      if (widget.initialRating != null) {
        result = await repo.updateRating(
          ratingId: widget.initialRating!.id,
          speedRating: _speedRating,
          attitudeRating: _attitudeRating,
          qualityRating: _qualityRating,
          comment: _commentController.text,
        );
      } else {
        result = await repo.submitRating(
          issueReportId: widget.issueReportId,
          reporterId: widget.reporterId,
          speedRating: _speedRating,
          attitudeRating: _attitudeRating,
          qualityRating: _qualityRating,
          comment: _commentController.text,
        );
      }

      ref.invalidate(issueRatingProvider(widget.issueReportId));
      ref.invalidate(allIssueRatingsProvider);

      if (mounted) {
        Navigator.of(context).pop(result);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.initialRating != null
                  ? 'Đã cập nhật đánh giá thành công'
                  : 'Cảm ơn bạn đã đánh giá chất lượng dịch vụ!',
            ),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi gửi đánh giá: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Widget _buildStarRow({
    required String title,
    required String subtitle,
    required int currentRating,
    required ValueChanged<int> onRatingChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (index) {
                  final starIndex = index + 1;
                  final isSelected = starIndex <= currentRating;
                  return InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onRatingChanged(starIndex);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.0),
                      child: Icon(
                        isSelected ? Icons.star_rate_rounded : Icons.star_outline_rounded,
                        color: isSelected ? Colors.amber : Colors.grey.shade400,
                        size: 28,
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
          Text(
            subtitle,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final overall = _currentOverall;
    final label = IssueRatingModel.getSatisfactionLabel(overall);
    final isEditing = widget.initialRating != null;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.star_rate_rounded, color: Colors.amber, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEditing ? 'Chỉnh sửa đánh giá' : 'Đánh giá chất lượng dịch vụ',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Đóng góp ý kiến giúp nâng cao chất lượng phục vụ',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Điểm trung bình tóm tắt
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.star_rate_rounded, color: Colors.amber, size: 22),
                  const SizedBox(width: 6),
                  Text(
                    '${overall.toStringAsFixed(1)} / 5.0',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '($label)',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Divider(),

            // 3 Tiêu chí
            _buildStarRow(
              title: 'Tốc độ xử lý',
              subtitle: 'Thời gian tiếp nhận và đến kiểm tra sự cố',
              currentRating: _speedRating,
              onRatingChanged: (val) => setState(() => _speedRating = val),
            ),
            _buildStarRow(
              title: 'Thái độ phục vụ',
              subtitle: 'Sự nhã nhặn, lịch sự và lắng nghe của nhân viên',
              currentRating: _attitudeRating,
              onRatingChanged: (val) => setState(() => _attitudeRating = val),
            ),
            _buildStarRow(
              title: 'Chất lượng kỹ thuật',
              subtitle: 'Hiệu quả khắc phục triệt để và vệ sinh sau sửa',
              currentRating: _qualityRating,
              onRatingChanged: (val) => setState(() => _qualityRating = val),
            ),
            const SizedBox(height: 12),

            // Nhận xét thêm
            TextField(
              controller: _commentController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Ý kiến góp ý thêm (tùy chọn)',
                hintText: 'Chia sẻ thêm cảm nhận hoặc góp ý xây dựng cho BQL...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),

            // Nút bấm gửi
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isSubmitting ? null : _handleSubmit,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      isEditing ? 'Cập nhật đánh giá' : 'Gửi đánh giá',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
