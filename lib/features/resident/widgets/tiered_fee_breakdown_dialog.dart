import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/tiered_calculation_result_model.dart';

/// Hộp thoại hiển thị chi tiết phân rã bậc thang lũy tiến (Điện/Nước) cho cư dân
class TieredFeeBreakdownDialog extends StatelessWidget {
  final String title;
  final String unit; // 'kWh' hoặc 'm³'
  final TieredCalculationResultModel result;

  const TieredFeeBreakdownDialog({
    super.key,
    required this.title,
    required this.unit,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final isWater = unit.toLowerCase().contains('m');
    final headerColor = isWater ? const Color(0xFF0288D1) : const Color(0xFFE65100);
    final headerIcon = isWater ? Icons.water_drop_rounded : Icons.electric_bolt_rounded;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark
        ? (Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface)
        : Colors.white;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: cardBg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Thanh tiêu đề
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: headerColor.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: headerColor.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(headerIcon, color: headerColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          result.policyName,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Nội dung cuộn
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge tổng tiêu thụ và tổng tiền
                    _buildSummaryHeader(headerColor, isDark),
                    const SizedBox(height: 16),

                    // Thanh phân bổ tỷ lệ các bậc
                    if (result.consumption > 0) ...[
                      const Text(
                        'TỶ LỆ PHÂN BỔ CÁC BẬC',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textSecondary,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildAllocationBar(headerColor),
                      const SizedBox(height: 18),
                    ],

                    // Danh sách chi tiết từng bậc
                    const Text(
                      'CHI TIẾT ĐỊNH MỨC & THÀNH TIỀN',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textSecondary,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...result.breakdown.map((item) => _buildTierItem(item, headerColor, isDark)),

                    // Thông tin nhân khẩu (nếu có)
                    if (result.residentCount != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.people_alt_rounded, size: 18, color: Colors.blue),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Định mức áp dụng: ${result.residentCount} nhân khẩu '
                                '${result.baseQuota != null ? "(${result.baseQuota!.toInt()} $unit/tháng)" : ""}',
                                style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.w600),
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

            // Nút đóng
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade200)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Đóng', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryHeader(Color accentColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tổng tiêu thụ',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                '${result.formattedConsumption} $unit',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: accentColor,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'Tổng thành tiền',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                result.formattedTotalAmount,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: accentColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAllocationBar(Color baseColor) {
    final activeItems = result.breakdown.where((t) => t.units > 0).toList();
    if (activeItems.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(
          value: 0,
          backgroundColor: Colors.grey.shade300,
          minHeight: 10,
        ),
      );
    }

    final colors = [
      baseColor.withValues(alpha: 0.4),
      baseColor.withValues(alpha: 0.6),
      baseColor.withValues(alpha: 0.8),
      baseColor,
      Colors.deepPurple,
      Colors.red.shade700,
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 10,
        child: Row(
          children: activeItems.map((item) {
            final flexVal = (item.units * 100).round();
            final color = colors[(item.tier - 1) % colors.length];
            return Flexible(
              flex: flexVal > 0 ? flexVal : 1,
              child: Container(color: color),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTierItem(TierBreakdownItem item, Color accentColor, bool isDark) {
    final isActive = item.units > 0;
    final formatCurrency = NumberFormat('#,##0 đ', 'vi_VN');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isActive
            ? accentColor.withValues(alpha: isDark ? 0.12 : 0.05)
            : (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive
              ? accentColor.withValues(alpha: 0.3)
              : (isDark ? Colors.white10 : Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isActive ? accentColor : Colors.grey.shade400,
              shape: BoxShape.circle,
            ),
            child: Text(
              '${item.tier}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: TextStyle(
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                    fontSize: 13,
                    color: isActive
                        ? (isDark ? Colors.white : AppTheme.textPrimary)
                        : AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.formattedUnits} $unit x ${formatCurrency.format(item.rate)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isActive ? AppTheme.textSecondary : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Text(
            item.formattedAmount,
            style: TextStyle(
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
              fontSize: 14,
              color: isActive ? accentColor : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

