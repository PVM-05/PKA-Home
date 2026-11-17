import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vivona/core/widgets/app_empty_state.dart';
import 'package:vivona/core/widgets/app_skeleton_shimmer.dart';
import 'package:vivona/data/models/user_model.dart';
import 'package:vivona/data/models/issue_model.dart';
import 'package:vivona/data/models/issue_comment_model.dart';
import 'package:vivona/data/providers/auth_provider.dart';
import 'package:vivona/data/providers/management_provider.dart';
import 'package:vivona/data/providers/role_delegation_provider.dart';
import 'package:vivona/data/providers/issue_comment_provider.dart';
import 'package:vivona/data/providers/issue_rating_provider.dart';
import 'package:vivona/features/management/screens/issue_management_screen.dart';
import 'package:vivona/features/resident/screens/issue_detail_screen.dart';

class FakeAuthNotifier extends StateNotifier<AsyncValue<UserModel?>> implements AuthNotifier {
  FakeAuthNotifier(UserModel user) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('IssueManagement & IssueDetail A11y & Shimmer Tests', () {
    final testManager = UserModel(
      id: 'mgr-002',
      fullName: 'Quản lý kỹ thuật',
      role: 'management',
    );

    final dummyIssue = IssueModel(
      id: 'issue-001',
      apartmentId: 'apt-001',
      reporterId: 'res-001',
      description: 'Vòi nước bị rò rỉ mạnh cần sửa chữa gấp',
      status: 'pending',
      priority: 'high',
      createdAt: DateTime.parse('2026-11-10'),
    );

    testWidgets('IssueManagementScreen: hiển thị AppEmptyState khi lọc không ra kết quả', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => FakeAuthNotifier(testManager)),
            activeDelegationsProvider.overrideWith((ref) => Stream.value([])),
            allIssuesProvider.overrideWith((ref) async => [dummyIssue]),
          ],
          child: const MaterialApp(
            home: IssueManagementScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Nhập từ khóa tìm kiếm không khớp
      await tester.enterText(find.byType(TextField), 'TU_KHOA_KHONG_KHOP_9999');
      await tester.pumpAndSettle();

      expect(find.byType(AppEmptyState), findsOneWidget);
    });

    testWidgets('IssueDetailScreen: hiển thị AppSkeletonShimmer khi comments đang tải dữ liệu', (tester) async {
      final controller = StreamController<List<IssueCommentModel>>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => FakeAuthNotifier(testManager)),
            issueCommentsProvider('issue-001').overrideWith((ref) => controller.stream),
            issueRatingProvider('issue-001').overrideWith((ref) async => null),
          ],
          child: MaterialApp(
            home: IssueDetailScreen(issue: dummyIssue),
          ),
        ),
      );

      await tester.pump();

      // Phải có Skeleton Shimmer và không còn Spinner đơn điệu
      expect(find.byType(AppSkeletonShimmer), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      controller.add([]);
      await tester.pumpAndSettle();
      await controller.close();
    });

    testWidgets('IssueManagementScreen: có Semantics trợ năng cho nhãn trạng thái và mức độ ưu tiên', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => FakeAuthNotifier(testManager)),
            activeDelegationsProvider.overrideWith((ref) => Stream.value([])),
            allIssuesProvider.overrideWith((ref) async => [dummyIssue]),
          ],
          child: const MaterialApp(
            home: IssueManagementScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final prioritySemanticsFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label != null &&
            widget.properties.label!.contains('Mức độ ưu tiên'),
      );

      expect(prioritySemanticsFinder, findsWidgets);
    });
  });
}
