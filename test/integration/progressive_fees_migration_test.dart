import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Progressive Fees and Pro-rata Engine Migration Tests (20261029_04)', () {
    const migrationPath =
        'supabase/migrations/20261029_04_progressive_fees_and_prorata_engine.sql';

    test('Migration file 20261029_04_progressive_fees_and_prorata_engine.sql must exist', () {
      final file = File(migrationPath);
      expect(file.existsSync(), isTrue, reason: 'Migration file must exist');
    });

    test('Migration defines fee_tier_policies table with schema and constraints', () {
      final file = File(migrationPath);
      if (!file.existsSync()) {
        fail('File does not exist');
      }
      final content = file.readAsStringSync();

      expect(content, contains('CREATE TABLE IF NOT EXISTS public.fee_tier_policies'));
      expect(content, contains('building_id UUID NULL REFERENCES public.buildings(id)'));
      expect(content, contains('policy_type VARCHAR(30) NOT NULL'));
      expect(content, contains("'ELECTRICITY_TIER'"));
      expect(content, contains("'WATER_QUOTA_TIER'"));
      expect(content, contains("'PARKING_PRORATA'"));
      expect(content, contains("'LATE_PAYMENT_PENALTY'"));
      expect(content, contains('calculation_method VARCHAR(30) NOT NULL'));
      expect(content, contains("'PROGRESSIVE_TIER'"));
      expect(content, contains("'PER_CAPITA_QUOTA'"));
      expect(content, contains("'PRO_RATA_DAILY'"));
      expect(content, contains("'PERCENTAGE_DAILY'"));
      expect(content, contains('tiers JSONB NOT NULL'));
      expect(content, contains('effective_from DATE NOT NULL DEFAULT CURRENT_DATE'));
      expect(content, contains('is_active BOOLEAN NOT NULL DEFAULT true'));
      expect(content, contains('ALTER TABLE public.fee_tier_policies ENABLE ROW LEVEL SECURITY;'));
    });

    test('Migration defines RLS policies for fee_tier_policies', () {
      final file = File(migrationPath);
      if (!file.existsSync()) {
        fail('File does not exist');
      }
      final content = file.readAsStringSync();

      expect(content, contains('ftp_read_policy'));
      expect(content, contains('FOR SELECT TO authenticated USING (true)'));
      expect(content, contains('ftp_manage_policy'));
      expect(content, contains("'admin'"));
      expect(content, contains("'manager'"));
      expect(content, contains("'accountant'"));
    });

    test('Migration seeds default EVN 6-tier electricity, water quota, and penalty policies', () {
      final file = File(migrationPath);
      if (!file.existsSync()) {
        fail('File does not exist');
      }
      final content = file.readAsStringSync();

      expect(content, contains("'ELECTRICITY_TIER'"));
      expect(content, contains('Điện sinh hoạt EVN 6 bậc'));
      expect(content, contains('1893'));
      expect(content, contains('1956'));
      expect(content, contains('2271'));
      expect(content, contains('2860'));
      expect(content, contains('3197'));
      expect(content, contains('3302'));

      expect(content, contains("'WATER_QUOTA_TIER'"));
      expect(content, contains('Nước sinh hoạt định mức 4m3/người'));
      expect(content, contains('quota_per_resident'));
      expect(content, contains('8500'));
      expect(content, contains('12000'));
      expect(content, contains('18000'));

      expect(content, contains("'LATE_PAYMENT_PENALTY'"));
      expect(content, contains('Lãi phạt trễ hạn 0.05%/ngày'));
      expect(content, contains('grace_period_days'));
      expect(content, contains('0.0005'));
    });

    test('Migration defines calculate_progressive_electricity_fee RPC', () {
      final file = File(migrationPath);
      if (!file.existsSync()) {
        fail('File does not exist');
      }
      final content = file.readAsStringSync();

      expect(content, contains('CREATE OR REPLACE FUNCTION public.calculate_progressive_electricity_fee'));
      expect(content, contains('p_consumption NUMERIC'));
      expect(content, contains('p_building_id UUID DEFAULT NULL'));
      expect(content, contains('RETURNS JSONB'));
      expect(content, contains('GRANT EXECUTE ON FUNCTION public.calculate_progressive_electricity_fee'));
    });

    test('Migration defines calculate_quota_water_fee RPC', () {
      final file = File(migrationPath);
      if (!file.existsSync()) {
        fail('File does not exist');
      }
      final content = file.readAsStringSync();

      expect(content, contains('CREATE OR REPLACE FUNCTION public.calculate_quota_water_fee'));
      expect(content, contains('p_consumption NUMERIC'));
      expect(content, contains('p_resident_count INT DEFAULT 1'));
      expect(content, contains('p_building_id UUID DEFAULT NULL'));
      expect(content, contains('RETURNS JSONB'));
      expect(content, contains('GRANT EXECUTE ON FUNCTION public.calculate_quota_water_fee'));
    });

    test('Migration defines calculate_prorated_vehicle_fee RPC', () {
      final file = File(migrationPath);
      if (!file.existsSync()) {
        fail('File does not exist');
      }
      final content = file.readAsStringSync();

      expect(content, contains('CREATE OR REPLACE FUNCTION public.calculate_prorated_vehicle_fee'));
      expect(content, contains('p_monthly_rate NUMERIC'));
      expect(content, contains('p_start_date DATE'));
      expect(content, contains('p_period VARCHAR(7)'));
      expect(content, contains('RETURNS JSONB'));
      expect(content, contains('GRANT EXECUTE ON FUNCTION public.calculate_prorated_vehicle_fee'));
    });

    test('Migration defines calculate_late_payment_penalty RPC', () {
      final file = File(migrationPath);
      if (!file.existsSync()) {
        fail('File does not exist');
      }
      final content = file.readAsStringSync();

      expect(content, contains('CREATE OR REPLACE FUNCTION public.calculate_late_payment_penalty'));
      expect(content, contains('p_invoice_id UUID'));
      expect(content, contains('p_as_of_date DATE DEFAULT CURRENT_DATE'));
      expect(content, contains('RETURNS JSONB'));
      expect(content, contains('GRANT EXECUTE ON FUNCTION public.calculate_late_payment_penalty'));
    });
  });
}
