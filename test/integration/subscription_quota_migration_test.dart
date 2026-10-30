import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SaaS Subscription & Quota Migration Tests (20261030_03)', () {
    const migrationPath =
        'supabase/migrations/20261030_03_saas_subscription_plans_and_quota.sql';

    test('Migration file exists and is not empty', () {
      final file = File(migrationPath);
      expect(file.existsSync(), isTrue,
          reason: 'Tệp migration $migrationPath phải tồn tại');
      final content = file.readAsStringSync();
      expect(content.trim().isNotEmpty, isTrue,
          reason: 'Tệp migration không được để trống');
    });

    test('Migration defines subscription_plans table with correct columns and constraints', () {
      final content = File(migrationPath).readAsStringSync();

      expect(content.contains('CREATE TABLE IF NOT EXISTS public.subscription_plans'), isTrue,
          reason: 'Phải tạo bảng subscription_plans');
      expect(content.contains('code TEXT NOT NULL UNIQUE'), isTrue,
          reason: 'Cột code phải là duy nhất');
      expect(content.contains('max_apartments INT NOT NULL DEFAULT'), isTrue,
          reason: 'Phải có cột max_apartments');
      expect(content.contains('max_buildings INT NOT NULL DEFAULT'), isTrue,
          reason: 'Phải có cột max_buildings');
      expect(content.contains('max_staff INT NOT NULL DEFAULT'), isTrue,
          reason: 'Phải có cột max_staff');
      expect(content.contains('price_monthly NUMERIC'), isTrue,
          reason: 'Phải có cột price_monthly');
      expect(content.contains('features JSONB NOT NULL DEFAULT'), isTrue,
          reason: 'Phải có cột features dạng jsonb');
    });

    test('Migration defines organization_subscriptions table with foreign keys', () {
      final content = File(migrationPath).readAsStringSync();

      expect(content.contains('CREATE TABLE IF NOT EXISTS public.organization_subscriptions'), isTrue,
          reason: 'Phải tạo bảng organization_subscriptions');
      expect(content.contains('organization_id UUID NOT NULL REFERENCES public.organizations'), isTrue,
          reason: 'Phải tham chiếu đến organizations(id)');
      expect(content.contains('plan_id UUID NOT NULL REFERENCES public.subscription_plans'), isTrue,
          reason: 'Phải tham chiếu đến subscription_plans(id)');
      expect(content.contains('status TEXT NOT NULL DEFAULT'), isTrue,
          reason: 'Phải có cột status');
      expect(content.contains('expires_at TIMESTAMPTZ'), isTrue,
          reason: 'Phải có cột expires_at');
    });

    test('Migration seeds 3 standard plans: starter, pro, enterprise', () {
      final content = File(migrationPath).readAsStringSync();

      expect(content.contains("'starter'"), isTrue,
          reason: 'Phải seed gói starter');
      expect(content.contains("'pro'"), isTrue,
          reason: 'Phải seed gói pro');
      expect(content.contains("'enterprise'"), isTrue,
          reason: 'Phải seed gói enterprise');
    });

    test('Migration defines trigger or function to enforce apartment quota', () {
      final content = File(migrationPath).readAsStringSync();

      expect(content.contains('enforce_apartment_quota') || content.contains('check_apartment_quota'), isTrue,
          reason: 'Phải có hàm hoặc trigger kiểm soát hạn mức căn hộ');
      expect(content.contains('TRIGGER'), isTrue,
          reason: 'Phải kích hoạt trigger trên bảng apartments');
    });

    test('Migration defines get_organization_subscription_status RPC', () {
      final content = File(migrationPath).readAsStringSync();

      expect(content.contains('get_organization_subscription_status'), isTrue,
          reason: 'Phải định nghĩa RPC get_organization_subscription_status');
      expect(content.contains('SECURITY DEFINER'), isTrue,
          reason: 'RPC phải được cấu hình SECURITY DEFINER để đọc dữ liệu bảo mật');
    });
  });
}
