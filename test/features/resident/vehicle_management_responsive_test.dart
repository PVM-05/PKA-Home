import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivona/data/models/vehicle_model.dart';
import 'package:vivona/data/models/parking_slot_model.dart';
import 'package:vivona/data/providers/vehicle_provider.dart';
import 'package:vivona/data/providers/parking_provider.dart';
import 'package:vivona/features/resident/screens/vehicle_management_screen.dart';

void main() {
  group('VehicleManagementScreen Responsive & Anti-RenderFlex Tests', () {
    final mockVehicles = [
      VehicleModel(
        id: 'v-1',
        apartmentId: 'apt-1',
        vehicleType: 'motorbike',
        licensePlate: '29A-999.99',
        brandModel: 'Honda SH 150i ABS Sport Phiên Bản Đặc Biệt',
        status: 'approved',
        createdAt: DateTime(2026, 10, 1),
      ),
      VehicleModel(
        id: 'v-2',
        apartmentId: 'apt-1',
        vehicleType: 'car',
        licensePlate: '30H-888.88',
        brandModel: 'Mercedes-Benz GLC 300 4MATIC Sedan',
        status: 'pending',
        createdAt: DateTime(2026, 10, 2),
      ),
      VehicleModel(
        id: 'v-3',
        apartmentId: 'apt-1',
        vehicleType: 'motorbike',
        licensePlate: '29B-777.77',
        brandModel: 'Yamaha Grande Hybrid 2026',
        status: 'rejected',
        rejectionReason: 'Ảnh chụp giấy đăng ký xe bị mờ không đọc được số khung số máy',
        createdAt: DateTime(2026, 10, 3),
      ),
    ];

    final mockSlots = [
      ParkingSlotModel(
        id: 'slot-1',
        zone: 'B1',
        slotNumber: 'B1-M01',
        slotType: 'motorcycle',
        status: 'occupied',
        assignedVehicleId: 'v-1',
        createdAt: DateTime(2026, 1, 1),
      ),
    ];

    testWidgets('Render an toàn trên mobile 320dp x 600dp kèm font zoom 1.3x không tràn layout', (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            residentApartmentIdProvider.overrideWith((ref) => Future.value('apt-1')),
            apartmentVehiclesProvider('apt-1').overrideWith((ref) => Stream.value(mockVehicles)),
            apartmentVehicleCountsProvider('apt-1').overrideWith((ref) => Future.value({'motorbike': 2, 'car': 1})),
            parkingSlotsProvider.overrideWith((ref) => Future.value(mockSlots)),
          ],
          child: MaterialApp(
            theme: ThemeData(useMaterial3: true),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.3),
              ),
              child: child!,
            ),
            home: const VehicleManagementScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Xác minh không có lỗi RenderFlex
      expect(tester.takeException(), isNull);

      // Xác minh tiêu đề và thẻ hạn mức
      expect(find.text('Phương Tiện Căn Hộ'), findsOneWidget);
      expect(find.text('Hạn Mức Đăng Ký Căn Hộ'), findsOneWidget);

      // Cuộn để thấy danh sách xe
      await tester.scrollUntilVisible(find.text('29A-999.99'), 200);
      expect(find.text('29A-999.99'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Render trạm làm việc Web Desktop 1200dp đầy đủ nội dung', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            residentApartmentIdProvider.overrideWith((ref) => Future.value('apt-1')),
            apartmentVehiclesProvider('apt-1').overrideWith((ref) => Stream.value(mockVehicles)),
            apartmentVehicleCountsProvider('apt-1').overrideWith((ref) => Future.value({'motorbike': 2, 'car': 1})),
            parkingSlotsProvider.overrideWith((ref) => Future.value(mockSlots)),
          ],
          child: const MaterialApp(
            home: VehicleManagementScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Phương Tiện Căn Hộ'), findsOneWidget);
      expect(find.text('Hạn Mức Đăng Ký Căn Hộ'), findsOneWidget);
      expect(find.text('29A-999.99'), findsOneWidget);
    });
  });
}
