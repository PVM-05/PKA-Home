import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pka_home/data/models/user_model.dart';
import 'package:pka_home/data/repositories/issue_repository.dart';
import 'package:pka_home/data/repositories/auth_repository.dart';
import 'package:pka_home/data/providers/resident_issue_provider.dart';
import 'package:pka_home/data/providers/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockIssueRepository extends Mock implements IssueRepository {}
class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockIssueRepository mockRepository;
  late MockAuthRepository mockAuthRepository;
  late ProviderContainer container;

  setUp(() {
    mockRepository = MockIssueRepository();
    mockAuthRepository = MockAuthRepository();
    
    // Giả lập currentUser và stream cho AuthNotifier
    when(() => mockAuthRepository.currentUser).thenReturn(null);
    when(() => mockAuthRepository.authStateChanges).thenAnswer((_) => const Stream.empty());
    
    container = ProviderContainer(
      overrides: [
        issueRepositoryProvider.overrideWithValue(mockRepository),
        authRepositoryProvider.overrideWithValue(mockAuthRepository),
        authProvider.overrideWith((ref) {
          final notifier = AuthNotifier(mockAuthRepository);
          notifier.state = AsyncValue.data(UserModel(id: 'user-1', fullName: 'Test', role: 'resident'));
          return notifier;
        }),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('ResidentIssueProvider TDD', () {
    test('residentIssueProvider fetches initial data and updates on stream event', () async {
      // Arrange
      final initialData = [
        {
          'id': 'issue-1',
          'apartment_id': 'apt-1',
          'reporter_id': 'user-1',
          'description': 'Test issue 1',
          'status': 'pending',
          'priority': 'low',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          'issue_images': [],
        }
      ];

      // Giả lập stream không bắn ra gì ban đầu (chỉ để giữ stream mở)
      when(() => mockRepository.streamIssues(userId: any(named: 'userId')))
          .thenAnswer((_) => const Stream.empty());

      // Giả lập fetchIssues() trả về initialData
      when(() => mockRepository.fetchIssues())
          .thenAnswer((_) async => initialData);

      // Act
      final issues = await container.read(residentIssueProvider.future);

      // Assert
      expect(issues.length, 1);
      expect(issues.first.description, 'Test issue 1');
      verify(() => mockRepository.fetchIssues()).called(1);
    });

    test('residentIssueProvider updates when Realtime stream emits a change event', () async {
      final streamController = StreamController<List<Map<String, dynamic>>>();

      final initialData = [
        {
          'id': 'issue-1',
          'apartment_id': 'apt-1',
          'reporter_id': 'user-1',
          'description': 'Rò rỉ nước',
          'status': 'pending',
          'priority': 'high',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          'issue_images': [],
        }
      ];

      final updatedData = [
        {
          'id': 'issue-1',
          'apartment_id': 'apt-1',
          'reporter_id': 'user-1',
          'description': 'Rò rỉ nước',
          'status': 'resolved',
          'priority': 'high',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          'issue_images': [],
        }
      ];

      when(() => mockRepository.streamIssues(userId: any(named: 'userId')))
          .thenAnswer((_) => streamController.stream);

      var callCount = 0;
      when(() => mockRepository.fetchIssues()).thenAnswer((_) async {
        callCount++;
        return callCount == 1 ? initialData : updatedData;
      });

      // Lần đọc đầu tiên
      final initialIssues = await container.read(residentIssueProvider.future);
      expect(initialIssues.first.status, 'pending');

      // Lắng nghe provider để trigger reactivity
      final subscription = container.listen(residentIssueProvider, (_, _) {});

      // Bắn event Realtime từ stream
      streamController.add([{'id': 'issue-1', 'status': 'resolved'}]);
      await pumpEventQueue();

      // Sau khi stream bắn event, provider tự động re-fetch dữ liệu mới nhất
      final updatedIssues = await container.read(residentIssueProvider.future);
      expect(updatedIssues.first.status, 'resolved');

      subscription.close();
      await streamController.close();
    });
  });
}
