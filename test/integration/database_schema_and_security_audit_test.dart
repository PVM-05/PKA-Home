import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Database Schema and Security Audit Tests (SYS-01, SYS-02, SYS-04, SYS-05)', () {
    late String migration20261025;

    setUpAll(() {
      final file20261025 = File('supabase/migrations/20261025_01_fix_waitlist_transactions_and_rpc_security.sql');
      expect(file20261025.existsSync(), isTrue, reason: 'Migration 20261025_01 phải tồn tại');
      migration20261025 = file20261025.readAsStringSync();
    });

    test('SYS-01: Giao dịch waitlist và thanh toán thống nhất cho phép PENDING trên payment_transactions', () {
      expect(migration20261025, contains('ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ'));
      expect(migration20261025, contains('payment_transactions_status_check'));
      expect(migration20261025, contains("status IN ('PENDING', 'SUCCESS', 'FAILED', 'CANCELLED')"));
      expect(migration20261025, contains("INSERT INTO public.payment_transactions"));
      expect(migration20261025, contains("'PENDING'"));
    });

    test('SYS-02: Toàn bộ RPC SECURITY DEFINER có search_path an toàn và thu hồi quyền từ anon/PUBLIC', () {
      final rpcs = [
        'simulate_unified_payment',
        'confirm_payment',
        'reschedule_amenity_booking',
        'is_staff_or_management',
      ];

      for (final rpc in rpcs) {
        expect(
          migration20261025.contains('SET search_path = public, pg_catalog'),
          isTrue,
          reason: 'RPC $rpc phải có SET search_path = public, pg_catalog',
        );
        expect(
          migration20261025.contains('REVOKE ALL ON FUNCTION public.$rpc'),
          isTrue,
          reason: 'RPC $rpc phải REVOKE từ anon/PUBLIC',
        );
      }
    });

    test('SYS-04: Lịch bảo trì tiện ích so khớp chính xác start_time và end_time', () {
      expect(migration20261025, contains('start_time AT TIME ZONE \'Asia/Ho_Chi_Minh\''));
      expect(migration20261025, contains('end_time AT TIME ZONE \'Asia/Ho_Chi_Minh\''));
      expect(migration20261025, contains('public.amenity_maintenance_windows'));
    });

    test('SYS-04: Nâng cấp bảng building_amenities đầy đủ các trường nâng cao', () {
      expect(migration20261025, contains('ALTER TABLE public.building_amenities'));
      expect(migration20261025, contains('ADD COLUMN IF NOT EXISTS booking_type'));
      expect(migration20261025, contains('ADD COLUMN IF NOT EXISTS max_capacity'));
      expect(migration20261025, contains('ADD COLUMN IF NOT EXISTS fee_amount'));
      expect(migration20261025, contains('ADD COLUMN IF NOT EXISTS deposit_amount'));
      expect(migration20261025, contains('ADD COLUMN IF NOT EXISTS requires_deposit'));
      expect(migration20261025, contains('ADD COLUMN IF NOT EXISTS is_active'));
    });

    test('SYS-05: Toàn bộ các kiểm tra trong pending_correction_migration_test không được sử dụng silent pass (return sớm)', () {
      final file = File('test/data/repositories/pending_correction_migration_test.dart');
      final content = file.readAsStringSync();
      expect(
        content.contains('if (!migrationFile.existsSync()) return;'),
        isFalse,
        reason: '${file.path} không được chứa pattern silent pass',
      );
    });

    test('SYS-06: Migration 20261025_02 bổ sung trường target_type và target_apartment cho announcements', () {
      final file = File('supabase/migrations/20261025_02_add_announcement_target_fields.sql');
      expect(file.existsSync(), isTrue, reason: 'Migration 20261025_02 phải tồn tại');
      final content = file.readAsStringSync();

      expect(content, contains('ADD COLUMN IF NOT EXISTS target_type'));
      expect(content, contains('ADD COLUMN IF NOT EXISTS target_apartment'));
      expect(content, contains('announcements_target_type_check'));
      expect(content, contains("target_type IN ('all', 'block_a', 'block_b', 'apartment')"));
      expect(content, contains('is_staff_or_management()'));
      expect(content, contains('"Management toàn quyền announcements"'));
      expect(content, contains('"User đăng nhập xem announcements"'));
    });
  });
}

