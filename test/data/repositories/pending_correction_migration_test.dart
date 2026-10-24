import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Task 1: Kiểm tra tính hợp lệ của Migration 20261024_04', () {
    final migrationFile = File('supabase/migrations/20261024_04_pending_requests_correction_and_reschedule.sql');

    test('File migration 20261024_04 phải tồn tại', () {
      expect(migrationFile.existsSync(), isTrue, reason: 'Chưa tạo file migration 20261024_04');
    });

    test('Migration phải định nghĩa đầy đủ 6 RPCs nguyên tử', () {
      if (!migrationFile.existsSync()) return;
      final content = migrationFile.readAsStringSync();

      expect(content.contains('cancel_pending_vehicle'), isTrue);
      expect(content.contains('update_pending_vehicle'), isTrue);
      expect(content.contains('reschedule_amenity_booking'), isTrue);
      expect(content.contains('update_pending_meter_reading'), isTrue);
      expect(content.contains('cancel_pending_meter_reading'), isTrue);
      expect(content.contains('cancel_apartment_link_request'), isTrue);
    });

    test('reschedule_amenity_booking phải có cơ chế sắp xếp advisory lock chống Deadlock', () {
      if (!migrationFile.existsSync()) return;
      final content = migrationFile.readAsStringSync();

      expect(content.contains('pg_advisory_xact_lock'), isTrue);
      expect(content.contains('LEAST(') && content.contains('GREATEST('), isTrue,
          reason: 'Bắt buộc phải sắp xếp hash lock bằng LEAST/GREATEST để chống Deadlock');
    });

    test('update_pending_vehicle phải khóa advisory theo căn hộ và kiểm tra hạn mức 2 xe máy', () {
      if (!migrationFile.existsSync()) return;
      final content = migrationFile.readAsStringSync();

      expect(content.contains('vehicle_limit_'), isTrue);
      expect(content.contains('Mỗi căn hộ chỉ được đăng ký tối đa 2 xe máy'), isTrue);
    });

    test('cancel_pending_vehicle phải kiểm tra quyền sở hữu nghiêm ngặt', () {
      if (!migrationFile.existsSync()) return;
      final content = migrationFile.readAsStringSync();

      expect(content.contains('user_id = v_user_id') || content.contains('registered_by = v_user_id'), isTrue);
      expect(content.contains('public.is_staff()'), isTrue);
    });

    test('apartment_link_requests phải chuyển sang VARCHAR và dùng Partial Unique Index', () {
      if (!migrationFile.existsSync()) return;
      final content = migrationFile.readAsStringSync();

      expect(content.contains('uq_link_requests_active'), isTrue);
      expect(content.contains('WHERE status IN (\'pending\', \'approved\')'), isTrue);
    });
  });
}
