import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Amenity Payment & Method Sync Migration Tests (20261011_05)', () {
    late String migrationContent;

    setUpAll(() {
      final migrationFile = File('supabase/migrations/20261011_05_fix_amenity_payment_and_method_sync.sql');
      expect(migrationFile.existsSync(), isTrue, reason: 'File migration 20261011_05 phải tồn tại');
      migrationContent = migrationFile.readAsStringSync();
    });

    test('Migration bổ sung các cột fee_amount, deposit_amount, deposit_status và guests_count', () {
      expect(migrationContent, contains('ADD COLUMN IF NOT EXISTS fee_amount NUMERIC(12,2)'));
      expect(migrationContent, contains('ADD COLUMN IF NOT EXISTS deposit_amount NUMERIC(12,2)'));
      expect(migrationContent, contains('ADD COLUMN IF NOT EXISTS deposit_status VARCHAR(20)'));
      expect(migrationContent, contains('ADD COLUMN IF NOT EXISTS guests_count INT'));
      expect(migrationContent, contains('pending_payment'));
    });

    test('RPC book_amenity_slot tính đúng fee_amount, deposit_amount và lưu vào database', () {
      expect(migrationContent, contains('v_fee := COALESCE(v_amenity.fee_amount, 0) * GREATEST(COALESCE(p_guests_count, 1), 1);'));
      expect(migrationContent, contains('v_deposit := COALESCE(v_amenity.deposit_amount, 0);'));
      expect(migrationContent, contains('v_status := \'pending_payment\';'));
      expect(migrationContent, contains('fee_amount,'));
      expect(migrationContent, contains('deposit_amount,'));
      expect(migrationContent, contains('deposit_status,'));
    });

    test('RPC simulate_unified_payment nhánh SERVICE kiểm tra trạng thái booking và tính đúng tổng phí', () {
      expect(migrationContent, contains("IF v_booking.status = 'cancelled' THEN"));
      expect(migrationContent, contains("IF v_booking.status = 'waitlist' THEN"));
      expect(migrationContent, contains("IF v_booking.status = 'completed' THEN"));
      expect(migrationContent, contains('v_total_service_fee := COALESCE(v_booking.fee_amount, 0) + COALESCE(v_booking.deposit_amount, 0);'));
      expect(migrationContent, contains("WHERE booking_id = p_reference_id AND status = 'PENDING'"));
    });

    test('RPC record_manual_amenity_payment kiểm tra quyền và cập nhật giao dịch PENDING sang SUCCESS giữ nguyên mã', () {
      expect(migrationContent, contains('IF NOT (public.is_admin_or_accountant() OR public.is_staff()) THEN'));
      expect(migrationContent, contains("WHERE booking_id = p_booking_id AND status = 'PENDING'"));
      expect(migrationContent, contains('v_txn_code := v_pending_txn.transaction_code;'));
      expect(migrationContent, contains("SET status = 'SUCCESS'"));
      expect(migrationContent, contains("confirmed_by = v_staff_id"));
      expect(migrationContent, contains("confirmed_at = NOW()"));
      expect(migrationContent, contains("status = 'confirmed'"));
      expect(migrationContent, contains("deposit_status = CASE"));
    });
  });
}
