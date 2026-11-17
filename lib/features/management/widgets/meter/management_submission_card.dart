import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
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
    Color statusColor = AppTheme.warning;
    if (item.isApproved) statusColor = AppStatusColors.paid;
    if (item.isRejected) statusColor = AppTheme.error;

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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: AppRadius.r8,
                ),
                child: const Icon(
                  Icons.apartment,
                  color: AppTheme.primary,
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
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Kỳ: ${item.period} • Gửi lúc ${formatter.format(item.createdAt)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              AppSpacing.w8,
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 90),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: AppRadius.r8,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      item.statusDisplayName,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
                color: Colors.green.shade50,
                borderRadius: AppRadius.r8,
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.receipt_long,
                    size: 16,
                    color: Colors.green.shade700,
                  ),
                  AppSpacing.w6,
                  Flexible(
                    child: Text(
                      'Đã xuất hóa đơn ${item.invoiceId != null ? "(${item.invoiceId})" : ""}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Banner cảnh báo bất thường AI/OCR nếu có
          if (item.hasAnomaly) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: item.isDangerAnomaly
                    ? AppTheme.error.withValues(alpha: 0.08)
                    : Colors.orange.withValues(alpha: 0.08),
                border: Border.all(
                  color: item.isDangerAnomaly ? AppTheme.error : Colors.orange,
                ),
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
                        color: item.isDangerAnomaly
                            ? AppTheme.error
                            : Colors.orange.shade800,
                      ),
                      AppSpacing.w6,
                      Expanded(
                        child: Text(
                          'Phát hiện bất thường: ${item.anomalySeverityDisplayName}',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: item.isDangerAnomaly
                                        ? AppTheme.error
                                        : Colors.orange.shade900,
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
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: item.isDangerAnomaly
                                ? AppTheme.error
                                : Colors.orange.shade900,
                          ),
                    ),
                  ],
                  if (item.previousElectricReading != null ||
                      item.previousWaterReading != null) ...[
                    AppSpacing.h4,
                    Text(
                      '• Đối chiếu cũ: Điện ${item.previousElectricReading ?? '—'} kWh (TB: ${item.avgElectricUsage ?? '—'}) | Nước ${item.previousWaterReading ?? '—'} m³ (TB: ${item.avgWaterUsage ?? '—'})',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
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
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: AppRadius.r8,
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.bolt,
                            color: Colors.amber.shade800,
                            size: 18,
                          ),
                          AppSpacing.w4,
                          Expanded(
                            child: Text(
                              'Điện (kWh)',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      AppSpacing.h6,
                      Text(
                        '${item.electricReading} kWh',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber.shade900,
                                ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.electricImageUrl != null) ...[
                        AppSpacing.h6,
                        GestureDetector(
                          onTap: () => onShowImage(
                            'Ảnh công tơ điện - Căn ${item.apartmentCode}',
                            item.electricImageUrl!,
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.image,
                                size: 14,
                                color: AppTheme.primary,
                              ),
                              AppSpacing.w4,
                              Text(
                                'Xem ảnh',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              AppSpacing.w12,
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: AppRadius.r8,
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.water_drop,
                            color: Colors.blue.shade800,
                            size: 18,
                          ),
                          AppSpacing.w4,
                          Expanded(
                            child: Text(
                              'Nước (m³)',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      AppSpacing.h6,
                      Text(
                        '${item.waterReading} m³',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade900,
                                ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.waterImageUrl != null) ...[
                        AppSpacing.h6,
                        GestureDetector(
                          onTap: () => onShowImage(
                            'Ảnh công tơ nước - Căn ${item.apartmentCode}',
                            item.waterImageUrl!,
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.image,
                                size: 14,
                                color: AppTheme.primary,
                              ),
                              AppSpacing.w4,
                              Text(
                                'Xem ảnh',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
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
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                AppSpacing.w8,
                Flexible(
                  child: Text(
                    'Độ tin cậy OCR: ${(item.ocrConfidence * 100).toStringAsFixed(1)}%',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],

          if (item.isRejected && item.rejectReason != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.08),
                borderRadius: AppRadius.r8,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 16,
                    color: AppTheme.error,
                  ),
                  AppSpacing.w6,
                  Expanded(
                    child: Text(
                      'Lý do từ chối: ${item.rejectReason}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.error,
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
                      foregroundColor: AppTheme.error,
                      side: const BorderSide(color: AppTheme.error),
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
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
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
}

