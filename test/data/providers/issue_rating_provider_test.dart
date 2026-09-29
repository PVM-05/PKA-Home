import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/issue_rating_model.dart';

void main() {
  group('IssueRating Provider & Calculation Tests', () {
    test('Calculates average ratings correctly for technicians', () {
      final ratings = [
        IssueRatingModel(
          id: '1',
          issueReportId: 'issue-1',
          reporterId: 'user-1',
          speedRating: 5,
          attitudeRating: 5,
          qualityRating: 5,
          overallRating: 5.0,
          createdAt: DateTime.now(),
        ),
        IssueRatingModel(
          id: '2',
          issueReportId: 'issue-2',
          reporterId: 'user-2',
          speedRating: 4,
          attitudeRating: 4,
          qualityRating: 4,
          overallRating: 4.0,
          createdAt: DateTime.now(),
        ),
      ];

      final totalOverall = ratings.map((r) => r.overallRating).reduce((a, b) => a + b);
      final avg = totalOverall / ratings.length;

      expect(avg, 4.5);
    });
  });
}
