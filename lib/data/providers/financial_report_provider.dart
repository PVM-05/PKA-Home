import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/financial_aging_report_model.dart';
import 'accounting_providers.dart';

/// Bộ lọc cho Báo cáo tài chính & Tuổi nợ
class FinancialReportFilter {
  final String? period;
  final String? buildingId;
  final String? bucketFilter; // null hoặc 'all', '0_30', '31_60', '61_90', 'over_90'

  const FinancialReportFilter({
    this.period,
    this.buildingId,
    this.bucketFilter,
  });

  FinancialReportFilter copyWith({
    String? period,
    String? buildingId,
    String? bucketFilter,
  }) {
    return FinancialReportFilter(
      period: period ?? this.period,
      buildingId: buildingId ?? this.buildingId,
      bucketFilter: bucketFilter ?? this.bucketFilter,
    );
  }
}

final financialReportFilterProvider = StateProvider<FinancialReportFilter>((ref) {
  return const FinancialReportFilter();
});

/// Provider tải báo cáo tài chính từ repository
final financialAgingReportProvider = FutureProvider<FinancialAgingReportModel>((ref) async {
  final repo = ref.watch(accountingRepositoryProvider);
  final filter = ref.watch(financialReportFilterProvider);

  return repo.fetchAgingReport(
    buildingId: filter.buildingId,
    period: filter.period,
  );
});

/// Provider lọc danh sách căn hộ nợ đọng theo xô nợ được chọn
final filteredDebtorsProvider = Provider<List<DebtorApartmentModel>>((ref) {
  final reportAsync = ref.watch(financialAgingReportProvider);
  final filter = ref.watch(financialReportFilterProvider);

  return reportAsync.when(
    data: (report) {
      final bucket = filter.bucketFilter;
      if (bucket == null || bucket.isEmpty || bucket == 'all') {
        return report.debtors;
      }
      return report.debtors.where((d) => d.riskLevel == bucket).toList();
    },
    loading: () => [],
    error: (_, _) => [],
  );
});

