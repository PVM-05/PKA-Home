import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/poll_model.dart';
import 'package:pka_home/data/models/poll_result_model.dart';

void main() {
  group('PollModel & PollResultModel Tests (D7)', () {
    final now = DateTime.now();

    test('PollModel fromJson parses data correctly', () {
      final json = {
        'id': 'poll-01',
        'poll_code': 'POLL-202611-00001',
        'building_id': 'bld-01',
        'title': 'Biểu quyết lựa chọn đơn vị vận hành năm 2027',
        'description': 'Đánh giá hồ sơ thầu dịch vụ quản lý vận hành chung cư',
        'category': 'agm',
        'vote_weight_type': 'by_area',
        'choice_type': 'single_choice',
        'min_participation_rate': 50.0,
        'required_approval_rate': 65.0,
        'start_time': now.subtract(const Duration(days: 1)).toIso8601String(),
        'end_time': now.add(const Duration(days: 2)).toIso8601String(),
        'status': 'active',
        'created_by': 'usr-admin-01',
        'created_at': now.subtract(const Duration(days: 2)).toIso8601String(),
        'poll_options': [
          {
            'id': 'opt-01',
            'poll_id': 'poll-01',
            'option_text': 'Công ty Savills Việt Nam',
            'option_order': 1,
          },
          {
            'id': 'opt-02',
            'poll_id': 'poll-01',
            'option_text': 'Công ty CBRE Việt Nam',
            'option_order': 2,
          },
        ],
      };

      final poll = PollModel.fromJson(json);

      expect(poll.id, equals('poll-01'));
      expect(poll.pollCode, equals('POLL-202611-00001'));
      expect(poll.voteWeightType, equals('by_area'));
      expect(poll.isByArea, isTrue);
      expect(poll.isActive, isTrue);
      expect(poll.isClosed, isFalse);
      expect(poll.categoryDisplayName, equals('Hội nghị chung cư'));
      expect(poll.voteWeightDisplayName, equals('Theo diện tích m²'));
      expect(poll.options.length, equals(2));
      expect(poll.options.first.optionText, equals('Công ty Savills Việt Nam'));
    });

    test('PollResultModel fromJson parses calculation results correctly', () {
      final json = {
        'success': true,
        'poll_id': 'poll-01',
        'poll_code': 'POLL-202611-00001',
        'title': 'Biểu quyết lựa chọn đơn vị vận hành',
        'status': 'active',
        'vote_weight_type': 'by_area',
        'total_apartments': 200,
        'voted_apartments': 150,
        'total_area': 16000.0,
        'voted_area': 12500.0,
        'participation_rate': 78.12,
        'is_quorum_met': true,
        'options': [
          {
            'option_id': 'opt-01',
            'option_text': 'Savills',
            'vote_count': 90,
            'vote_weight_sum': 8000.0,
            'percent_of_votes': 64.0,
          },
          {
            'option_id': 'opt-02',
            'option_text': 'CBRE',
            'vote_count': 60,
            'vote_weight_sum': 4500.0,
            'percent_of_votes': 36.0,
          },
        ],
      };

      final result = PollResultModel.fromJson(json);

      expect(result.pollCode, equals('POLL-202611-00001'));
      expect(result.participationRate, equals(78.12));
      expect(result.isQuorumMet, isTrue);
      expect(result.options.length, equals(2));
      expect(result.options.first.percentOfVotes, equals(64.0));
      expect(result.options.first.voteWeightSum, equals(8000.0));
    });
  });
}

