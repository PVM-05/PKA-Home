import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Amenity Booking RPC & Concurrency Lock Tests (20261026_03)', () {
    late String migrationContent;

    setUpAll(() {
      final file = File('supabase/migrations_archive/20261026_03_core_audit_locking_and_amenity_payment.sql');
      expect(file.existsSync(), isTrue, reason: 'Migration 20261026_03 phải tồn tại');
      migrationContent = file.readAsStringSync();
    });

    test('book_amenity_slot sử dụng pg_advisory_xact_lock bảo vệ đồng thời', () {
      expect(migrationContent, contains('PERFORM pg_advisory_xact_lock('));
    });

    test('book_amenity_slot KHÔNG chứa FOR UPDATE trên câu lệnh aggregate (COUNT / SUM)', () {
      // PostgreSQL báo lỗi "ERROR: 0A000: FOR UPDATE is not allowed with aggregate functions"
      // nếu gắn FOR UPDATE vào SELECT COUNT(*) hoặc SELECT SUM(*)
      // Kiểm tra trong phạm vi câu lệnh (trước dấu chấm phẩy ;)
      final countRegex = RegExp(r'SELECT\s+COUNT\(\*\)\s+INTO\s+v_current_occupancy[^;]*?FOR\s+UPDATE', caseSensitive: false);
      final sumRegex = RegExp(r'SELECT\s+COALESCE\(SUM\(guests_count\),\s*0\)\s+INTO\s+v_current_occupancy[^;]*?FOR\s+UPDATE', caseSensitive: false);

      expect(countRegex.hasMatch(migrationContent), isFalse,
          reason: 'Không được đặt FOR UPDATE sau SELECT COUNT(*)');
      expect(sumRegex.hasMatch(migrationContent), isFalse,
          reason: 'Không được đặt FOR UPDATE sau SELECT SUM(guests_count)');
    });

    test('book_amenity_slot được phân quyền an toàn cho authenticated', () {
      expect(migrationContent, contains('GRANT EXECUTE ON FUNCTION public.book_amenity_slot'));
    });
  });
}

