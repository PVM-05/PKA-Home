import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Parking Management & Capacity Migration Tests (20261102_01)', () {
    const migrationPath = 'supabase/migrations/20261102_01_parking_slots_and_visitor_tickets.sql';

    test('Migration file exists and is not empty', () {
      final file = File(migrationPath);
      expect(file.existsSync(), isTrue, reason: 'Migration file must exist at $migrationPath');
      final content = file.readAsStringSync().trim();
      expect(content.isNotEmpty, isTrue, reason: 'Migration file must not be empty');
    });

    test('Migration defines parking_slots table with required columns and constraints', () {
      final content = File(migrationPath).readAsStringSync();
      expect(content.contains('CREATE TABLE IF NOT EXISTS public.parking_slots'), isTrue);
      expect(content.contains('building_id'), isTrue);
      expect(content.contains('zone'), isTrue);
      expect(content.contains('slot_number'), isTrue);
      expect(content.contains('slot_type'), isTrue);
      expect(content.contains('status'), isTrue);
      expect(content.contains('assigned_vehicle_id'), isTrue);
      expect(content.contains('assigned_apartment_id'), isTrue);
    });

    test('Migration defines visitor_parking_tickets table with required columns', () {
      final content = File(migrationPath).readAsStringSync();
      expect(content.contains('CREATE TABLE IF NOT EXISTS public.visitor_parking_tickets'), isTrue);
      expect(content.contains('ticket_code'), isTrue);
      expect(content.contains('license_plate'), isTrue);
      expect(content.contains('vehicle_type'), isTrue);
      expect(content.contains('check_in_at'), isTrue);
      expect(content.contains('check_out_at'), isTrue);
      expect(content.contains('fee_amount'), isTrue);
      expect(content.contains('payment_status'), isTrue);
      expect(content.contains('qr_payload'), isTrue);
    });

    test('Migration alters vehicles table with parking slot references', () {
      final content = File(migrationPath).readAsStringSync();
      expect(content.contains('ALTER TABLE public.vehicles'), isTrue);
      expect(content.contains('parking_slot_id'), isTrue);
      expect(content.contains('parking_slot_number'), isTrue);
    });

    test('Migration defines required RPCs for capacity stats and visitor parking engine', () {
      final content = File(migrationPath).readAsStringSync();
      expect(content.contains('get_parking_capacity_stats'), isTrue);
      expect(content.contains('calculate_visitor_parking_fee'), isTrue);
      expect(content.contains('checkout_visitor_ticket'), isTrue);
    });
  });
}
