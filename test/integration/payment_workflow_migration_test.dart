import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Payment Workflow Migration Tests (20261011_04)', () {
    late String migrationContent;

    setUpAll(() {
      final migrationFile = File('supabase/migrations/20261011_04_resident_payment_submission_workflow.sql');
      expect(migrationFile.existsSync(), isTrue, reason: 'File migration 20261011_04 phải tồn tại');
      migrationContent = migrationFile.readAsStringSync();
    });

    test('Migration nới lỏng constraint cho phép trạng thái PENDING', () {
      expect(
        migrationContent,
        contains("ALTER TABLE public.payment_transactions \nADD CONSTRAINT payment_transactions_status_check \nCHECK (status IN ('SUCCESS', 'PENDING', 'FAILED', 'CANCELLED'));"),
      );
    });

    test('Migration bổ sung cột kiểm toán confirmed_by và confirmed_at', () {
      expect(migrationContent, contains('ADD COLUMN IF NOT EXISTS confirmed_by UUID'));
      expect(migrationContent, contains('ADD COLUMN IF NOT EXISTS confirmed_at TIMESTAMPTZ'));
    });

    test('RPC simulate_unified_payment sử dụng FOR UPDATE và kiểm tra quyền sở hữu', () {
      expect(migrationContent, contains('WHERE i.id = p_reference_id\n        FOR UPDATE;'));
      expect(migrationContent, contains('WHERE b.id = p_reference_id\n        FOR UPDATE;'));
      expect(migrationContent, contains("RAISE EXCEPTION 'Bạn không có quyền thanh toán cho hóa đơn của căn hộ này';"));
    });

    test('RPC simulate_unified_payment có cơ chế chống gửi lặp (Idempotency) khi pending_confirmation', () {
      expect(migrationContent, contains("IF v_invoice.status = 'pending_confirmation' THEN"));
      expect(migrationContent, contains("WHERE invoice_id = p_reference_id AND status = 'PENDING'"));
      expect(migrationContent, contains("'is_pending', true"));
      expect(migrationContent, contains("'status', 'PENDING'"));
    });

    test('RPC record_manual_payment kiểm tra quyền BQL và cập nhật giao dịch PENDING sang SUCCESS giữ nguyên mã', () {
      expect(migrationContent, contains('IF NOT public.is_admin_or_accountant() THEN'));
      expect(migrationContent, contains("WHERE invoice_id = p_invoice_id AND status = 'PENDING'"));
      expect(migrationContent, contains('v_txn_code := v_pending_txn.transaction_code;'));
      expect(migrationContent, contains("SET status = 'SUCCESS'"));
      expect(migrationContent, contains("confirmed_by = v_staff_id"));
      expect(migrationContent, contains("confirmed_at = NOW()"));
    });
  });
}
