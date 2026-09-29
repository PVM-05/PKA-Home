import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pka_home/data/models/issue_rating_model.dart';
import 'package:pka_home/data/models/user_model.dart';
import 'package:pka_home/data/providers/auth_provider.dart';
import 'package:pka_home/data/providers/issue_rating_provider.dart';
import 'package:pka_home/data/providers/role_delegation_provider.dart';
import 'package:pka_home/features/management/screens/service_rating_overview_screen.dart';

class FakeAuthNotifier extends StateNotifier<AsyncValue<UserModel?>>
    implements AuthNotifier {
  FakeAuthNotifier(UserModel user) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('ServiceRatingOverviewScreen Widget Tests', () {
    final sampleRatings = [
      IssueRatingModel(
        id: 'rating-1',
        issueReportId: 'issue-1',
        reporterId: 'user-1',
        speedRating: 5,
        attitudeRating: 5,
        qualityRating: 5,
        overallRating: 5.0,
        comment: 'Dịch vụ xử lý xuất sắc!',
        reporterName: 'Cư dân A0110',
        createdAt: DateTime(2026, 9, 29, 10, 0),
      ),
      IssueRatingModel(
        id: 'rating-2',
        issueReportId: 'issue-2',
        reporterId: 'user-2',
        speedRating: 4,
        attitudeRating: 4,
        qualityRating: 4,
        overallRating: 4.0,
        comment: 'Khắc phục tốt, đúng giờ.',
        reporterName: 'Cư dân B0202',
        createdAt: DateTime(2026, 9, 29, 11, 0),
      ),
    ];

    testWidgets('renders KPI cards, filter chips and rating items for staff',
        (tester) async {
      final adminUser = UserModel(
        id: 'admin-id',
        fullName: 'Nguyễn Quản Trị',
        role: 'admin',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => FakeAuthNotifier(adminUser)),
            activeDelegationsProvider.overrideWith((ref) => Stream.value([])),
            allIssueRatingsProvider
                .overrideWith((ref) => Future.value(sampleRatings)),
          ],
          child: const MaterialApp(
            home: ServiceRatingOverviewScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify AppBar and Header
      expect(find.text('Đánh giá chất lượng dịch vụ'), findsOneWidget);
      expect(find.text('Điểm dịch vụ toàn khu'), findsOneWidget);
      expect(find.text('Tỷ lệ hài lòng'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('4.5 / 5.0'), findsOneWidget);

      // Verify Filter chips
      expect(find.text('Tất cả (2)'), findsOneWidget);
      expect(find.text('5 sao (1)'), findsOneWidget);
      expect(find.text('4 sao (1)'), findsOneWidget);

      // Verify Rating items
      expect(find.text('Cư dân A0110'), findsOneWidget);
      expect(find.text('"Dịch vụ xử lý xuất sắc!"'), findsOneWidget);
      expect(find.text('Cư dân B0202'), findsOneWidget);
      expect(find.text('"Khắc phục tốt, đúng giờ."'), findsOneWidget);
    });

    testWidgets('renders empty state when there are no ratings',
        (tester) async {
      final adminUser = UserModel(
        id: 'admin-id',
        fullName: 'Nguyễn Quản Trị',
        role: 'admin',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => FakeAuthNotifier(adminUser)),
            activeDelegationsProvider.overrideWith((ref) => Stream.value([])),
            allIssueRatingsProvider.overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(
            home: ServiceRatingOverviewScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Chưa có lượt đánh giá nào'), findsOneWidget);
    });
  });
}
