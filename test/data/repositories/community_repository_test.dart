import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/repositories/community_repository.dart';

void main() {
  group('CommunityRepository Tests (Offline Fallback Engine D7)', () {
    late CommunityRepository repository;

    setUp(() {
      repository = CommunityRepository();
    });

    test('1. fetchPolls tra ve danh sach polls mau co options', () async {
      final polls = await repository.fetchPolls();
      expect(polls.isNotEmpty, isTrue);
      expect(polls.first.options.isNotEmpty, isTrue);
    });

    test('2. createPoll them moi dot bieu quyet', () async {
      final newPoll = await repository.createPoll(
        title: 'Bầu bổ sung thành viên Ban Quản Trị nhiệm kỳ 2026-2029',
        description: 'Lấy ý kiến biểu quyết tín nhiệm ứng viên đại diện Cư dân tháp B',
        category: 'agm',
        voteWeightType: 'by_area',
        choiceType: 'single_choice',
        minParticipationRate: 50.0,
        requiredApprovalRate: 50.0,
        startTime: DateTime.now().subtract(const Duration(hours: 1)),
        endTime: DateTime.now().add(const Duration(days: 3)),
        options: ['Ứng viên Nguyễn Văn A', 'Ứng viên Trần Thị B', 'Không tán thành cả hai'],
        createdBy: 'usr-admin-01',
      );

      expect(newPoll.id, isNotEmpty);
      expect(newPoll.pollCode, startsWith('POLL-'));
      expect(newPoll.options.length, equals(3));
      expect(newPoll.isByArea, isTrue);

      final list = await repository.fetchPolls();
      expect(list.any((p) => p.id == newPoll.id), isTrue);
    });

    test('3. submitPollVote ghi nhan phieu bau va chan bieu quyet 2 lan', () async {
      final polls = await repository.fetchPolls();
      final poll = polls.first;
      const testAptId = 'apt-vote-test-01';
      const testUserId = 'usr-vote-01';

      // Bỏ phiếu lần 1
      final voteRes = await repository.submitPollVote(
        pollId: poll.id,
        apartmentId: testAptId,
        voterUserId: testUserId,
        selectedOptionIds: [poll.options.first.id],
      );

      expect(voteRes['success'], isTrue);

      // Bỏ phiếu lần 2 cùng căn hộ -> thất bại
      final duplicateVoteRes = await repository.submitPollVote(
        pollId: poll.id,
        apartmentId: testAptId,
        voterUserId: testUserId,
        selectedOptionIds: [poll.options.last.id],
      );

      expect(duplicateVoteRes['success'], isFalse);
      expect(duplicateVoteRes['message'], contains('đã tham gia'));
    });

    test('4. getPollResults tinh toan ty le phan tram bieu quyet', () async {
      final polls = await repository.fetchPolls();
      final poll = polls.first;

      final results = await repository.getPollResults(poll.id);
      expect(results.pollId, equals(poll.id));
      expect(results.options.isNotEmpty, isTrue);
      expect(results.totalApartments, greaterThan(0));
    });

    test('5. fetchPetitions tra ve danh sach kien nghi cu dan', () async {
      final petitions = await repository.fetchPetitions();
      expect(petitions.isNotEmpty, isTrue);
      expect(petitions.first.title, isNotEmpty);
    });

    test('6. createPetition tao kien nghi moi thanh cong', () async {
      final newPet = await repository.createPetition(
        apartmentId: 'apt-01',
        authorUserId: 'usr-01',
        title: 'Đề xuất lắp đặt thùng phân loại rác tái chế tại sảnh',
        content: 'Chung cư cần thúc đẩy bảo vệ môi trường bằng cách phân loại rác thải tại nguồn.',
        category: 'hygiene',
      );

      expect(newPet.petitionCode, startsWith('PET-'));
      expect(newPet.status, equals('pending'));
      expect(newPet.endorsementCount, equals(0));

      final list = await repository.fetchPetitions();
      expect(list.any((p) => p.id == newPet.id), isTrue);
    });

    test('7. endorsePetition tang so luot dong thuan va chan spam', () async {
      final petitions = await repository.fetchPetitions();
      final pet = petitions.first;
      const testAptId = 'apt-endorse-test-01';
      const testUserId = 'usr-endorse-01';

      // Đồng thuận lần 1
      final res1 = await repository.endorsePetition(
        petitionId: pet.id,
        apartmentId: testAptId,
        userId: testUserId,
      );
      expect(res1['success'], isTrue);

      // Đồng thuận lần 2 cùng căn hộ -> báo lỗi
      final res2 = await repository.endorsePetition(
        petitionId: pet.id,
        apartmentId: testAptId,
        userId: testUserId,
      );
      expect(res2['success'], isFalse);
    });

    test('8. updatePetitionResponse BQL phan hoi va chuyen trang thai', () async {
      final petitions = await repository.fetchPetitions();
      final pet = petitions.first;

      final res = await repository.updatePetitionResponse(
        petitionId: pet.id,
        status: 'in_progress',
        officialResponse: 'BQL đã giao kỹ thuật tòa nhà kiểm tra và lên phương án xử lý.',
        staffId: 'usr-admin-01',
      );

      expect(res['success'], isTrue);

      final updatedList = await repository.fetchPetitions();
      final target = updatedList.firstWhere((p) => p.id == pet.id);
      expect(target.status, equals('in_progress'));
      expect(target.officialResponse, contains('BQL đã giao kỹ thuật'));
    });
  });
}
