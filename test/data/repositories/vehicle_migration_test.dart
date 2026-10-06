import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Vehicle Migration SQL Tests', () {
    test('Migration file 20261006_02_vehicle_rejection_reason_and_limit_fix.sql ton tai va dung cu phap', () {
      final file = File('supabase/migrations/20261006_02_vehicle_rejection_reason_and_limit_fix.sql');
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      expect(content, contains('ADD COLUMN IF NOT EXISTS rejection_reason TEXT'));
      expect(content, contains('check_vehicle_limits()'));
      expect(content, contains("NEW.vehicle_type = 'motorbike' AND NEW.status != 'rejected'"));
      expect(content, contains("status IN ('pending', 'approved')"));
      expect(content, contains('BEFORE INSERT OR UPDATE ON public.vehicles'));
    });
  });
}
