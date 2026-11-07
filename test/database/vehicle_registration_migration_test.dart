import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Database Migration: 20261107_01_vehicle_registration_and_slot_allocation.sql', () {
    late String migrationSql;

    setUpAll(() {
      final file = File('supabase/migrations/20261107_01_vehicle_registration_and_slot_allocation.sql');
      expect(file.existsSync(), isTrue, reason: 'Migration file 20261107_01 phải tồn tại.');
      migrationSql = file.readAsStringSync();
    });

    test('Chứa lệnh thêm các cột registration_image_url, approved_at, approved_by vào vehicles', () {
      expect(migrationSql, contains('ALTER TABLE public.vehicles'));
      expect(migrationSql, contains('registration_image_url'));
      expect(migrationSql, contains('approved_at'));
      expect(migrationSql, contains('approved_by'));
    });

    test('Chứa khai báo tạo bucket vehicle-docs trong storage.buckets', () {
      expect(migrationSql, contains('vehicle-docs'));
      expect(migrationSql, contains('storage.buckets'));
    });

    test('Chứa chính sách bảo mật RLS cho bucket vehicle-docs', () {
      expect(migrationSql, contains('storage.objects'));
    });
  });
}
