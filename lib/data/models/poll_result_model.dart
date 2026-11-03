class PollOptionResultModel {
  final String optionId;
  final String optionText;
  final int voteCount;
  final double voteWeightSum;
  final double percentOfVotes;

  const PollOptionResultModel({
    required this.optionId,
    required this.optionText,
    required this.voteCount,
    required this.voteWeightSum,
    required this.percentOfVotes,
  });

  factory PollOptionResultModel.fromJson(Map<String, dynamic> json) {
    return PollOptionResultModel(
      optionId: (json['option_id'] as String?) ?? '',
      optionText: (json['option_text'] as String?) ?? '',
      voteCount: (json['vote_count'] as int?) ?? 0,
      voteWeightSum: ((json['vote_weight_sum'] as num?) ?? 0.0).toDouble(),
      percentOfVotes: ((json['percent_of_votes'] as num?) ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'option_id': optionId,
      'option_text': optionText,
      'vote_count': voteCount,
      'vote_weight_sum': voteWeightSum,
      'percent_of_votes': percentOfVotes,
    };
  }
}

class PollResultModel {
  final String pollId;
  final String pollCode;
  final String title;
  final String status;
  final String voteWeightType;
  final int totalApartments;
  final int votedApartments;
  final double totalArea;
  final double votedArea;
  final double participationRate;
  final bool isQuorumMet;
  final List<PollOptionResultModel> options;

  const PollResultModel({
    required this.pollId,
    required this.pollCode,
    required this.title,
    required this.status,
    required this.voteWeightType,
    required this.totalApartments,
    required this.votedApartments,
    required this.totalArea,
    required this.votedArea,
    required this.participationRate,
    required this.isQuorumMet,
    required this.options,
  });

  bool get isByArea => voteWeightType.toLowerCase() == 'by_area';

  factory PollResultModel.fromJson(Map<String, dynamic> json) {
    var rawOpts = json['options'];
    List<PollOptionResultModel> parsedOpts = [];
    if (rawOpts is List) {
      parsedOpts = rawOpts
          .map((o) => PollOptionResultModel.fromJson(o as Map<String, dynamic>))
          .toList();
    }

    return PollResultModel(
      pollId: (json['poll_id'] as String?) ?? '',
      pollCode: (json['poll_code'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'active',
      voteWeightType: (json['vote_weight_type'] as String?) ?? 'per_apartment',
      totalApartments: (json['total_apartments'] as int?) ?? 0,
      votedApartments: (json['voted_apartments'] as int?) ?? 0,
      totalArea: ((json['total_area'] as num?) ?? 0.0).toDouble(),
      votedArea: ((json['voted_area'] as num?) ?? 0.0).toDouble(),
      participationRate: ((json['participation_rate'] as num?) ?? 0.0).toDouble(),
      isQuorumMet: (json['is_quorum_met'] as bool?) ?? false,
      options: parsedOpts,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'poll_id': pollId,
      'poll_code': pollCode,
      'title': title,
      'status': status,
      'vote_weight_type': voteWeightType,
      'total_apartments': totalApartments,
      'voted_apartments': votedApartments,
      'total_area': totalArea,
      'voted_area': votedArea,
      'participation_rate': participationRate,
      'is_quorum_met': isQuorumMet,
      'options': options.map((o) => o.toJson()).toList(),
    };
  }
}

