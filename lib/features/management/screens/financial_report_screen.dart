import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/permissions.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/error_formatter.dart';
import '../../../core/utils/excel_export_helper.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_card.dart';
import '../../../core/widgets/app_skeleton_shimmer.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/role_guard.dart';
import '../../../data/models/debt_risk_score_model.dart';
import '../../../data/models/financial_aging_report_model.dart';
import '../../../data/providers/financial_report_provider.dart';
import '../widgets/debt_risk_radar_tab.dart';
import '../widgets/execute_dunning_dialog.dart';
import 'apartment_ledger_screen.dart';

class FinancialReportScreen extends ConsumerStatefulWidget {
  const FinancialReportScreen({super.key});

  @override
  ConsumerState<FinancialReportScreen> createState() =>
      _FinancialReportScreenState();
}

class _FinancialReportScreenState extends ConsumerState<FinancialReportScreen> {
  bool _isExporting = false;
  final _moneyFormat = NumberFormat('#,##0', 'vi_VN');

  Future<void> _handleExportExcel(FinancialAgingReportModel report) async {
    setState(() => _isExporting = true);
    try {
      final currentPeriod = ref.read(financialReportFilterProvider).period;
      final filePath = await ExcelExportHelper.exportAgingReport(
        report: report,
        period: currentPeriod,
      );

      if (!mounted) return;
      final colorScheme = Theme.of(context).colorScheme;

      if (filePath != null) {
        AppSnackBar.showSuccess(
          context,
          'Đã xuất báo cáo thành công: ${filePath.split('/').last}',
          action: SnackBarAction(
            label: 'Chia sẻ',
            textColor: colorScheme.onPrimary,
            onPressed: () {
              ExcelExportHelper.shareFile(
                filePath,
                subject: 'Báo cáo Tuổi nợ và Tài chính',
                text: 'Báo cáo đối soát công nợ tòa nhà Vivona',
              );
            },
          ),
        );
      } else {
        AppSnackBar.showError(
          context,
          'Không thể tạo file Excel báo cáo. Vui lòng thử lại.',
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, formatErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _showReminderDialog(DebtorApartmentModel debtor, [String? buildingId]) {
    final overdueDays = debtor.maxDaysOverdue;
    final recommendedTier = overdueDays > 45
        ? DunningTier.tier3
        : (overdueDays > 15 ? DunningTier.tier2 : DunningTier.tier1);
    final riskScore = (overdueDays * 2).clamp(0, 100);

    showDialog<void>(
      context: context,
      builder: (ctx) => ExecuteDunningDialog(
        buildingId: buildingId ?? 'bld-default',
        apartmentId: debtor.apartmentId,
        apartmentCode: debtor.apartmentCode,
        ownerName: debtor.ownerName,
        unpaidAmount: debtor.totalDebt,
        overdueDays: overdueDays,
        riskScore: riskScore,
        initialTier: recommendedTier,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reportAsync = ref.watch(financialAgingReportProvider);
    final filter = ref.watch(financialReportFilterProvider);
    final debtors = ref.watch(filteredDebtorsProvider);

    return RoleGuard(
      permission: AppPermissions.financialReport,
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text(
              'Báo cáo Tài chính & Tuổi nợ',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            bottom: const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(
                  icon: Icon(Icons.analytics_outlined),
                  text: 'Tuổi nợ & Dòng tiền',
                ),
                Tab(
                  icon: Icon(Icons.radar_rounded),
                  text: 'Radar Rủi ro nợ AI',
                ),
              ],
            ),
            actions: [
              reportAsync.when(
                data: (report) => IconButton(
                  icon: _isExporting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.file_download_outlined),
                  tooltip: 'Xuất file Excel đối soát',
                  onPressed: _isExporting
                      ? null
                      : () => _handleExportExcel(report),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Làm mới dữ liệu',
                onPressed: () => ref.refresh(financialAgingReportProvider),
              ),
            ],
          ),
          body: TabBarView(
            children: [
              reportAsync.when(
                data: (report) => RefreshIndicator(
                  onRefresh: () async =>
                      ref.refresh(financialAgingReportProvider),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isDesktop = constraints.maxWidth >= 900;

                      return Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1400),
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: AppSpacing.p16,
                            children: [
                              // 1. Bộ lọc Kỳ thu
                              _buildFilterSection(filter),
                              AppSpacing.h16,

                              // 2. Thẻ KPI Dòng tiền & Tỷ lệ thu
                              _buildKpiSection(context, report.summary),
                              AppSpacing.h20,

                              if (isDesktop) ...[
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 5,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _buildAgingBucketsSection(
                                            context,
                                            report.agingBuckets,
                                            filter.bucketFilter,
                                          ),
                                          if (report
                                              .collectionByBlock
                                              .isNotEmpty) ...[
                                            AppSpacing.h20,
                                            _buildBlockCollectionSection(
                                              context,
                                              report.collectionByBlock,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    AppSpacing.w20,
                                    Expanded(
                                      flex: 7,
                                      child: _buildDebtorsSection(
                                        context,
                                        report.filterBuildingId ?? '',
                                        debtors,
                                        filter.bucketFilter,
                                      ),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                _buildAgingBucketsSection(
                                  context,
                                  report.agingBuckets,
                                  filter.bucketFilter,
                                ),
                                AppSpacing.h20,
                                if (report.collectionByBlock.isNotEmpty) ...[
                                  _buildBlockCollectionSection(
                                    context,
                                    report.collectionByBlock,
                                  ),
                                  AppSpacing.h20,
                                ],
                                _buildDebtorsSection(
                                  context,
                                  report.filterBuildingId ?? '',
                                  debtors,
                                  filter.bucketFilter,
                                ),
                              ],
                              AppSpacing.h32,
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                loading: () => ListView(
                  padding: AppSpacing.p16,
                  children: [
                    AppSkeletonShimmer.cardList(count: 4, itemHeight: 110),
                  ],
                ),
                error: (err, _) => Center(
                  child: Padding(
                    padding: AppSpacing.p24,
                    child: AppErrorCard(
                      error: err,
                      onRetry: () => ref.refresh(financialAgingReportProvider),
                    ),
                  ),
                ),
              ),
              DebtRiskRadarTab(
                buildingId: reportAsync.maybeWhen(
                  data: (r) => r.filterBuildingId ?? 'bld-default',
                  orElse: () => 'bld-default',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<String> _generateRecentPeriods({int count = 6}) {
    final now = DateTime.now();
    return List.generate(count, (i) {
      final date = DateTime(now.year, now.month - i, 1);
      return '${date.month}/${date.year}';
    });
  }

  Widget _buildFilterSection(FinancialReportFilter filter) {
    final colorScheme = Theme.of(context).colorScheme;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 320;
          final periods = _generateRecentPeriods();
          final dropdown = DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: filter.period,
              isExpanded: true,
              hint: const Text('Tất cả các kỳ'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Tất cả các kỳ'),
                ),
                for (final period in periods)
                  DropdownMenuItem<String?>(
                    value: period,
                    child: Text('Tháng $period'),
                  ),
              ],
              onChanged: (val) {
                ref
                    .read(financialReportFilterProvider.notifier)
                    .update((state) => state.copyWith(period: val));
              },
            ),
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.filter_alt_outlined,
                      color: colorScheme.primary,
                      size: 20,
                    ),
                    AppSpacing.w8,
                    const Expanded(
                      child: Text(
                        'Kỳ đối soát:',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                AppSpacing.h8,
                dropdown,
              ],
            );
          }

          return Row(
            children: [
              Icon(
                Icons.filter_alt_outlined,
                color: colorScheme.primary,
                size: 20,
              ),
              AppSpacing.w8,
              const Text(
                'Kỳ đối soát:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              AppSpacing.w12,
              Expanded(child: dropdown),
            ],
          );
        },
      ),
    );
  }

  Widget _buildKpiSection(
    BuildContext context,
    FinancialAgingSummaryModel summary,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final successColor = AppTheme.getSemanticSuccess(context);
    final warningColor = AppTheme.getSemanticWarning(context);
    final errorColor = AppTheme.getSemanticError(context);
    final secondaryColor = AppTheme.getSemanticSecondary(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TỔNG QUAN TÀI CHÍNH',
          style: context.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        AppSpacing.h12,
        LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 900;
            final isNarrow = constraints.maxWidth < 360;
            final crossAxisCount = isDesktop ? 4 : 2;
            final childAspectRatio = isDesktop
                ? 1.85
                : (isNarrow ? 1.15 : 1.45);

            return GridView.count(
              crossAxisCount: crossAxisCount,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: childAspectRatio,
              children: [
                _buildKpiCard(
                  context,
                  title: 'Tổng phát hành',
                  value: '${_moneyFormat.format(summary.totalBilled)} đ',
                  subtitle: '${summary.totalInvoiceCount} hóa đơn',
                  icon: Icons.receipt_long_outlined,
                  color: colorScheme.primary,
                ),
                _buildKpiCard(
                  context,
                  title: 'Đã thu thực tế',
                  value: '${_moneyFormat.format(summary.actualCollected)} đ',
                  subtitle: '${summary.paidInvoiceCount} hóa đơn',
                  icon: Icons.check_circle_outline,
                  color: successColor,
                ),
                _buildKpiCard(
                  context,
                  title: 'Công nợ tồn đọng',
                  value: '${_moneyFormat.format(summary.totalOutstanding)} đ',
                  subtitle: '${summary.unpaidInvoiceCount} hóa đơn',
                  icon: Icons.pending_actions_outlined,
                  color: errorColor,
                ),
                _buildKpiCard(
                  context,
                  title: 'Tỷ lệ thu hồi',
                  value: '${summary.collectionRate}%',
                  subtitle: 'Mục tiêu: >= 95%',
                  icon: Icons.pie_chart_outline,
                  color: summary.collectionRate >= 80
                      ? secondaryColor
                      : warningColor,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildKpiCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return AppCard(
      padding: AppSpacing.p12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: context.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, size: 18, color: color),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: context.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold, color: color)
                  .tabularFigures(),
            ),
          ),
          Text(
            subtitle,
            style: context.labelSmall
                ?.copyWith(color: colorScheme.onSurfaceVariant)
                .tabularFigures(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildAgingBucketsSection(
    BuildContext context,
    DebtAgingBucketModel buckets,
    String? activeBucket,
  ) {
    final totalDebt = buckets.totalDebt > 0 ? buckets.totalDebt : 1.0;
    final colorScheme = Theme.of(context).colorScheme;
    final successColor = AppTheme.getSemanticSuccess(context);
    final secondaryColor = AppTheme.getSemanticSecondary(context);
    final warningColor = AppTheme.getSemanticWarning(context);
    final errorColor = AppTheme.getSemanticError(context);

    return AppCard(
      padding: AppSpacing.p16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                'PHÂN LOẠI 4 XÔ TUỔI NỢ',
                style: context.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                'Tổng nợ: ${_moneyFormat.format(buckets.totalDebt)} đ',
                style: context.labelSmall
                    ?.copyWith(fontWeight: FontWeight.bold, color: errorColor)
                    .tabularFigures(),
              ),
            ],
          ),
          AppSpacing.h16,

          // Thanh phân bổ tỷ lệ phần trăm
          ClipRRect(
            borderRadius: AppRadius.r6,
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  Expanded(
                    flex: ((buckets.amount0To30 / totalDebt) * 100)
                        .round()
                        .clamp(1, 100),
                    child: Container(color: successColor),
                  ),
                  Expanded(
                    flex: ((buckets.amount31To60 / totalDebt) * 100)
                        .round()
                        .clamp(1, 100),
                    child: Container(color: secondaryColor),
                  ),
                  Expanded(
                    flex: ((buckets.amount61To90 / totalDebt) * 100)
                        .round()
                        .clamp(1, 100),
                    child: Container(color: warningColor),
                  ),
                  Expanded(
                    flex: ((buckets.amountOver90 / totalDebt) * 100)
                        .round()
                        .clamp(1, 100),
                    child: Container(color: errorColor),
                  ),
                ],
              ),
            ),
          ),
          AppSpacing.h16,

          _buildBucketRow(
            context,
            label: '0 - 30 ngày',
            description: 'Trong hạn / Mới phát sinh',
            amount: buckets.amount0To30,
            count: buckets.count0To30,
            color: successColor,
            bucketKey: '0_30',
            isSelected: activeBucket == '0_30',
          ),
          const Divider(height: 12),
          _buildBucketRow(
            context,
            label: '31 - 60 ngày',
            description: 'Quá hạn mức 1 (Cần đôn đốc)',
            amount: buckets.amount31To60,
            count: buckets.count31To60,
            color: secondaryColor,
            bucketKey: '31_60',
            isSelected: activeBucket == '31_60',
          ),
          const Divider(height: 12),
          _buildBucketRow(
            context,
            label: '61 - 90 ngày',
            description: 'Quá hạn mức 2 (Cảnh báo dịch vụ)',
            amount: buckets.amount61To90,
            count: buckets.count61To90,
            color: warningColor,
            bucketKey: '61_90',
            isSelected: activeBucket == '61_90',
          ),
          const Divider(height: 12),
          _buildBucketRow(
            context,
            label: '> 90 ngày',
            description: 'Nợ xấu / Khó đòi (Nghiêm trọng)',
            amount: buckets.amountOver90,
            count: buckets.countOver90,
            color: errorColor,
            bucketKey: 'over_90',
            isSelected: activeBucket == 'over_90',
          ),
        ],
      ),
    );
  }

  Widget _buildBucketRow(
    BuildContext context, {
    required String label,
    required String description,
    required double amount,
    required int count,
    required Color color,
    required String bucketKey,
    required bool isSelected,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: AppRadius.r8,
      onTap: () {
        ref
            .read(financialReportFilterProvider.notifier)
            .update(
              (state) =>
                  state.copyWith(bucketFilter: isSelected ? null : bucketKey),
            );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.08) : null,
          borderRadius: AppRadius.r8,
          border: isSelected ? Border.all(color: color, width: 1.5) : null,
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
            AppSpacing.w10,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: context.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? color : colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    description,
                    style: context.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            AppSpacing.w8,
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${_moneyFormat.format(amount)} đ',
                    style: context.bodySmall
                        ?.copyWith(fontWeight: FontWeight.bold, color: color)
                        .tabularFigures(),
                  ),
                ),
                Text(
                  '$count hóa đơn',
                  style: context.labelSmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant)
                      .tabularFigures(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockCollectionSection(
    BuildContext context,
    List<BlockCollectionRateModel> blocks,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final successColor = AppTheme.getSemanticSuccess(context);
    final warningColor = AppTheme.getSemanticWarning(context);

    return AppCard(
      padding: AppSpacing.p16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TỶ LỆ THU HỒI THEO BLOCK',
            style: context.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          AppSpacing.h12,
          for (final block in blocks)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 72,
                    child: Text(
                      'Block ${block.blockName}',
                      style: context.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: AppRadius.r4,
                      child: LinearProgressIndicator(
                        value: block.collectionRate / 100,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          block.collectionRate >= 80
                              ? successColor
                              : warningColor,
                        ),
                        minHeight: 8,
                      ),
                    ),
                  ),
                  AppSpacing.w12,
                  SizedBox(
                    width: 54,
                    child: Text(
                      '${block.collectionRate}%',
                      textAlign: TextAlign.end,
                      style: context.labelSmall
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: block.collectionRate >= 80
                                ? successColor
                                : warningColor,
                          )
                          .tabularFigures(),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDebtorsSection(
    BuildContext context,
    String buildingId,
    List<DebtorApartmentModel> debtors,
    String? activeBucket,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final errorColor = AppTheme.getSemanticError(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Text(
              'DANH SÁCH CĂN HỘ NỢ (${debtors.length})',
              style: context.labelMedium
                  ?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: colorScheme.onSurfaceVariant,
                  )
                  .tabularFigures(),
            ),
            if (activeBucket != null)
              TextButton(
                onPressed: () {
                  ref
                      .read(financialReportFilterProvider.notifier)
                      .update((state) => state.copyWith(bucketFilter: null));
                },
                child: const Text('Bỏ lọc xô'),
              ),
          ],
        ),
        AppSpacing.h12,
        if (debtors.isEmpty)
          const AppCard(
            padding: AppSpacing.p24,
            child: AppEmptyState(
              icon: Icons.check_circle_outline,
              title: 'Không có căn hộ nợ đọng',
              description: 'Không có căn hộ nào nợ đọng trong bộ lọc này',
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: debtors.length,
            separatorBuilder: (_, _) => AppSpacing.h12,
            itemBuilder: (ctx, index) {
              final debtor = debtors[index];
              final isOver90 = debtor.isSevereRisk;
              final badgeColor = isOver90 ? errorColor : colorScheme.primary;

              return AppCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.12),
                            borderRadius: AppRadius.r6,
                          ),
                          child: Text(
                            debtor.apartmentCode,
                            style: context.labelMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: badgeColor,
                                )
                                .tabularFigures(),
                          ),
                        ),
                        AppSpacing.w8,
                        Expanded(
                          flex: 3,
                          child: Text(
                            debtor.ownerName,
                            style: context.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        AppSpacing.w8,
                        Flexible(
                          flex: 2,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              '${_moneyFormat.format(debtor.totalDebt)} đ',
                              style: context.bodyMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: isOver90
                                        ? errorColor
                                        : colorScheme.onSurface,
                                  )
                                  .tabularFigures(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.h6,
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          'Quá hạn: ${debtor.maxDaysOverdue} ngày (${debtor.unpaidInvoicesCount} hóa đơn)',
                          style: context.labelSmall
                              ?.copyWith(
                                color: isOver90
                                    ? errorColor
                                    : colorScheme.onSurfaceVariant,
                                fontWeight: isOver90
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              )
                              .tabularFigures(),
                        ),
                        if (debtor.ownerPhone.isNotEmpty)
                          Text(
                            debtor.ownerPhone,
                            style: context.labelSmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant)
                                .tabularFigures(),
                          ),
                      ],
                    ),
                    AppSpacing.h12,
                    Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              minimumSize: const Size(0, 48),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ApartmentLedgerScreen(
                                    buildingId: buildingId,
                                    apartmentId: debtor.apartmentId,
                                    apartmentCode: debtor.apartmentCode,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.account_balance_wallet_outlined,
                              size: 16,
                            ),
                            label: Text('Sổ cái', style: context.labelSmall),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isOver90
                                  ? colorScheme.error
                                  : colorScheme.primary,
                              foregroundColor: isOver90
                                  ? colorScheme.onError
                                  : colorScheme.onPrimary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              minimumSize: const Size(0, 48),
                            ),
                            onPressed: () =>
                                _showReminderDialog(debtor, buildingId),
                            icon: const Icon(
                              Icons.notifications_active_outlined,
                              size: 16,
                            ),
                            label: Text('Nhắc nợ', style: context.labelSmall),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
