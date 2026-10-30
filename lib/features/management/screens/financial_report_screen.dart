import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/excel_export_helper.dart';
import '../../../core/widgets/app_card.dart';
import '../../../data/models/financial_aging_report_model.dart';
import '../../../data/providers/financial_report_provider.dart';
import 'apartment_ledger_screen.dart';

class FinancialReportScreen extends ConsumerStatefulWidget {
  const FinancialReportScreen({super.key});

  @override
  ConsumerState<FinancialReportScreen> createState() => _FinancialReportScreenState();
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

      if (filePath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã xuất báo cáo thành công: ${filePath.split('/').last}'),
            backgroundColor: AppTheme.success,
            action: SnackBarAction(
              label: 'Chia sẻ',
              textColor: Colors.white,
              onPressed: () {
                ExcelExportHelper.shareFile(
                  filePath,
                  subject: 'Báo cáo Tuổi nợ và Tài chính',
                  text: 'Báo cáo đối soát công nợ tòa nhà PKA-Home',
                );
              },
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể tạo file Excel báo cáo. Vui lòng thử lại.'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi xuất file: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _showReminderDialog(DebtorApartmentModel debtor) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gửi Nhắc Nợ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Xác nhận gửi thông báo nhắc nợ đến căn hộ ${debtor.apartmentCode} (${debtor.ownerName})?',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tổng tiền nợ: ${_moneyFormat.format(debtor.totalDebt)} đ',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.error),
                  ),
                  const SizedBox(height: 4),
                  Text('Số ngày quá hạn: ${debtor.maxDaysOverdue} ngày'),
                  Text('Số hóa đơn chưa đóng: ${debtor.unpaidInvoicesCount} hóa đơn'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Đã gửi thông báo đôn đốc công nợ tới căn hộ ${debtor.apartmentCode} thành công!'),
                  backgroundColor: AppTheme.success,
                ),
              );
            },
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text('Xác nhận gửi'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reportAsync = ref.watch(financialAgingReportProvider);
    final filter = ref.watch(financialReportFilterProvider);
    final debtors = ref.watch(filteredDebtorsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Báo cáo Tài chính & Tuổi nợ',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          reportAsync.when(
            data: (report) => IconButton(
              icon: _isExporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.file_download_outlined),
              tooltip: 'Xuất file Excel đối soát',
              onPressed: _isExporting ? null : () => _handleExportExcel(report),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Làm mới dữ liệu',
            onPressed: () => ref.refresh(financialAgingReportProvider),
          ),
        ],
      ),
      body: reportAsync.when(
        data: (report) => RefreshIndicator(
          onRefresh: () async => ref.refresh(financialAgingReportProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 1. Bộ lọc Kỳ thu
              _buildFilterSection(filter),
              const SizedBox(height: 16),

              // 2. Thẻ KPI Dòng tiền & Tỷ lệ thu
              _buildKpiSection(report.summary),
              const SizedBox(height: 20),

              // 3. Phân tích 4 xô tuổi nợ (Aging Buckets)
              _buildAgingBucketsSection(report.agingBuckets, filter.bucketFilter),
              const SizedBox(height: 20),

              // 4. Thống kê theo Block
              if (report.collectionByBlock.isNotEmpty) ...[
                _buildBlockCollectionSection(report.collectionByBlock),
                const SizedBox(height: 20),
              ],

              // 5. Danh sách căn hộ nợ đọng
              _buildDebtorsSection(report.filterBuildingId ?? '', debtors, filter.bucketFilter),
              const SizedBox(height: 32),
            ],
          ),
        ),
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Đang tổng hợp báo cáo tài chính...'),
            ],
          ),
        ),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
                const SizedBox(height: 16),
                Text(
                  'Không thể tải báo cáo: $err',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => ref.refresh(financialAgingReportProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSection(FinancialReportFilter filter) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.filter_alt_outlined, color: AppTheme.primary, size: 20),
          const SizedBox(width: 8),
          const Text('Kỳ đối soát:', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: filter.period,
                isExpanded: true,
                hint: const Text('Tất cả các kỳ'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Tất cả các kỳ'),
                  ),
                  // Các kỳ mẫu thông dụng
                  for (final m in [10, 9, 8, 7, 6])
                    DropdownMenuItem<String?>(
                      value: '$m/2026',
                      child: Text('Tháng $m/2026'),
                    ),
                ],
                onChanged: (val) {
                  ref.read(financialReportFilterProvider.notifier).update(
                        (state) => state.copyWith(period: val),
                      );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiSection(FinancialAgingSummaryModel summary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'TỔNG QUAN TÀI CHÍNH',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.45,
          children: [
            _buildKpiCard(
              title: 'Tổng phát hành',
              value: '${_moneyFormat.format(summary.totalBilled)} đ',
              subtitle: '${summary.totalInvoiceCount} hóa đơn',
              icon: Icons.receipt_long_outlined,
              color: AppTheme.primary,
            ),
            _buildKpiCard(
              title: 'Đã thu thực tế',
              value: '${_moneyFormat.format(summary.actualCollected)} đ',
              subtitle: '${summary.paidInvoiceCount} hóa đơn',
              icon: Icons.check_circle_outline,
              color: AppTheme.success,
            ),
            _buildKpiCard(
              title: 'Công nợ tồn đọng',
              value: '${_moneyFormat.format(summary.totalOutstanding)} đ',
              subtitle: '${summary.unpaidInvoiceCount} hóa đơn',
              icon: Icons.pending_actions_outlined,
              color: AppTheme.error,
            ),
            _buildKpiCard(
              title: 'Tỷ lệ thu hồi',
              value: '${summary.collectionRate}%',
              subtitle: 'Mục tiêu: >= 95%',
              icon: Icons.pie_chart_outline,
              color: summary.collectionRate >= 80 ? Colors.teal : Colors.orange,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              Icon(icon, size: 18, color: color),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildAgingBucketsSection(DebtAgingBucketModel buckets, String? activeBucket) {
    final totalDebt = buckets.totalDebt > 0 ? buckets.totalDebt : 1.0;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'PHÂN LOẠI 4 XÔ TUỔI NỢ',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: AppTheme.textSecondary,
                ),
              ),
              Text(
                'Tổng nợ: ${_moneyFormat.format(buckets.totalDebt)} đ',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.error),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Thanh phân bổ tỷ lệ phần trăm
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  Expanded(
                    flex: ((buckets.amount0To30 / totalDebt) * 100).round().clamp(1, 100),
                    child: Container(color: Colors.green),
                  ),
                  Expanded(
                    flex: ((buckets.amount31To60 / totalDebt) * 100).round().clamp(1, 100),
                    child: Container(color: Colors.amber),
                  ),
                  Expanded(
                    flex: ((buckets.amount61To90 / totalDebt) * 100).round().clamp(1, 100),
                    child: Container(color: Colors.orange),
                  ),
                  Expanded(
                    flex: ((buckets.amountOver90 / totalDebt) * 100).round().clamp(1, 100),
                    child: Container(color: Colors.red),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 4 Thẻ xô nợ bấm chọn được
          _buildBucketRow(
            label: '0 - 30 ngày',
            description: 'Trong hạn / Mới phát sinh',
            amount: buckets.amount0To30,
            count: buckets.count0To30,
            color: Colors.green,
            bucketKey: '0_30',
            isSelected: activeBucket == '0_30',
          ),
          const Divider(height: 12),
          _buildBucketRow(
            label: '31 - 60 ngày',
            description: 'Quá hạn mức 1 (Cần đôn đốc)',
            amount: buckets.amount31To60,
            count: buckets.count31To60,
            color: Colors.amber.shade700,
            bucketKey: '31_60',
            isSelected: activeBucket == '31_60',
          ),
          const Divider(height: 12),
          _buildBucketRow(
            label: '61 - 90 ngày',
            description: 'Quá hạn mức 2 (Cảnh báo dịch vụ)',
            amount: buckets.amount61To90,
            count: buckets.count61To90,
            color: Colors.orange.shade800,
            bucketKey: '61_90',
            isSelected: activeBucket == '61_90',
          ),
          const Divider(height: 12),
          _buildBucketRow(
            label: '> 90 ngày',
            description: 'Nợ xấu / Khó đòi (Nghiêm trọng)',
            amount: buckets.amountOver90,
            count: buckets.countOver90,
            color: Colors.red.shade700,
            bucketKey: 'over_90',
            isSelected: activeBucket == 'over_90',
          ),
        ],
      ),
    );
  }

  Widget _buildBucketRow({
    required String label,
    required String description,
    required double amount,
    required int count,
    required Color color,
    required String bucketKey,
    required bool isSelected,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        ref.read(financialReportFilterProvider.notifier).update(
              (state) => state.copyWith(bucketFilter: isSelected ? null : bucketKey),
            );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: color, width: 1.5) : null,
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isSelected ? color : AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${_moneyFormat.format(amount)} đ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: color,
                  ),
                ),
                Text(
                  '$count hóa đơn',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockCollectionSection(List<BlockCollectionRateModel> blocks) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TỶ LỆ THU HỒI THEO BLOCK',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          for (final block in blocks) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 70,
                    child: Text(
                      'Block ${block.blockName}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: block.collectionRate / 100,
                        backgroundColor: AppTheme.surface,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          block.collectionRate >= 80 ? AppTheme.success : AppTheme.warning,
                        ),
                        minHeight: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 50,
                    child: Text(
                      '${block.collectionRate}%',
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: block.collectionRate >= 80 ? AppTheme.success : AppTheme.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDebtorsSection(String buildingId, List<DebtorApartmentModel> debtors, String? activeBucket) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'DANH SÁCH CĂN HỘ NỢ (${debtors.length})',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: AppTheme.textSecondary,
              ),
            ),
            if (activeBucket != null)
              TextButton(
                onPressed: () {
                  ref.read(financialReportFilterProvider.notifier).update(
                        (state) => state.copyWith(bucketFilter: null),
                      );
                },
                child: const Text('Bỏ lọc xô'),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (debtors.isEmpty)
          const AppCard(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.check_circle_outline, size: 40, color: AppTheme.success),
                  SizedBox(height: 8),
                  Text('Không có căn hộ nào nợ đọng trong bộ lọc này'),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: debtors.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (ctx, index) {
              final debtor = debtors[index];
              final isOver90 = debtor.isSevereRisk;

              return AppCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isOver90 ? AppTheme.error.withOpacity(0.12) : AppTheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                debtor.apartmentCode,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isOver90 ? AppTheme.error : AppTheme.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              debtor.ownerName,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                          ],
                        ),
                        Text(
                          '${_moneyFormat.format(debtor.totalDebt)} đ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isOver90 ? AppTheme.error : AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Quá hạn: ${debtor.maxDaysOverdue} ngày (${debtor.unpaidInvoicesCount} hóa đơn)',
                          style: TextStyle(
                            fontSize: 12,
                            color: isOver90 ? AppTheme.error : AppTheme.textSecondary,
                            fontWeight: isOver90 ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                        if (debtor.ownerPhone.isNotEmpty)
                          Text(
                            debtor.ownerPhone,
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            minimumSize: Size.zero,
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
                          icon: const Icon(Icons.account_balance_wallet_outlined, size: 14),
                          label: const Text('Sổ cái', style: TextStyle(fontSize: 12)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isOver90 ? AppTheme.error : AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            minimumSize: Size.zero,
                          ),
                          onPressed: () => _showReminderDialog(debtor),
                          icon: const Icon(Icons.notifications_active_outlined, size: 14),
                          label: const Text('Nhắc nợ', style: TextStyle(fontSize: 12)),
                        ),
                      ],
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

