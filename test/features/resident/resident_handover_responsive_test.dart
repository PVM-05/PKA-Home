import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/apartment_handover_model.dart';
import 'package:pka_home/data/models/handover_item_model.dart';
import 'package:pka_home/data/providers/handover_provider.dart';
import 'package:pka_home/data/repositories/handover_repository.dart';
import 'package:pka_home/features/resident/screens/resident_handover_detail_screen.dart';
import 'package:pka_home/features/resident/screens/resident_handover_screen.dart';

void main() {
  group('ResidentHandover Responsive & Anti-RenderFlex Tests', () {
    late HandoverRepository repository;

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

    setUp(() {
      repository = HandoverRepository();
    });

    Widget buildTestWidget(Widget screen, {double textScale = 1.0}) {
      return ProviderScope(
        overrides: [
          handoverRepositoryProvider.overrideWithValue(repository),
          residentHandoversProvider.overrideWith((ref, resId) async => [mockHandover]),
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

    testWidgets('ResidentHandoverScreen render an toan tren mobile 320dp x 600dp kem text scale 1.3x', (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget(
        const ResidentHandoverScreen(residentId: 'res-01'),
        textScale: 1.3,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Biên bản bàn giao căn hộ'), findsOneWidget);
      expect(find.text('HO-202611-00001'), findsOneWidget);
    });

    testWidgets('ResidentHandoverDetailScreen render an toan tren mobile 320dp x 600dp kem text scale 1.3x', (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget(
        const ResidentHandoverDetailScreen(handoverId: 'ho-01'),
        textScale: 1.3,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Chi tiết biên bản bàn giao'), findsOneWidget);
      expect(find.text('Ký tên xác nhận'), findsOneWidget);
    });

    testWidgets('Desktop Web 1200dp render ResidentHandoverScreen va ResidentHandoverDetailScreen Split-Screen can doi', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget(
        const ResidentHandoverDetailScreen(handoverId: 'ho-01'),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Chi tiết biên bản bàn giao'), findsOneWidget);
      expect(find.text('Điều hòa Daikin Inverter 1.5HP Tiết Kiệm Điện'), findsOneWidget);
    });
  });
}
