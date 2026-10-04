import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/building_equipment_model.dart';

void main() {
  group('BuildingEquipmentModel Tests', () {
    final now = DateTime.now();
    final sampleJson = {
      'id': 'eq-123',
      'code': 'TM-A01',
      'name': 'Thang máy chở khách A1',
      'category': 'elevator',
      'building': 'Tòa A',
      'location': 'Trục lõi Block A',
      'installation_date': '2024-01-15',
      'warranty_until': '2026-01-15',
      'maintenance_interval_days': 30,
      'last_maintenance_date': now.subtract(const Duration(days: 25)).toIso8601String(),
      'next_maintenance_date': now.add(const Duration(days: 5)).toIso8601String(),
      'status': 'operational',
      'specifications': 'Tải trọng 1000kg, 13 người',
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    };

    test('fromJson and toJson map correctly', () {
      final model = BuildingEquipmentModel.fromJson(sampleJson);

      expect(model.id, 'eq-123');
      expect(model.code, 'TM-A01');
      expect(model.name, 'Thang máy chở khách A1');
      expect(model.category, 'elevator');
      expect(model.building, 'Tòa A');
      expect(model.location, 'Trục lõi Block A');
      expect(model.maintenanceIntervalDays, 30);
      expect(model.status, 'operational');
      expect(model.specifications, 'Tải trọng 1000kg, 13 người');

      final json = model.toJson();
      expect(json['code'], 'TM-A01');
      expect(json['category'], 'elevator');
      expect(json['status'], 'operational');
    });

    test('categoryDisplayName returns friendly Vietnamese label', () {
      expect(
        BuildingEquipmentModel.fromJson({...sampleJson, 'category': 'elevator'}).categoryDisplayName,
        'Thang máy',
      );
      expect(
        BuildingEquipmentModel.fromJson({...sampleJson, 'category': 'fire_safety'}).categoryDisplayName,
        'Hệ thống PCCC',
      );
      expect(
        BuildingEquipmentModel.fromJson({...sampleJson, 'category': 'water_pump'}).categoryDisplayName,
        'Máy bơm nước',
      );
      expect(
        BuildingEquipmentModel.fromJson({...sampleJson, 'category': 'generator'}).categoryDisplayName,
        'Máy phát điện',
      );
      expect(
        BuildingEquipmentModel.fromJson({...sampleJson, 'category': 'electrical'}).categoryDisplayName,
        'Hệ thống điện',
      );
      expect(
        BuildingEquipmentModel.fromJson({...sampleJson, 'category': 'hvac'}).categoryDisplayName,
        'Hệ thống thông gió / HVAC',
      );
    });

    test('statusDisplayName and isUnderMaintenance evaluate correctly', () {
      final operationalModel = BuildingEquipmentModel.fromJson({...sampleJson, 'status': 'operational'});
      expect(operationalModel.statusDisplayName, 'Hoạt động tốt');
      expect(operationalModel.isUnderMaintenance, isFalse);

      final underMaintModel = BuildingEquipmentModel.fromJson({...sampleJson, 'status': 'under_maintenance'});
      expect(underMaintModel.statusDisplayName, 'Đang bảo dưỡng');
      expect(underMaintModel.isUnderMaintenance, isTrue);

      final degradedModel = BuildingEquipmentModel.fromJson({...sampleJson, 'status': 'degraded'});
      expect(degradedModel.statusDisplayName, 'Cảnh báo hư hỏng');

      final inactiveModel = BuildingEquipmentModel.fromJson({...sampleJson, 'status': 'inactive'});
      expect(inactiveModel.statusDisplayName, 'Ngừng hoạt động');
    });

    test('isUpcomingMaintenance identifies equipment within 7 days threshold', () {
      final upcomingModel = BuildingEquipmentModel.fromJson({
        ...sampleJson,
        'next_maintenance_date': now.add(const Duration(days: 3)).toIso8601String(),
      });
      expect(upcomingModel.isUpcomingMaintenance, isTrue);

      final farAwayModel = BuildingEquipmentModel.fromJson({
        ...sampleJson,
        'next_maintenance_date': now.add(const Duration(days: 20)).toIso8601String(),
      });
      expect(farAwayModel.isUpcomingMaintenance, isFalse);
    });

    test('isOverdueMaintenance identifies equipment past next_maintenance_date', () {
      final overdueModel = BuildingEquipmentModel.fromJson({
        ...sampleJson,
        'status': 'operational',
        'next_maintenance_date': now.subtract(const Duration(days: 2)).toIso8601String(),
      });
      expect(overdueModel.isOverdueMaintenance, isTrue);

      // If already under maintenance, not flagged as overdue
      final underMaintModel = BuildingEquipmentModel.fromJson({
        ...sampleJson,
        'status': 'under_maintenance',
        'next_maintenance_date': now.subtract(const Duration(days: 2)).toIso8601String(),
      });
      expect(underMaintModel.isOverdueMaintenance, isFalse);
    });

    test('copyWith updates properties properly', () {
      final model = BuildingEquipmentModel.fromJson(sampleJson);
      final updated = model.copyWith(
        status: 'under_maintenance',
        maintenanceIntervalDays: 45,
      );

      expect(updated.id, model.id);
      expect(updated.status, 'under_maintenance');
      expect(updated.maintenanceIntervalDays, 45);
      expect(updated.code, model.code);
    });
  });
}
