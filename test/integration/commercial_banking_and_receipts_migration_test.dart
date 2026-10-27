import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Commercial Banking and Receipts Migration Verification Tests', () {
    final migrationFile = File(
      'supabase/migrations/20261027_04_commercial_banking_and_receipts.sql',
    );

    test('migration file exists', () {
      expect(
        migrationFile.existsSync(),
        isTrue,
        reason: 'Migration file 20261027_04 must exist',
      );
    });

    test('adds banking columns to buildings table', () {
      if (!migrationFile.existsSync()) return;
      final content = migrationFile.readAsStringSync();

      expect(content, contains('bank_bin'));
      expect(content, contains('bank_name'));
      expect(content, contains('bank_account_number'));
      expect(content, contains('bank_account_name'));
      expect(content, contains('buildings'));
    });

    test('adds receipt and lookup code columns to invoices and transactions', () {
      if (!migrationFile.existsSync()) return;
      final content = migrationFile.readAsStringSync();

      expect(content, contains('receipt_number'));
      expect(content, contains('einvoice_lookup_code'));
      expect(content, contains('paid_amount'));
      expect(content, contains('invoices'));
      expect(content, contains('payment_transactions'));
    });

    test('defines generate_receipt_number function', () {
      if (!migrationFile.existsSync()) return;
      final content = migrationFile.readAsStringSync();

      expect(content, contains('CREATE OR REPLACE FUNCTION public.generate_receipt_number'));
      expect(content, contains('PT-'));
    });
  });
}
