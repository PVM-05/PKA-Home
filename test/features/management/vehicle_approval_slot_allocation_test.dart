import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivona/data/models/parking_slot_model.dart';
import 'package:vivona/data/models/user_model.dart';
import 'package:vivona/data/models/vehicle_model.dart';
import 'package:vivona/data/providers/auth_provider.dart';
import 'package:vivona/data/providers/parking_provider.dart';
import 'package:vivona/data/providers/vehicle_provider.dart';
import 'package:vivona/data/repositories/parking_repository.dart';
import 'package:vivona/data/repositories/vehicle_repository.dart';
import 'package:vivona/features/management/screens/vehicle_approval_screen.dart';

class FakeAuthNotifier extends StateNotifier<AsyncValue<UserModel?>>
    implements AuthNotifier {
  FakeAuthNotifier(UserModel user) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeVehicleRepository extends Fake implements VehicleRepository {
  bool approveCalled = false;
  String? approvedId;
  String? assignedSlotId;
  String? assignedSlotNumber;

  final List<VehicleModel> vehicles;
  FakeVehicleRepository(this.vehicles);

  @override
  Future<List<VehicleModel>> getAllVehicles({String? status}) async {
    if (status != null) {
      return vehicles.where((v) => v.status == status).toList();
    }
    return vehicles;
  }

  @override
  String getRegistrationImageUrl(String? urlOrPath) => urlOrPath ?? '';

  @override
  Future<void> approveVehicle(
    String vehicleId, {
    String? parkingSlotId,
    String? parkingSlotNumber,
    String? approvedBy,
  }) async {
    approveCalled = true;
    approvedId = vehicleId;
    assignedSlotId = parkingSlotId;
    assignedSlotNumber = parkingSlotNumber;
  }
}

class FakeParkingRepository extends Fake implements ParkingRepository {
  final List<ParkingSlotModel> availableCarSlots;
  FakeParkingRepository(this.availableCarSlots);

  @override
  Future<List<ParkingSlotModel>> fetchAvailableCarSlots({
    String? buildingId,
    String? zone,
  }) async {
    return availableCarSlots;
  }
}

void main() {
  group('VehicleApprovalScreen Slot Allocation & Proof Tests', () {
    late UserModel adminUser;

    setUp(() {
      adminUser = UserModel(
        id: 'admin-01',
        fullName: 'Quản Lý Tòa Nhà',
        phone: '0901234567',
        role: 'admin',
      );
    });

    testWidgets('Hiển thị ảnh cà vẹt xe và vị trí ô đỗ trên thẻ phương tiện', (tester) async {
      final mockVehicles = [
        VehicleModel(
          id: 'v-car-approved',
          apartmentId: 'apt-01',
          vehicleType: 'car',
          licensePlate: '30E-888.88',
          brandModel: 'Mazda CX-5',
          status: 'approved',
          registrationImageUrl: 'apt-01/cavat.jpg',
          parkingSlotId: 'slot-b1-05',
          parkingSlotNumber: 'P-B1-05',
          createdAt: DateTime(2026, 11, 1),
        ),
      ];

      final fakeVehicleRepo = FakeVehicleRepository(mockVehicles);
      final fakeParkingRepo = FakeParkingRepository([]);

      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => FakeAuthNotifier(adminUser)),
            vehicleRepositoryProvider.overrideWithValue(fakeVehicleRepo),
            parkingRepositoryProvider.overrideWithValue(fakeParkingRepo),
            pendingVehiclesCountProvider.overrideWith((ref) => Future.value(0)),
          ],
          child: const MaterialApp(
            home: VehicleApprovalScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Kiểm tra biển số và biểu phí
      expect(find.text('30E-888.88'), findsOneWidget);
      expect(find.text('Vị trí ô đỗ: P-B1-05'), findsOneWidget);
      expect(find.text('Xem ảnh cà vẹt xe'), findsOneWidget);
      expect(find.byIcon(Icons.badge_outlined), findsOneWidget);
    });

    testWidgets('Phê duyệt xe ô tô hiển thị danh sách ô đỗ ô tô còn trống để gán', (tester) async {
      final mockVehicles = [
        VehicleModel(
          id: 'v-car-pending',
          apartmentId: 'apt-01',
          vehicleType: 'car',
          licensePlate: '30F-123.45',
          brandModel: 'Toyota Camry',
          status: 'pending',
          registrationImageUrl: 'apt-01/camry.jpg',
          createdAt: DateTime(2026, 11, 2),
        ),
      ];

      final availableSlots = [
        ParkingSlotModel(
          id: 'slot-b1-08',
          zone: 'B1',
          slotNumber: 'P-B1-08',
          slotType: 'car',
          status: 'available',
          createdAt: DateTime(2026, 11, 1),
        ),
        ParkingSlotModel(
          id: 'slot-b2-02',
          zone: 'B2',
          slotNumber: 'P-B2-02',
          slotType: 'car',
          status: 'available',
          createdAt: DateTime(2026, 11, 1),
        ),
      ];

      final fakeVehicleRepo = FakeVehicleRepository(mockVehicles);
      final fakeParkingRepo = FakeParkingRepository(availableSlots);

      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => FakeAuthNotifier(adminUser)),
            vehicleRepositoryProvider.overrideWithValue(fakeVehicleRepo),
            parkingRepositoryProvider.overrideWithValue(fakeParkingRepo),
            pendingVehiclesCountProvider.overrideWith((ref) => Future.value(1)),
          ],
          child: const MaterialApp(
            home: VehicleApprovalScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Bấm nút Phê duyệt
      final approveBtn = find.widgetWithText(ElevatedButton, 'Phê duyệt');
      expect(approveBtn, findsOneWidget);
      await tester.tap(approveBtn);
      await tester.pumpAndSettle();

      // Kiểm tra modal phê duyệt có dropdown gán ô đỗ
      expect(find.text('Phê Duyệt Đăng Ký Xe'), findsOneWidget);
      expect(find.text('Vị trí ô đỗ tầng hầm (B1/B2):'), findsOneWidget);
      expect(find.text('P-B1-08 (Tầng B1)'), findsOneWidget);

      // Bấm xác nhận duyệt
      final confirmBtn = find.widgetWithText(ElevatedButton, 'Xác nhận duyệt');
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Kiểm tra repository nhận lệnh approve với slot gán
      expect(fakeVehicleRepo.approveCalled, isTrue);
      expect(fakeVehicleRepo.approvedId, 'v-car-pending');
      expect(fakeVehicleRepo.assignedSlotId, 'slot-b1-08');
      expect(fakeVehicleRepo.assignedSlotNumber, 'P-B1-08');
    });
  });
}
