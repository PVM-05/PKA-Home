import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P0 Database Verification: Vehicles & Users Security', () {
    test('Migration file exists and defines vehicle columns and users protection trigger', () {
      final file = File('supabase/migrations/20261007_01_fix_p0_database_and_security.sql');
      expect(file.existsSync(), isTrue, reason: 'Migration file must exist');
      final content = file.readAsStringSync();
      
      // Vehicles schema checks
      expect(content.contains('license_plate'), isTrue);
      expect(content.contains('status'), isTrue);
      expect(content.contains('brand_model'), isTrue);
      expect(content.contains('user_id'), isTrue);
      expect(content.contains('UPDATE public.vehicles'), isTrue);
      
      // Users protection trigger checks
      expect(content.contains('trg_protect_user_sensitive_fields'), isTrue);
      expect(content.contains('is_locked'), isTrue);
      expect(content.contains('role'), isTrue);
    });
  });
}
