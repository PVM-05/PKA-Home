import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/repositories/management_repository.dart';
import '../../../core/supabase_config.dart';

final managementRepositoryProvider = Provider((ref) => ManagementRepository());

final pendingIssuesCountProvider = StreamProvider<int>((ref) {
  return SupabaseConfig.client.from('issue_reports').stream(primaryKey: ['id']).eq('status', 'pending').map((list) => list.length);
});

final pendingLinkRequestsCountProvider = StreamProvider<int>((ref) {
  return SupabaseConfig.client.from('apartment_link_requests').stream(primaryKey: ['id']).eq('status', 'pending').map((list) => list.length);
});


final pendingConfirmationInvoicesProvider = StreamProvider<int>((ref) {
  return SupabaseConfig.client.from('invoices').stream(primaryKey: ['id']).eq('status', 'pending_confirmation').map((list) => list.length);
});

final unpaidInvoicesTotalProvider = Provider<AsyncValue<double>>((ref) {
  // Thống nhất với financialStatsProvider: tính tất cả hóa đơn chưa thanh toán (unpaid + pending_confirmation)
  return ref.watch(financialStatsProvider).whenData((stats) => stats.unpaidTotal);
});

final apartmentsStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return SupabaseConfig.client
      .from('apartments')
      .stream(primaryKey: ['id']);
});

final totalApartmentsProvider = Provider<AsyncValue<int>>((ref) {
  return ref.watch(apartmentsStreamProvider).whenData((list) => list.length);
});

final totalResidentsProvider = StreamProvider<int>((ref) {
  return SupabaseConfig.client
      .from('users')
      .stream(primaryKey: ['id'])
      .eq('role', 'resident')
      .map((list) => list.length);
});

final occupancyRateProvider = Provider<AsyncValue<double>>((ref) {
  return ref.watch(apartmentsStreamProvider).whenData((apartments) {
    if (apartments.isEmpty) return 0.0;
    final occupied = apartments.where((a) => a['is_empty'] == false).length;
    return occupied / apartments.length;
  });
});

class FinancialStats {
  final double paidTotal;
  final double unpaidTotal;
  final int paidCount;
  final int unpaidCount;

  FinancialStats({
    required this.paidTotal,
    required this.unpaidTotal,
    required this.paidCount,
    required this.unpaidCount,
  });

  double get totalRevenue => paidTotal + unpaidTotal;
  double get collectionRate => totalRevenue > 0 ? (paidTotal / totalRevenue) : 0.0;
}

final financialStatsProvider = StreamProvider<FinancialStats>((ref) {
  return SupabaseConfig.client
      .from('invoices')
      .stream(primaryKey: ['id'])
      .map((invoices) {
        double paid = 0.0;
        double unpaid = 0.0;
        int paidCnt = 0;
        int unpaidCnt = 0;

        for (var inv in invoices) {
          final amt = (inv['total_amount'] as num?)?.toDouble() ?? 0.0;
          final status = inv['status'];
          if (status == 'paid') {
            paid += amt;
            paidCnt++;
          } else {
            unpaid += amt;
            unpaidCnt++;
          }
        }
        return FinancialStats(
          paidTotal: paid,
          unpaidTotal: unpaid,
          paidCount: paidCnt,
          unpaidCount: unpaidCnt,
        );
      });
});
