import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pka_home/data/models/user_model.dart';
import 'package:pka_home/data/models/vehicle_model.dart';
import 'package:pka_home/data/providers/auth_provider.dart';
import 'package:pka_home/data/providers/vehicle_provider.dart';
import 'package:pka_home/data/repositories/vehicle_repository.dart';
import 'package:pka_home/features/management/screens/vehicle_approval_screen.dart';

class FakeAuthNotifier extends StateNotifier<AsyncValue<UserModel?>> implements AuthNotifier {
  FakeAuthNotifier(UserModel user) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockVehicleRepository implements VehicleRepository {
  bool approveCalled = false;
  bool rejectCalled = false;
  String? lastVehicleId;
  String? lastRejectionReason;

  @override
  Future<void> approveVehicle(String vehicleId) async {
    approveCalled = true;
    lastVehicleId = vehicleId;
  }

  @override
  Future<void> rejectVehicle(String vehicleId, {String? reason}) async {
    rejectCalled = true;
    lastVehicleId = vehicleId;
    lastRejectionReason = reason;
  }

  @override
  Future<List<VehicleModel>> getAllVehicles({String? status}) async {
    final list = [
      VehicleModel(
        id: 'veh-1',
        apartmentId: 'apt-1',
        vehicleType: 'motorbike',
        licensePlate: '29A-123.45',
        brandModel: 'Honda Vision',
        status: 'pending',
        createdAt: DateTime(2026, 10, 5, 10, 0),
      ),
      VehicleModel(
        id: 'veh-2',
        apartmentId: 'apt-2',
        vehicleType: 'car',
        licensePlate: '30F-999.99',
        brandModel: 'Mazda CX-5',
        status: 'approved',
        createdAt: DateTime(2026, 10, 4, 15, 30),
      ),
      VehicleModel(
        id: 'veh-3',
        apartmentId: 'apt-1',
        vehicleType: 'motorbike',
        licensePlate: '29B-888.88',
        brandModel: 'Yamaha NVX',
        status: 'rejected',
        rejectionReason: 'Vượt quá hạn mức xe máy',
        createdAt: DateTime(2026, 10, 3, 9, 0),
      ),
    ];

    if (status != null) {
      return list.where((v) => v.status == status).toList();
    }
    return list;
  }

  @override
  Future<void> updateVehicleStatus(String vehicleId, String status, {String? reason}) async {}

  @override
  Future<void> deleteVehicle(String vehicleId) async {}

  @override
  Future<VehicleModel> registerVehicle({
    required String apartmentId,
    required String plateNumber,
    required String vehicleType,
    required String userId,
    String? brandModel,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<Map<String, int>> getVehicleCounts(String apartmentId) async => {'motorbike': 1, 'car': 1};

  @override
  Future<int> getActiveMotorbikeCount(String apartmentId) async => 1;

  @override
  Future<List<VehicleModel>> getVehiclesByApartment(String apartmentId) async => [];

  @override
  Stream<List<VehicleModel>> streamVehiclesByApartment(String apartmentId) => const Stream.empty();
}

void main() {
  final adminUser = UserModel(
    id: 'admin-1',
    fullName: 'Ban Quản Trị',
    phone: '0988888888',
    role: 'admin',
  );

  testWidgets('VehicleApprovalScreen hiển thị danh sách phương tiện và phê duyệt thành công', (tester) async {
    final mockRepo = MockVehicleRepository();

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
          vehicleRepositoryProvider.overrideWithValue(mockRepo),
          allVehiclesProvider.overrideWith((ref, status) => mockRepo.getAllVehicles(status: status)),
          pendingVehiclesCountProvider.overrideWith((ref) => 1),
        ],
        child: const MaterialApp(
          home: VehicleApprovalScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Kiểm tra tiêu đề và tabs
    expect(find.text('Duyệt Đăng Ký Phương Tiện'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Tất cả'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Chờ duyệt'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Đã duyệt'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Đã từ chối'), findsOneWidget);

    // 2. Kiểm tra danh sách xe
    expect(find.text('29A-123.45'), findsOneWidget);
    expect(find.textContaining('Honda Vision'), findsOneWidget);
    expect(find.textContaining('100.000'), findsNWidgets(2));

    expect(find.text('30F-999.99'), findsOneWidget);
    expect(find.textContaining('Mazda CX-5'), findsOneWidget);
    expect(find.textContaining('1.200.000'), findsOneWidget);

    // 3. Kiểm tra hiển thị lý do từ chối của xe veh-3
    expect(find.textContaining('Lý do từ chối: Vượt quá hạn mức xe máy'), findsOneWidget);

    // 4. Kiểm tra nút thao tác cho xe chờ duyệt (veh-1)
    final approveBtn = find.widgetWithText(ElevatedButton, 'Phê duyệt');
    expect(approveBtn, findsOneWidget);

    final rejectBtn = find.widgetWithText(OutlinedButton, 'Từ chối');
    expect(rejectBtn, findsOneWidget);

    // 5. Nhấn nút Phê duyệt và xác nhận trong dialog
    await tester.tap(approveBtn);
    await tester.pumpAndSettle();

    expect(find.text('Phê Duyệt Đăng Ký Xe'), findsOneWidget);
    expect(find.text('Xác nhận duyệt'), findsOneWidget);

    await tester.tap(find.text('Xác nhận duyệt'));
    await tester.pumpAndSettle();

    expect(mockRepo.approveCalled, isTrue);
    expect(mockRepo.lastVehicleId, 'veh-1');
    expect(find.textContaining('Đã phê duyệt thành công'), findsOneWidget);
  });

  testWidgets('VehicleApprovalScreen từ chối xe kèm lý do từ quick chip', (tester) async {
    final mockRepo = MockVehicleRepository();

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
          vehicleRepositoryProvider.overrideWithValue(mockRepo),
          allVehiclesProvider.overrideWith((ref, status) => mockRepo.getAllVehicles(status: status)),
          pendingVehiclesCountProvider.overrideWith((ref) => 1),
        ],
        child: const MaterialApp(
          home: VehicleApprovalScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Nhấn nút Từ chối của xe pending
    final rejectBtn = find.widgetWithText(OutlinedButton, 'Từ chối');
    expect(rejectBtn, findsOneWidget);
    await tester.tap(rejectBtn);
    await tester.pumpAndSettle();

    // Kiểm tra dialog từ chối
    expect(find.text('Từ Chối Đăng Ký'), findsOneWidget);
    expect(find.text('Lý do từ chối (tùy chọn):'), findsOneWidget);
    expect(find.text('Biển số không hợp lệ'), findsOneWidget);
    expect(find.text('Vượt quá hạn mức xe máy'), findsOneWidget);

    // Chọn quick chip "Biển số không hợp lệ"
    await tester.tap(find.text('Biển số không hợp lệ'));
    await tester.pumpAndSettle();

    // Nhấn nút Từ chối trong dialog
    final confirmRejectBtn = find.widgetWithText(ElevatedButton, 'Từ chối');
    await tester.tap(confirmRejectBtn);
    await tester.pumpAndSettle();

    // Kiểm tra mock repo nhận đúng id và lý do
    expect(mockRepo.rejectCalled, isTrue);
    expect(mockRepo.lastVehicleId, 'veh-1');
    expect(mockRepo.lastRejectionReason, 'Biển số không hợp lệ');
  });
}
