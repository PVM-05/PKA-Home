import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Database Migration: 20261107020000_digital_asset_handover_and_inspection.sql', () {
    late String migrationSql;

    setUpAll(() {
      final file = File('supabase/migrations/20261107020000_digital_asset_handover_and_inspection.sql');
      expect(file.existsSync(), isTrue, reason: 'Migration file 20261107_02 phải tồn tại.');
      migrationSql = file.readAsStringSync();
    });

    test('Chứa lệnh tạo bảng apartment_assets, apartment_handovers, handover_items', () {
      expect(migrationSql, contains('CREATE TABLE IF NOT EXISTS public.apartment_assets'));
      expect(migrationSql, contains('CREATE TABLE IF NOT EXISTS public.apartment_handovers'));
      expect(migrationSql, contains('CREATE TABLE IF NOT EXISTS public.handover_items'));
    });

    test('Chứa các cột nghiệp vụ trọng yếu của biên bản bàn giao và cấn trừ cọc', () {
      expect(migrationSql, contains('report_code'));
      expect(migrationSql, contains('handover_type'));
      expect(migrationSql, contains('initial_electricity_reading'));
      expect(migrationSql, contains('initial_water_reading'));
      expect(migrationSql, contains('deposit_held'));
      expect(migrationSql, contains('total_deduction'));
      expect(migrationSql, contains('deposit_refund'));
      expect(migrationSql, contains('staff_signature_url'));
      expect(migrationSql, contains('resident_signature_url'));
      expect(migrationSql, contains('lookup_code'));
      expect(migrationSql, contains('repair_cost'));
      expect(migrationSql, contains('photos'));
    });

    test('Chứa trigger sinh mã biên bản và trigger khóa bất biến khi confirmed', () {
      expect(migrationSql, contains('trg_generate_handover_report_code'));
      expect(migrationSql, contains('trg_enforce_handover_immutability'));
      expect(migrationSql, contains('HO-'));
    });

    test('Chứa cấu hình bucket handover-docs và RLS policies bảo mật', () {
      expect(migrationSql, contains('handover-docs'));
      expect(migrationSql, contains('storage.buckets'));
      expect(migrationSql, contains('ENABLE ROW LEVEL SECURITY'));
    });
  });
}

