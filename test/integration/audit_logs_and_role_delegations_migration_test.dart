import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Audit Logs & Role Delegations Migration Tests (20261029_01)', () {
    const migrationPath = 'supabase/migrations/20261029_01_audit_logs_and_role_delegations.sql';

    test('Tập tin migration 20261029_01_audit_logs_and_role_delegations.sql phải tồn tại', () {
      final file = File(migrationPath);
      expect(file.existsSync(), isTrue, reason: 'Migration 20261029_01 chưa được tạo.');
    });

    test('Migration phải định nghĩa bảng role_delegations với đầy đủ ràng buộc và RLS', () {
      final content = File(migrationPath).readAsStringSync();

      expect(content.contains('CREATE TABLE IF NOT EXISTS public.role_delegations'), isTrue);
      expect(content.contains('delegator_id'), isTrue);
      expect(content.contains('delegate_id'), isTrue);
      expect(content.contains('delegated_role'), isTrue);
      expect(content.contains('starts_at'), isTrue);
      expect(content.contains('ends_at'), isTrue);
      expect(content.contains('is_revoked'), isTrue);
      expect(content.contains('ENABLE ROW LEVEL SECURITY'), isTrue);
      expect(content.contains('role_delegations_read'), isTrue);
      expect(content.contains('role_delegations_manage'), isTrue);
    });

    test('Migration phải nâng cấp bảng audit_logs với tính năng Append-Only và bảo mật RLS', () {
      final content = File(migrationPath).readAsStringSync();

      expect(content.contains('audit_logs'), isTrue);
      expect(content.contains('building_id'), isTrue);
      expect(content.contains('old_values'), isTrue);
      expect(content.contains('new_values'), isTrue);
      expect(content.contains('audit_logs_read'), isTrue);
      expect(content.contains('audit_logs_insert'), isTrue);
    });

    test('Migration phải định nghĩa Triggers ghi log tự động cho hóa đơn và thẻ xe', () {
      final content = File(migrationPath).readAsStringSync();

      // Trigger Audit hóa đơn
      expect(content.contains('fn_audit_invoice_changes'), isTrue);
      expect(content.contains('trg_audit_invoice_changes'), isTrue);

      // Trigger Audit thẻ xe
      expect(content.contains('fn_audit_vehicle_changes'), isTrue);
      expect(content.contains('trg_audit_vehicle_changes'), isTrue);

      // Trigger Audit ủy quyền
      expect(content.contains('fn_audit_role_delegation_changes'), isTrue);
      expect(content.contains('trg_audit_role_delegation_changes'), isTrue);
    });

    test('Migration phải cung cấp RPC get_effective_user_role kiểm tra quyền có thời hạn', () {
      final content = File(migrationPath).readAsStringSync();

      expect(content.contains('get_effective_user_role'), isTrue);
      expect(content.contains('role_delegations'), isTrue);
      expect(content.contains('starts_at <= now()'), isTrue);
      expect(content.contains('ends_at >= now()'), isTrue);
      expect(content.contains('is_revoked = false'), isTrue);
    });
  });
}
