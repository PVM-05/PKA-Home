import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Baseline Schema Migration Verification Tests (20261027_01)', () {
    late String baselineContent;

    setUpAll(() {
      final file = File('supabase/migrations/20261027_01_baseline_schema.sql');
      expect(file.existsSync(), isTrue, reason: 'Baseline migration file must exist');
      baselineContent = file.readAsStringSync();
    });

    test('Baseline migration includes essential extensions and enums', () {
      expect(baselineContent, contains('CREATE EXTENSION IF NOT EXISTS "uuid-ossp";'));
      expect(baselineContent, contains('CREATE EXTENSION IF NOT EXISTS "pgcrypto";'));
      expect(baselineContent, contains('CREATE TYPE public.user_role AS ENUM'));
      expect(baselineContent, contains('CREATE TYPE public.invoice_status AS ENUM'));
      expect(baselineContent, contains('CREATE TYPE public.amenity_booking_status AS ENUM'));
    });

    test('Baseline migration defines dynamic fee schedules and tariffs', () {
      expect(baselineContent, contains('CREATE TABLE IF NOT EXISTS public.fee_schedules'));
      expect(baselineContent, contains('CREATE TABLE IF NOT EXISTS public.tiered_tariffs'));
    });

    test('Baseline migration defines canonical RPCs with advisory locking', () {
      expect(baselineContent, contains('CREATE OR REPLACE FUNCTION public.simulate_unified_payment('));
      expect(baselineContent, contains('CREATE OR REPLACE FUNCTION public.reschedule_amenity_booking('));
      expect(baselineContent, contains('CREATE OR REPLACE FUNCTION public.book_amenity_slot('));
      expect(baselineContent, contains('CREATE OR REPLACE FUNCTION public.confirm_payment('));
      expect(baselineContent, contains('CREATE OR REPLACE FUNCTION public.record_manual_amenity_payment('));
      expect(baselineContent, contains('PERFORM pg_advisory_xact_lock('));
    });

    test('reschedule_amenity_booking uses correct column start_time and start_time/end_time comparison', () {
      expect(baselineContent, contains('start_time <= v_day_end'));
      expect(baselineContent, contains('end_time >= v_day_start'));
      expect(baselineContent, isNot(contains('AND p_new_date BETWEEN start_date AND end_date')));
    });

    test('Baseline enables RLS on core tables', () {
      expect(baselineContent, contains('ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;'));
      expect(baselineContent, contains('ALTER TABLE public.apartments ENABLE ROW LEVEL SECURITY;'));
      expect(baselineContent, contains('ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;'));
      expect(baselineContent, contains('ALTER TABLE public.amenity_bookings ENABLE ROW LEVEL SECURITY;'));
    });
  });
}
