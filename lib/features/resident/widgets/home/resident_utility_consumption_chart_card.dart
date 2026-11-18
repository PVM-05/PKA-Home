import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../../../core/widgets/bounceable.dart';
import '../../../../data/providers/meter_reading_provider.dart';

enum UtilityType { electricity, water }

/// Thẻ Bento hiển thị biểu đồ mức tiêu thụ điện và nước của căn hộ cho cư dân.
/// Nối dữ liệu thật từ Supabase. Tự động ẩn khi có ít hơn 2 kỳ chốt chỉ số để đảm bảo tính trung thực.
class ResidentUtilityConsumptionChartCard extends ConsumerStatefulWidget {
  const ResidentUtilityConsumptionChartCard({super.key});

  @override
  ConsumerState<ResidentUtilityConsumptionChartCard> createState() =>
      _ResidentUtilityConsumptionChartCardState();
}

class _ResidentUtilityConsumptionChartCardState
    extends ConsumerState<ResidentUtilityConsumptionChartCard> {
  UtilityType _selectedType = UtilityType.electricity;

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
    final historyAsync = ref.watch(residentUtilityConsumptionHistoryProvider);

    return historyAsync.when(
      data: (submissions) {
        // Chỉ hiển thị biểu đồ khi có tối thiểu 2 kỳ dữ liệu thật để vẽ xu hướng và tính % tăng/giảm
        if (submissions.length < 2) {
          return const SizedBox.shrink();
        }

        final theme = Theme.of(context);
        final textTheme = theme.textTheme;
        final colorScheme = theme.colorScheme;

        final isElectricity = _selectedType == UtilityType.electricity;
        final currentData = isElectricity
            ? submissions.map((s) => s.effectiveElectricConsumed).toList()
            : submissions.map((s) => s.effectiveWaterConsumed).toList();

        final months = submissions.map((s) {
          final parts = s.period.split(RegExp(r'[/-]'));
          if (parts.length >= 2) {
            final m = parts.first.length == 4 ? parts[1] : parts[0];
            return 'T${int.tryParse(m) ?? m}';
          }
          return s.period;
        }).toList();

        final currentUnit = isElectricity ? 'kWh' : 'm³';
        final latestVal = currentData.last;
        final prevVal = currentData[currentData.length - 2];
        final diff = latestVal - prevVal;
        final percentChange = prevVal > 0
            ? (diff.abs() / prevVal * 100).toStringAsFixed(1)
            : '0.0';
        final isReduced = diff <= 0;

        // Tính giá trị đỉnh động cho biểu đồ
        final maxVal = currentData.reduce((a, b) => a > b ? a : b);
        final dynamicMaxY = (maxVal * 1.25).clamp(10.0, double.infinity);

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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tiêu thụ điện & nước',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Xu hướng ${submissions.length} tháng gần nhất',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AppSpacing.w8,
                    // Toggle Tab Buttons
                    Container(
                      padding: AppSpacing.p4,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: AppRadius.rFull,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
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
                                ? '-$percentChange%'
                                : '+$percentChange%',
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
                Semantics(
                  container: true,
                  label: 'Biểu đồ tiêu thụ ${isElectricity ? 'Điện' : 'Nước'}. Tháng này tiêu thụ ${latestVal.toStringAsFixed(0)} $currentUnit, ${isReduced ? 'giảm' : 'tăng'} $percentChange% so với tháng trước.',
                  child: SizedBox(
                    height: 120,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: dynamicMaxY,
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
                                if (idx >= 0 && idx < months.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6.0),
                                    child: Text(
                                      months[idx],
                                      style: textTheme.labelSmall?.copyWith(
                                        color: idx == months.length - 1
                                            ? primaryAccent
                                            : colorScheme.onSurfaceVariant,
                                        fontWeight: idx == months.length - 1
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
                                  toY: dynamicMaxY,
                                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, st) => Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.rLg,
          side: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Padding(
          padding: AppSpacing.p12,
          child: Row(
            children: [
              Icon(
                Icons.sync_problem_rounded,
                color: Theme.of(context).colorScheme.error,
                size: 20,
              ),
              AppSpacing.w8,
              Expanded(
                child: Text(
                  'Không thể tải dữ liệu tiêu thụ điện nước',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              TextButton(
                onPressed: () => ref.invalidate(residentUtilityConsumptionHistoryProvider),
                child: const Text('Thử lại'),
              ),
            ],
          ),
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
