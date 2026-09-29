import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pka_home/data/models/issue_rating_model.dart';
import 'package:pka_home/features/resident/widgets/issue_rating_bottom_sheet.dart';

void main() {
  group('IssueRatingBottomSheet Widget Tests', () {
    testWidgets('renders all 3 criteria and submit button correctly', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: IssueRatingBottomSheet(
                issueReportId: 'issue-1',
                reporterId: 'user-1',
              ),
            ),
          ),
        ),
      );

      // Verify header and criteria titles
      expect(find.text('Đánh giá chất lượng dịch vụ'), findsOneWidget);
      expect(find.text('Tốc độ xử lý'), findsOneWidget);
      expect(find.text('Thái độ phục vụ'), findsOneWidget);
      expect(find.text('Chất lượng kỹ thuật'), findsOneWidget);

      // Verify submit button
      expect(find.text('Gửi đánh giá'), findsOneWidget);

      // Initial default rating should be 5.0 (Rất hài lòng)
      expect(find.text('5.0 / 5.0'), findsOneWidget);
      expect(find.text('(Rất hài lòng)'), findsOneWidget);
    });

    testWidgets('initialRating populates fields in edit mode', (tester) async {
      final initialRating = IssueRatingModel(
        id: 'rating-1',
        issueReportId: 'issue-1',
        reporterId: 'user-1',
        speedRating: 4,
        attitudeRating: 3,
        qualityRating: 5,
        overallRating: 4.0,
        comment: 'Nhận xét ban đầu',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: IssueRatingBottomSheet(
                issueReportId: 'issue-1',
                reporterId: 'user-1',
                initialRating: initialRating,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Chỉnh sửa đánh giá'), findsOneWidget);
      expect(find.text('Cập nhật đánh giá'), findsOneWidget);
      expect(find.text('Nhận xét ban đầu'), findsOneWidget);
      expect(find.text('4.0 / 5.0'), findsOneWidget);
      expect(find.text('(Hài lòng)'), findsOneWidget);
    });
  });
}
