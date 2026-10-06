import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pka_home/data/models/apartment_model.dart';
import 'package:pka_home/data/models/user_model.dart';
import 'package:pka_home/data/models/vehicle_model.dart';
import 'package:pka_home/data/providers/auth_provider.dart';
import 'package:pka_home/data/providers/management_provider.dart';
import 'package:pka_home/data/providers/role_delegation_provider.dart';
import 'package:pka_home/data/providers/vehicle_provider.dart';
import 'package:pka_home/data/repositories/vehicle_repository.dart';
import 'package:pka_home/features/management/screens/create_invoice_screen.dart';

class FakeAuthNotifier extends StateNotifier<AsyncValue<UserModel?>> implements AuthNotifier {
  FakeAuthNotifier(UserModel user) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockVehicleBillingRepository implements VehicleRepository {
  String? lastApartmentIdQueried;
  final Map<String, Map<String, int>> countsByApartment;

  MockVehicleBillingRepository({required this.countsByApartment});

  @override
  Future<Map<String, int>> getVehicleCounts(String apartmentId) async {
    lastApartmentIdQueried = apartmentId;
    return countsByApartment[apartmentId] ?? {'motorbike': 0, 'car': 0};
  }

  @override
  Future<int> getActiveMotorbikeCount(String apartmentId) async => 0;

  @override
  Future<List<VehicleModel>> getAllVehicles({String? status}) async => [];

  @override
  Future<List<VehicleModel>> getVehiclesByApartment(String apartmentId) async => [];

  @override
  Stream<List<VehicleModel>> streamVehiclesByApartment(String apartmentId) => const Stream.empty();

  @override
  Future<VehicleModel> registerVehicle({
    required String apartmentId,
    required String plateNumber,
    required String vehicleType,
    required String userId,
    String? brandModel,
  }) async => throw UnimplementedError();

  @override
  Future<void> approveVehicle(String vehicleId) async {}

  @override
  Future<void> rejectVehicle(String vehicleId, {String? reason}) async {}

  @override
  Future<void> updateVehicleStatus(String vehicleId, String status, {String? reason}) async {}

  @override
  Future<void> deleteVehicle(String vehicleId) async {}
}

void main() {
  group('CreateInvoiceScreen Vehicle Billing Auto-Fill Tests', () {
    final mockUser = UserModel(
      id: 'manager-1',
      fullName: 'Trưởng Ban Quản Lý',
      role: 'management',
      phone: '0901234567',
    );

    final mockApartments = [
      ApartmentModel(
        id: 'apt-1',
        code: 'A0101',
        buildingCode: 'A',
        floorNumber: 1,
        area: 60.0,
        isEmpty: false,
      ),
      ApartmentModel(
        id: 'apt-2',
        code: 'A0102',
        buildingCode: 'A',
        floorNumber: 1,
        area: 70.0,
        isEmpty: false,
      ),
    ];

    testWidgets('Tự động điền số lượng xe đã duyệt vào trường tính phí gửi xe', (tester) async {
      final mockRepo = MockVehicleBillingRepository(
        countsByApartment: {
          'apt-1': {'motorbike': 2, 'car': 1},
          'apt-2': {'motorbike': 0, 'car': 0},
        },
      );

      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => FakeAuthNotifier(mockUser)),
            activeDelegationsProvider.overrideWith((ref) => Stream.value([])),
            apartmentsProvider.overrideWith((ref) => Future.value(mockApartments)),
            vehicleRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: CreateInvoiceScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Kiểm tra tiêu đề màn hình
      expect(find.text('Lập hóa đơn mới'), findsOneWidget);

      // Mở dropdown chọn căn hộ
      final dropdownFinder = find.byType(DropdownButtonFormField<ApartmentModel>);
      expect(dropdownFinder, findsOneWidget);
      await tester.tap(dropdownFinder);
      await tester.pumpAndSettle();

      // Chọn căn hộ A0101
      final aptOption = find.textContaining('A0101').last;
      await tester.tap(aptOption);
      await tester.pumpAndSettle();

      // Xác minh repository getVehicleCounts được gọi với apt-1
      expect(mockRepo.lastApartmentIdQueried, equals('apt-1'));

      // Kiểm tra số lượng xe tự động điền: 2 xe máy, 1 ô tô
      expect(find.widgetWithText(TextFormField, '2'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '1'), findsOneWidget);

      // Phí gửi xe: 2 * 100.000 + 1 * 1.200.000 = 1.400.000 đ
      expect(find.textContaining('1.400.000'), findsWidgets);
    });

    testWidgets('Căn hộ không có xe đã duyệt thì trường số xe để trống và phí gửi xe = 0 đ', (tester) async {
      final mockRepo = MockVehicleBillingRepository(
        countsByApartment: {
          'apt-2': {'motorbike': 0, 'car': 0},
        },
      );

      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => FakeAuthNotifier(mockUser)),
            activeDelegationsProvider.overrideWith((ref) => Stream.value([])),
            apartmentsProvider.overrideWith((ref) => Future.value(mockApartments)),
            vehicleRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: CreateInvoiceScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Mở dropdown chọn căn hộ A0102 (apt-2)
      final dropdownFinder = find.byType(DropdownButtonFormField<ApartmentModel>);
      await tester.tap(dropdownFinder);
      await tester.pumpAndSettle();

      final aptOption = find.textContaining('A0102').last;
      await tester.tap(aptOption);
      await tester.pumpAndSettle();

      expect(mockRepo.lastApartmentIdQueried, equals('apt-2'));

      // Phí gửi xe hiển thị 0 đ
      expect(find.textContaining('0 đ'), findsWidgets);
    });

    testWidgets('Xe trạng thái pending hoặc rejected không được tính vào biểu phí lập hóa đơn', (tester) async {
      // Giả lập apt-1 có xe nhưng đều là pending hoặc rejected,
      // getVehicleCounts chỉ trả về xe approved -> count = 0
      final mockRepo = MockVehicleBillingRepository(
        countsByApartment: {
          'apt-1': {'motorbike': 0, 'car': 0},
        },
      );

      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => FakeAuthNotifier(mockUser)),
            activeDelegationsProvider.overrideWith((ref) => Stream.value([])),
            apartmentsProvider.overrideWith((ref) => Future.value(mockApartments)),
            vehicleRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: CreateInvoiceScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final dropdownFinder = find.byType(DropdownButtonFormField<ApartmentModel>);
      await tester.tap(dropdownFinder);
      await tester.pumpAndSettle();

      final aptOption = find.textContaining('A0101').last;
      await tester.tap(aptOption);
      await tester.pumpAndSettle();

      expect(mockRepo.lastApartmentIdQueried, equals('apt-1'));

      // Các trường số xe máy và ô tô không bị điền số > 0
      final motorbikeField = find.widgetWithText(TextFormField, '');
      expect(motorbikeField, findsWidgets);
    });
  });
}
