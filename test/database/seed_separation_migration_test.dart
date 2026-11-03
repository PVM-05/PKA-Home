import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Kiểm tra Migration 20261104_02: Làm Sạch Production & Tách Seed (INF-02)', () {
    const migrationPath = 'supabase/migrations/20261104_02_production_clean_seed_separation.sql';
    const seedPath = 'supabase/seed.sql';

    test('File migration clean seed và file seed.sql độc lập phải tồn tại', () {
      final migFile = File(migrationPath);
      final seedFile = File(seedPath);

      expect(migFile.existsSync(), isTrue, reason: 'Migration 20261104_02 phải tồn tại');
      expect(seedFile.existsSync(), isTrue, reason: 'File supabase/seed.sql phải tồn tại');

      expect(migFile.readAsStringSync().trim().isNotEmpty, isTrue);
      expect(seedFile.readAsStringSync().trim().isNotEmpty, isTrue);
    });

    test('Migration phải gỡ bỏ giá trị mặc định demo khỏi bảng buildings và maintenance_funds', () {
      final content = File(migrationPath).readAsStringSync();
      expect(content.contains('ALTER TABLE public.buildings ALTER COLUMN bank_account_number DROP DEFAULT'), isTrue,
          reason: 'Phải gỡ bỏ DEFAULT 1234567890 khỏi buildings');
      expect(content.contains('ALTER TABLE public.maintenance_funds ALTER COLUMN bank_account_number DROP DEFAULT'), isTrue,
          reason: 'Phải gỡ bỏ DEFAULT STK demo khỏi maintenance_funds');
      expect(content.contains('ALTER TABLE public.maintenance_funds ALTER COLUMN total_balance SET DEFAULT 0.00'), isTrue,
          reason: 'Số dư quỹ bảo trì mặc định ban đầu phải là 0.00');
    });

    test('Phải định nghĩa RPC onboard_building_commercial_config có ghi nhận audit_logs', () {
      final content = File(migrationPath).readAsStringSync();
      expect(content.contains('CREATE OR REPLACE FUNCTION public.onboard_building_commercial_config'), isTrue,
          reason: 'Phải có RPC onboard_building_commercial_config');
      expect(content.contains('has_building_role'), isTrue,
          reason: 'Phải kiểm tra thẩm quyền quản trị của người thực hiện onboarding');
      expect(content.contains('INSERT INTO public.audit_logs'), isTrue,
          reason: 'Phải ghi nhận vết kiểm toán bất biến khi onboarding thông tin ngân hàng và số dư');
      expect(content.contains('GRANT EXECUTE ON FUNCTION public.onboard_building_commercial_config'), isTrue,
          reason: 'Phải cấp quyền thực thi cho authenticated');
    });

    test('File supabase/seed.sql độc lập phải chứa dữ liệu mẫu demo phục vụ test/dev', () {
      final content = File(seedPath).readAsStringSync();
      expect(content.contains('a0110') || content.contains('A0110'), isTrue,
          reason: 'Seed data phải có căn hộ mẫu mã chuẩn');
      expect(content.contains('2450000000') || content.contains('2450000000.00'), isTrue,
          reason: 'Dữ liệu mẫu quỹ bảo trì 2.45 tỷ đồng phải nằm trong seed.sql');
      expect(content.contains('BIDV') || content.contains('1234567890'), isTrue,
          reason: 'Tài khoản demo ngân hàng phải nằm trong seed.sql thay vì core production migration');
    });
  });
}
