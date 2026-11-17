import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivona/core/theme/app_theme.dart';
import 'package:vivona/data/models/maintenance_material_model.dart';
import 'package:vivona/data/providers/material_provider.dart';
import 'package:vivona/features/management/screens/maintenance_materials_screen.dart';

void main() {
  final mockMaterials = [
    MaintenanceMaterialModel(
      id: 'mat-1',
      code: 'ELEC-01',
      name: 'Bóng đèn LED Philips 18W Trắng',
      category: 'electrical',
      unit: 'bóng',
      unitPrice: 85000,
      stockQuantity: 42,
      minStockAlert: 10,
      createdAt: DateTime.now(),
    ),
    MaintenanceMaterialModel(
      id: 'mat-2',
      code: 'PLUMB-02',
      name: 'Van khóa nước đồng phi 21 Minh Hòa',
      category: 'plumbing',
      unit: 'cái',
      unitPrice: 120000,
      stockQuantity: 3,
      minStockAlert: 5,
      createdAt: DateTime.now(),
    ),
  ];

  Widget buildTestWidget({required Size screenSize, double textScale = 1.0}) {
    return ProviderScope(
      overrides: [
        maintenanceMaterialsProvider(null).overrideWith((ref) => Future.value(mockMaterials)),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: MediaQueryData(
            size: screenSize,
            textScaler: TextScaler.linear(textScale),
          ),
          child: const MaintenanceMaterialsScreen(),
        ),
      ),
    );
  }

  group('MaintenanceMaterials Responsive & Anti-RenderFlex Tests', () {
    testWidgets('MaintenanceMaterialsScreen renders safely on 320dp mobile with 1.3x text zoom', (tester) async {
      tester.view.physicalSize = const Size(320 * 2, 600 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget(screenSize: const Size(320, 600), textScale: 1.3));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Kho Vật Tư Kỹ Thuật'), findsOneWidget);
      expect(find.text('Bóng đèn LED Philips 18W Trắng'), findsOneWidget);
      expect(find.text('Tồn: 3 cái'), findsOneWidget);
    });

    testWidgets('MaintenanceMaterialsScreen renders centered on 1200dp desktop width', (tester) async {
      tester.view.physicalSize = const Size(1200 * 2, 800 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget(screenSize: const Size(1200, 800)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Kho Vật Tư Kỹ Thuật'), findsOneWidget);
      expect(find.text('Tổng loại vật tư'), findsOneWidget);
    });
  });
}
