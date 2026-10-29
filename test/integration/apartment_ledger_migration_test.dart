import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Apartment Ledger and Credit Notes Migration Tests (20261029_03)', () {
    const migrationPath =
        'supabase/migrations/20261029_03_apartment_ledger_and_credit_notes.sql';

    test('Migration file 20261029_03_apartment_ledger_and_credit_notes.sql must exist', () {
      final file = File(migrationPath);
      expect(file.existsSync(), isTrue, reason: 'Migration file must exist');
    });

    test('Migration defines accounting_periods table with constraints', () {
      final file = File(migrationPath);
      if (!file.existsSync()) return;
      final content = file.readAsStringSync();

      expect(content, contains('CREATE TABLE IF NOT EXISTS public.accounting_periods'));
      expect(content, contains('building_id UUID NOT NULL REFERENCES public.buildings(id)'));
      expect(content, contains('period VARCHAR(7) NOT NULL'));
      expect(content, contains("status VARCHAR(20) NOT NULL DEFAULT 'OPEN'"));
      expect(content, contains('UNIQUE(building_id, period)'));
      expect(content, contains('ALTER TABLE public.accounting_periods ENABLE ROW LEVEL SECURITY;'));
    });

    test('Migration defines apartment_ledger_entries table with balance_after', () {
      final file = File(migrationPath);
      if (!file.existsSync()) return;
      final content = file.readAsStringSync();

      expect(content, contains('CREATE TABLE IF NOT EXISTS public.apartment_ledger_entries'));
      expect(content, contains('entry_code VARCHAR(30) UNIQUE NOT NULL'));
      expect(content, contains('entry_type VARCHAR(20) NOT NULL'));
      expect(content, contains('amount NUMERIC(15,2) NOT NULL CHECK (amount > 0)'));
      expect(content, contains('balance_after NUMERIC(15,2) NOT NULL'));
      expect(content, contains('reference_type VARCHAR(30) NOT NULL'));
      expect(content, contains('ALTER TABLE public.apartment_ledger_entries ENABLE ROW LEVEL SECURITY;'));
    });

    test('Migration defines credit_notes table', () {
      final file = File(migrationPath);
      if (!file.existsSync()) return;
      final content = file.readAsStringSync();

      expect(content, contains('CREATE TABLE IF NOT EXISTS public.credit_notes'));
      expect(content, contains('credit_note_code VARCHAR(30) UNIQUE NOT NULL'));
      expect(content, contains('note_type VARCHAR(20) NOT NULL'));
      expect(content, contains('amount NUMERIC(15,2) NOT NULL CHECK (amount > 0)'));
      expect(content, contains('reason TEXT NOT NULL'));
      expect(content, contains('ALTER TABLE public.credit_notes ENABLE ROW LEVEL SECURITY;'));
    });

    test('Migration defines invoice immutability trigger & period mutation guard', () {
      final file = File(migrationPath);
      if (!file.existsSync()) return;
      final content = file.readAsStringSync();

      expect(content, contains('fn_enforce_invoice_immutability'));
      expect(content, contains('trg_enforce_invoice_immutability'));
      expect(content, contains('fn_prevent_closed_period_mutation'));
      expect(content, contains('trg_prevent_closed_period_mutation'));
      expect(content, contains('fn_auto_post_ledger_on_invoice_paid'));
      expect(content, contains('trg_auto_post_ledger_on_invoice_paid'));
    });

    test('Migration defines RPCs for ledger operations and period close', () {
      final file = File(migrationPath);
      if (!file.existsSync()) return;
      final content = file.readAsStringSync();

      expect(content, contains('CREATE OR REPLACE FUNCTION public.record_apartment_ledger_entry'));
      expect(content, contains('CREATE OR REPLACE FUNCTION public.issue_credit_note'));
      expect(content, contains('CREATE OR REPLACE FUNCTION public.close_accounting_period'));
      expect(content, contains('CREATE OR REPLACE FUNCTION public.get_apartment_ledger_balance'));
    });
  });
}
