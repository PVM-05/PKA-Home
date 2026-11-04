import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/debt_risk_score_model.dart';
import '../../../data/providers/debt_prediction_provider.dart';

class ExecuteDunningDialog extends ConsumerStatefulWidget {
  final String buildingId;
  final String apartmentId;
  final String apartmentCode;
  final String ownerName;
  final double unpaidAmount;
  final int overdueDays;
  final int riskScore;
  final DunningTier initialTier;

  const ExecuteDunningDialog({
    super.key,
    required this.buildingId,
    required this.apartmentId,
    required this.apartmentCode,
    required this.ownerName,
    required this.unpaidAmount,
    required this.overdueDays,
    required this.riskScore,
    required this.initialTier,
  });

  @override
  ConsumerState<ExecuteDunningDialog> createState() => _ExecuteDunningDialogState();
}

class _ExecuteDunningDialogState extends ConsumerState<ExecuteDunningDialog> {
  late DunningTier _selectedTier;
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  bool _isSubmitting = false;

  final _moneyFormat = NumberFormat('#,##0', 'vi_VN');

  @override
  void initState() {
    super.initState();
    _selectedTier = widget.initialTier;
    _titleController = TextEditingController(text: _selectedTier.defaultTitle);
    _contentController = TextEditingController(
      text: _selectedTier.defaultContent(
        widget.apartmentCode,
        widget.unpaidAmount,
        widget.overdueDays,
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _onTierChanged(DunningTier newTier) {
    setState(() {
      _selectedTier = newTier;
      _titleController.text = newTier.defaultTitle;
      _contentController.text = newTier.defaultContent(
        widget.apartmentCode,
        widget.unpaidAmount,
        widget.overdueDays,
      );
    });
  }

  Future<void> _handleConfirm() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập đầy đủ tiêu đề và nội dung đôn đốc'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final repo = ref.read(debtPredictionRepositoryProvider);
      await repo.executeDunningAction(
        buildingId: widget.buildingId,
        apartmentId: widget.apartmentId,
        tier: _selectedTier,
        title: title,
        content: content,
      );

      if (!mounted) return;

      // Refresh radar data
      ref.invalidate(buildingDebtRadarProvider(widget.buildingId));

      Navigator.of(context).pop(true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đã gửi thông báo đôn đốc (${_selectedTier.shortName}) tới căn hộ ${widget.apartmentCode} thành công!',
          ),
          backgroundColor: AppTheme.success,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi gửi thông báo: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _selectedTier.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.campaign_rounded,
                        color: _selectedTier.color,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Thực Thi Đôn Đốc Đa Tầng',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            'Căn hộ: ${widget.apartmentCode} - ${widget.ownerName}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Card tóm tắt nợ và điểm rủi ro
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text('Tổng nợ quá hạn', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          const SizedBox(height: 4),
                          Text(
                            '${_moneyFormat.format(widget.unpaidAmount)} đ',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.error, fontSize: 14),
                          ),
                        ],
                      ),
                      Container(height: 30, width: 1, color: AppTheme.border),
                      Column(
                        children: [
                          const Text('Số ngày trễ', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          const SizedBox(height: 4),
                          Text(
                            '${widget.overdueDays} ngày',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontSize: 14),
                          ),
                        ],
                      ),
                      Container(height: 30, width: 1, color: AppTheme.border),
                      Column(
                        children: [
                          const Text('Điểm rủi ro', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          const SizedBox(height: 4),
                          Text(
                            '${widget.riskScore} / 100',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: widget.riskScore >= 70
                                  ? AppTheme.error
                                  : (widget.riskScore >= 40 ? AppTheme.warning : AppTheme.success),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Chọn tầng đôn đốc
                const Text(
                  'Chọn cấp độ chiến lược đôn đốc:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 8),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: DunningTier.values.map((tier) {
                    final isSelected = tier == _selectedTier;
                    final isRecommended = tier == widget.initialTier;
                    return InkWell(
                      onTap: () => _onTierChanged(tier),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? tier.color.withValues(alpha: 0.15) : AppTheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? tier.color : AppTheme.border,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                              size: 16,
                              color: isSelected ? tier.color : AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              tier.label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? tier.color : AppTheme.textPrimary,
                              ),
                            ),
                            if (isRecommended) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Đề xuất AI',
                                  style: TextStyle(fontSize: 10, color: AppTheme.primary, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),

                // Tiêu đề thông báo
                const Text(
                  'Tiêu đề thông báo:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),

                const SizedBox(height: 12),

                // Nội dung thông báo
                const Text(
                  'Nội dung gửi Quý cư dân:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _contentController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),

                const SizedBox(height: 20),

                // Hành động
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
                      child: const Text('Hủy'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedTier.color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _isSubmitting ? null : _handleConfirm,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send_rounded, size: 16),
                      label: Text(_isSubmitting ? 'Đang gửi...' : 'Gửi thông báo đôn đốc'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
