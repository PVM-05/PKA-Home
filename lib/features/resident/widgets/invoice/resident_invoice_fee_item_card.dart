import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/invoice_fee_helper.dart';
import '../../../../core/widgets/app_card.dart';

class ResidentInvoiceFeeItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final NumberFormat formatCurrency;
  final void Function({
    required bool isElectricity,
    required num quantity,
    required Map<String, dynamic> item,
  }) onViewTieredBreakdown;

  const ResidentInvoiceFeeItemCard({
    super.key,
    required this.item,
    required this.formatCurrency,
    required this.onViewTieredBreakdown,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rawFeeType = item['fee_type'] as String?;
    final feeDisplayName = InvoiceFeeHelper.getFeeName(rawFeeType);
    final feeIcon = InvoiceFeeHelper.getFeeIcon(rawFeeType);
    final feeColor = InvoiceFeeHelper.getFeeColor(rawFeeType);
    final feeUnit = InvoiceFeeHelper.getFeeUnit(rawFeeType);
    final proratedColor = AppTheme.getSemanticSecondary(context);

    final qty = item['quantity'] ?? 1;
    final qtyNum = (qty is num) ? qty : (num.tryParse(qty.toString()) ?? 1);
    final qtyStr = (qty is num && qty == qty.roundToDouble())
        ? qty.toInt().toString()
        : qty.toString();

    final feeTypeLower = (rawFeeType ?? '').toLowerCase().trim();
    final noteText = '${item['note'] ?? ''} ${item['description'] ?? ''}'
        .toLowerCase();

    final isElectricity =
        feeTypeLower == 'electricity' || feeTypeLower.contains('điện');
    final isWater = feeTypeLower == 'water' || feeTypeLower.contains('nước');
    final isTiered = isElectricity || isWater;

    final isParking =
        feeTypeLower.contains('parking') || feeTypeLower.contains('xe');
    final isProratedParking =
        isParking &&
        (noteText.contains('ngày') ||
            noteText.contains('pro-rata') ||
            noteText.contains('prorated'));

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: feeColor.withValues(alpha: isDark ? 0.2 : 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(feeIcon, color: feeColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feeDisplayName,
                  style: context.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${formatCurrency.format(item['unit_price'] ?? 0)} x $qtyStr$feeUnit',
                  style: context.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (isTiered) ...[
                  const SizedBox(height: 8),
                  Semantics(
                    button: true,
                    label: 'Xem chi tiết bậc thang $feeDisplayName',
                    child: InkWell(
                      onTap: () {
                        onViewTieredBreakdown(
                          isElectricity: isElectricity,
                          quantity: qtyNum,
                          item: item,
                        );
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: feeColor.withValues(
                              alpha: isDark ? 0.2 : 0.1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: feeColor.withValues(
                                alpha: isDark ? 0.4 : 0.3,
                              ),
                            ),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.tune_rounded,
                                  size: 14,
                                  color: feeColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Chi tiết bậc thang',
                                  style: context.labelSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: feeColor,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 15,
                                  color: feeColor,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                if (isProratedParking) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: proratedColor.withValues(
                        alpha: isDark ? 0.2 : 0.1,
                      ),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: proratedColor.withValues(
                          alpha: isDark ? 0.4 : 0.3,
                        ),
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_month_outlined,
                            size: 13,
                            color: proratedColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Phí theo ngày lẻ',
                            style: context.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: proratedColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                formatCurrency.format(item['subtotal'] ?? 0),
                style: context.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
