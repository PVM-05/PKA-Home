import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P0 Database Verification: RBAC Helpers & Amenity RLS', () {
    test('Migration defines correct columns for role_delegations and amenity RLS', () {
      final file = File('supabase/migrations/20261007_01_fix_p0_database_and_security.sql');
      final content = file.readAsStringSync();
      
      // Check column references in is_staff_or_management
      expect(content.contains('rd.delegate_id = auth.uid()'), isTrue);
      expect(content.contains('rd.delegated_role IN'), isTrue);
      expect(content.contains('now() BETWEEN rd.starts_at AND rd.ends_at'), isTrue);
      expect(content.contains('delegate_user_id'), isFalse, reason: 'Must not reference non-existing column');
      
      // Check helper is_admin_or_accountant
      expect(content.contains('is_admin_or_accountant()'), isTrue);
      
      // Check amenity RLS cancellation restriction
      expect(content.contains('amenity_bookings_resident_cancel_only'), isTrue);
      expect(content.contains("status = 'cancelled'"), isTrue);
    });
  });
}
