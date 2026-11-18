import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivona/data/models/issue_model.dart';
import 'package:vivona/data/models/user_model.dart';
import 'package:vivona/data/providers/auth_provider.dart';
import 'package:vivona/data/providers/issue_comment_provider.dart';
import 'package:vivona/data/providers/issue_rating_provider.dart';
import 'package:vivona/data/providers/resident_issue_provider.dart';
import 'package:vivona/features/resident/screens/resident_issue_screen.dart';

class FakeAuthNotifier extends StateNotifier<AsyncValue<UserModel?>>
    implements AuthNotifier {
  FakeAuthNotifier([UserModel? user]) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final testUser = UserModel(
    id: 'user-1',
    fullName: 'Cư dân A',
    phone: '0901234567',
    role: 'resident',
  );

  final testIssue = IssueModel(
    id: 'issue-test-1',
    apartmentId: 'apt-1',
    reporterId: 'user-1',
    description: 'Hỏng vòi nước bồn rửa chén',
    status: 'pending',
    priority: 'high',
    createdAt: DateTime(2026, 11, 10, 8, 30),
    imageUrls: [],
  );

  Widget createWidgetUnderTest() {
    return ProviderScope(
      overrides: [
        residentIssueProvider.overrideWith((ref) => [testIssue]),
        authProvider.overrideWith((ref) => FakeAuthNotifier(testUser)),
        issueCommentsProvider('issue-test-1').overrideWith((ref) => Stream.value([])),
        issueRatingProvider('issue-test-1').overrideWith((ref) => Future.value(null)),
      ],
      child: const MaterialApp(
        home: ResidentIssueScreen(),
      ),
    );
  }

  group('ResidentIssueScreen Adaptive Tests', () {
    testWidgets('renders single pane list on mobile viewport (390dp)', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Phản ánh sự cố'), findsOneWidget);
      expect(find.text('Hỏng vòi nước bồn rửa chén'), findsOneWidget);
      // Trên mobile không có placeholder trống bên phải
      expect(find.text('Chưa chọn sự cố nào'), findsNothing);
    });

    testWidgets('renders master-detail split layout on desktop viewport (1200dp)', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Hỏng vòi nước bồn rửa chén'), findsOneWidget);

      // Nhấp chọn phản ánh ở cột Master bên trái
      await tester.tap(find.text('Hỏng vòi nước bồn rửa chén'));
      await tester.pumpAndSettle();

      // Cột Detail bên phải hiển thị chi tiết phản ánh
      expect(find.text('Chi tiết phản ánh'), findsOneWidget);
    });
  });
}
