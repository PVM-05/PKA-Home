import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/accounting_period_model.dart';
import 'package:pka_home/data/models/apartment_ledger_entry_model.dart';
import 'package:pka_home/data/models/credit_note_model.dart';
import 'package:pka_home/data/repositories/accounting_repository.dart';

void main() {
  group('AccountingRepository Unit Tests', () {
    test('AccountingRepository can be instantiated', () {
      final repo = AccountingRepository();
      expect(repo, isNotNull);
    });

    test('Helper method parseLedgerEntries parses valid List of maps', () {
      final repo = AccountingRepository();
      final list = [
        {
          'id': 'ale-1',
          'building_id': 'bld-1',
          'apartment_id': 'apt-1',
          'entry_code': 'LE-202610-00001',
          'entry_type': 'DEBIT',
          'amount': 1000000,
          'balance_after': 1000000,
          'period': '2026-10',
          'reference_type': 'INVOICE',
          'description': 'Tiền điện',
        },
      ];

      final entries = repo.parseLedgerEntries(list);
      expect(entries.length, 1);
      expect(entries.first, isA<ApartmentLedgerEntryModel>());
      expect(entries.first.amount, 1000000.0);
    });

    test('Helper method parseCreditNotes parses valid List of maps', () {
      final repo = AccountingRepository();
      final list = [
        {
          'id': 'cn-1',
          'credit_note_code': 'CN-202610-00001',
          'building_id': 'bld-1',
          'apartment_id': 'apt-1',
          'note_type': 'CREDIT',
          'amount': 50000,
          'reason': 'Giảm trừ',
          'status': 'APPROVED',
        },
      ];

      final notes = repo.parseCreditNotes(list);
      expect(notes.length, 1);
      expect(notes.first, isA<CreditNoteModel>());
      expect(notes.first.amount, 50000.0);
    });

    test('Helper method parseAccountingPeriods parses valid List of maps', () {
      final repo = AccountingRepository();
      final list = [
        {
          'id': 'ap-1',
          'building_id': 'bld-1',
          'period': '2026-10',
          'status': 'OPEN',
        },
      ];

      final periods = repo.parseAccountingPeriods(list);
      expect(periods.length, 1);
      expect(periods.first, isA<AccountingPeriodModel>());
      expect(periods.first.period, '2026-10');
    });
  });
}
