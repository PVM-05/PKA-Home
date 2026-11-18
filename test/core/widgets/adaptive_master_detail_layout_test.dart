import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivona/core/widgets/adaptive_master_detail_layout.dart';

void main() {
  group('AdaptiveMasterDetailLayout Tests', () {
    testWidgets('renders only master on small screens (< 900dp)', (tester) async {
      tester.view.physicalSize = const Size(600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdaptiveMasterDetailLayout<String>(
              selectedItem: 'item-1',
              masterBuilder: (context, isMasterOnly) => Text(
                isMasterOnly ? 'Master Only View' : 'Master Split View',
              ),
              detailBuilder: (context, item) => Text('Detail: $item'),
            ),
          ),
        ),
      );

      expect(find.text('Master Only View'), findsOneWidget);
      expect(find.text('Detail: item-1'), findsNothing);
    });

    testWidgets('renders both master and detail on large screens (>= 900dp)', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdaptiveMasterDetailLayout<String>(
              selectedItem: 'item-1',
              masterBuilder: (context, isMasterOnly) => Text(
                isMasterOnly ? 'Master Only View' : 'Master Split View',
              ),
              detailBuilder: (context, item) => Text('Detail: $item'),
            ),
          ),
        ),
      );

      expect(find.text('Master Split View'), findsOneWidget);
      expect(find.text('Detail: item-1'), findsOneWidget);
    });

    testWidgets('renders empty detail placeholder on large screen when selectedItem is null',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdaptiveMasterDetailLayout<String>(
              selectedItem: null,
              masterBuilder: (context, isMasterOnly) => const Text('Danh sách hóa đơn'),
              detailBuilder: (context, item) => Text('Detail: $item'),
              emptyDetailBuilder: (context) => const Text('Vui lòng chọn một hóa đơn để xem chi tiết'),
            ),
          ),
        ),
      );

      expect(find.text('Danh sách hóa đơn'), findsOneWidget);
      expect(find.text('Vui lòng chọn một hóa đơn để xem chi tiết'), findsOneWidget);
    });
  });
}

