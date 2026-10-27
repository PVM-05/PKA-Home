import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Dynamic Fees and Maintenance Fund Migration Verification', () {
    final migrationFile = File(
      'supabase/migrations/20261027_02_dynamic_fees_and_maintenance_fund.sql',
    );

    test('migration file exists', () {
      expect(
        migrationFile.existsSync(),
        isTrue,
        reason: 'Migration file 20261027_02 must exist',
      );
    });

    test('seeds standard fee schedules', () {
      if (!migrationFile.existsSync()) return;
      final content = migrationFile.readAsStringSync();

      expect(content, contains('fee_schedules'));
      expect(content, contains("'electricity'"));
      expect(content, contains('3500'));
      expect(content, contains("'water'"));
      expect(content, contains('18000'));
      expect(content, contains("'management'"));
      expect(content, contains('16500'));
      expect(content, contains("'parking_motorcycle'"));
      expect(content, contains('100000'));
      expect(content, contains("'parking_car'"));
      expect(content, contains('1200000'));
    });

    test('creates maintenance_funds table with RLS and seed record', () {
      if (!migrationFile.existsSync()) return;
      final content = migrationFile.readAsStringSync();

      expect(content, contains('CREATE TABLE IF NOT EXISTS public.maintenance_funds'));
      expect(content, contains('total_balance'));
      expect(content, contains('annual_interest_earned'));
      expect(content, contains('interest_rate_percent'));
      expect(content, contains('collected_percent'));
      expect(content, contains('bank_name'));
      expect(content, contains('bank_account_number'));
      expect(content, contains('ALTER TABLE public.maintenance_funds ENABLE ROW LEVEL SECURITY;'));
      expect(content, contains('maintenance_funds_read'));
      expect(content, contains('INSERT INTO public.maintenance_funds'));
    });

    test('creates get_effective_fee_schedule helper function', () {
      if (!migrationFile.existsSync()) return;
      final content = migrationFile.readAsStringSync();

      expect(content, contains('CREATE OR REPLACE FUNCTION public.get_effective_fee_schedule'));
      expect(content, contains('p_fee_type TEXT'));
      expect(content, contains('RETURNS NUMERIC'));
    });
  });
}
