import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Maintenance Fund Ledger Migration Tests', () {
    final migrationFile =
        File('supabase/migrations/20261027_05_maintenance_fund_ledger.sql');

    test('Migration file exists and contains necessary DDL & RPC', () {
      expect(migrationFile.existsSync(), isTrue);
      final sql = migrationFile.readAsStringSync();

      expect(sql.contains('ALTER TABLE public.maintenance_funds'), isTrue);
      expect(sql.contains('CREATE TABLE IF NOT EXISTS public.maintenance_fund_transactions'), isTrue);
      expect(sql.contains('voucher_number VARCHAR(30)'), isTrue);
      expect(sql.contains('balance_after NUMERIC(15,2)'), isTrue);
      expect(sql.contains('CREATE OR REPLACE FUNCTION public.record_maintenance_fund_transaction'), isTrue);
      expect(sql.contains('FOR UPDATE'), isTrue);
      expect(sql.contains('PT-'), isTrue);
      expect(sql.contains('PC-'), isTrue);
    });
  });
}
