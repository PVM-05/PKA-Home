import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/core/widgets/building_switcher_dropdown.dart';
import 'package:pka_home/data/models/building_model.dart';
import 'package:pka_home/data/providers/building_provider.dart';

void main() {
  group('BuildingSwitcherDropdown Widget Tests', () {
    testWidgets('renders single building badge when only 1 building', (tester) async {
      final sampleBuildings = [
        BuildingModel(
          id: 'b-1',
          organizationId: 'org-1',
          name: 'Tòa Landmark PKA',
          code: 'PKAL',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userBuildingsProvider.overrideWith((ref) => Future.value(sampleBuildings)),
            activeBuildingIdProvider.overrideWith((ref) => ActiveBuildingIdNotifier()..setBuildingId('b-1')),
          ],
          child: const MaterialApp(
            home: Scaffold(
              appBar: PreferredSize(
                preferredSize: Size.fromHeight(56),
                child: BuildingSwitcherDropdown(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tòa Landmark PKA'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_drop_down), findsNothing);
    });

    testWidgets('renders dropdown and switches active building when multiple buildings', (tester) async {
      final sampleBuildings = [
        BuildingModel(
          id: 'b-1',
          organizationId: 'org-1',
          name: 'Tòa Landmark PKA',
          code: 'PKAL',
        ),
        BuildingModel(
          id: 'b-2',
          organizationId: 'org-1',
          name: 'Tòa Park 2',
          code: 'PKAP2',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userBuildingsProvider.overrideWith((ref) => Future.value(sampleBuildings)),
            activeBuildingIdProvider.overrideWith((ref) => ActiveBuildingIdNotifier()..setBuildingId('b-1')),
          ],
          child: const MaterialApp(
            home: Scaffold(
              appBar: PreferredSize(
                preferredSize: Size.fromHeight(56),
                child: BuildingSwitcherDropdown(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tòa Landmark PKA'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);

      // Nhấn mở menu chọn tòa nhà
      await tester.tap(find.text('Tòa Landmark PKA'));
      await tester.pumpAndSettle();

      expect(find.text('Tòa Park 2'), findsOneWidget);

      // Chọn Tòa Park 2
      await tester.tap(find.text('Tòa Park 2'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Đã chuyển sang quản lý: Tòa Park 2'), findsOneWidget);
    });
  });
}
