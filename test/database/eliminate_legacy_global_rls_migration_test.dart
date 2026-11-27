import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivona/data/models/maintenance_material_model.dart';

void main() {
  group('Eliminate Legacy Global RLS Policies (20261127020000) & Material UUID', () {
    final migrationFile = File(
      'supabase/migrations/20261127020000_eliminate_legacy_global_rls_policies.sql',
    );
    late String sql;

    setUpAll(() {
      expect(
        migrationFile.existsSync(),
        isTrue,
        reason: 'Tệp migration 20261127020000 phải tồn tại trong supabase/migrations/',
      );
      sql = migrationFile.readAsStringSync();
    });

    test('Gỡ bỏ các policy toàn cục is_management()/auth.uid() IS NOT NULL trên bảng lõi', () {
      const droppedPolicies = [
        'DROP POLICY IF EXISTS "Management toàn quyền apartments" ON public.apartments',
        'DROP POLICY IF EXISTS "Management toàn quyền residents_apartments" ON public.residents_apartments',
        'DROP POLICY IF EXISTS "Management toàn quyền invoices" ON public.invoices',
        'DROP POLICY IF EXISTS "Admin và Accountant toàn quyền trên invoices" ON public.invoices',
        'DROP POLICY IF EXISTS "Management toàn quyền issue_reports" ON public.issue_reports',
        'DROP POLICY IF EXISTS "User đăng nhập xem announcements" ON public.announcements',
        'DROP POLICY IF EXISTS "Mọi user đăng nhập xem building_amenities" ON public.building_amenities',
        'DROP POLICY IF EXISTS "Mọi user đăng nhập xem building_rules" ON public.building_rules',
        'DROP POLICY IF EXISTS "Mọi user đăng nhập xem emergency_contacts" ON public.emergency_contacts',
        'DROP POLICY IF EXISTS "Mọi người xem lịch tiện ích" ON public.amenity_bookings',
        'DROP POLICY IF EXISTS "BQL toàn quyền quản lý xe" ON public.vehicles',
        'DROP POLICY IF EXISTS "BQL xem audit_logs" ON public.audit_logs',
        'DROP POLICY IF EXISTS "Users can view own notifications" ON public.notifications',
        'DROP POLICY IF EXISTS "Admin toàn quyền trên role_delegations" ON public.role_delegations',
        'DROP POLICY IF EXISTS "Management toàn quyền users" ON public.users',
      ];
      for (final stmt in droppedPolicies) {
        expect(sql, contains(stmt));
      }
    });

    test('Thay thế các policy dùng FROM users bằng tenant-scoped is_building_staff / can_access_apartment', () {
      expect(sql, contains('CREATE POLICY "maintenance_windows_manage_tenant"'));
      expect(sql, contains('CREATE POLICY "issue_materials_read_tenant"'));
      expect(sql, contains('CREATE POLICY "issue_materials_manage_tenant"'));
      expect(sql, contains('CREATE POLICY "maintenance_funds_manage_tenant"'));
      expect(sql, contains('CREATE POLICY "maintenance_materials_manage_tenant"'));
      expect(sql, contains('CREATE POLICY "org_subscriptions_admin_update"'));
      expect(sql, contains('public.can_access_apartment(apartment_id)'));
    });

    test('visitor_parking_tickets cấp quyền đầy đủ cho bảo vệ và lễ tân theo tòa nhà', () {
      expect(sql, contains('CREATE POLICY "visitor_tickets_read"'));
      expect(sql, contains('CREATE POLICY "visitor_tickets_manage_admin"'));
      expect(
        sql,
        contains("ARRAY['admin', 'management', 'manager', 'owner', 'technician', 'security', 'receptionist', 'staff']"),
      );
    });

    test('MaintenanceMaterialModel.toJson() loại bỏ id giả (non-UUID) và giữ nguyên UUID hợp lệ', () {
      final now = DateTime(2026, 11, 27, 10, 0);
      final fakeIdMaterial = MaintenanceMaterialModel(
        id: 'mat-1732700000000',
        buildingId: '00000000-0000-0000-0000-000000000002',
        code: 'VT-001',
        name: 'Bóng đèn LED 18W',
        createdAt: now,
      );
      final fakeJson = fakeIdMaterial.toJson();
      expect(fakeJson.containsKey('id'), isFalse);
      expect(fakeJson['building_id'], '00000000-0000-0000-0000-000000000002');

      const realUuid = '11111111-2222-3333-4444-555555555555';
      final realIdMaterial = fakeIdMaterial.copyWith(id: realUuid);
      final realJson = realIdMaterial.toJson();
      expect(realJson['id'], realUuid);
    });
  });
}
