import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Secure Bank Webhook & VNPay Migration Tests (20261114_01)', () {
    const migrationPath = 'supabase/migrations/20261114010000_secure_bank_webhook_and_vnpay.sql';

    test('Tập tin migration 20261114010000_secure_bank_webhook_and_vnpay.sql phải tồn tại', () {
      final file = File(migrationPath);
      expect(file.existsSync(), isTrue, reason: 'Tập tin migration phải tồn tại trên đĩa');
      expect(file.readAsStringSync().trim(), isNotEmpty, reason: 'Migration không được rỗng');
    });

    test('Migration phải thu hồi quyền EXECUTE khỏi anon/authenticated và cấp cho service_role', () {
      final content = File(migrationPath).readAsStringSync();

      // Kiểm tra khóa process_bank_payment_webhook
      expect(content, contains('REVOKE EXECUTE ON FUNCTION public.process_bank_payment_webhook'));
      expect(content, contains('GRANT EXECUTE ON FUNCTION public.process_bank_payment_webhook(JSONB) TO service_role'));

      // Kiểm tra khóa process_sepay_webhook
      expect(content, contains('REVOKE EXECUTE ON FUNCTION public.process_sepay_webhook'));
      expect(content, contains('GRANT EXECUTE ON FUNCTION public.process_sepay_webhook(JSONB, TEXT) TO service_role'));
    });

    test('Migration phải định nghĩa các trường cấu hình cổng VNPay', () {
      final content = File(migrationPath).readAsStringSync();

      expect(content, contains('vnpay_tmn_code'));
      expect(content, contains('vnpay_hash_secret'));
      expect(content, contains('vnpay_is_active'));
      expect(content, contains('building_payment_configs'));
    });
  });
}

