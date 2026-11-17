import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivona/data/models/parking_slot_model.dart';
import 'package:vivona/data/models/vehicle_model.dart';
import 'package:vivona/data/providers/parking_provider.dart';
import 'package:vivona/data/providers/vehicle_provider.dart';
import 'package:vivona/features/resident/screens/vehicle_management_screen.dart';

void main() {
  group('Vehicle Proof & Slot Allocation Resident Screen Tests', () {
    testWidgets('VehicleManagementScreen hiển thị ảnh minh chứng cà vẹt và vị trí ô đỗ ô tô', (tester) async {
      final mockVehicles = [
        VehicleModel(
          id: 'v-car-01',
          apartmentId: 'apt-1',
          vehicleType: 'car',
          licensePlate: '30E-999.88',
          brandModel: 'Mazda CX-5',
          status: 'approved',
          registrationImageUrl: 'apt-1/usr-1/cavat.jpg',
          parkingSlotId: 'slot-b1-05',
          parkingSlotNumber: 'P-B1-05',
          createdAt: DateTime(2026, 11, 1),
        ),
      ];

      final mockSlots = [
        ParkingSlotModel(
          id: 'slot-b1-05',
          zone: 'B1',
          slotNumber: 'P-B1-05',
          slotType: 'car',
          status: 'occupied',
          assignedVehicleId: 'v-car-01',
          assignedApartmentId: 'apt-1',
          createdAt: DateTime(2026, 11, 1),
        ),
      ];

      tester.view.physicalSize = const Size(800, 1400);
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
            parkingSlotsProvider.overrideWith((ref) => Future.value(mockSlots)),
          ],
          child: const MaterialApp(
            home: VehicleManagementScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Kiểm tra thông tin xe và biển số
      expect(find.text('30E-999.88'), findsOneWidget);
      expect(find.textContaining('Mazda CX-5'), findsOneWidget);

      // Kiểm tra vị trí ô đỗ P-B1-05
      expect(find.textContaining('Vị trí ô đỗ: P-B1-05 (Tầng B1)'), findsOneWidget);

      // Kiểm tra nút xem ảnh cà vẹt xe
      expect(find.text('Xem ảnh cà vẹt xe'), findsOneWidget);
      expect(find.byIcon(Icons.badge_outlined), findsOneWidget);
    });

    testWidgets('Modal Đăng ký xe mới có khu vực tải ảnh Cà vẹt / Giấy đăng ký xe', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            residentApartmentIdProvider.overrideWith((ref) => Future.value('apt-1')),
            apartmentVehiclesProvider('apt-1').overrideWith((ref) => Stream.value([])),
            parkingSlotsProvider.overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(
            home: VehicleManagementScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Bấm nút Đăng ký mới
      final addBtn = find.text('Đăng ký mới');
      expect(addBtn, findsOneWidget);
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      // Kiểm tra hiển thị tiêu đề và khu vực tải ảnh cà vẹt
      expect(find.text('Đăng Ký Phương Tiện Mới'), findsOneWidget);
      expect(find.text('Minh chứng giấy đăng ký xe (Cà vẹt)'), findsOneWidget);
      expect(find.text('Tải lên ảnh Cà vẹt / Giấy đăng ký xe'), findsOneWidget);
      expect(find.byIcon(Icons.add_a_photo_outlined), findsOneWidget);
    });
  });
}
