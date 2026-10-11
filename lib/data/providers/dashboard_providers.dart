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
  // Thống nhất với financialStatsProvider: tính tất cả hóa đơn còn phải thu (unpaid + pending_confirmation)
  return ref.watch(financialStatsProvider).whenData((stats) => stats.unpaidTotal + stats.pendingConfirmationTotal);
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
  final double pendingConfirmationTotal;
  final double cancelledTotal;
  final int paidCount;
  final int unpaidCount;
  final int pendingConfirmationCount;
  final int cancelledCount;

  FinancialStats({
    required this.paidTotal,
    required this.unpaidTotal,
    this.pendingConfirmationTotal = 0.0,
    this.cancelledTotal = 0.0,
    required this.paidCount,
    required this.unpaidCount,
    this.pendingConfirmationCount = 0,
    this.cancelledCount = 0,
  });

  /// Tổng tiền phát hành hợp lệ cần thu (loại trừ đã hủy)
  double get totalBilled => paidTotal + unpaidTotal + pendingConfirmationTotal;

  /// Doanh thu thực tế đã thu
  double get actualRevenue => paidTotal;

  /// Giữ tương thích ngược với getter cũ
  double get totalRevenue => totalBilled;

  /// Tỷ lệ thu tiền thực tế
  double get collectionRate => totalBilled > 0 ? (paidTotal / totalBilled) : 0.0;
}

final financialStatsProvider = StreamProvider<FinancialStats>((ref) {
  return ref.watch(rawInvoicesStream).map((invoices) {
    // Đếm số căn hộ duy nhất đã đóng / chưa đóng trong kỳ hiện tại
    final now = DateTime.now();
    final curMm = now.month.toString().padLeft(2, '0');
    final curPeriod = '$curMm/${now.year}';
    final curSinglePeriod = '${now.month}/${now.year}';

    var currentInvoices = invoices.where((inv) {
      final p = (inv['period'] as String?)?.trim();
      return p == curPeriod || p == curSinglePeriod;
    }).toList();

    // Nếu kỳ hiện tại chưa lập hóa đơn, lấy kỳ gần nhất có dữ liệu theo ngày tháng
    if (currentInvoices.isEmpty && invoices.isNotEmpty) {
      String? latestPeriod;
      DateTime? latestDate;
      for (final inv in invoices) {
        final p = (inv['period'] as String?)?.trim();
        if (p == null || !p.contains('/')) continue;
        final parts = p.split('/');
        if (parts.length == 2) {
          final m = int.tryParse(parts[0]);
          final y = int.tryParse(parts[1]);
          if (m != null && y != null) {
            final dt = DateTime(y, m);
            if (latestDate == null || dt.isAfter(latestDate)) {
              latestDate = dt;
              latestPeriod = p;
            }
          }
        }
      }
      if (latestPeriod != null) {
        currentInvoices = invoices.where((inv) => (inv['period'] as String?)?.trim() == latestPeriod).toList();
      } else {
        currentInvoices = invoices;
      }
    }

    double paid = 0.0;
    double unpaid = 0.0;
    double pendingConfirmation = 0.0;
    double cancelled = 0.0;

    final paidApartments = <String>{};
    final unpaidApartments = <String>{};
    final pendingConfirmationApartments = <String>{};
    final cancelledApartments = <String>{};

    for (var inv in currentInvoices) {
      final amt = (inv['total_amount'] as num?)?.toDouble() ?? 0.0;
      final aptId = inv['apartment_id'] as String? ?? inv['id'] as String;
      final status = (inv['status'] as String?)?.toLowerCase();

      if (status == 'paid') {
        paid += amt;
        paidApartments.add(aptId);
      } else if (status == 'pending_confirmation') {
        pendingConfirmation += amt;
        pendingConfirmationApartments.add(aptId);
      } else if (status == 'cancelled' || status == 'void') {
        cancelled += amt;
        cancelledApartments.add(aptId);
      } else if (status == 'unpaid' || status == 'overdue') {
        unpaid += amt;
        unpaidApartments.add(aptId);
      }
    }

    return FinancialStats(
      paidTotal: paid,
      unpaidTotal: unpaid,
      pendingConfirmationTotal: pendingConfirmation,
      cancelledTotal: cancelled,
      paidCount: paidApartments.length,
      unpaidCount: unpaidApartments.length,
      pendingConfirmationCount: pendingConfirmationApartments.length,
      cancelledCount: cancelledApartments.length,
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
        // Chỉ fallback sang created_at nếu invPeriod rỗng (không xác định được chu kỳ)
        if (!isMatch && invPeriod.isEmpty && inv['created_at'] != null) {
          final created = DateTime.tryParse(inv['created_at'] as String);
          if (created != null && created.year == m.year && created.month == m.month) {
            isMatch = true;
          }
        }

        if (isMatch) {
          final s = status?.toString().toLowerCase();
          if (s == 'paid') {
            paid += amt;
          } else if (s == 'unpaid' || s == 'overdue' || s == 'pending_confirmation') {
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
