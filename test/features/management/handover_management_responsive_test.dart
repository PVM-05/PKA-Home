import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/apartment_asset_model.dart';
import 'package:pka_home/data/models/apartment_handover_model.dart';
import 'package:pka_home/data/models/handover_item_model.dart';
import 'package:pka_home/data/models/user_model.dart';
import 'package:pka_home/data/providers/auth_provider.dart';
import 'package:pka_home/data/providers/handover_provider.dart';
import 'package:pka_home/data/repositories/handover_repository.dart';
import 'package:pka_home/features/management/screens/handover_management_screen.dart';
import 'package:pka_home/features/management/screens/inspection_workstation_screen.dart';

class FakeAuthNotifier extends StateNotifier<AsyncValue<UserModel?>> implements AuthNotifier {
  FakeAuthNotifier(UserModel user) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeHandoverRepository extends Fake implements HandoverRepository {
  final ApartmentHandoverModel? handoverDetail;

  FakeHandoverRepository({this.handoverDetail});

  @override
  Future<ApartmentHandoverModel?> fetchHandoverDetail(String handoverId) async => handoverDetail;

  @override
  Future<List<ApartmentHandoverModel>> fetchHandoversByBuilding(
    String buildingId, {
    String? status,
    String? type,
  }) async =>
      handoverDetail != null ? [handoverDetail!] : [];

  @override
  Future<List<ApartmentAssetModel>> fetchAssetsByApartment(String apartmentId) async => [];
}

void main() {
  group('HandoverManagement & Inspection Responsive & Anti-RenderFlex Tests', () {
    final adminUser = UserModel(
      id: 'admin-01',
      fullName: 'Quản Lý Trưởng',
      role: 'admin',
    );

    final mockHandover = ApartmentHandoverModel(
      id: 'ho-01',
      apartmentId: 'apt-01',
      buildingId: 'bld-01',
      residentId: 'res-01',
      handoverType: 'move_out',
      reportCode: 'HO-202611-00001',
      handoverDate: DateTime(2026, 11, 9, 10, 0),
      conductedBy: 'staff-01',
      initialElectricityReading: 1540.0,
      initialWaterReading: 85.0,
      depositHeld: 10000000.0,
      totalDeduction: 1200000.0,
      depositRefund: 8800000.0,
      status: 'pending_resident',
      lookupCode: 'HK-TEST01',
      apartmentCode: 'A0110',
      residentName: 'Nguyễn Văn An Cư Dân Mẫu Mực',
      staffName: 'Trần Kỹ Thuật Trưởng',
      items: [
        const HandoverItemModel(
          id: 'item-01',
          handoverId: 'ho-01',
          itemName: 'Điều hòa Daikin Inverter 1.5HP Tiết Kiệm Điện',
          roomArea: 'bedroom',
          condition: 'good',
        ),
        const HandoverItemModel(
          id: 'item-02',
          handoverId: 'ho-01',
          itemName: 'Mặt đá bếp Granit tự nhiên',
          roomArea: 'kitchen',
          condition: 'damaged',
          repairCost: 500000.0,
          note: 'Vết nứt góc phải cạnh bồn rửa chén',
        ),
      ],
    );

    Widget buildTestWidget(Widget screen, {double textScale = 1.0}) {
      return ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => FakeAuthNotifier(adminUser)),
          handoverRepositoryProvider.overrideWithValue(FakeHandoverRepository(handoverDetail: mockHandover)),
          buildingHandoversProvider.overrideWith((ref, buildingId) async => [mockHandover]),
          handoverDetailProvider.overrideWith((ref, id) async => mockHandover),
        ],
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
            ),
            child: child!,
          ),
          home: screen,
        ),
      );
    }

    testWidgets('HandoverManagementScreen render an toan tren mobile 320dp x 600dp kem text scale 1.3x', (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget(
        const HandoverManagementScreen(buildingId: 'bld-01'),
        textScale: 1.3,
      ));
      await tester.pumpAndSettle();

      final err = tester.takeException();
      expect(err, isNull);
      expect(find.text('Quản lý bàn giao & kiểm kê'), findsOneWidget);
      expect(find.text('HO-202611-00001'), findsOneWidget);
    });

    testWidgets('HandoverManagementScreen render Executive KPI Bar va Data Grid tren Desktop Web 1200dp', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget(
        const HandoverManagementScreen(buildingId: 'bld-01'),
      ));
      await tester.pumpAndSettle();

      final err = tester.takeException();
      expect(err, isNull);
      expect(find.text('Quản lý bàn giao & kiểm kê'), findsOneWidget);
      expect(find.text('HO-202611-00001'), findsOneWidget);
      expect(find.text('Mở trạm kiểm kê'), findsOneWidget);
    });

    testWidgets('InspectionWorkstationScreen render an toan tren mobile 320dp x 600dp kem text scale 1.3x', (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget(
        const InspectionWorkstationScreen(
          buildingId: 'bld-01',
          apartmentId: 'apt-01',
          apartmentCode: 'A0110',
          existingHandoverId: 'ho-01',
        ),
        textScale: 1.3,
      ));
      await tester.pumpAndSettle();

      final err = tester.takeException();
      expect(err, isNull);
      expect(find.text('Trạm kiểm kê & bàn giao'), findsOneWidget);
      expect(find.textContaining('A0110'), findsWidgets);
    });

    testWidgets('InspectionWorkstationScreen render Split-Screen tren Desktop Web 1200dp', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget(
        const InspectionWorkstationScreen(
          buildingId: 'bld-01',
          apartmentId: 'apt-01',
          apartmentCode: 'A0110',
          existingHandoverId: 'ho-01',
        ),
      ));
      await tester.pumpAndSettle();

      final err = tester.takeException();
      expect(err, isNull);
      expect(find.text('Trạm kiểm kê & bàn giao'), findsOneWidget);
      expect(find.textContaining('A0110'), findsWidgets);
    });
  });
}
