import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase_config.dart';

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

/// Shared Realtime Stream duy nhất cho bảng invoices, giảm tải kết nối WebSocket
final rawInvoicesStream = Provider<Stream<List<Map<String, dynamic>>>>((ref) {
  return SupabaseConfig.client
      .from('invoices')
      .stream(primaryKey: ['id'])
      .asBroadcastStream();
});

final rawInvoicesStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(rawInvoicesStream);
});

final pendingConfirmationInvoicesProvider = StreamProvider<int>((ref) {
  return ref.watch(rawInvoicesStream).map(
    (list) => list.where((inv) => inv['status'] == 'pending_confirmation').length,
  );
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
  return ref.watch(rawInvoicesStream).map((invoices) {
    double paid = 0.0;
    double unpaid = 0.0;

    for (var inv in invoices) {
      final amt = (inv['total_amount'] as num?)?.toDouble() ?? 0.0;
      final status = inv['status'];
      if (status == 'paid') {
        paid += amt;
      } else {
        unpaid += amt;
      }
    }

    // Đếm số căn hộ duy nhất đã đóng / chưa đóng trong kỳ hiện tại
    final now = DateTime.now();
    final curMm = now.month.toString().padLeft(2, '0');
    final curPeriod = '$curMm/${now.year}';
    final curSinglePeriod = '${now.month}/${now.year}';

    var currentInvoices = invoices.where((inv) {
      final p = (inv['period'] as String?)?.trim();
      return p == curPeriod || p == curSinglePeriod;
    }).toList();

    // Nếu kỳ hiện tại chưa lập hóa đơn, lấy kỳ gần nhất có dữ liệu
    if (currentInvoices.isEmpty && invoices.isNotEmpty) {
      final latestPeriod = invoices.first['period'];
      currentInvoices = invoices.where((inv) => inv['period'] == latestPeriod).toList();
    }

    final paidApartments = <String>{};
    final unpaidApartments = <String>{};

    for (var inv in currentInvoices) {
      final aptId = inv['apartment_id'] as String? ?? inv['id'] as String;
      if (inv['status'] == 'paid') {
        paidApartments.add(aptId);
      } else {
        unpaidApartments.add(aptId);
      }
    }

    return FinancialStats(
      paidTotal: paid,
      unpaidTotal: unpaid,
      paidCount: paidApartments.length,
      unpaidCount: unpaidApartments.length,
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
  return ref.watch(rawInvoicesStream).map((invoices) {
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
