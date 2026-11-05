// Hợp đồng RPC cho Nhóm Cộng Đồng, Biểu Quyết & Kiến Nghị

// -------------------------------------------------------------
// 1. Bỏ Phiếu Biểu Quyết (submit_poll_vote)
// -------------------------------------------------------------
class SubmitPollVoteRequestDto {
  final String pollId;
  final String apartmentId;
  final String? voterUserId;
  final List<String> optionIds;

  const SubmitPollVoteRequestDto({
    required this.pollId,
    required this.apartmentId,
    this.voterUserId,
    required this.optionIds,
  });

  Map<String, dynamic> toRpcParams() {
    final map = <String, dynamic>{
      'p_poll_id': pollId,
      'p_apartment_id': apartmentId,
      'p_option_ids': optionIds,
    };
    if (voterUserId != null && voterUserId!.isNotEmpty) {
      map['p_voter_user_id'] = voterUserId;
    }
    return map;
  }
}

class SubmitPollVoteResponseDto {
  final bool success;
  final String? voteId;
  final double? weight;
  final String message;

  const SubmitPollVoteResponseDto({
    required this.success,
    this.voteId,
    this.weight,
    required this.message,
  });

  factory SubmitPollVoteResponseDto.fromRpc(dynamic raw) {
    if (raw == null) {
      return const SubmitPollVoteResponseDto(
        success: false,
        message: 'Phản hồi từ máy chủ trống rỗng.',
      );
    }
    final map = Map<String, dynamic>.from(raw as Map);
    return SubmitPollVoteResponseDto(
      success: map['success'] == true,
      voteId: map['vote_id'] as String?,
      weight: (map['weight'] as num?)?.toDouble(),
      message: map['message'] as String? ?? '',
    );
  }
}

// -------------------------------------------------------------
// 2. Đồng Thuận Kiến Nghị (endorse_petition)
// -------------------------------------------------------------
class EndorsePetitionRequestDto {
  final String petitionId;
  final String apartmentId;
  final String? userId;

  const EndorsePetitionRequestDto({
    required this.petitionId,
    required this.apartmentId,
    this.userId,
  });

  Map<String, dynamic> toRpcParams() {
    final map = <String, dynamic>{
      'p_petition_id': petitionId,
      'p_apartment_id': apartmentId,
    };
    if (userId != null && userId!.isNotEmpty) {
      map['p_user_id'] = userId;
    }
    return map;
  }
}

class EndorsePetitionResponseDto {
  final bool success;
  final int? endorsementCount;
  final String message;

  const EndorsePetitionResponseDto({
    required this.success,
    this.endorsementCount,
    required this.message,
  });

  factory EndorsePetitionResponseDto.fromRpc(dynamic raw) {
    if (raw == null) {
      return const EndorsePetitionResponseDto(
        success: false,
        message: 'Phản hồi từ máy chủ trống rỗng.',
      );
    }
    final map = Map<String, dynamic>.from(raw as Map);
    return EndorsePetitionResponseDto(
      success: map['success'] == true,
      endorsementCount: (map['endorsement_count'] as num?)?.toInt(),
      message: map['message'] as String? ?? '',
    );
  }
}
