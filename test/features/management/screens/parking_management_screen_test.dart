import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/parking_capacity_stats_model.dart';
import 'package:pka_home/data/models/parking_slot_model.dart';
import 'package:pka_home/data/models/visitor_parking_ticket_model.dart';
import 'package:pka_home/data/providers/parking_provider.dart';
import 'package:pka_home/data/repositories/parking_repository.dart';
import 'package:pka_home/features/management/screens/parking_management_screen.dart';

class FakeParkingRepo extends ParkingRepository {
  final List<ParkingSlotModel> mockSlots;
  final List<VisitorParkingTicketModel> mockTickets;
  final ParkingCapacityStatsModel mockStats;

  FakeParkingRepo({
    required this.mockSlots,
    required this.mockTickets,
    required this.mockStats,
  });

  @override
  Future<List<ParkingSlotModel>> fetchSlots({
    String? buildingId,
    String? zone,
    String? slotType,
    String? status,
  }) async {
    return mockSlots;
  }

  @override
  Future<ParkingCapacityStatsModel> fetchCapacityStats({String? buildingId}) async {
    return mockStats;
  }

  @override
  Future<List<VisitorParkingTicketModel>> fetchActiveVisitorTickets({String? buildingId}) async {
    return mockTickets;
  }
}

void main() {
  final mockSlots = [
    ParkingSlotModel(
      id: 'slot-01',
      zone: 'B1',
      slotNumber: 'P-B1-01',
      slotType: 'car',
      status: 'occupied',
      licensePlate: '30A-999.88',
      apartmentCode: 'A0101',
      createdAt: DateTime.now(),
    ),
    ParkingSlotModel(
      id: 'slot-02',
      zone: 'B1',
      slotNumber: 'P-B1-02',
      slotType: 'car',
      status: 'available',
      createdAt: DateTime.now(),
    ),
  ];

  final mockTickets = [
    VisitorParkingTicketModel(
      id: 'tkt-01',
      ticketCode: 'TKT-202611-0001',
      licensePlate: '29V1-123.45',
      vehicleType: 'motorcycle',
      checkInAt: DateTime.now().subtract(const Duration(minutes: 30)),
      status: 'in_parking',
      feeAmount: 5000,
      qrPayload: 'PKAPARKING:TKT-202611-0001:29V1-123.45',
      createdAt: DateTime.now(),
    ),
  ];

  final mockStats = ParkingCapacityStatsModel(
    carTotal: 20,
    carOccupied: 1,
    carAvailable: 19,
    motoTotal: 30,
    motoOccupied: 0,
    motoAvailable: 30,
    visitorCount: 1,
  );

  Widget createTestWidget() {
    return ProviderScope(
      overrides: [
        parkingRepositoryProvider.overrideWithValue(
          FakeParkingRepo(
            mockSlots: mockSlots,
            mockTickets: mockTickets,
            mockStats: mockStats,
          ),
        ),
      ],
      child: const MaterialApp(
        home: ParkingManagementScreen(),
      ),
    );
  }

  testWidgets('ParkingManagementScreen hien thi 2 tabs va thong tin o do B1', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Quản Lý Bãi Xe & Ô Đỗ'), findsOneWidget);
    expect(find.text('Sơ đồ Ô đỗ'), findsOneWidget);
    expect(find.text('Trạm soát vé cổng'), findsOneWidget);

    // Tab 1: Slots Grid
    expect(find.text('P-B1-01'), findsOneWidget);
    expect(find.text('30A-999.88'), findsOneWidget);
    expect(find.text('P-B1-02'), findsOneWidget);
    expect(find.text('Còn trống'), findsOneWidget);
  });

  testWidgets('ParkingManagementScreen chuyen sang Tram soat ve va hien thi ve xe', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Chuyển sang Tab 2
    await tester.tap(find.text('Trạm soát vé cổng'));
    await tester.pumpAndSettle();

    expect(find.text('Check-in Xe Vào'), findsOneWidget);
    expect(find.text('29V1-123.45'), findsOneWidget);
    expect(find.text('Loại xe: Xe máy'), findsOneWidget);
    expect(find.text('Đang gửi'), findsWidgets);
    expect(find.text('Check-out & Thu tiền'), findsOneWidget);
  });
}
