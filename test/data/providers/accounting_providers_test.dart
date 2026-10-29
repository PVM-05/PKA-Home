import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/apartment_ledger_entry_model.dart';
import 'package:pka_home/data/providers/accounting_providers.dart';
import 'package:pka_home/data/repositories/accounting_repository.dart';

class FakeAccountingRepository extends AccountingRepository {
  @override
  Future<double> fetchApartmentBalance(String apartmentId) async {
    return 1250000.0;
  }

  @override
  Future<List<ApartmentLedgerEntryModel>> fetchLedgerEntries({
    required String apartmentId,
    String? period,
  }) async {
    return [
      ApartmentLedgerEntryModel(
        id: 'ale-1',
        buildingId: 'bld-1',
        apartmentId: apartmentId,
        entryCode: 'LE-202610-00001',
        entryType: 'DEBIT',
        amount: 1250000.0,
        balanceAfter: 1250000.0,
        period: '2026-10',
        referenceType: 'INVOICE',
        description: 'Phát hành hóa đơn',
        createdAt: DateTime(2026, 10, 29),
      ),
    ];
  }
}

void main() {
  group('Accounting Providers Tests', () {
    test('accountingRepositoryProvider defaults to AccountingRepository instance', () {
      final container = ProviderContainer();
      final repo = container.read(accountingRepositoryProvider);
      expect(repo, isA<AccountingRepository>());
    });

    test('apartmentBalanceProvider reads balance from repository correctly', () async {
      final container = ProviderContainer(
        overrides: [
          accountingRepositoryProvider.overrideWithValue(FakeAccountingRepository()),
        ],
      );

      final balanceAsync = await container.read(apartmentBalanceProvider('apt-test').future);
      expect(balanceAsync, 1250000.0);
    });

    test('apartmentLedgerEntriesProvider reads ledger entries correctly', () async {
      final container = ProviderContainer(
        overrides: [
          accountingRepositoryProvider.overrideWithValue(FakeAccountingRepository()),
        ],
      );

      final entries = await container.read(apartmentLedgerEntriesProvider('apt-test').future);
      expect(entries.length, 1);
      expect(entries.first.entryCode, 'LE-202610-00001');
      expect(entries.first.amount, 1250000.0);
    });
  });
}
