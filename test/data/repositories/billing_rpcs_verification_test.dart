import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P0 Database Verification: Billing & Meter RPCs', () {
    test('RPCs do not insert subtotal and use correct status and delta calculations', () {
      final file = File('supabase/migrations/20261007_01_fix_p0_database_and_security.sql');
      final content = file.readAsStringSync();
      
      // Ensure no insertion into generated subtotal column in invoice_items
      final subtotalInserts = RegExp(r'INSERT\s+INTO\s+public\.invoice_items[^\)]*subtotal', caseSensitive: false);
      expect(subtotalInserts.hasMatch(content), isFalse, reason: 'invoice_items.subtotal is GENERATED ALWAYS and must not be inserted');
      
      // Ensure invoice status 'unpaid' instead of 'pending'
      expect(content.contains("'pending', now(), now()"), isFalse, reason: 'invoices.status pending is invalid enum');
      expect(content.contains("'unpaid', now(), now()"), isTrue);
      
      // Ensure old RPC is dropped
      expect(content.contains('DROP FUNCTION IF EXISTS public.generate_monthly_bulk_invoices'), isTrue);
      
      // Ensure parking fee only inserted if v_parking_fee > 0
      expect(content.contains('IF v_parking_fee > 0 THEN'), isTrue);
      
      // Ensure role checking in RPCs
      expect(content.contains('is_admin_or_accountant()'), isTrue);
    });
  });
}
