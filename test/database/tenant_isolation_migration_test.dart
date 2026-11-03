import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Database Migration: 20261103_05_tenant_isolation_and_memberships.sql', () {
    late File migrationFile;
    late String content;

    setUpAll(() {
      migrationFile = File('supabase/migrations/20261103_05_tenant_isolation_and_memberships.sql');
      expect(migrationFile.existsSync(), isTrue,
          reason: 'File migration 20261103_05_tenant_isolation_and_memberships.sql phai ton tai');
      content = migrationFile.readAsStringSync();
    });

    test('Chứa cấu trúc bảng organization_memberships và building_memberships', () {
      expect(content.contains('CREATE TABLE IF NOT EXISTS public.organization_memberships'), isTrue);
      expect(content.contains('CREATE TABLE IF NOT EXISTS public.building_memberships'), isTrue);
      expect(content.contains('org_role'), isTrue);
      expect(content.contains('building_role'), isTrue);
      expect(content.contains('expires_at'), isTrue);
    });

    test('Chứa 3 hàm bảo mật phân quyền tenant tập trung', () {
      expect(content.contains('FUNCTION public.get_user_accessible_organizations'), isTrue);
      expect(content.contains('FUNCTION public.get_user_accessible_buildings'), isTrue);
      expect(content.contains('FUNCTION public.has_building_role'), isTrue);
      expect(content.contains('SECURITY DEFINER'), isTrue);
    });

    test('Xóa bỏ và thay thế toàn bộ chính sách RLS USING (true) lỏng lẻo', () {
      expect(content.contains('DROP POLICY IF EXISTS "organizations_read_authenticated"'), isTrue);
      expect(content.contains('DROP POLICY IF EXISTS "buildings_read_authenticated"'), isTrue);
      expect(content.contains('DROP POLICY IF EXISTS "building_staff_read_authenticated"'), isTrue);
      expect(content.contains('DROP POLICY IF EXISTS "mft_read_policy"'), isTrue);

      // RLS mới phải dùng get_user_accessible_organizations và get_user_accessible_buildings
      expect(content.contains('get_user_accessible_organizations()'), isTrue);
      expect(content.contains('get_user_accessible_buildings()'), isTrue);
      expect(content.contains('has_building_role'), isTrue);
    });

    test('Chứa logic di chuyển dữ liệu cũ từ building_staff sang building_memberships an toàn', () {
      expect(content.contains('FROM public.building_staff'), isTrue);
      expect(content.contains('ON CONFLICT'), isTrue);
    });
  });
}
