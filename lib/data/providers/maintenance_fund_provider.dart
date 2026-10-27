import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/maintenance_fund_model.dart';
import '../models/maintenance_fund_transaction_model.dart';
import '../repositories/maintenance_fund_repository.dart';
import 'building_provider.dart';

final maintenanceFundRepositoryProvider = Provider<MaintenanceFundRepository>((ref) {
  return MaintenanceFundRepository();
});

final activeMaintenanceFundProvider = FutureProvider<MaintenanceFundModel?>((ref) async {
  final repo = ref.watch(maintenanceFundRepositoryProvider);
  final activeBuilding = ref.watch(activeBuildingProvider).valueOrNull;
  return repo.fetchFundByBuilding(activeBuilding?.id);
});

// Giữ lại maintenanceFundProvider để tương thích ngược 100%
final maintenanceFundProvider = FutureProvider<MaintenanceFundModel?>((ref) async {
  return ref.watch(activeMaintenanceFundProvider.future);
});

final maintenanceFundLedgerFilterProvider = StateProvider<String>((ref) => 'ALL');

final maintenanceFundLedgerProvider =
    FutureProvider<List<MaintenanceFundTransactionModel>>((ref) async {
  final repo = ref.watch(maintenanceFundRepositoryProvider);
  final activeBuilding = ref.watch(activeBuildingProvider).valueOrNull;
  final filter = ref.watch(maintenanceFundLedgerFilterProvider);

  return repo.fetchTransactions(
    buildingId: activeBuilding?.id,
    transactionType: filter,
  );
});
