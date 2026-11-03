import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/organization_membership_model.dart';
import 'package:pka_home/data/models/building_membership_model.dart';

void main() {
  group('OrganizationMembershipModel Unit Tests', () {
    test('Khởi tạo, parse fromJson và toJson chính xác', () {
      final json = {
        'id': 'org-mem-123',
        'organization_id': 'org-001',
        'user_id': 'user-001',
        'org_role': 'owner',
        'is_active': true,
        'created_at': '2026-11-03T08:00:00Z',
        'updated_at': '2026-11-03T08:00:00Z',
        'organization_name': 'Công ty Quản lý Đô thị Tân Hoàng',
      };

      final model = OrganizationMembershipModel.fromJson(json);

      expect(model.id, equals('org-mem-123'));
      expect(model.organizationId, equals('org-001'));
      expect(model.userId, equals('user-001'));
      expect(model.orgRole, equals('owner'));
      expect(model.isOwner, isTrue);
      expect(model.isAdmin, isFalse);
      expect(model.isActive, isTrue);
      expect(model.organizationName, equals('Công ty Quản lý Đô thị Tân Hoàng'));
      expect(model.orgRoleDisplayName, equals('Chủ sở hữu tổ chức'));

      final outJson = model.toJson();
      expect(outJson['organization_id'], equals('org-001'));
      expect(outJson['org_role'], equals('owner'));
    });
  });

  group('BuildingMembershipModel Unit Tests', () {
    test('Khởi tạo, parse fromJson và kiểm tra phân quyền vai trò', () {
      final json = {
        'id': 'bm-456',
        'building_id': 'bld-001',
        'user_id': 'user-002',
        'building_role': 'accountant',
        'apartment_id': null,
        'is_active': true,
        'expires_at': null,
        'created_at': '2026-11-03T09:00:00Z',
        'building_name': 'Tòa Tháp Park 1',
        'building_code': 'P01',
      };

      final model = BuildingMembershipModel.fromJson(json);

      expect(model.id, equals('bm-456'));
      expect(model.buildingId, equals('bld-001'));
      expect(model.buildingRole, equals('accountant'));
      expect(model.isAccountant, isTrue);
      expect(model.isManager, isFalse);
      expect(model.isResident, isFalse);
      expect(model.isManagementStaff, isTrue);
      expect(model.isExpired, isFalse);
      expect(model.roleDisplayName, equals('Kế toán tòa nhà'));
    });

    test('Kiểm tra quyền cư dân gắn với căn hộ và tính toán hết hạn ủy quyền', () {
      final expiredDate = DateTime.now().subtract(const Duration(days: 1));
      final model = BuildingMembershipModel(
        id: 'bm-789',
        buildingId: 'bld-002',
        userId: 'user-003',
        buildingRole: 'resident',
        apartmentId: 'apt-010',
        apartmentCode: 'A0110',
        isActive: true,
        expiresAt: expiredDate,
        createdAt: DateTime.now(),
      );

      expect(model.isResident, isTrue);
      expect(model.isManagementStaff, isFalse);
      expect(model.apartmentCode, equals('A0110'));
      expect(model.isExpired, isTrue);
      expect(model.roleDisplayName, equals('Cư dân căn hộ'));
    });
  });
}
