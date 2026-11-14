import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/core/widgets/app_skeleton_shimmer.dart';

void main() {
  group('AppSkeletonShimmer Widget Tests', () {
    testWidgets('render đúng rectangular shimmer với kích thước mong đợi', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppSkeletonShimmer.rectangular(
              width: 200,
              height: 40,
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
          ),
        ),
      );

      expect(find.byType(AppSkeletonShimmer), findsOneWidget);
      final size = tester.getSize(find.byType(AppSkeletonShimmer));
      expect(size.width, equals(200));
      expect(size.height, equals(40));
    });

    testWidgets('render đúng circular shimmer với size vuông tròn', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppSkeletonShimmer.circular(size: 48),
          ),
        ),
      );

      expect(find.byType(AppSkeletonShimmer), findsOneWidget);
      final size = tester.getSize(find.byType(AppSkeletonShimmer));
      expect(size.width, equals(48));
      expect(size.height, equals(48));
    });

    testWidgets('render đúng danh sách cardList shimmer', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppSkeletonShimmer.cardList(count: 3, itemHeight: 80),
          ),
        ),
      );

      expect(find.byType(AppSkeletonShimmer), findsNWidgets(3));
    });
  });
}

