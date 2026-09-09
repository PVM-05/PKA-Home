import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/repositories/issue_repository.dart';

void main() {
  group('CreateIssueResult Model Tests', () {
    test('CreateIssueResult holds correct issueId and default imageUploadFailed value', () {
      const result = CreateIssueResult(issueId: 'test-uuid-123');

      expect(result.issueId, equals('test-uuid-123'));
      expect(result.imageUploadFailed, isFalse);
    });

    test('CreateIssueResult holds imageUploadFailed when set to true', () {
      const result = CreateIssueResult(
        issueId: 'test-uuid-456',
        imageUploadFailed: true,
      );

      expect(result.issueId, equals('test-uuid-456'));
      expect(result.imageUploadFailed, isTrue);
    });
  });
}
