import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/user_model.dart';
import 'package:pka_home/data/models/vehicle_model.dart';
import 'package:pka_home/data/providers/auth_provider.dart';
import 'package:pka_home/data/providers/vehicle_provider.dart';
import 'package:pka_home/data/providers/parking_provider.dart';
import 'package:pka_home/data/repositories/vehicle_repository.dart';
import 'package:pka_home/features/management/screens/vehicle_approval_screen.dart';

class MockVehicleRepository implements VehicleRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<VehicleModel>> getAllVehicles({String? status}) async {
    return [
      VehicleModel(
        id: 'veh-1',
        apartmentId: 'apt-1',
        vehicleType: 'motorbike',
        licensePlate: '29A-123.45',
        brandModel: 'Honda SH 150i ABS Sport',
        status: 'pending',
        createdAt: DateTime(2026, 10, 5, 10, 0),
      ),
      VehicleModel(
        id: 'veh-2',
        apartmentId: 'apt-2',
        vehicleType: 'car',
        licensePlate: '30F-999.99',
        brandModel: 'Mercedes-Benz GLC 300 4MATIC',
        status: 'approved',
        createdAt: DateTime(2026, 10, 4, 15, 30),
      ),
      VehicleModel(
        id: 'veh-3',
        apartmentId: 'apt-1',
        vehicleType: 'motorbike',
        licensePlate: '29B-888.88',
        brandModel: 'Yamaha Grande Hybrid',
        status: 'rejected',
        rejectionReason: 'Vượt quá hạn mức xe máy của căn hộ',
        createdAt: DateTime(2026, 10, 3, 9, 0),
      ),
    ];
  }
}

class FakeAuthNotifier extends StateNotifier<AsyncValue<UserModel?>>
    implements AuthNotifier {
  FakeAuthNotifier(UserModel user) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('VehicleApprovalScreen Responsive & Anti-RenderFlex Tests', () {
    final mockUser = UserModel(
      id: 'admin-1',
      fullName: 'Trưởng Ban Quản Lý',
      phone: '0901234567',
      role: 'admin',
    );

    final mockVehicles = [
      VehicleModel(
        id: 'veh-1',
        apartmentId: 'apt-1',
        vehicleType: 'motorbike',
        licensePlate: '29A-123.45',
        brandModel: 'Honda SH 150i ABS Sport',
        status: 'pending',
        createdAt: DateTime(2026, 10, 5, 10, 0),
      ),
      VehicleModel(
        id: 'veh-2',
        apartmentId: 'apt-2',
        vehicleType: 'car',
        licensePlate: '30F-999.99',
        brandModel: 'Mercedes-Benz GLC 300 4MATIC',
        status: 'approved',
        createdAt: DateTime(2026, 10, 4, 15, 30),
      ),
      VehicleModel(
        id: 'veh-3',
        apartmentId: 'apt-1',
        vehicleType: 'motorbike',
        licensePlate: '29B-888.88',
        brandModel: 'Yamaha Grande Hybrid',
        status: 'rejected',
        rejectionReason: 'Vượt quá hạn mức xe máy của căn hộ',
        createdAt: DateTime(2026, 10, 3, 9, 0),
      ),
    ];

    testWidgets('Render an toàn trên mobile 320dp x 600dp kèm text scale 1.3x không tràn layout', (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => FakeAuthNotifier(mockUser)),
            allVehiclesProvider(null).overrideWith((ref) => Future.value(mockVehicles)),
            allVehiclesProvider('pending').overrideWith((ref) => Future.value([mockVehicles[0]])),
            allVehiclesProvider('approved').overrideWith((ref) => Future.value([mockVehicles[1]])),
            allVehiclesProvider('rejected').overrideWith((ref) => Future.value([mockVehicles[2]])),
            pendingVehiclesCountProvider.overrideWith((ref) => Future.value(1)),
            parkingSlotsProvider.overrideWith((ref) => Future.value([])),
            vehicleRepositoryProvider.overrideWithValue(MockVehicleRepository()),
          ],
          child: MaterialApp(
            theme: ThemeData(useMaterial3: true),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.3),
              ),
              child: child!,
            ),
            home: const VehicleApprovalScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Xác minh không có lỗi RenderFlex
      expect(tester.takeException(), isNull);
      expect(find.text('Duyệt Đăng Ký Phương Tiện'), findsOneWidget);
      expect(find.text('29A-123.45'), findsOneWidget);
    });

    testWidgets('Render trạm làm việc Web Desktop 1200dp với Executive KPI Bar và bố cục lưới', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => FakeAuthNotifier(mockUser)),
            allVehiclesProvider(null).overrideWith((ref) => Future.value(mockVehicles)),
            pendingVehiclesCountProvider.overrideWith((ref) => Future.value(1)),
            parkingSlotsProvider.overrideWith((ref) => Future.value([])),
            vehicleRepositoryProvider.overrideWithValue(MockVehicleRepository()),
          ],
          child: const MaterialApp(
            home: VehicleApprovalScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Duyệt Đăng Ký Phương Tiện'), findsOneWidget);
      expect(find.text('Chờ duyệt'), findsWidgets);
      expect(find.text('29A-123.45'), findsOneWidget);
    });
  });
}
