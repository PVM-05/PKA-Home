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

final unpaidInvoicesTotalProvider = StreamProvider<double>((ref) {
  final repo = ref.watch(managementRepositoryProvider);
  return repo.watchUnpaidInvoices().map((invoices) {
    return invoices.fold(0.0, (sum, item) {
      final amount = item['total_amount'];
      if (amount is int) return sum + amount.toDouble();
      if (amount is double) return sum + amount;
      return sum;
    });
  });
});


final totalApartmentsProvider = StreamProvider<int>((ref) {
  return SupabaseConfig.client
      .from('apartments')
      .stream(primaryKey: ['id'])
      .map((list) => list.length);
});

final totalResidentsProvider = StreamProvider<int>((ref) {
  return SupabaseConfig.client
      .from('users')
      .stream(primaryKey: ['id'])
      .eq('role', 'resident')
      .map((list) => list.length);
});

final occupancyRateProvider = FutureProvider<double>((ref) async {
  final repo = ref.watch(managementRepositoryProvider);
  final apartments = await repo.fetchApartments();
  if (apartments.isEmpty) return 0.0;
  final occupied = apartments.where((a) => !a.isEmpty).length;
  return occupied / apartments.length;
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
