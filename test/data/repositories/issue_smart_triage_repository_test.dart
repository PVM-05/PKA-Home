import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pka_home/data/repositories/issue_repository.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class FakePostgrestFilterBuilder extends Fake implements PostgrestFilterBuilder<dynamic> {
  final dynamic _result;
  FakePostgrestFilterBuilder(this._result);

  @override
  Future<R> then<R>(FutureOr<R> Function(dynamic value) onValue, {Function? onError}) {
    return Future.value(_result).then(onValue, onError: onError);
  }
}

void main() {
  group('IssueSmartTriageRepository Tests', () {
    late MockSupabaseClient mockClient;
    late IssueRepository repository;

    setUp(() {
      mockClient = MockSupabaseClient();
      repository = IssueRepository(mockClient);
    });

    test('autoAssignIssue invokes triage_and_auto_assign_issue RPC and returns response', () async {
      const issueId = 'issue-123';
      final expectedResult = {
        'success': true,
        'issue_id': issueId,
        'suggested_category': 'plumbing',
        'suggested_priority': 'high',
        'confidence': 0.95,
        'assigned_staff_id': 'staff-456',
        'auto_assigned': true,
      };

      when(() => mockClient.rpc(
            'triage_and_auto_assign_issue',
            params: {
              'p_issue_id': issueId,
              'p_auto_assign': true,
            },
          )).thenAnswer((_) => FakePostgrestFilterBuilder(expectedResult));

      final result = await repository.autoAssignIssue(issueId, autoAssign: true);

      expect(result['success'], isTrue);
      expect(result['suggested_category'], equals('plumbing'));
      expect(result['assigned_staff_id'], equals('staff-456'));
      expect(result['auto_assigned'], isTrue);

      verify(() => mockClient.rpc(
            'triage_and_auto_assign_issue',
            params: {
              'p_issue_id': issueId,
              'p_auto_assign': true,
            },
          )).called(1);
    });

    test('autoAssignIssue can query recommendations without auto assigning (autoAssign: false)', () async {
      const issueId = 'issue-789';
      final expectedResult = {
        'success': true,
        'issue_id': issueId,
        'suggested_category': 'elevator',
        'suggested_priority': 'high',
        'confidence': 0.99,
        'assigned_staff_id': null,
        'auto_assigned': false,
      };

      when(() => mockClient.rpc(
            'triage_and_auto_assign_issue',
            params: {
              'p_issue_id': issueId,
              'p_auto_assign': false,
            },
          )).thenAnswer((_) => FakePostgrestFilterBuilder(expectedResult));

      final result = await repository.autoAssignIssue(issueId, autoAssign: false);

      expect(result['success'], isTrue);
      expect(result['suggested_category'], equals('elevator'));
      expect(result['auto_assigned'], isFalse);

      verify(() => mockClient.rpc(
            'triage_and_auto_assign_issue',
            params: {
              'p_issue_id': issueId,
              'p_auto_assign': false,
            },
          )).called(1);
    });
  });
}
