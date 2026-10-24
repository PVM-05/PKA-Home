import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/issue_comment_model.dart';

void main() {
  group('IssueCommentModel Tests', () {
    test('fromJson ánh xạ đúng trường dữ liệu và join users', () {
      final json = {
        'id': 'comment-123',
        'issue_report_id': 'issue-456',
        'user_id': 'user-789',
        'content': 'Đã điều phối kỹ thuật viên kiểm tra ống nước.',
        'created_at': '2026-10-24T20:00:00.000Z',
        'users': {
          'full_name': 'Nguyễn Văn Quản Lý',
          'role': 'management',
        },
      };

      final model = IssueCommentModel.fromJson(json);

      expect(model.id, equals('comment-123'));
      expect(model.issueReportId, equals('issue-456'));
      expect(model.userId, equals('user-789'));
      expect(model.content, equals('Đã điều phối kỹ thuật viên kiểm tra ống nước.'));
      expect(model.createdAt, equals(DateTime.parse('2026-10-24T20:00:00.000Z')));
      expect(model.userName, equals('Nguyễn Văn Quản Lý'));
      expect(model.userRole, equals('management'));
      expect(model.isManagement, isTrue);
      expect(model.roleDisplayName, equals('Ban Quản Lý'));
    });

    test('roleDisplayName và isManagement xác định đúng các vai trò kỹ thuật, kế toán, cư dân', () {
      final residentComment = IssueCommentModel(
        id: '1',
        issueReportId: 'issue-1',
        userId: 'u1',
        content: 'Nước vẫn đang rò rỉ ạ',
        createdAt: DateTime.now(),
        userRole: 'resident',
      );
      expect(residentComment.isManagement, isFalse);
      expect(residentComment.roleDisplayName, equals('Cư dân'));

      final techComment = IssueCommentModel(
        id: '2',
        issueReportId: 'issue-1',
        userId: 'u2',
        content: 'Đã thay ron cao su mới',
        createdAt: DateTime.now(),
        userRole: 'technician',
      );
      expect(techComment.isManagement, isTrue);
      expect(techComment.roleDisplayName, equals('Kỹ thuật viên'));

      final accountantComment = IssueCommentModel(
        id: '3',
        issueReportId: 'issue-1',
        userId: 'u3',
        content: 'Phí sửa chữa đã được ghi nhận',
        createdAt: DateTime.now(),
        userRole: 'accountant',
      );
      expect(accountantComment.isManagement, isTrue);
      expect(accountantComment.roleDisplayName, equals('Kế toán'));
    });
  });
}
