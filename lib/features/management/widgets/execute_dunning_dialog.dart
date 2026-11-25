import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/error_formatter.dart';
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
            content: Text(formatErrorMessage(e)),
            backgroundColor: AppTheme.textError,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
                        color: _selectedTier.color.withValues(alpha: 0.12),
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
                          Text(
                            'Thực Thi Đôn Đốc Đa Tầng',
                            style: context.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            'Căn hộ: ${widget.apartmentCode} - ${widget.ownerName}',
                            style: context.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
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
                    color: colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.spaceAround,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      Column(
                        children: [
                          Text('Tổng nợ quá hạn', style: context.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                          const SizedBox(height: 4),
                          Text(
                            '${_moneyFormat.format(widget.unpaidAmount)} đ',
                            style: context.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: AppTheme.getSemanticError(context)),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text('Số ngày trễ', style: context.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                          const SizedBox(height: 4),
                          Text(
                            '${widget.overdueDays} ngày',
                            style: context.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text('Điểm rủi ro', style: context.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                          const SizedBox(height: 4),
                          Text(
                            '${widget.riskScore} / 100',
                            style: context.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: widget.riskScore >= 70
                                  ? AppTheme.getSemanticError(context)
                                  : (widget.riskScore >= 40
                                      ? AppTheme.getSemanticWarning(context)
                                      : AppTheme.getSemanticSuccess(context)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Chọn tầng đôn đốc
                Text(
                  'Chọn cấp độ chiến lược đôn đốc:',
                  style: context.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: colorScheme.onSurface),
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
                          color: isSelected ? tier.color.withValues(alpha: 0.15) : colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? tier.color : colorScheme.outlineVariant,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                              size: 16,
                              color: isSelected ? tier.color : colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                tier.label,
                                style: context.bodyMedium?.copyWith(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? tier.color : colorScheme.onSurface,
                                ),
                              ),
                            ),
                            if (isRecommended) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Đề xuất AI',
                                  style: context.labelSmall?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold),
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
                Text(
                  'Tiêu đề thông báo:',
                  style: context.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  style: context.bodyMedium,
                ),

                const SizedBox(height: 12),

                // Nội dung thông báo
                Text(
                  'Nội dung gửi Quý cư dân:',
                  style: context.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _contentController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  style: context.bodyMedium,
                ),

                const SizedBox(height: 20),

                // Hành động
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
                      child: const Text('Hủy'),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedTier.color,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 48),
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
