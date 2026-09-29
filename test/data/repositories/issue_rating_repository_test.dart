import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pka_home/data/repositories/issue_repository.dart';
import 'package:pka_home/data/repositories/management_repository.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}
class MockPostgrestFilterBuilder extends Mock implements PostgrestFilterBuilder<List<Map<String, dynamic>>> {}

void main() {
  group('IssueRating Repository Tests', () {
    test('IssueRepository can be instantiated with MockSupabaseClient', () {
      final mockClient = MockSupabaseClient();
      final repo = IssueRepository(mockClient);
      expect(repo, isNotNull);
    });

    test('ManagementRepository can be instantiated with MockSupabaseClient', () {
      final mockClient = MockSupabaseClient();
      final repo = ManagementRepository(mockClient);
      expect(repo, isNotNull);
    });
  });
}
