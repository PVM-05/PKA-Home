import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../data/models/meter_reading_submission_model.dart';

/// Card hiển thị chi tiết phiếu khai báo chỉ số điện nước phía BQL
class ManagementSubmissionCard extends StatelessWidget {
  final MeterReadingSubmissionModel item;
  final String currentTabStatus;
  final void Function(String title, String imageUrl) onShowImage;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final DateFormat? dateFormat;

  const ManagementSubmissionCard({
    super.key,
    required this.item,
    required this.currentTabStatus,
    required this.onShowImage,
    required this.onApprove,
    required this.onReject,
    this.dateFormat,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final successColor = AppTheme.getSemanticSuccess(context);
    final warningColor = AppTheme.getSemanticWarning(context);
    final errorColor = AppTheme.getSemanticError(context);
    final secondaryColor = AppTheme.getSemanticSecondary(context);

    Color statusColor = warningColor;
    if (item.isApproved) statusColor = successColor;
    if (item.isRejected) statusColor = errorColor;

    final anomalyColor = item.isDangerAnomaly ? errorColor : warningColor;
    final formatter = dateFormat ?? DateFormat('dd/MM/yyyy HH:mm');

    return AppCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: AppSpacing.p8,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: AppRadius.r8,
                ),
                child: Icon(
                  Icons.apartment,
                  color: colorScheme.primary,
                  size: 20,
                ),
              ),
              AppSpacing.w8,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Căn hộ ${item.apartmentCode ?? ''}',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)
                          .tabularFigures(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Kỳ: ${item.period} • Gửi lúc ${formatter.format(item.createdAt)}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: colorScheme.onSurfaceVariant)
                          .tabularFigures(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              AppSpacing.w8,
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 96),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: AppRadius.r8,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      item.statusDisplayName,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Huy hiệu đã xuất hóa đơn
          if (item.hasGeneratedInvoice) ...[
            AppSpacing.h8,
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: successColor.withValues(alpha: 0.1),
                borderRadius: AppRadius.r8,
                border: Border.all(color: successColor.withValues(alpha: 0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.receipt_long, size: 16, color: successColor),
                  AppSpacing.w6,
                  Flexible(
                    child: Text(
                      'Đã xuất hóa đơn ${item.invoiceId != null ? "(${item.invoiceId})" : ""}',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: successColor,
                          )
                          .tabularFigures(),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Banner cảnh báo bất thường AI/OCR nếu có
          if (item.hasAnomaly) ...[
            AppSpacing.h12,
            Container(
              padding: AppSpacing.p12,
              decoration: BoxDecoration(
                color: anomalyColor.withValues(alpha: 0.08),
                border: Border.all(color: anomalyColor.withValues(alpha: 0.4)),
                borderRadius: AppRadius.r8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        item.isDangerAnomaly
                            ? Icons.error_outline
                            : Icons.warning_amber_rounded,
                        size: 16,
                        color: anomalyColor,
                      ),
                      AppSpacing.w6,
                      Expanded(
                        child: Text(
                          'Phát hiện bất thường: ${item.anomalySeverityDisplayName}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: anomalyColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (item.anomalyReason != null &&
                      item.anomalyReason!.isNotEmpty) ...[
                    AppSpacing.h4,
                    Text(
                      item.anomalyReason!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: anomalyColor,
                      ),
                    ),
                  ],
                  if (item.previousElectricReading != null ||
                      item.previousWaterReading != null) ...[
                    AppSpacing.h4,
                    Text(
                      '• Đối chiếu cũ: Điện ${item.previousElectricReading ?? '—'} kWh (TB: ${item.avgElectricUsage ?? '—'}) | Nước ${item.previousWaterReading ?? '—'} m³ (TB: ${item.avgWaterUsage ?? '—'})',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: colorScheme.onSurfaceVariant)
                          .tabularFigures(),
                    ),
                  ],
                ],
              ),
            ),
          ],

          AppSpacing.h12,
          const Divider(height: 1),
          AppSpacing.h12,

          // Chỉ số điện và nước
          Row(
            children: [
              Expanded(
                child: _buildUtilityTile(
                  context: context,
                  icon: Icons.bolt,
                  accentColor: warningColor,
                  label: 'Điện (kWh)',
                  value: '${item.electricReading} kWh',
                  imageUrl: item.electricImageUrl,
                  onTapImage: item.electricImageUrl == null
                      ? null
                      : () => onShowImage(
                          'Ảnh công tơ điện - Căn ${item.apartmentCode}',
                          item.electricImageUrl!,
                        ),
                ),
              ),
              AppSpacing.w12,
              Expanded(
                child: _buildUtilityTile(
                  context: context,
                  icon: Icons.water_drop,
                  accentColor: secondaryColor,
                  label: 'Nước (m³)',
                  value: '${item.waterReading} m³',
                  imageUrl: item.waterImageUrl,
                  onTapImage: item.waterImageUrl == null
                      ? null
                      : () => onShowImage(
                          'Ảnh công tơ nước - Căn ${item.apartmentCode}',
                          item.waterImageUrl!,
                        ),
                ),
              ),
            ],
          ),

          if (item.submitterName != null) ...[
            AppSpacing.h8,
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Người gửi: ${item.submitterName}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                AppSpacing.w8,
                Flexible(
                  child: Text(
                    'Độ tin cậy OCR: ${(item.ocrConfidence * 100).toStringAsFixed(1)}%',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: colorScheme.onSurfaceVariant)
                        .tabularFigures(),
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],

          if (item.isRejected && item.rejectReason != null) ...[
            AppSpacing.h12,
            Container(
              padding: AppSpacing.p12,
              decoration: BoxDecoration(
                color: errorColor.withValues(alpha: 0.08),
                borderRadius: AppRadius.r8,
                border: Border.all(color: errorColor.withValues(alpha: 0.25)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 16, color: errorColor),
                  AppSpacing.w6,
                  Expanded(
                    child: Text(
                      'Lý do từ chối: ${item.rejectReason}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: errorColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Hành động nếu là Tab Chờ duyệt hoặc Bất thường có status pending
          if (currentTabStatus == 'pending') ...[
            AppSpacing.h16,
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: errorColor,
                      side: BorderSide(color: errorColor),
                      minimumSize: const Size(0, 48),
                      shape: AppRadius.shapeSm,
                    ),
                    icon: const Icon(Icons.close, size: 18),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Từ chối'),
                    ),
                    onPressed: onReject,
                  ),
                ),
                AppSpacing.w12,
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      minimumSize: const Size(0, 48),
                      shape: AppRadius.shapeSm,
                    ),
                    icon: const Icon(Icons.check, size: 18),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Phê duyệt'),
                    ),
                    onPressed: onApprove,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUtilityTile({
    required BuildContext context,
    required IconData icon,
    required Color accentColor,
    required String label,
    required String value,
    required String? imageUrl,
    required VoidCallback? onTapImage,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: AppSpacing.p12,
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: AppRadius.r8,
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor, size: 18),
              AppSpacing.w4,
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          AppSpacing.h6,
          Text(
            value,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold, color: accentColor)
                .tabularFigures(),
            overflow: TextOverflow.ellipsis,
          ),
          if (imageUrl != null && onTapImage != null) ...[
            AppSpacing.h6,
            InkWell(
              onTap: onTapImage,
              borderRadius: AppRadius.r6,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.image, size: 14, color: colorScheme.primary),
                    AppSpacing.w4,
                    Flexible(
                      child: Text(
                        'Xem ảnh',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
