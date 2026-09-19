import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/core/widgets/shimmer_loading.dart';

void main() {
  group('ShimmerLoading Widget Tests', () {
    testWidgets('renders child inside ShimmerLoading without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ShimmerLoading(
              child: Text('Đang tải...'),
            ),
          ),
        ),
      );

      expect(find.text('Đang tải...'), findsOneWidget);
    });

    testWidgets('StatCardSkeleton renders without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatCardSkeleton(),
          ),
        ),
      );

      expect(find.byType(StatCardSkeleton), findsOneWidget);
      expect(find.byType(ShimmerLoading), findsWidgets);
    });

    testWidgets('InvoiceCardSkeleton renders without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: InvoiceCardSkeleton(),
          ),
        ),
      );

      expect(find.byType(InvoiceCardSkeleton), findsOneWidget);
      expect(find.byType(ShimmerLoading), findsWidgets);
    });

    testWidgets('IssueCardSkeleton renders without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: IssueCardSkeleton(),
          ),
        ),
      );

      expect(find.byType(IssueCardSkeleton), findsOneWidget);
      expect(find.byType(ShimmerLoading), findsWidgets);
    });

    testWidgets('ListItemSkeleton renders without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ListItemSkeleton(),
          ),
        ),
      );

      expect(find.byType(ListItemSkeleton), findsOneWidget);
      expect(find.byType(ShimmerLoading), findsWidgets);
    });
  });
}
