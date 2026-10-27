import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/apartment_model.dart';
import 'package:pka_home/data/models/building_model.dart';
import 'package:pka_home/data/models/building_staff_model.dart';
import 'package:pka_home/data/models/organization_model.dart';

void main() {
  group('Multi-Tenancy Models Serialization Tests', () {
    test('OrganizationModel fromJson and toJson', () {
      final json = {
        'id': 'org-1',
        'name': 'PKA Holdings',
        'slug': 'pka-corp',
        'logo_url': 'https://pka.vn/logo.png',
        'contact_phone': '0901234567',
        'contact_email': 'info@pka.vn',
        'status': 'active',
        'settings': {'feature_amenity': true},
        'created_at': '2026-01-01T00:00:00Z',
      };

      final model = OrganizationModel.fromJson(json);
      expect(model.id, 'org-1');
      expect(model.name, 'PKA Holdings');
      expect(model.slug, 'pka-corp');
      expect(model.logoUrl, 'https://pka.vn/logo.png');
      expect(model.status, 'active');
      expect(model.settings['feature_amenity'], isTrue);

      final outJson = model.toJson();
      expect(outJson['slug'], 'pka-corp');
      expect(outJson['name'], 'PKA Holdings');
    });

    test('BuildingModel fromJson and toJson', () {
      final json = {
        'id': 'building-1',
        'organization_id': 'org-1',
        'name': 'Landmark Tower',
        'code': 'PKAL',
        'address': '1 Dai Co Viet',
        'total_floors': 30,
        'total_units': 350,
        'is_active': true,
        'created_at': '2026-01-01T00:00:00Z',
      };

      final model = BuildingModel.fromJson(json);
      expect(model.id, 'building-1');
      expect(model.organizationId, 'org-1');
      expect(model.name, 'Landmark Tower');
      expect(model.code, 'PKAL');
      expect(model.totalFloors, 30);
      expect(model.totalUnits, 350);
      expect(model.isActive, isTrue);

      final outJson = model.toJson();
      expect(outJson['code'], 'PKAL');
      expect(outJson['total_units'], 350);
    });

    test('BuildingStaffModel fromJson and toJson', () {
      final json = {
        'id': 'staff-rel-1',
        'user_id': 'user-100',
        'building_id': 'building-1',
        'assigned_role': 'manager',
        'is_primary': true,
      };

      final model = BuildingStaffModel.fromJson(json);
      expect(model.id, 'staff-rel-1');
      expect(model.userId, 'user-100');
      expect(model.buildingId, 'building-1');
      expect(model.assignedRole, 'manager');
      expect(model.isPrimary, isTrue);

      final outJson = model.toJson();
      expect(outJson['user_id'], 'user-100');
      expect(outJson['assigned_role'], 'manager');
    });

    test('ApartmentModel handles optional buildingId', () {
      final jsonWithBuilding = {
        'id': 'apt-1',
        'code': 'A0110',
        'building_id': 'building-1',
        'area': 65.5,
      };

      final apt = ApartmentModel.fromJson(jsonWithBuilding);
      expect(apt.id, 'apt-1');
      expect(apt.code, 'A0110');
      expect(apt.buildingId, 'building-1');

      final copied = apt.copyWith(buildingId: 'building-2');
      expect(copied.buildingId, 'building-2');
      expect(copied.code, 'A0110');
    });
  });
}
