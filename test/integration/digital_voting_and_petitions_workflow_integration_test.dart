import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/repositories/community_repository.dart';

void main() {
  group('Quy trình Tích hợp Biểu Quyết Điện Tử & Kiến Nghị Cộng Đồng (D7)', () {
    late CommunityRepository repository;

    setUp(() {
      repository = CommunityRepository();
    });

    test('Toan ven luong bieu quyet theo dien tich va kien nghi dong thuan', () async {
      const apartmentId1 = 'apt-int-01';
      const apartmentId2 = 'apt-int-02';
      const residentUser1 = 'usr-resident-01';
      const residentUser2 = 'usr-resident-02';
      const staffAdmin = 'usr-admin-01';

      // ─── PHẦN 1: BIỂU QUYẾT ĐIỆN TỬ (ĐIỀU 102 LUẬT NHÀ Ở 2023) ───
      // 1. BQL phát hành đợt biểu quyết theo diện tích m2
      final poll = await repository.createPoll(
        title: 'Thông qua kế hoạch bảo trì cụm thang máy tháp A năm 2027',
        description: 'Trích quỹ bảo trì 2% thực hiện đại tu thay cáp tải và biến tần theo khuyến cáo kỹ thuật',
        category: 'maintenance',
        voteWeightType: 'by_area',
        choiceType: 'single_choice',
        minParticipationRate: 50.0,
        requiredApprovalRate: 65.0,
        startTime: DateTime.now().subtract(const Duration(hours: 1)),
        endTime: DateTime.now().add(const Duration(days: 3)),
        options: ['Tán thành phương án', 'Không tán thành', 'Ý kiến khác'],
        createdBy: staffAdmin,
      );

      expect(poll.pollCode, startsWith('POLL-'));
      expect(poll.isByArea, isTrue);
      expect(poll.options.length, equals(3));

      // 2. Cư dân căn hộ 1 tham gia biểu quyết
      final voteRes1 = await repository.submitPollVote(
        pollId: poll.id,
        apartmentId: apartmentId1,
        voterUserId: residentUser1,
        selectedOptionIds: [poll.options.first.id],
      );
      expect(voteRes1['success'], isTrue);

      // Căn hộ 1 không thể biểu quyết lần 2
      final duplicateVoteRes = await repository.submitPollVote(
        pollId: poll.id,
        apartmentId: apartmentId1,
        voterUserId: residentUser1,
        selectedOptionIds: [poll.options[1].id],
      );
      expect(duplicateVoteRes['success'], isFalse);

      // 3. Cư dân căn hộ 2 tham gia biểu quyết
      final voteRes2 = await repository.submitPollVote(
        pollId: poll.id,
        apartmentId: apartmentId2,
        voterUserId: residentUser2,
        selectedOptionIds: [poll.options.first.id],
      );
      expect(voteRes2['success'], isTrue);

      // 4. BQL kiểm tra thống kê kết quả
      final results = await repository.getPollResults(poll.id);
      expect(results.pollId, equals(poll.id));
      expect(results.votedApartments, greaterThanOrEqualTo(2));
      expect(results.options.first.voteCount, greaterThan(0));

      // ─── PHẦN 2: KIẾN NGHỊ CỘNG ĐỒNG & ĐỒNG THUẬN ───
      // 5. Cư dân căn hộ 1 tạo kiến nghị
      final petition = await repository.createPetition(
        apartmentId: apartmentId1,
        authorUserId: residentUser1,
        title: 'Bổ sung thùng rác phân loại pin cũ và rác điện tử',
        content: 'Đề nghị BQL đặt thùng thu gom pin đã qua sử dụng tại sảnh chính để đảm bảo an toàn môi trường.',
        category: 'hygiene',
      );

      expect(petition.petitionCode, startsWith('PET-'));
      expect(petition.status, equals('pending'));
      expect(petition.endorsementCount, equals(0));

      // 6. Cư dân căn hộ 2 bấm "Đồng thuận"
      final endorseRes = await repository.endorsePetition(
        petitionId: petition.id,
        apartmentId: apartmentId2,
        userId: residentUser2,
      );
      expect(endorseRes['success'], isTrue);
      expect(endorseRes['endorsement_count'], equals(1));

      // 7. Ban Quản Lý tiếp nhận và cập nhật phản hồi chính thức
      final responseRes = await repository.updatePetitionResponse(
        petitionId: petition.id,
        status: 'resolved',
        officialResponse: 'BQL đã trang bị thùng thu gom rác điện tử tại góc sảnh lễ tân tầng 1 kể từ ngày 05/11.',
        staffId: staffAdmin,
      );

      expect(responseRes['success'], isTrue);

      final updatedPetitions = await repository.fetchPetitions();
      final targetPetition = updatedPetitions.firstWhere((p) => p.id == petition.id);
      expect(targetPetition.status, equals('resolved'));
      expect(targetPetition.officialResponse, contains('BQL đã trang bị thùng thu gom'));
    });
  });
}

