import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/repositories/management_repository.dart';
import '../../../core/supabase_config.dart';

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

final totalApartmentsProvider = StreamProvider<int>((ref) {
  return SupabaseConfig.client.from('apartments').stream(primaryKey: ['id']).map((list) => list.length);
});

final totalResidentsProvider = StreamProvider<int>((ref) {
  return SupabaseConfig.client.from('users').stream(primaryKey: ['id']).eq('role', 'resident').map((list) => list.length);
});
