import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/repositories/management_repository.dart';

final managementRepositoryProvider = Provider((ref) => ManagementRepository());

final pendingIssuesCountProvider = StreamProvider<int>((ref) {
  final repo = ref.watch(managementRepositoryProvider);
  return repo.watchPendingIssues().map((issues) => issues.length);
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
