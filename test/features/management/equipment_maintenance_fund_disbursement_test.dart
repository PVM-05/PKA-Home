import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/building_equipment_model.dart';
import 'package:pka_home/data/models/equipment_maintenance_task_model.dart';
import 'package:pka_home/data/providers/equipment_provider.dart';
import 'package:pka_home/features/management/screens/equipment_detail_screen.dart';

void main() {
  testWidgets('EquipmentDetailScreen displays action to disburse maintenance fund when task completed with cost', (tester) async {
    final equipment = BuildingEquipmentModel(
      id: 'eq-1',
      code: 'TM-01',
      name: 'Thang máy Otis Tòa A',
      category: 'ELEVATOR',
      status: 'active',
      location: 'Tầng 1 - Sảnh chính',
      building: 'bld-01',
    );

    final mockTasks = [
      EquipmentMaintenanceTaskModel(
        id: 'task-1',
        equipmentId: 'eq-1',
        title: 'Bảo dưỡng định kỳ tháng 10',
        status: 'completed',
        cost: 3500000.0,
        vendorName: 'Công ty Thang máy Otis',
        scheduledStart: DateTime(2026, 10, 10),
        scheduledEnd: DateTime(2026, 10, 10, 12),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          equipmentTasksProvider('eq-1').overrideWith((ref) => Future.value(mockTasks)),
        ],
        child: MaterialApp(
          home: EquipmentDetailScreen(equipment: equipment),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Thang máy Otis Tòa A'), findsWidgets);
    expect(find.text('Bảo dưỡng định kỳ tháng 10'), findsOneWidget);
    expect(find.text('Chi từ Quỹ bảo trì'), findsOneWidget);
  });
}
