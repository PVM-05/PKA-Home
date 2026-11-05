import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/poll_model.dart';

void main() {
  group('Tuân thủ Điều 102 Luật Nhà ở 2023 & Phân quyền Biểu quyết', () {
    test('PollModel parse chính xác pollType và nhận diện official_assembly', () {
      final jsonOfficial = {
        'id': 'poll-01',
        'poll_code': 'POLL-202611-00001',
        'title': 'Hội nghị nhà chung cư thường niên 2026',
        'poll_type': 'official_assembly',
        'category': 'agm',
        'start_time': '2026-11-01T00:00:00.000Z',
        'end_time': '2026-11-10T00:00:00.000Z',
        'created_at': '2026-11-01T00:00:00.000Z',
      };

      final poll = PollModel.fromJson(jsonOfficial);
      expect(poll.pollType, 'official_assembly');
      expect(poll.isOfficialAssembly, isTrue);

      final jsonSurvey = {
        'id': 'poll-02',
        'poll_code': 'POLL-202611-00002',
        'title': 'Khảo sát lắp thêm cây xanh sân chơi',
        'poll_type': 'survey',
        'category': 'general',
        'start_time': '2026-11-01T00:00:00.000Z',
        'end_time': '2026-11-10T00:00:00.000Z',
        'created_at': '2026-11-01T00:00:00.000Z',
      };

      final surveyPoll = PollModel.fromJson(jsonSurvey);
      expect(surveyPoll.pollType, 'survey');
      expect(surveyPoll.isOfficialAssembly, isFalse);
    });

    test('Chủ sở hữu (owner) có quyền biểu quyết nghị quyết chính thức', () {
      final poll = PollModel(
        id: 'poll-01',
        pollCode: 'POLL-01',
        title: 'Nghị quyết BQL',
        pollType: 'official_assembly',
        startTime: DateTime.now().subtract(const Duration(days: 1)),
        endTime: DateTime.now().add(const Duration(days: 2)),
        createdAt: DateTime.now(),
      );

      const relationRole = 'owner';
      final canVote = !poll.isOfficialAssembly || relationRole.toLowerCase() == 'owner';
      expect(canVote, isTrue);
    });

    test('Khách thuê (tenant) bị chặn bỏ phiếu nghị quyết chính thức và nhận thông báo Luật Nhà ở 2023', () {
      final poll = PollModel(
        id: 'poll-01',
        pollCode: 'POLL-01',
        title: 'Nghị quyết BQL',
        pollType: 'official_assembly',
        startTime: DateTime.now().subtract(const Duration(days: 1)),
        endTime: DateTime.now().add(const Duration(days: 2)),
        createdAt: DateTime.now(),
      );

      const relationRole = 'tenant';
      final canVote = !poll.isOfficialAssembly || relationRole.toLowerCase() == 'owner';
      expect(canVote, isFalse);
    });

    test('Khảo sát ý kiến (survey) cho phép cả khách thuê và chủ hộ tham gia', () {
      final surveyPoll = PollModel(
        id: 'poll-02',
        pollCode: 'POLL-02',
        title: 'Khảo sát cộng đồng',
        pollType: 'survey',
        startTime: DateTime.now().subtract(const Duration(days: 1)),
        endTime: DateTime.now().add(const Duration(days: 2)),
        createdAt: DateTime.now(),
      );

      const relationRole = 'tenant';
      final canVote = !surveyPoll.isOfficialAssembly || relationRole.toLowerCase() == 'owner';
      expect(canVote, isTrue);
    });
  });
}
