import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Multi-Tenancy Migration Verification Tests', () {
    final migrationFile = File(
      'supabase/migrations/20261027_03_multi_tenancy_organizations_and_buildings.sql',
    );

    test('migration file exists', () {
      expect(
        migrationFile.existsSync(),
        isTrue,
        reason: 'Migration file 20261027_03 must exist',
      );
    });

    test('creates organizations, buildings and building_staff tables', () {
      if (!migrationFile.existsSync()) return;
      final content = migrationFile.readAsStringSync();

      expect(content, contains('CREATE TABLE IF NOT EXISTS public.organizations'));
      expect(content, contains('CREATE TABLE IF NOT EXISTS public.buildings'));
      expect(content, contains('CREATE TABLE IF NOT EXISTS public.building_staff'));
    });

    test('seeds canonical default organization and building', () {
      if (!migrationFile.existsSync()) return;
      final content = migrationFile.readAsStringSync();

      expect(content, contains('00000000-0000-0000-0000-000000000001'));
      expect(content, contains('00000000-0000-0000-0000-000000000002'));
      expect(content, contains('pka-corp'));
      expect(content, contains('PKAL'));
    });

    test('adds building_id column and backfills existing tables', () {
      if (!migrationFile.existsSync()) return;
      final content = migrationFile.readAsStringSync();

      expect(content, contains('building_id UUID'));
      expect(content, contains('apartments'));
      expect(content, contains('announcements'));
      expect(content, contains('building_amenities'));
      expect(content, contains('fee_schedules'));
      expect(content, contains('maintenance_funds'));
    });

    test('updates apartments uniqueness constraint to (building_id, code)', () {
      if (!migrationFile.existsSync()) return;
      final content = migrationFile.readAsStringSync();

      expect(content, contains('UNIQUE (building_id, code)'));
    });
  });
}
