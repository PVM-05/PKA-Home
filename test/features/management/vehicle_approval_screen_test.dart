import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pka_home/data/models/vehicle_model.dart';
import 'package:pka_home/data/providers/vehicle_provider.dart';
import 'package:pka_home/data/repositories/vehicle_repository.dart';
import 'package:pka_home/features/management/screens/vehicle_approval_screen.dart';

class MockVehicleRepository implements VehicleRepository {
  bool approveCalled = false;
  bool rejectCalled = false;
  String? lastVehicleId;

  @override
  Future<void> approveVehicle(String vehicleId) async {
    approveCalled = true;
    lastVehicleId = vehicleId;
  }

  @override
  Future<void> rejectVehicle(String vehicleId) async {
    rejectCalled = true;
    lastVehicleId = vehicleId;
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
    ];

    if (status != null) {
      return list.where((v) => v.status == status).toList();
    }
    return list;
  }

  @override
  Future<void> updateVehicleStatus(String vehicleId, String status) async {}

  @override
  Future<void> deleteVehicle(String vehicleId) async {}

  @override
  Future<VehicleModel> registerVehicle({
    required String apartmentId,
    required String plateNumber,
    required String vehicleType,
    required String userId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<Map<String, int>> getVehicleCounts(String apartmentId) async => {'motorbike': 1, 'car': 1};

  @override
  Future<List<VehicleModel>> getVehiclesByApartment(String apartmentId) async => [];

  @override
  Stream<List<VehicleModel>> streamVehiclesByApartment(String apartmentId) => const Stream.empty();
}

void main() {
  testWidgets('VehicleApprovalScreen hiển thị danh sách phương tiện và phê duyệt thành công', (tester) async {
    final mockRepo = MockVehicleRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
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
    expect(find.text('Tất cả'), findsOneWidget);
    expect(find.text('Chờ duyệt'), findsOneWidget);
    expect(find.text('Đã duyệt'), findsOneWidget);
    expect(find.text('Đã từ chối'), findsOneWidget);

    // 2. Kiểm tra danh sách xe
    expect(find.text('29A-123.45'), findsOneWidget);
    expect(find.textContaining('Honda Vision'), findsOneWidget);
    expect(find.textContaining('100.000'), findsOneWidget);

    expect(find.text('30F-999.99'), findsOneWidget);
    expect(find.textContaining('Mazda CX-5'), findsOneWidget);
    expect(find.textContaining('1.200.000'), findsOneWidget);

    // 3. Kiểm tra nút thao tác cho xe chờ duyệt (veh-1)
    final approveBtn = find.widgetWithText(ElevatedButton, 'Phê duyệt');
    expect(approveBtn, findsOneWidget);

    final rejectBtn = find.widgetWithText(OutlinedButton, 'Từ chối');
    expect(rejectBtn, findsOneWidget);

    // 4. Nhấn nút Phê duyệt và xác nhận trong dialog
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
}
