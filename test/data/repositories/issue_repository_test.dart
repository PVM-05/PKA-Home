import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pka_home/data/repositories/issue_repository.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockSupabaseStorageClient extends Mock implements SupabaseStorageClient {}
class MockStorageFileApi extends Mock implements StorageFileApi {}
class MockPostgrestClient extends Mock implements PostgrestClient {}

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

  group('IssueRepository delete and update tests', () {
    test('IssueRepository can be instantiated with MockSupabaseClient', () {
      final mockClient = MockSupabaseClient();
      final repo = IssueRepository(mockClient);
      expect(repo, isNotNull);
    });
  });
}
