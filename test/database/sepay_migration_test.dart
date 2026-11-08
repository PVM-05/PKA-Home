import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Database Migration: 20261108_01_sepay_real_payment_and_webhook.sql', () {
    late String migrationSql;

    setUpAll(() {
      final file = File('supabase/migrations/20261108_01_sepay_real_payment_and_webhook.sql');
      expect(file.existsSync(), isTrue, reason: 'Migration file 20261108_01_sepay_real_payment_and_webhook.sql phải tồn tại.');
      migrationSql = file.readAsStringSync();
    });

    test('Chứa lệnh tạo bảng building_payment_configs cấu hình SePay theo tòa nhà', () {
      expect(migrationSql, contains('CREATE TABLE IF NOT EXISTS public.building_payment_configs'));
      expect(migrationSql, contains('building_id UUID'));
      expect(migrationSql, contains('sepay_api_key TEXT'));
      expect(migrationSql, contains('bank_name TEXT'));
      expect(migrationSql, contains('bank_account_number TEXT'));
      expect(migrationSql, contains('bank_account_name TEXT'));
      expect(migrationSql, contains('bank_bin TEXT'));
    });

    test('Chứa hàm process_sepay_webhook nhận diện payload chuẩn SePay và API Key', () {
      expect(migrationSql, contains('CREATE OR REPLACE FUNCTION public.process_sepay_webhook'));
      expect(migrationSql, contains('p_payload JSONB'));
      expect(migrationSql, contains('p_api_key TEXT'));
      expect(migrationSql, contains('transferType'));
      expect(migrationSql, contains('transferAmount'));
      expect(migrationSql, contains('referenceCode'));
    });

    test('Xử lý phân loại luồng tiền vào in/out, kiểm tra trùng lặp và gạch nợ tự động', () {
      expect(migrationSql, contains('IGNORED_OUTGOING'));
      expect(migrationSql, contains('DUPLICATE'));
      expect(migrationSql, contains('status = \'paid\''));
      expect(migrationSql, contains('payment_method = \'vietqr\''));
      expect(migrationSql, contains('REC-'));
    });

    test('Chứa xử lý giao dịch chưa khớp UNMATCHED và RLS policies bảo mật', () {
      expect(migrationSql, contains('UNMATCHED'));
      expect(migrationSql, contains('ENABLE ROW LEVEL SECURITY'));
      expect(migrationSql, contains('building_payment_configs'));
    });
  });
}

