import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/core/widgets/adaptive_management_scaffold.dart';

void main() {
  const testDestinations = [
    AdaptiveNavigationItem(
      label: 'Tổng quan',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
    ),
    AdaptiveNavigationItem(
      label: 'Kế toán',
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long,
    ),
    AdaptiveNavigationItem(
      label: 'Cư dân',
      icon: Icons.people_outline,
      selectedIcon: Icons.people,
    ),
  ];

  Widget buildScaffold({
    required int selectedIndex,
    required ValueChanged<int> onDestinationSelected,
    Widget? sidebarHeader,
    Widget? sidebarFooter,
  }) {
    return MaterialApp(
      home: AdaptiveManagementScaffold(
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        destinations: testDestinations,
        sidebarHeader: sidebarHeader,
        sidebarFooter: sidebarFooter,
        body: const Center(child: Text('Nội dung trang')),
      ),
    );
  }

  group('AdaptiveManagementScaffold Tests', () {
    testWidgets('renders bottom NavigationBar on mobile screens (width < 900)', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      int selectedIdx = 0;
      await tester.pumpWidget(
        buildScaffold(
          selectedIndex: selectedIdx,
          onDestinationSelected: (idx) => selectedIdx = idx,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.text('Nội dung trang'), findsOneWidget);
      expect(find.text('Tổng quan'), findsWidgets);
    });

    testWidgets('renders left sidebar NavigationRail on desktop screens (width >= 900)', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      int selectedIdx = 0;
      await tester.pumpWidget(
        buildScaffold(
          selectedIndex: selectedIdx,
          onDestinationSelected: (idx) => selectedIdx = idx,
          sidebarHeader: const Text('PKA-HOME BQL'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('PKA-HOME BQL'), findsOneWidget);
      expect(find.text('Nội dung trang'), findsOneWidget);
      expect(find.text('Tổng quan'), findsOneWidget);
      expect(find.text('Kế toán'), findsOneWidget);

      // Tap on 'Kế toán' menu item
      await tester.tap(find.text('Kế toán'));
      await tester.pumpAndSettle();

      expect(selectedIdx, 1);
    });
  });
}
