import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Meter Reading Submissions Migration Tests', () {
    const migrationPath = 'supabase/migrations/20261005_05_meter_reading_submissions.sql';

    test('Tập tin migration 20261005_05_meter_reading_submissions.sql phải tồn tại', () {
      final file = File(migrationPath);
      expect(file.existsSync(), isTrue, reason: 'Tập tin migration phải được tạo');
    });

    test('Migration phải định nghĩa bảng meter_reading_submissions và các hàm RPC duyệt', () {
      final file = File(migrationPath);
      final content = file.readAsStringSync();

      // 1. Bảng meter_reading_submissions
      expect(content.contains('CREATE TABLE IF NOT EXISTS public.meter_reading_submissions'), isTrue);
      expect(content.contains('apartment_id'), isTrue);
      expect(content.contains('submitted_by'), isTrue);
      expect(content.contains('electric_reading'), isTrue);
      expect(content.contains('water_reading'), isTrue);
      expect(content.contains('electric_image_url'), isTrue);
      expect(content.contains('water_image_url'), isTrue);
      expect(content.contains('status'), isTrue);

      // 2. RPC approve_meter_reading
      expect(content.contains('approve_meter_reading'), isTrue);
      expect(content.contains('p_submission_id'), isTrue);
      expect(content.contains('p_generate_invoice'), isTrue);

      // 3. RPC reject_meter_reading
      expect(content.contains('reject_meter_reading'), isTrue);
      expect(content.contains('p_reason'), isTrue);
    });
  });
}
