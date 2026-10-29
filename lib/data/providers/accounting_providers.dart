import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/accounting_period_model.dart';
import '../models/apartment_ledger_entry_model.dart';
import '../models/credit_note_model.dart';
import '../repositories/accounting_repository.dart';

final accountingRepositoryProvider = Provider<AccountingRepository>((ref) {
  return AccountingRepository();
});

final apartmentLedgerEntriesProvider =
    FutureProvider.family<List<ApartmentLedgerEntryModel>, String>((ref, apartmentId) async {
  final repo = ref.watch(accountingRepositoryProvider);
  return repo.fetchLedgerEntries(apartmentId: apartmentId);
});

final apartmentBalanceProvider =
    FutureProvider.family<double, String>((ref, apartmentId) async {
  final repo = ref.watch(accountingRepositoryProvider);
  return repo.fetchApartmentBalance(apartmentId);
});

final accountingPeriodsProvider =
    FutureProvider.family<List<AccountingPeriodModel>, String>((ref, buildingId) async {
  final repo = ref.watch(accountingRepositoryProvider);
  return repo.fetchAccountingPeriods(buildingId);
});

final creditNotesProvider =
    FutureProvider.family<List<CreditNoteModel>, String>((ref, buildingId) async {
  final repo = ref.watch(accountingRepositoryProvider);
  return repo.fetchCreditNotes(buildingId: buildingId);
});
