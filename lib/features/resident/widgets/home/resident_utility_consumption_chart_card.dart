import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../../../core/widgets/bounceable.dart';

enum UtilityType { electricity, water }

/// Thẻ Bento hiển thị biểu đồ mức tiêu thụ điện và nước của căn hộ cho cư dân.
class ResidentUtilityConsumptionChartCard extends StatefulWidget {
  const ResidentUtilityConsumptionChartCard({super.key});

  @override
  State<ResidentUtilityConsumptionChartCard> createState() =>
      _ResidentUtilityConsumptionChartCardState();
}

class _ResidentUtilityConsumptionChartCardState
    extends State<ResidentUtilityConsumptionChartCard> {
  UtilityType _selectedType = UtilityType.electricity;

  // Dữ liệu tiêu thụ 6 tháng gần nhất (T6 - T11)
  static const List<double> _electricityData = [210, 260, 290, 275, 230, 215];
  static const List<double> _waterData = [16, 19, 22, 20, 18, 17];
  static const List<String> _months = ['T6', 'T7', 'T8', 'T9', 'T10', 'T11'];

  void _onSelectType(UtilityType type) {
    if (_selectedType != type) {
      AppHaptics.selection();
      setState(() {
        _selectedType = type;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    final isElectricity = _selectedType == UtilityType.electricity;
    final currentData = isElectricity ? _electricityData : _waterData;
    final currentUnit = isElectricity ? 'kWh' : 'm³';
    final latestVal = currentData.last;
    final prevVal = currentData[currentData.length - 2];
    final diff = latestVal - prevVal;
    final percentChange = (diff / prevVal * 100).toStringAsFixed(1);
    final isReduced = diff <= 0;

    final primaryAccent = isElectricity
        ? colorScheme.primary
        : colorScheme.tertiary;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.rLg,
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: AppSpacing.p16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Tiêu đề + Chuyển tab
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: AppSpacing.p8,
                      decoration: BoxDecoration(
                        color: primaryAccent.withValues(alpha: 0.12),
                        borderRadius: AppRadius.rSm,
                      ),
                      child: Icon(
                        isElectricity
                            ? Icons.electric_bolt_rounded
                            : Icons.water_drop_rounded,
                        color: primaryAccent,
                        size: 20,
                      ),
                    ),
                    AppSpacing.w12,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tiêu thụ điện & nước',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Xu hướng 6 tháng gần nhất',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // Toggle Tab Buttons
                Container(
                  padding: AppSpacing.p4,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: AppRadius.rFull,
                  ),
                  child: Row(
                    children: [
                      _buildTabButton(
                        label: 'Điện',
                        isSelected: isElectricity,
                        onTap: () => _onSelectType(UtilityType.electricity),
                      ),
                      _buildTabButton(
                        label: 'Nước',
                        isSelected: !isElectricity,
                        onTap: () => _onSelectType(UtilityType.water),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            AppSpacing.h20,

            // Chỉ số nổi bật tháng này
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  latestVal.toStringAsFixed(0),
                  style: textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                AppSpacing.w6,
                Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Text(
                    currentUnit,
                    style: textTheme.titleSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: AppSpacing.px8 + AppSpacing.py4,
                  decoration: BoxDecoration(
                    color: isReduced
                        ? colorScheme.primary.withValues(alpha: 0.12)
                        : colorScheme.error.withValues(alpha: 0.12),
                    borderRadius: AppRadius.rFull,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isReduced
                            ? Icons.trending_down_rounded
                            : Icons.trending_up_rounded,
                        size: 16,
                        color: isReduced
                            ? colorScheme.primary
                            : colorScheme.error,
                      ),
                      AppSpacing.w4,
                      Text(
                        isReduced
                            ? '$percentChange% so với tháng trước'
                            : '+$percentChange% so với tháng trước',
                        style: textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isReduced
                              ? colorScheme.primary
                              : colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            AppSpacing.h16,

            // Biểu đồ cột mini FlChart
            SizedBox(
              height: 120,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: isElectricity ? 320 : 25,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => colorScheme.inverseSurface,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          '${rod.toY.toStringAsFixed(0)} $currentUnit',
                          textTheme.labelSmall?.copyWith(
                                color: colorScheme.onInverseSurface,
                                fontWeight: FontWeight.bold,
                              ) ??
                              const TextStyle(),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx >= 0 && idx < _months.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 6.0),
                              child: Text(
                                _months[idx],
                                style: textTheme.labelSmall?.copyWith(
                                  color: idx == _months.length - 1
                                      ? primaryAccent
                                      : colorScheme.onSurfaceVariant,
                                  fontWeight: idx == _months.length - 1
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(currentData.length, (index) {
                    final isLast = index == currentData.length - 1;
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: currentData[index],
                          color: isLast
                              ? primaryAccent
                              : primaryAccent.withValues(alpha: 0.35),
                          width: 14,
                          borderRadius: BorderRadius.circular(4),
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: isElectricity ? 320 : 25,
                            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Bounceable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: AppSpacing.px12 + AppSpacing.py4,
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.surface : Colors.transparent,
          borderRadius: AppRadius.rFull,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: colorScheme.shadow.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: textTheme.labelSmall?.copyWith(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? colorScheme.onSurface
                : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
