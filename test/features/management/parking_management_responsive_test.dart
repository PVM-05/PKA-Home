import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivona/data/models/parking_capacity_stats_model.dart';
import 'package:vivona/data/models/parking_slot_model.dart';
import 'package:vivona/data/models/visitor_parking_ticket_model.dart';
import 'package:vivona/data/providers/parking_provider.dart';
import 'package:vivona/data/repositories/parking_repository.dart';
import 'package:vivona/features/management/screens/parking_management_screen.dart';

class MockParkingRepository extends ParkingRepository {
  final List<ParkingSlotModel> mockSlots;
  final List<VisitorParkingTicketModel> mockTickets;
  final ParkingCapacityStatsModel mockStats;

  MockParkingRepository({
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
  group('ParkingManagementScreen Responsive & Anti-RenderFlex Tests', () {
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
      ParkingSlotModel(
        id: 'slot-03',
        zone: 'B2',
        slotNumber: 'P-B2-15',
        slotType: 'motorcycle',
        status: 'occupied',
        licensePlate: '29V1-987.65',
        apartmentCode: 'B0212',
        createdAt: DateTime.now(),
      ),
    ];

    final mockTickets = [
      VisitorParkingTicketModel(
        id: 'tkt-01',
        ticketCode: 'TKT-202611-0001',
        licensePlate: '29V1-123.45',
        vehicleType: 'motorcycle',
        checkInAt: DateTime(2026, 11, 9, 8, 30),
        status: 'in_parking',
        feeAmount: 5000,
        note: 'Khách thăm cư dân căn hộ A0101 tháp A',
        qrPayload: 'PKAPARKING:TKT-202611-0001:29V1-123.45',
        createdAt: DateTime(2026, 11, 9, 8, 30),
      ),
      VisitorParkingTicketModel(
        id: 'tkt-02',
        ticketCode: 'TKT-202611-0002',
        licensePlate: '30E-888.99',
        vehicleType: 'car',
        checkInAt: DateTime(2026, 11, 9, 9, 15),
        status: 'in_parking',
        feeAmount: 25000,
        note: 'Khách đối tác công ty PKA Tech',
        qrPayload: 'PKAPARKING:TKT-202611-0002:30E-888.99',
        createdAt: DateTime(2026, 11, 9, 9, 15),
      ),
    ];

    final mockStats = ParkingCapacityStatsModel(
      carTotal: 40,
      carOccupied: 28,
      carAvailable: 12,
      motoTotal: 120,
      motoOccupied: 95,
      motoAvailable: 25,
      visitorCount: 14,
    );

    Widget buildTestWidget() {
      return ProviderScope(
        overrides: [
          parkingRepositoryProvider.overrideWithValue(
            MockParkingRepository(
              mockSlots: mockSlots,
              mockTickets: mockTickets,
              mockStats: mockStats,
            ),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.3),
            ),
            child: child!,
          ),
          home: const ParkingManagementScreen(),
        ),
      );
    }

    testWidgets('Render an toàn trên mobile 320dp x 600dp kèm text scale 1.3x trên cả 2 tabs', (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tab 1: Sơ đồ ô đỗ
      expect(tester.takeException(), isNull);
      expect(find.text('Quản Lý Bãi Xe & Ô Đỗ'), findsOneWidget);
      expect(find.text('P-B1-01'), findsOneWidget);
      expect(find.text('30A-999.88'), findsOneWidget);

      // Chuyển sang Tab 2: Trạm soát vé cổng
      await tester.tap(find.text('Trạm soát vé cổng'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('29V1-123.45'), findsOneWidget);

      // Cuộn để thấy vé thứ 2 trên màn hình 600dp
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('30E-888.99'), findsOneWidget);
    });

    testWidgets('Render trạm làm việc Web Desktop 1200dp cân đối trên cả 2 tabs', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tab 1: Sơ đồ ô đỗ
      expect(tester.takeException(), isNull);
      expect(find.text('Quản Lý Bãi Xe & Ô Đỗ'), findsOneWidget);
      expect(find.text('P-B1-01'), findsOneWidget);

      // Chuyển sang Tab 2: Trạm soát vé cổng
      await tester.tap(find.text('Trạm soát vé cổng'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('29V1-123.45'), findsOneWidget);
    });
  });
}
