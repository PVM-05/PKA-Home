import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pka_home/data/models/building_equipment_model.dart';
import 'package:pka_home/data/models/equipment_maintenance_task_model.dart';
import 'package:pka_home/data/repositories/equipment_repository.dart';
import 'package:pka_home/features/management/screens/equipment_management_screen.dart';

class MockEquipmentRepository extends Mock implements EquipmentRepository {}

void main() {
  late MockEquipmentRepository mockRepo;

  final sampleEquipments = [
    BuildingEquipmentModel(
      id: 'eq-1',
      code: 'TM-A01',
      name: 'Thang máy A1',
      category: 'elevator',
      building: 'Tòa A',
      location: 'Trục A',
      maintenanceIntervalDays: 30,
      status: 'operational',
      nextMaintenanceDate: DateTime.now().add(const Duration(days: 4)),
    ),
    BuildingEquipmentModel(
      id: 'eq-2',
      code: 'MB-01',
      name: 'Máy bơm B1',
      category: 'water_pump',
      building: 'Toàn khu',
      location: 'Hầm B2',
      maintenanceIntervalDays: 60,
      status: 'under_maintenance',
      nextMaintenanceDate: DateTime.now().add(const Duration(days: 20)),
    ),
  ];

  final sampleTasks = [
    EquipmentMaintenanceTaskModel(
      id: 'task-1',
      equipmentId: 'eq-1',
      equipmentCode: 'TM-A01',
      equipmentName: 'Thang máy A1',
      title: 'Bảo dưỡng định kỳ tháng 10',
      taskType: 'scheduled',
      scheduledStart: DateTime.now(),
      scheduledEnd: DateTime.now().add(const Duration(hours: 2)),
      cost: 1500000,
      status: 'pending',
      affectsService: true,
      serviceInterruptionNote: 'Tạm ngưng thang từ 09:00 - 11:00',
    ),
  ];

  setUp(() {
    mockRepo = MockEquipmentRepository();
    when(() => mockRepo.getEquipments(
          building: any(named: 'building'),
          category: any(named: 'category'),
          status: any(named: 'status'),
        )).thenAnswer((_) async => sampleEquipments);

    when(() => mockRepo.getMaintenanceTasks(
          equipmentId: any(named: 'equipmentId'),
          status: any(named: 'status'),
          building: any(named: 'building'),
        )).thenAnswer((_) async => sampleTasks);
  });

  Widget buildTestWidget() {
    return ProviderScope(
      overrides: [
        equipmentRepositoryProvider.overrideWithValue(mockRepo),
      ],
      child: const MaterialApp(
        home: EquipmentManagementScreen(),
      ),
    );
  }

  group('EquipmentManagementScreen Widget Tests', () {
    testWidgets('renders tabs, KPI cards, and equipment items', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Bảo trì thiết bị tòa nhà'), findsOneWidget);
      expect(find.text('Danh mục thiết bị'), findsOneWidget);
      expect(find.text('Phiếu & Lịch bảo trì'), findsOneWidget);

      // KPI cards & Badges
      expect(find.text('Tổng số'), findsOneWidget);
      expect(find.text('Hoạt động tốt'), findsNWidgets(2)); // KPI label and equipment badge
      expect(find.text('Đang bảo trì'), findsOneWidget); // KPI label
      expect(find.text('Đang bảo dưỡng'), findsOneWidget); // Equipment badge
      expect(find.text('Sắp đến hạn'), findsOneWidget);

      // Equipment cards
      expect(find.text('TM-A01'), findsOneWidget);
      expect(find.text('Thang máy A1'), findsOneWidget);
      expect(find.text('MB-01'), findsOneWidget);
      expect(find.text('Máy bơm B1'), findsOneWidget);
    });

    testWidgets('switching to second tab displays maintenance tasks', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tap on Tab 2
      await tester.tap(find.text('Phiếu & Lịch bảo trì'));
      await tester.pumpAndSettle();

      expect(find.text('Bảo dưỡng định kỳ tháng 10'), findsOneWidget);
      expect(find.text('Chờ thực hiện'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Bắt đầu'), findsOneWidget);
    });
  });
}
