import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pka_home/core/widgets/app_empty_state.dart';
import 'package:pka_home/core/widgets/app_skeleton_shimmer.dart';
import 'package:pka_home/data/models/issue_model.dart';
import 'package:pka_home/data/providers/resident_issue_provider.dart';
import 'package:pka_home/features/resident/screens/resident_issue_screen.dart';

void main() {
  group('ResidentIssueScreen A11y & Shimmer Tests', () {
    final dummyIssue = IssueModel(
      id: 'issue-res-001',
      apartmentId: 'apt-001',
      reporterId: 'res-001',
      description: 'Chập cầu dao điện phòng khách',
      status: 'pending',
      priority: 'high',
      createdAt: DateTime.parse('2026-11-12 09:30:00'),
    );

    testWidgets('ResidentIssueScreen: hiển thị AppSkeletonShimmer khi đang tải dữ liệu', (tester) async {
      final completer = Completer<List<IssueModel>>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            residentIssueProvider.overrideWith((ref) => completer.future),
          ],
          child: const MaterialApp(
            home: ResidentIssueScreen(),
          ),
        ),
      );

      await tester.pump();

      // Phải có Skeleton Shimmer khi loading
      expect(find.byType(AppSkeletonShimmer), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      completer.complete([]);
      await tester.pumpAndSettle();
    });

    testWidgets('ResidentIssueScreen: hiển thị AppEmptyState khi danh sách phản ánh rỗng', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            residentIssueProvider.overrideWith((ref) async => []),
          ],
          child: const MaterialApp(
            home: ResidentIssueScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(AppEmptyState), findsOneWidget);
      expect(find.text('Bạn chưa gửi phản ánh nào'), findsOneWidget);
      expect(find.text('Gửi phản ánh ngay'), findsOneWidget);
    });

    testWidgets('ResidentIssueScreen: có Semantics trợ năng cho thẻ sự cố, trạng thái và mức độ ưu tiên', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            residentIssueProvider.overrideWith((ref) async => [dummyIssue]),
          ],
          child: const MaterialApp(
            home: ResidentIssueScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Kiểm tra có Semantics tổng thể của thẻ phản ánh
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && (w.properties.label?.contains('Chập cầu dao điện phòng khách') ?? false),
        ),
        findsOneWidget,
      );

      // Kiểm tra có Semantics cho Trạng thái
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && (w.properties.label?.contains('Trạng thái: Chờ tiếp nhận') ?? false),
        ),
        findsOneWidget,
      );

      // Kiểm tra có Semantics cho Mức độ ưu tiên
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && (w.properties.label?.contains('Mức độ ưu tiên: Khẩn cấp') ?? false),
        ),
        findsOneWidget,
      );

      // Kiểm tra FloatingActionButton có tooltip trợ năng
      final fab = tester.widget<FloatingActionButton>(find.byType(FloatingActionButton));
      expect(fab.tooltip, 'Tạo phản ánh sự cố mới');
    });
  });
}

