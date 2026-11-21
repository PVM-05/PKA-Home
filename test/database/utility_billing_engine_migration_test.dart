import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Database Migration: 20261108030000_utility_billing_engine.sql', () {
    late String sqlContent;
    final migrationFile = File('supabase/migrations/20261108030000_utility_billing_engine.sql');

    setUpAll(() {
      expect(
        migrationFile.existsSync(),
        isTrue,
        reason: 'Tệp migration 20261108030000_utility_billing_engine.sql phải tồn tại',
      );
      sqlContent = migrationFile.readAsStringSync();
    });

    test('Chứa định nghĩa bảng building_utility_rates với đầy đủ ràng buộc', () {
      expect(sqlContent, contains('CREATE TABLE IF NOT EXISTS public.building_utility_rates'));
      expect(sqlContent, contains('utility_type'));
      expect(sqlContent, contains('pricing_model'));
      expect(sqlContent, contains('base_unit_price'));
      expect(sqlContent, contains('vat_percentage'));
      expect(sqlContent, contains('environment_fee_percentage'));
      expect(sqlContent, contains('tiers'));
      expect(sqlContent, contains('is_active'));
    });

    test('Mở rộng bảng meter_reading_submissions với các trường tiêu thụ và invoice_id', () {
      expect(sqlContent, contains('ALTER TABLE public.meter_reading_submissions'));
      expect(sqlContent, contains('previous_electric_reading'));
      expect(sqlContent, contains('previous_water_reading'));
      expect(sqlContent, contains('electric_consumed'));
      expect(sqlContent, contains('water_consumed'));
      expect(sqlContent, contains('invoice_id'));
    });

    test('Chứa RPC approve_meter_reading nâng cấp nhận p_generate_invoice và p_due_date', () {
      expect(sqlContent, contains('CREATE OR REPLACE FUNCTION public.approve_meter_reading'));
      expect(sqlContent, contains('p_submission_id UUID'));
      expect(sqlContent, contains('p_generate_invoice BOOLEAN DEFAULT true'));
      expect(sqlContent, contains('p_due_date DATE DEFAULT NULL'));
      expect(sqlContent, contains('invoices'));
      expect(sqlContent, contains('invoice_items'));
    });

    test('Chứa RPC batch_record_meter_readings cho phép chốt số theo tầng hàng loạt', () {
      expect(sqlContent, contains('CREATE OR REPLACE FUNCTION public.batch_record_meter_readings'));
      expect(sqlContent, contains('p_period TEXT'));
      expect(sqlContent, contains('p_readings JSONB'));
      expect(sqlContent, contains('GRANT EXECUTE ON FUNCTION public.batch_record_meter_readings'));
    });
  });
}
