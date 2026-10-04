import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/equipment_maintenance_task_model.dart';

void main() {
  group('EquipmentMaintenanceTaskModel Tests', () {
    final now = DateTime.now();
    final sampleJson = {
      'id': 'task-001',
      'equipment_id': 'eq-123',
      'title': 'Bảo dưỡng định kỳ tháng 10',
      'task_type': 'scheduled',
      'scheduled_start': now.toIso8601String(),
      'scheduled_end': now.add(const Duration(hours: 3)).toIso8601String(),
      'actual_start': null,
      'actual_end': null,
      'technician_id': 'user-tech-1',
      'vendor_name': 'Schindler Elevator',
      'vendor_contact': '0901234567',
      'cost': 2500000.0,
      'status': 'pending',
      'affects_service': true,
      'service_interruption_note': 'Tạm ngưng thang từ 09:00 - 12:00',
      'notes': 'Kiểm tra cáp và bôi trơn ray trượt',
      'created_by': 'user-admin-1',
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
      // joined fields
      'building_equipments': {
        'code': 'TM-A01',
        'name': 'Thang máy A1',
      },
      'users': {
        'full_name': 'Nguyễn Văn Kỹ Thuật',
      },
    };

    test('fromJson and toJson map fields correctly including joined relations', () {
      final model = EquipmentMaintenanceTaskModel.fromJson(sampleJson);

      expect(model.id, 'task-001');
      expect(model.equipmentId, 'eq-123');
      expect(model.equipmentCode, 'TM-A01');
      expect(model.equipmentName, 'Thang máy A1');
      expect(model.technicianName, 'Nguyễn Văn Kỹ Thuật');
      expect(model.title, 'Bảo dưỡng định kỳ tháng 10');
      expect(model.taskType, 'scheduled');
      expect(model.vendorName, 'Schindler Elevator');
      expect(model.vendorContact, '0901234567');
      expect(model.cost, 2500000.0);
      expect(model.status, 'pending');
      expect(model.affectsService, isTrue);
      expect(model.serviceInterruptionNote, 'Tạm ngưng thang từ 09:00 - 12:00');

      final json = model.toJson();
      expect(json['title'], 'Bảo dưỡng định kỳ tháng 10');
      expect(json['cost'], 2500000.0);
      expect(json['affects_service'], isTrue);
    });

    test('taskTypeDisplayName returns Vietnamese title', () {
      expect(
        EquipmentMaintenanceTaskModel.fromJson({...sampleJson, 'task_type': 'scheduled'}).taskTypeDisplayName,
        'Định kỳ',
      );
      expect(
        EquipmentMaintenanceTaskModel.fromJson({...sampleJson, 'task_type': 'unscheduled'}).taskTypeDisplayName,
        'Đột xuất / Sự cố',
      );
      expect(
        EquipmentMaintenanceTaskModel.fromJson({...sampleJson, 'task_type': 'inspection'}).taskTypeDisplayName,
        'Kiểm định an toàn',
      );
    });

    test('statusDisplayName and status flags evaluate correctly', () {
      final pending = EquipmentMaintenanceTaskModel.fromJson({...sampleJson, 'status': 'pending'});
      expect(pending.statusDisplayName, 'Chờ thực hiện');
      expect(pending.isCompleted, isFalse);
      expect(pending.isInProgress, isFalse);

      final inProg = EquipmentMaintenanceTaskModel.fromJson({...sampleJson, 'status': 'in_progress'});
      expect(inProg.statusDisplayName, 'Đang bảo dưỡng');
      expect(inProg.isCompleted, isFalse);
      expect(inProg.isInProgress, isTrue);

      final completed = EquipmentMaintenanceTaskModel.fromJson({...sampleJson, 'status': 'completed'});
      expect(completed.statusDisplayName, 'Đã hoàn thành');
      expect(completed.isCompleted, isTrue);

      final cancelled = EquipmentMaintenanceTaskModel.fromJson({...sampleJson, 'status': 'cancelled'});
      expect(cancelled.statusDisplayName, 'Đã hủy');
    });

    test('copyWith produces clone with updated values', () {
      final model = EquipmentMaintenanceTaskModel.fromJson(sampleJson);
      final updated = model.copyWith(
        status: 'completed',
        cost: 3000000.0,
      );

      expect(updated.id, model.id);
      expect(updated.status, 'completed');
      expect(updated.cost, 3000000.0);
      expect(updated.vendorName, model.vendorName);
    });
  });
}
