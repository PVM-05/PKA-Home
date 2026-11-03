class PollOptionModel {
  final String id;
  final String pollId;
  final String optionText;
  final int optionOrder;
  final DateTime? createdAt;

  const PollOptionModel({
    required this.id,
    required this.pollId,
    required this.optionText,
    this.optionOrder = 0,
    this.createdAt,
  });

  factory PollOptionModel.fromJson(Map<String, dynamic> json) {
    return PollOptionModel(
      id: json['id'] as String,
      pollId: (json['poll_id'] as String?) ?? '',
      optionText: (json['option_text'] as String?) ?? '',
      optionOrder: (json['option_order'] as int?) ?? 0,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'poll_id': pollId,
      'option_text': optionText,
      'option_order': optionOrder,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }
}

class PollModel {
  final String id;
  final String pollCode;
  final String? buildingId;
  final String title;
  final String? description;
  final String category; // general, agm, finance, maintenance, rule
  final String voteWeightType; // per_apartment, by_area
  final String choiceType; // single_choice, multiple_choice, yes_no_abstain
  final double minParticipationRate;
  final double requiredApprovalRate;
  final DateTime startTime;
  final DateTime endTime;
  final String status; // draft, active, closed, cancelled
  final String? createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<PollOptionModel> options;
  final bool hasVoted;

  const PollModel({
    required this.id,
    required this.pollCode,
    this.buildingId,
    required this.title,
    this.description,
    this.category = 'general',
    this.voteWeightType = 'per_apartment',
    this.choiceType = 'single_choice',
    this.minParticipationRate = 50.0,
    this.requiredApprovalRate = 50.0,
    required this.startTime,
    required this.endTime,
    this.status = 'active',
    this.createdBy,
    required this.createdAt,
    this.updatedAt,
    this.options = const [],
    this.hasVoted = false,
  });

  bool get isByArea => voteWeightType.toLowerCase() == 'by_area';
  bool get isActive => status.toLowerCase() == 'active' && DateTime.now().isBefore(endTime);
  bool get isClosed => status.toLowerCase() == 'closed' || DateTime.now().isAfter(endTime);

  String get categoryDisplayName {
    switch (category.toLowerCase()) {
      case 'agm':
        return 'Hội nghị chung cư';
      case 'finance':
        return 'Tài chính & Phí';
      case 'maintenance':
        return 'Bảo trì & Đầu tư';
      case 'rule':
        return 'Nội quy & Quy chế';
      case 'general':
      default:
        return 'Lấy ý kiến chung';
    }
  }

  String get statusDisplayName {
    if (status.toLowerCase() == 'cancelled') return 'Đã hủy';
    if (DateTime.now().isBefore(startTime)) return 'Sắp diễn ra';
    if (isClosed) return 'Đã kết thúc';
    return 'Đang mở';
  }

  String get voteWeightDisplayName {
    return isByArea ? 'Theo diện tích m²' : '1 Căn hộ = 1 Phiếu';
  }

  String get choiceTypeDisplayName {
    switch (choiceType.toLowerCase()) {
      case 'multiple_choice':
        return 'Chọn nhiều phương án';
      case 'yes_no_abstain':
        return 'Tán thành / Không / Ý kiến khác';
      case 'single_choice':
      default:
        return 'Chọn 1 phương án duy nhất';
    }
  }

  factory PollModel.fromJson(Map<String, dynamic> json) {
    var rawOptions = json['poll_options'] ?? json['options'];
    List<PollOptionModel> parsedOptions = [];
    if (rawOptions is List) {
      parsedOptions = rawOptions
          .map((o) => PollOptionModel.fromJson(o as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.optionOrder.compareTo(b.optionOrder));
    }

    return PollModel(
      id: json['id'] as String,
      pollCode: (json['poll_code'] as String?) ?? '',
      buildingId: json['building_id'] as String?,
      title: (json['title'] as String?) ?? '',
      description: json['description'] as String?,
      category: (json['category'] as String?) ?? 'general',
      voteWeightType: (json['vote_weight_type'] as String?) ?? 'per_apartment',
      choiceType: (json['choice_type'] as String?) ?? 'single_choice',
      minParticipationRate: ((json['min_participation_rate'] as num?) ?? 50.0).toDouble(),
      requiredApprovalRate: ((json['required_approval_rate'] as num?) ?? 50.0).toDouble(),
      startTime: DateTime.tryParse(json['start_time'].toString()) ?? DateTime.now(),
      endTime: DateTime.tryParse(json['end_time'].toString()) ?? DateTime.now().add(const Duration(days: 7)),
      status: (json['status'] as String?) ?? 'active',
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
      options: parsedOptions,
      hasVoted: (json['has_voted'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'poll_code': pollCode,
      'building_id': buildingId,
      'title': title,
      'description': description,
      'category': category,
      'vote_weight_type': voteWeightType,
      'choice_type': choiceType,
      'min_participation_rate': minParticipationRate,
      'required_approval_rate': requiredApprovalRate,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'status': status,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      'options': options.map((o) => o.toJson()).toList(),
      'has_voted': hasVoted,
    };
  }

  PollModel copyWith({
    String? id,
    String? pollCode,
    String? buildingId,
    String? title,
    String? description,
    String? category,
    String? voteWeightType,
    String? choiceType,
    double? minParticipationRate,
    double? requiredApprovalRate,
    DateTime? startTime,
    DateTime? endTime,
    String? status,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<PollOptionModel>? options,
    bool? hasVoted,
  }) {
    return PollModel(
      id: id ?? this.id,
      pollCode: pollCode ?? this.pollCode,
      buildingId: buildingId ?? this.buildingId,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      voteWeightType: voteWeightType ?? this.voteWeightType,
      choiceType: choiceType ?? this.choiceType,
      minParticipationRate: minParticipationRate ?? this.minParticipationRate,
      requiredApprovalRate: requiredApprovalRate ?? this.requiredApprovalRate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      options: options ?? this.options,
      hasVoted: hasVoted ?? this.hasVoted,
    );
  }
}

