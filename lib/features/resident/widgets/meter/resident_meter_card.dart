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
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.history_toggle_off,
                color: AppTheme.primary,
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
                child: Container(
                  padding: AppSpacing.p12,
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: AppRadius.r12,
                    border: Border.all(
                      color: Colors.amber.shade200,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.bolt,
                            color: Colors.amber.shade800,
                            size: 20,
                          ),
                          AppSpacing.w4,
                          Expanded(
                            child: Text(
                              'Điện cũ',
                              style: textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
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
                          '$oldElec kWh',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              AppSpacing.w12,
              Expanded(
                child: Container(
                  padding: AppSpacing.p12,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: AppRadius.r12,
                    border: Border.all(
                      color: Colors.blue.shade200,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.water_drop,
                            color: Colors.blue.shade800,
                            size: 20,
                          ),
                          AppSpacing.w4,
                          Expanded(
                            child: Text(
                              'Nước cũ',
                              style: textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
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
                          '$oldWater m³',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

