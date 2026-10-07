import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P0 Database Verification: Notification Triggers', () {
    test('Triggers use valid column names and enum values', () {
      final file = File('supabase/migrations/20261007_01_fix_p0_database_and_security.sql');
      final content = file.readAsStringSync();
      
      // Issue trigger checks
      expect(content.contains('NEW.title'), isFalse, reason: 'issue_reports does not have title column');
      expect(content.contains("NEW.priority = 'urgent'"), isFalse, reason: 'Enum only has low/medium/high');
      expect(content.contains("NEW.priority = 'high'"), isTrue);
      expect(content.contains('trg_notify_on_issue_event'), isTrue);
      
      // Amenity cancellation notification check
      expect(content.contains('notifications (user_id, title, content, type)'), isFalse, reason: 'Must use body instead of content');
      expect(content.contains('handle_amenity_booking_cancellation'), isTrue);
      
      // Equipment maintenance check
      expect(content.contains('a.building = v_building'), isFalse, reason: 'apartments table has building_code');
      expect(content.contains('a.building_code = v_building'), isTrue);
    });
  });
}
