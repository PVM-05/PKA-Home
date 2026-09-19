import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/repositories/management_repository.dart';
import '../../../core/supabase_config.dart';

final managementRepositoryProvider = Provider((ref) => ManagementRepository());

final pendingIssuesCountProvider = StreamProvider<int>((ref) {
  return SupabaseConfig.client
      .from('issue_reports')
      .stream(primaryKey: ['id'])
      .map((list) => list.where((issue) => issue['status'] == 'pending').length);
});

final pendingLinkRequestsCountProvider = StreamProvider<int>((ref) {
  return SupabaseConfig.client
      .from('apartment_link_requests')
      .stream(primaryKey: ['id'])
      .map((list) => list.where((req) => req['status'] == 'pending').length);
});

final pendingConfirmationInvoicesProvider = StreamProvider<int>((ref) {
  return SupabaseConfig.client
      .from('invoices')
      .stream(primaryKey: ['id'])
      .map((list) => list.where((inv) => inv['status'] == 'pending_confirmation').length);
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

final emptyApartmentsProvider = Provider<AsyncValue<int>>((ref) {
  return ref.watch(apartmentsStreamProvider).whenData((apartments) {
    return apartments.where((a) => a['is_empty'] == true).length;
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

class MonthlyRevenueItem {
  final String period; // e.g. "09/2026"
  final String shortLabel; // e.g. "T9"
  final double paidAmount;
  final double unpaidAmount;

  MonthlyRevenueItem({
    required this.period,
    required this.shortLabel,
    required this.paidAmount,
    required this.unpaidAmount,
  });

  double get totalAmount => paidAmount + unpaidAmount;
  double get collectionRate => totalAmount > 0 ? (paidAmount / totalAmount) : 0.0;
}

final monthlyRevenueTrendProvider = StreamProvider<List<MonthlyRevenueItem>>((ref) {
  return SupabaseConfig.client
      .from('invoices')
      .stream(primaryKey: ['id'])
      .map((invoices) {
        final now = DateTime.now();
        final List<DateTime> months = [];
        for (int i = 5; i >= 0; i--) {
          int year = now.year;
          int month = now.month - i;
          while (month <= 0) {
            month += 12;
            year -= 1;
          }
          months.add(DateTime(year, month, 1));
        }

        final List<MonthlyRevenueItem> items = [];

        for (final m in months) {
          final mm = m.month.toString().padLeft(2, '0');
          final mSingle = m.month.toString();
          final yyyy = m.year.toString();
          final periodKey1 = '$mm/$yyyy';
          final periodKey2 = '$mSingle/$yyyy';
          final shortLabel = 'T${m.month}';

          double paid = 0.0;
          double unpaid = 0.0;

          for (final inv in invoices) {
            final invPeriod = (inv['period'] as String?)?.trim() ?? '';
            final amt = (inv['total_amount'] as num?)?.toDouble() ?? 0.0;
            final status = inv['status'];

            bool isMatch = invPeriod == periodKey1 || invPeriod == periodKey2;
            if (!isMatch && inv['created_at'] != null) {
              final created = DateTime.tryParse(inv['created_at'] as String);
              if (created != null && created.year == m.year && created.month == m.month) {
                isMatch = true;
              }
            }

            if (isMatch) {
              if (status == 'paid') {
                paid += amt;
              } else {
                unpaid += amt;
              }
            }
          }

          items.add(MonthlyRevenueItem(
            period: periodKey1,
            shortLabel: shortLabel,
            paidAmount: paid,
            unpaidAmount: unpaid,
          ));
        }

        return items;
      });
});
