import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P0 Database Verification: Payment Concurrency & Timezone', () {
    test('simulate_unified_payment has FOR UPDATE and timezone is Asia/Ho_Chi_Minh', () {
      final file = File('supabase/migrations/20261007_01_fix_p0_database_and_security.sql');
      final content = file.readAsStringSync();
      
      // Concurrency checks
      expect(content.contains('FOR UPDATE;'), isTrue, reason: 'Row locking required to prevent double payment');
      
      // Timezone checks
      expect(content.contains("AT TIME ZONE 'Asia/Ho_Chi_Minh'"), isTrue);
      
      // Check in permission
      expect(content.contains('check_in_amenity_booking'), isTrue);
      
      // Revoke execution from public/anon
      expect(content.contains('REVOKE ALL ON FUNCTION public.approve_meter_reading FROM anon, PUBLIC;'), isTrue);
      expect(content.contains('REVOKE ALL ON FUNCTION public.generate_valid_bulk_invoices FROM anon, PUBLIC;'), isTrue);
    });
  });
}
