import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:vivona/core/theme/app_radius.dart';
import 'package:vivona/core/theme/app_spacing.dart';
import 'package:vivona/core/theme/app_theme.dart';
import 'package:vivona/core/widgets/app_card.dart';
import 'package:vivona/core/widgets/app_empty_state.dart';
import 'package:vivona/core/widgets/app_error_card.dart';
import 'package:vivona/core/widgets/app_skeleton_shimmer.dart';
import 'package:vivona/data/models/meter_reading_submission_model.dart';

class MeterReadingHistorySection extends StatelessWidget {
  final AsyncValue<List<MeterReadingSubmissionModel>> historyAsync;
  final DateFormat dateFormat;
  final VoidCallback onRetry;
  final void Function(MeterReadingSubmissionModel item) onEdit;
  final void Function(MeterReadingSubmissionModel item) onCancel;

  const MeterReadingHistorySection({
    super.key,
    required this.historyAsync,
    required this.dateFormat,
    required this.onRetry,
    required this.onEdit,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Lịch Sử Khai Báo Chỉ Số',
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        AppSpacing.h12,
        historyAsync.when(
          data: (history) {
            if (history.isEmpty) {
              return const AppEmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'Chưa có lịch sử khai báo chỉ số nào.',
                description:
                    'Các phiếu khai báo chỉ số điện nước đã gửi sẽ hiển thị tại đây.',
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: history.length,
              itemBuilder: (context, index) {
                return _MeterHistoryItemCard(
                  item: history[index],
                  dateFormat: dateFormat,
                  onEdit: () => onEdit(history[index]),
                  onCancel: () => onCancel(history[index]),
                );
              },
            );
          },
          loading: () => AppSkeletonShimmer.cardList(count: 2, itemHeight: 96),
          error: (e, _) => AppErrorCard(error: e, onRetry: onRetry),
        ),
      ],
    );
  }
}

class _MeterHistoryItemCard extends StatelessWidget {
  final MeterReadingSubmissionModel item;
  final DateFormat dateFormat;
  final VoidCallback onEdit;
  final VoidCallback onCancel;

  const _MeterHistoryItemCard({
    required this.item,
    required this.dateFormat,
    required this.onEdit,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;

    final Color statusColor;
    if (item.isApproved) {
      statusColor = AppStatusColors.getPaid(context);
    } else if (item.isRejected) {
      statusColor = AppStatusColors.getRejected(context);
    } else if (item.isCancelled) {
      statusColor = colorScheme.onSurfaceVariant;
    } else {
      statusColor = AppStatusColors.getPending(context);
    }

    final errorColor = AppTheme.getSemanticError(context);
    final warningColor = AppTheme.getSemanticWarning(context);

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  'Kỳ: ${item.period}',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              AppSpacing.w8,
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 132),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: isDark ? 0.18 : 0.12),
                    borderRadius: AppRadius.r8,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      item.statusDisplayName,
                      style: textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.h8,
          Row(
            children: [
              Expanded(
                child: Text(
                  'Điện: ${item.electricReading} kWh',
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              AppSpacing.w8,
              Expanded(
                child: Text(
                  'Nước: ${item.waterReading} m³',
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          AppSpacing.h6,
          Text(
            'Gửi lúc: ${dateFormat.format(item.createdAt)}',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (item.hasAnomaly && item.anomalyReason != null) ...[
            AppSpacing.h8,
            Container(
              padding: AppSpacing.p8,
              decoration: BoxDecoration(
                color: (item.isDangerAnomaly ? errorColor : warningColor)
                    .withValues(alpha: isDark ? 0.14 : 0.08),
                borderRadius: AppRadius.r8,
                border: Border.all(
                  color: (item.isDangerAnomaly ? errorColor : warningColor)
                      .withValues(alpha: isDark ? 0.4 : 0.35),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    item.isDangerAnomaly
                        ? Icons.error_outline
                        : Icons.warning_amber_rounded,
                    size: 18,
                    color: item.isDangerAnomaly ? errorColor : warningColor,
                  ),
                  AppSpacing.w8,
                  Expanded(
                    child: Text(
                      'Lưu ý BQL: ${item.anomalyReason}',
                      style: textTheme.bodySmall?.copyWith(
                        color: item.isDangerAnomaly ? errorColor : warningColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (item.isRejected && item.rejectReason != null) ...[
            AppSpacing.h8,
            Container(
              padding: AppSpacing.p8,
              decoration: BoxDecoration(
                color: errorColor.withValues(alpha: isDark ? 0.14 : 0.08),
                borderRadius: AppRadius.r8,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: errorColor,
                  ),
                  AppSpacing.w8,
                  Expanded(
                    child: Text(
                      'Lý do từ chối: ${item.rejectReason}',
                      style: textTheme.bodySmall?.copyWith(
                        color: errorColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (item.isPending) ...[
            AppSpacing.h12,
            const Divider(height: 1),
            AppSpacing.h8,
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.primary,
                      minimumSize: const Size(0, 48),
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Sửa chỉ số'),
                    onPressed: onEdit,
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: errorColor,
                      minimumSize: const Size(0, 48),
                    ),
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: const Text('Hủy phiếu'),
                    onPressed: onCancel,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
