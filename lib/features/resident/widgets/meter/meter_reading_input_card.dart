import 'package:flutter/material.dart';
import 'package:vivona/core/theme/app_radius.dart';
import 'package:vivona/core/theme/app_spacing.dart';
import 'package:vivona/core/theme/app_theme.dart';
import 'package:vivona/core/utils/utility_anomaly_detector.dart';
import 'package:vivona/core/widgets/app_card.dart';

class MeterReadingInputCard extends StatelessWidget {
  final MeterType meterType;
  final TextEditingController controller;
  final double previousReading;
  final String? imagePath;
  final bool isOcrScanning;
  final AnomalyAnalysisResult? analysis;
  final VoidCallback onPickCamera;
  final VoidCallback onPickGallery;
  final VoidCallback onClearImage;

  const MeterReadingInputCard({
    super.key,
    required this.meterType,
    required this.controller,
    required this.previousReading,
    required this.imagePath,
    required this.isOcrScanning,
    required this.analysis,
    required this.onPickCamera,
    required this.onPickGallery,
    required this.onClearImage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;

    final isElectric = meterType == MeterType.electric;
    final accentColor = isElectric
        ? AppTheme.getSemanticWarning(context)
        : colorScheme.primary;
    final successColor = AppTheme.getSemanticSuccess(context);

    final title = isElectric ? 'Công tơ Điện (kWh)' : 'Công tơ Nước (m³)';
    final unit = isElectric ? 'kWh' : 'm³';
    final labelText = isElectric ? 'Chỉ số điện mới *' : 'Chỉ số nước mới *';
    final emptyError = isElectric
        ? 'Vui lòng nhập chỉ số điện'
        : 'Vui lòng nhập chỉ số nước';
    final cameraTooltip = isElectric
        ? 'Chụp ảnh công tơ điện'
        : 'Chụp ảnh công tơ nước';
    final attachedPrefix = isElectric
        ? 'Đã đính kèm ảnh công tơ điện'
        : 'Đã đính kèm ảnh công tơ nước';

    final currentVal = double.tryParse(controller.text.trim());
    final delta = (currentVal != null && currentVal >= previousReading)
        ? currentVal - previousReading
        : null;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(
                        alpha: isDark ? 0.18 : 0.10,
                      ),
                      borderRadius: AppRadius.r8,
                    ),
                    child: Icon(
                      isElectric ? Icons.bolt : Icons.water_drop,
                      color: accentColor,
                      size: 20,
                    ),
                  ),
                  AppSpacing.w8,
                  Flexible(
                    child: Text(
                      title,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton.filledTonal(
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    tooltip: cameraTooltip,
                    icon: const Icon(
                      Icons.camera_alt_outlined,
                      size: 20,
                    ),
                    onPressed: onPickCamera,
                  ),
                  AppSpacing.w4,
                  IconButton.outlined(
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    tooltip: 'Chọn ảnh từ thư viện',
                    icon: const Icon(
                      Icons.photo_library_outlined,
                      size: 20,
                    ),
                    onPressed: onPickGallery,
                  ),
                ],
              ),
            ],
          ),
          if (imagePath != null) ...[
            AppSpacing.h8,
            Container(
              padding: const EdgeInsets.only(left: 10, right: 2, top: 2, bottom: 2),
              decoration: BoxDecoration(
                color: successColor.withValues(alpha: isDark ? 0.14 : 0.08),
                borderRadius: AppRadius.r8,
                border: Border.all(
                  color: successColor.withValues(alpha: isDark ? 0.35 : 0.28),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 18,
                    color: successColor,
                  ),
                  AppSpacing.w8,
                  Expanded(
                    child: Text(
                      '$attachedPrefix: ${imagePath!.split('/').last.split(r'\').last}',
                      style: textTheme.labelSmall?.copyWith(
                        color: successColor,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Gỡ ảnh đính kèm',
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    icon: Icon(
                      Icons.close,
                      size: 18,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    onPressed: onClearImage,
                  ),
                ],
              ),
            ),
          ],
          if (isOcrScanning) ...[
            AppSpacing.h8,
            Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                AppSpacing.w8,
                Expanded(
                  child: Text(
                    'Đang xử lý OCR bóc tách chỉ số từ ảnh công tơ...',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.primary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ],
          AppSpacing.h12,
          TextFormField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: textTheme.bodyLarge?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            decoration: InputDecoration(
              labelText: labelText,
              suffixText: unit,
              border: const OutlineInputBorder(),
              prefixIcon: Icon(
                isElectric
                    ? Icons.electric_meter_outlined
                    : Icons.water_damage_outlined,
              ),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return emptyError;
              }
              if (double.tryParse(val.trim()) == null) {
                return 'Chỉ số phải là số hợp lệ';
              }
              return null;
            },
          ),
          if (delta != null) ...[
            AppSpacing.h8,
            Row(
              children: [
                Icon(
                  Icons.trending_up_rounded,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                AppSpacing.w6,
                Expanded(
                  child: Text(
                    'Sản lượng ước tính kỳ này: +${delta.toStringAsFixed(delta == delta.roundToDouble() ? 0 : 1)} $unit',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (analysis != null) MeterAnomalyBanner(analysis: analysis!),
        ],
      ),
    );
  }
}

class MeterAnomalyBanner extends StatelessWidget {
  final AnomalyAnalysisResult analysis;

  const MeterAnomalyBanner({super.key, required this.analysis});

  @override
  Widget build(BuildContext context) {
    if (!analysis.isAnomaly) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;

    final Color semanticColor;
    final IconData icon;

    switch (analysis.severity) {
      case AnomalySeverity.danger:
        semanticColor = AppTheme.getSemanticError(context);
        icon = Icons.error_outline;
      case AnomalySeverity.warning:
        semanticColor = AppTheme.getSemanticWarning(context);
        icon = Icons.warning_amber_rounded;
      case AnomalySeverity.info:
      case AnomalySeverity.normal:
        semanticColor = colorScheme.primary;
        icon = Icons.info_outline;
    }

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: AppSpacing.p12,
      decoration: BoxDecoration(
        color: semanticColor.withValues(alpha: isDark ? 0.14 : 0.08),
        borderRadius: AppRadius.r8,
        border: Border.all(
          color: semanticColor.withValues(alpha: isDark ? 0.45 : 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: semanticColor, size: 20),
          AppSpacing.w8,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cảnh báo: ${analysis.severityDisplayName}',
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: semanticColor,
                  ),
                ),
                if (analysis.reason != null) ...[
                  AppSpacing.h4,
                  Text(
                    analysis.reason!,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
