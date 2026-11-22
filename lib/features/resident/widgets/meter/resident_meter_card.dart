import 'package:flutter/material.dart';
import 'package:vivona/core/theme/app_radius.dart';
import 'package:vivona/core/theme/app_spacing.dart';
import 'package:vivona/core/theme/app_theme.dart';
import 'package:vivona/core/widgets/app_card.dart';

class ResidentPreviousMeterCard extends StatelessWidget {
  final String aptCode;
  final double oldElec;
  final double oldWater;

  const ResidentPreviousMeterCard({
    super.key,
    required this.aptCode,
    required this.oldElec,
    required this.oldWater,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;
    final electricAccent = AppTheme.getSemanticWarning(context);
    final waterAccent = colorScheme.primary;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.history_toggle_off,
                color: colorScheme.primary,
              ),
              AppSpacing.w8,
              Expanded(
                child: Text(
                  'Chỉ số kỳ trước • Căn hộ $aptCode',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          AppSpacing.h12,
          Row(
            children: [
              Expanded(
                child: _PreviousMeterTile(
                  icon: Icons.bolt,
                  label: 'Điện cũ',
                  value: '$oldElec kWh',
                  accentColor: electricAccent,
                  isDark: isDark,
                ),
              ),
              AppSpacing.w12,
              Expanded(
                child: _PreviousMeterTile(
                  icon: Icons.water_drop,
                  label: 'Nước cũ',
                  value: '$oldWater m³',
                  accentColor: waterAccent,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreviousMeterTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accentColor;
  final bool isDark;

  const _PreviousMeterTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.accentColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: AppSpacing.p12,
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: isDark ? 0.14 : 0.08),
        borderRadius: AppRadius.r12,
        border: Border.all(
          color: accentColor.withValues(alpha: isDark ? 0.35 : 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: accentColor,
                size: 20,
              ),
              AppSpacing.w4,
              Expanded(
                child: Text(
                  label,
                  style: textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          AppSpacing.h6,
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: accentColor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
