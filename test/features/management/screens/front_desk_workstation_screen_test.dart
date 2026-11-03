import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/front_desk_stats_model.dart';
import 'package:pka_home/data/models/parcel_model.dart';
import 'package:pka_home/data/models/user_model.dart';
import 'package:pka_home/data/models/visitor_pass_model.dart';
import 'package:pka_home/data/providers/auth_provider.dart';
import 'package:pka_home/data/providers/front_desk_provider.dart';
import 'package:pka_home/data/providers/role_delegation_provider.dart';
import 'package:pka_home/features/management/screens/front_desk_workstation_screen.dart';

class FakeAuthNotifier extends StateNotifier<AsyncValue<UserModel?>> implements AuthNotifier {
  FakeAuthNotifier(UserModel user) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final now = DateTime.now();

  final mockStats = const FrontDeskStatsModel(
    expectedVisitorsToday: 5,
    visitorsInBuilding: 2,
    pendingParcels: 14,
    overdueParcels: 2,
  );

  final mockVisitors = [
    VisitorPassModel(
      id: 'vp-01',
      passCode: 'VP-202611-00001',
      apartmentId: 'apt-01',
      apartmentCode: 'A0110',
      hostUserId: 'usr-01',
      visitorName: 'Vũ Đình Trọng',
      visitorPhone: '0901234567',
      licensePlate: '30E-123.45',
      vehicleType: 'car',
      visitorCount: 2,
      expectedArrival: now.add(const Duration(hours: 1)),
      purpose: 'visit',
      qrPayload: 'PKAPASS:VP-202611-00001:hash',
      status: 'pending',
      note: 'Ghé chơi chúc mừng tân gia',
      createdAt: now.subtract(const Duration(hours: 2)),
    ),
  ];

  final mockParcels = [
    ParcelModel(
      id: 'pcl-01',
      parcelCode: 'PCL-202611-00001',
      apartmentId: 'apt-01',
      apartmentCode: 'A0110',
      recipientName: 'Chị Mai',
      carrier: 'SPX',
      trackingNumber: 'SPXVN998811',
      description: 'Mỹ phẩm dưỡng da',
      shelfLocation: 'Kệ A1',
      pickupPin: '582914',
      status: 'arrived',
      arrivedAt: now.subtract(const Duration(hours: 3)),
      createdAt: now.subtract(const Duration(hours: 3)),
    ),
  ];

  Widget createTestWidget() {
    return ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => FakeAuthNotifier(
              UserModel(id: 'usr-admin', fullName: 'Lễ Tân Tòa Nhà', role: 'admin'),
            )),
        activeDelegationsProvider.overrideWith((ref) => Stream.value([])),
        frontDeskStatsProvider.overrideWith((ref) async => mockStats),
        visitorPassesProvider.overrideWith((ref, filter) async => mockVisitors),
        parcelsProvider.overrideWith((ref, filter) async => mockParcels),
      ],
      child: const MaterialApp(
        home: FrontDeskWorkstationScreen(),
      ),
    );
  }

  testWidgets('FrontDeskWorkstationScreen hien thi day du 2 tabs va thong tin KPI', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // 1. Kiểm tra tiêu đề màn hình và 2 Tabs
    expect(find.text('Trạm Lễ Tân & An Ninh'), findsOneWidget);
    expect(find.text('Khách vào ra'), findsOneWidget);
    expect(find.text('Bưu kiện sảnh'), findsOneWidget);

    // 2. Tab 1: Khách viếng thăm
    expect(find.text('Vũ Đình Trọng'), findsOneWidget);
    expect(find.textContaining('A0110'), findsWidgets);
    expect(find.text('VP-202611-00001'), findsOneWidget);
    expect(find.text('Chờ đến'), findsWidgets);

    // 3. Chuyển sang Tab 2: Bưu kiện
    await tester.tap(find.text('Bưu kiện sảnh'));
    await tester.pumpAndSettle();

    expect(find.text('PCL-202611-00001'), findsOneWidget);
    expect(find.text('Mỹ phẩm dưỡng da'), findsOneWidget);
    expect(find.textContaining('Kệ A1'), findsWidgets);
    expect(find.text('Chờ nhận tại kệ'), findsWidgets);
  });
}

