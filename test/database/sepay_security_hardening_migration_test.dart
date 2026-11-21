import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Database Migration: 20261116010000_sepay_webhook_security_hardening.sql', () {
    late String migrationSql;

    setUpAll(() {
      final file = File('supabase/migrations/20261116010000_sepay_webhook_security_hardening.sql');
      expect(file.existsSync(), isTrue, reason: 'Migration file 20261116010000_sepay_webhook_security_hardening.sql phải tồn tại.');
      migrationSql = file.readAsStringSync();
    });

    test('Chứa hàm process_sepay_webhook với p_api_key bắt buộc', () {
      expect(migrationSql, contains('CREATE OR REPLACE FUNCTION public.process_sepay_webhook'));
      expect(migrationSql, contains('p_payload JSONB'));
      expect(migrationSql, contains('p_api_key TEXT'));
    });

    test('Kiểm tra p_api_key không được để trống và đối chiếu với building_payment_configs', () {
      expect(migrationSql, contains('IF p_api_key IS NULL OR trim(p_api_key) = \'\' THEN'));
      expect(migrationSql, contains('building_payment_configs'));
      expect(migrationSql, contains('sepay_api_key = trim(p_api_key)'));
      expect(migrationSql, contains('is_active = true'));
    });

    test('Ghi nhận nhật ký audit log SEPAY_WEBHOOK_UNAUTHORIZED khi xác thực thất bại', () {
      expect(migrationSql, contains('SEPAY_WEBHOOK_UNAUTHORIZED'));
      expect(migrationSql, contains('audit_logs'));
      expect(migrationSql, contains('401 Unauthorized'));
    });

    test('Thu hồi quyền từ public/anon/authenticated và chỉ cấp quyền service_role', () {
      expect(migrationSql, contains('REVOKE EXECUTE ON FUNCTION public.process_sepay_webhook(JSONB, TEXT) FROM PUBLIC, anon, authenticated;'));
      expect(migrationSql, contains('GRANT EXECUTE ON FUNCTION public.process_sepay_webhook(JSONB, TEXT) TO service_role;'));
    });
  });
}

