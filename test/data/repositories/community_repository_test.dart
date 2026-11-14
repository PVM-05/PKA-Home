import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/core/utils/guard_helper.dart';
import 'package:pka_home/data/repositories/community_repository.dart';

void main() {
  group('CommunityRepository Fail-Closed Tests', () {
    late CommunityRepository repository;

    setUp(() {
      repository = CommunityRepository(null);
    });

    test('1. fetchPolls ném AppException khi không có kết nối Supabase', () async {
      expect(
        () => repository.fetchPolls(),
        throwsA(isA<AppException>()),
      );
    });

    test('2. createPoll ném AppException khi không có kết nối Supabase', () async {
      expect(
        () => repository.createPoll(
          title: 'Khảo sát bảo trì',
          startTime: DateTime.now(),
          endTime: DateTime.now().add(const Duration(days: 3)),
          options: ['Đồng ý', 'Không đồng ý'],
          createdBy: 'admin-01',
        ),
        throwsA(isA<AppException>()),
      );
    });

    test('3. submitPollVote ném AppException khi không có kết nối Supabase', () async {
      expect(
        () => repository.submitPollVote(
          pollId: 'poll-01',
          apartmentId: 'apt-01',
          selectedOptionIds: ['opt-01'],
        ),
        throwsA(isA<AppException>()),
      );
    });

    test('4. fetchPetitions ném AppException khi không có kết nối Supabase', () async {
      expect(
        () => repository.fetchPetitions(),
        throwsA(isA<AppException>()),
      );
    });

    test('5. createPetition ném AppException khi không có kết nối Supabase', () async {
      expect(
        () => repository.createPetition(
          apartmentId: 'apt-01',
          authorUserId: 'usr-01',
          title: 'Lắp thêm camera',
          content: 'Khu vực tầng hầm',
        ),
        throwsA(isA<AppException>()),
      );
    });

    test('6. endorsePetition ném AppException khi không có kết nối Supabase', () async {
      expect(
        () => repository.endorsePetition(
          petitionId: 'pet-01',
          apartmentId: 'apt-01',
        ),
        throwsA(isA<AppException>()),
      );
    });
  });
}
