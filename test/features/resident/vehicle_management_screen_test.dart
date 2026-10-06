import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/vehicle_model.dart';
import 'package:pka_home/data/providers/vehicle_provider.dart';
import 'package:pka_home/features/resident/screens/vehicle_management_screen.dart';

void main() {
  group('VehicleManagementScreen Widget Tests', () {
    testWidgets('VehicleManagementScreen hiển thị đúng danh sách phương tiện với các badge trạng thái', (tester) async {
      final mockVehicles = [
        VehicleModel(
          id: 'v-1',
          apartmentId: 'apt-1',
          vehicleType: 'motorbike',
          licensePlate: '29A-111.11',
          brandModel: 'Honda Vision',
          status: 'approved',
          createdAt: DateTime(2026, 10, 1),
        ),
        VehicleModel(
          id: 'v-2',
          apartmentId: 'apt-1',
          vehicleType: 'car',
          licensePlate: '30H-222.22',
          brandModel: 'Toyota Vios',
          status: 'pending',
          createdAt: DateTime(2026, 10, 2),
        ),
        VehicleModel(
          id: 'v-3',
          apartmentId: 'apt-1',
          vehicleType: 'motorbike',
          licensePlate: '29B-333.33',
          brandModel: 'Yamaha Grande',
          status: 'rejected',
          rejectionReason: 'Biển số xe không hợp lệ',
          createdAt: DateTime(2026, 10, 3),
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
          ],
          child: const MaterialApp(
            home: VehicleManagementScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Kiểm tra biển số xe và hãng xe
      expect(find.text('29A-111.11'), findsOneWidget);
      expect(find.textContaining('Honda Vision'), findsOneWidget);
      expect(find.text('30H-222.22'), findsOneWidget);
      expect(find.textContaining('Toyota Vios'), findsOneWidget);
      expect(find.text('29B-333.33'), findsOneWidget);
      expect(find.textContaining('Yamaha Grande'), findsOneWidget);

      // Kiểm tra các badge trạng thái
      expect(find.text('Đã phê duyệt'), findsOneWidget);
      expect(find.text('Chờ phê duyệt'), findsOneWidget);
      expect(find.text('Đã từ chối'), findsOneWidget);

      // Kiểm tra hiển thị lý do từ chối
      expect(find.textContaining('Lý do từ chối: Biển số xe không hợp lệ'), findsOneWidget);
    });

    testWidgets('Mở hộp thoại Đăng ký mới có trường Nhãn hiệu / Dòng xe và Biển số xe', (tester) async {
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
          ],
          child: const MaterialApp(
            home: VehicleManagementScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Đăng ký mới
      final addBtn = find.text('Đăng ký mới');
      expect(addBtn, findsOneWidget);
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      // Kiểm tra tiêu đề modal và các trường input
      expect(find.text('Đăng Ký Phương Tiện Mới'), findsOneWidget);
      expect(find.text('Hãng và mẫu xe (tùy chọn)'), findsOneWidget);
      expect(find.text('Biển số xe *'), findsOneWidget);
      expect(find.text('Xác Nhận Đăng Ký'), findsOneWidget);
    });

    testWidgets('Bấm xóa xe bị từ chối mở hộp thoại xác nhận xóa', (tester) async {
      final mockVehicles = [
        VehicleModel(
          id: 'v-rejected',
          apartmentId: 'apt-1',
          vehicleType: 'motorbike',
          licensePlate: '29B-999.99',
          brandModel: 'Yamaha Grande',
          status: 'rejected',
          rejectionReason: 'Biển số xe trùng lặp',
          createdAt: DateTime(2026, 10, 3),
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
          ],
          child: const MaterialApp(
            home: VehicleManagementScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find delete button
      final deleteBtn = find.byIcon(Icons.delete_forever_outlined);
      expect(deleteBtn, findsOneWidget);
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      // Kiểm tra AlertDialog hiển thị
      expect(find.text('Xóa Bản Ghi Bị Từ Chối'), findsOneWidget);
      expect(find.text('Xác nhận xóa'), findsOneWidget);
      expect(find.text('Hủy bỏ'), findsOneWidget);
    });
  });
}

