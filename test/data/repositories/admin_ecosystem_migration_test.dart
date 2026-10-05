import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Admin Ecosystem Migration Tests', () {
    const migrationPath = 'supabase/migrations/20261005_04_admin_management_ecosystem.sql';

    test('Tập tin migration 20261005_04_admin_management_ecosystem.sql phải tồn tại', () {
      final file = File(migrationPath);
      expect(file.existsSync(), isTrue, reason: 'Tập tin migration phải được tạo');
    });

    test('Migration phải định nghĩa bảng vehicles, users.is_locked và RPC generate_monthly_bulk_invoices', () {
      final file = File(migrationPath);
      final content = file.readAsStringSync();

      // 1. users.is_locked
      expect(content.contains('is_locked'), isTrue);

      // 2. bảng vehicles
      expect(content.contains('CREATE TABLE IF NOT EXISTS public.vehicles'), isTrue);
      expect(content.contains('license_plate'), isTrue);
      expect(content.contains('vehicle_type'), isTrue);

      // 3. RPC generate_monthly_bulk_invoices
      expect(content.contains('generate_monthly_bulk_invoices'), isTrue);
      expect(content.contains('p_period'), isTrue);

      // 4. RPC check_in_amenity_booking
      expect(content.contains('check_in_amenity_booking'), isTrue);
    });
  });
}
