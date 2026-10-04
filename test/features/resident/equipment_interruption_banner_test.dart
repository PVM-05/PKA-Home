import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pka_home/data/models/equipment_maintenance_task_model.dart';
import 'package:pka_home/data/providers/equipment_provider.dart';
import 'package:pka_home/data/providers/resident_apartment_provider.dart';
import 'package:pka_home/features/resident/widgets/equipment_interruption_banner.dart';

void main() {
  final sampleTask1 = EquipmentMaintenanceTaskModel(
    id: 'task-1',
    equipmentId: 'eq-1',
    title: 'Bảo dưỡng định kỳ động cơ tời',
    serviceInterruptionNote: 'Tạm ngưng phục vụ thang để thay cáp kéo',
    scheduledStart: DateTime(2026, 10, 4, 14, 0),
    scheduledEnd: DateTime(2026, 10, 4, 16, 0),
    status: 'in_progress',
    cost: 5000000,
    vendorName: 'Schindler VN',
    affectsService: true,
    equipmentCode: 'TM-A01',
    equipmentName: 'Thang máy A1',
  );

  final sampleTask2 = EquipmentMaintenanceTaskModel(
    id: 'task-2',
    equipmentId: 'eq-2',
    title: 'Sửa chữa van áp lực cấp nước',
    scheduledStart: DateTime(2026, 10, 4, 15, 30),
    scheduledEnd: DateTime(2026, 10, 4, 17, 30),
    status: 'in_progress',
    cost: 1200000,
    affectsService: true,
    equipmentCode: 'MB-01',
    equipmentName: 'Máy bơm tăng áp tầng mái',
  );

  Widget createTestWidget({
    required List<EquipmentMaintenanceTaskModel> interruptions,
    String? building,
    Map<String, dynamic>? currentApartment,
  }) {
    return ProviderScope(
      overrides: [
        currentSelectedApartmentProvider.overrideWithValue(currentApartment),
        activeServiceInterruptionsProvider.overrideWith((ref, bld) => interruptions),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: EquipmentInterruptionBanner(building: building),
          ),
        ),
      ),
    );
  }

  group('EquipmentInterruptionBanner Tests', () {
    testWidgets('renders empty SizedBox when there are no active service interruptions',
        (tester) async {
      await tester.pumpWidget(createTestWidget(interruptions: []));
      await tester.pumpAndSettle();

      expect(find.text('Bảo trì thiết bị - Tạm gián đoạn dịch vụ'), findsNothing);
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    });

    testWidgets('renders warning banner with task details when interruptions exist',
        (tester) async {
      await tester.pumpWidget(createTestWidget(
        interruptions: [sampleTask1],
        building: 'Tòa A',
      ));
      await tester.pumpAndSettle();

      expect(find.text('Bảo trì thiết bị - Tạm gián đoạn dịch vụ'), findsOneWidget);
      expect(find.text('Khu vực: Tòa A'), findsOneWidget);
      expect(find.text('Thang máy A1: Bảo dưỡng định kỳ động cơ tời'), findsOneWidget);
      expect(find.text('Tạm ngưng phục vụ thang để thay cáp kéo'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('displays multiple tasks count badge when more than 1 task is active',
        (tester) async {
      await tester.pumpWidget(createTestWidget(
        interruptions: [sampleTask1, sampleTask2],
        building: 'Tòa A',
      ));
      await tester.pumpAndSettle();

      expect(find.text('Bảo trì thiết bị - Tạm gián đoạn dịch vụ'), findsOneWidget);
      expect(find.text('2 thiết bị'), findsOneWidget);
      expect(find.text('Thang máy A1: Bảo dưỡng định kỳ động cơ tời'), findsOneWidget);
      expect(find.text('Máy bơm tăng áp tầng mái: Sửa chữa van áp lực cấp nước'), findsOneWidget);
    });

    testWidgets('resolves building from currentSelectedApartment when building param is omitted',
        (tester) async {
      final mockApartment = {
        'apartment_id': 'apt-101',
        'apartments': {
          'id': 'apt-101',
          'code': 'A0110',
          'building_code': 'A',
          'floor_number': 1,
        }
      };

      await tester.pumpWidget(createTestWidget(
        interruptions: [sampleTask1],
        currentApartment: mockApartment,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Khu vực: Tòa A'), findsOneWidget);
      expect(find.text('Thang máy A1: Bảo dưỡng định kỳ động cơ tời'), findsOneWidget);
    });
  });
}
