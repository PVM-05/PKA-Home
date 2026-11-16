import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Database Migration: 20261116_02_separate_payment_secrets_and_scope_webhook.sql', () {
    late String migrationSql;

    setUpAll(() {
      final file = File('supabase/migrations/20261116_02_separate_payment_secrets_and_scope_webhook.sql');
      expect(file.existsSync(), isTrue, reason: 'Migration file 20261116_02_separate_payment_secrets_and_scope_webhook.sql phải tồn tại.');
      migrationSql = file.readAsStringSync();
    });

    test('Tạo bảng bí mật building_payment_secrets cách ly hoàn toàn khỏi bảng công khai', () {
      expect(migrationSql, contains('CREATE TABLE IF NOT EXISTS public.building_payment_secrets'));
      expect(migrationSql, contains('building_id UUID NOT NULL REFERENCES public.buildings(id)'));
      expect(migrationSql, contains('sepay_api_key TEXT'));
      expect(migrationSql, contains('vnpay_hash_secret TEXT'));
      expect(migrationSql, contains('uq_building_payment_secrets_building UNIQUE (building_id)'));
    });

    test('Bảo vệ đa tầng RLS cho building_payment_secrets: cấm anon/resident, chỉ cấp quyền service_role và admin', () {
      expect(migrationSql, contains('ALTER TABLE public.building_payment_secrets ENABLE ROW LEVEL SECURITY;'));
      expect(migrationSql, contains('REVOKE ALL ON public.building_payment_secrets FROM PUBLIC, anon, authenticated;'));
      expect(migrationSql, contains('GRANT ALL ON public.building_payment_secrets TO service_role;'));
      expect(migrationSql, contains('role = \'admin\''));
    });

    test('Xóa bỏ vĩnh viễn sepay_api_key và vnpay_hash_secret khỏi building_payment_configs để triệt tiêu nguy cơ rò rỉ qua API cư dân', () {
      expect(migrationSql, contains('ALTER TABLE public.building_payment_configs DROP COLUMN IF EXISTS sepay_api_key;'));
      expect(migrationSql, contains('ALTER TABLE public.building_payment_configs DROP COLUMN IF EXISTS vnpay_hash_secret;'));
    });

    test('Thực hiện cơ chế xoay vòng khóa bí mật (Secret Rotation) cho các key cũ từng bị lộ sáng', () {
      expect(migrationSql, contains('UPDATE public.building_payment_secrets'));
      expect(migrationSql, contains('gen_random_bytes'));
    });

    test('Hàm process_sepay_webhook thẩm định API Key theo đúng Tòa Nhà của Hóa Đơn (Tenant-Scoped)', () {
      expect(migrationSql, contains('CREATE OR REPLACE FUNCTION public.process_sepay_webhook'));
      expect(migrationSql, contains('a.building_id AS invoice_building_id'));
      expect(migrationSql, contains('FROM public.building_payment_secrets'));
      expect(migrationSql, contains('WHERE building_id = v_invoice.invoice_building_id'));
      expect(migrationSql, contains('SEPAY_WEBHOOK_CROSS_TENANT_UNAUTHORIZED'));
      expect(migrationSql, contains('401 Unauthorized: API Key không khớp với cấu hình SePay của tòa nhà chứa hóa đơn.'));
    });

    test('Xử lý thẩm định tài khoản thụ hưởng khi giao dịch UNMATCHED', () {
      expect(migrationSql, contains('v_target_building_id'));
      expect(migrationSql, contains('replace(bank_account_number, \' \', \'\') = replace(v_account_number, \' \', \'\')'));
      expect(migrationSql, contains('UNMATCHED'));
    });

    test('Thu hồi quyền EXECUTE từ public/anon/authenticated và chỉ cấp cho service_role', () {
      expect(migrationSql, contains('REVOKE EXECUTE ON FUNCTION public.process_sepay_webhook(JSONB, TEXT) FROM PUBLIC, anon, authenticated;'));
      expect(migrationSql, contains('GRANT EXECUTE ON FUNCTION public.process_sepay_webhook(JSONB, TEXT) TO service_role;'));
    });
  });
}

