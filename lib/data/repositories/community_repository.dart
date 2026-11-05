import '../../core/utils/guard_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_config.dart';
import '../models/poll_model.dart';
import '../models/poll_result_model.dart';
import '../models/petition_model.dart';

class CommunityRepository {
  final SupabaseClient? _client;

  CommunityRepository([this._client]);

  SupabaseClient? get _supabase {
    if (_client != null) return _client;
    try {
      if (SupabaseConfig.isConfigured) {
        return SupabaseConfig.client;
      }
    } catch (_) {}
    return null;
  }

  // ─── OFFLINE FALLBACK ENGINE ───
  static final List<PollModel> _mockPolls = [
    PollModel(
      id: 'poll-mock-01',
      pollCode: 'POLL-202611-00001',
      title: 'Biểu quyết lựa chọn đơn vị vận hành năm 2027',
      description: 'Đánh giá năng lực hồ sơ thầu dịch vụ quản lý vận hành tòa nhà chung cư nhiệm kỳ mới theo Điều 102 Luật Nhà ở 2023.',
      category: 'agm',
      voteWeightType: 'by_area',
      choiceType: 'single_choice',
      minParticipationRate: 50.0,
      requiredApprovalRate: 60.0,
      startTime: DateTime.now().subtract(const Duration(days: 1)),
      endTime: DateTime.now().add(const Duration(days: 5)),
      status: 'active',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      options: const [
        PollOptionModel(
          id: 'opt-mock-01',
          pollId: 'poll-mock-01',
          optionText: 'Công ty Savills Property Management',
          optionOrder: 1,
        ),
        PollOptionModel(
          id: 'opt-mock-02',
          pollId: 'poll-mock-01',
          optionText: 'Công ty CBRE Việt Nam',
          optionOrder: 2,
        ),
        PollOptionModel(
          id: 'opt-mock-03',
          pollId: 'poll-mock-01',
          optionText: 'Không đồng thuận với cả 2 đơn vị trên',
          optionOrder: 3,
        ),
      ],
    ),
    PollModel(
      id: 'poll-mock-02',
      pollCode: 'POLL-202611-00002',
      title: 'Khảo sát lắp đặt trạm sạc xe điện thông minh tầng hầm B2',
      description: 'Lấy ý kiến cư dân về phương án bố trí 10 trụ sạc xe máy điện & ô tô điện có hệ thống tự ngắt PCCC an toàn.',
      category: 'maintenance',
      voteWeightType: 'per_apartment',
      choiceType: 'single_choice',
      minParticipationRate: 40.0,
      requiredApprovalRate: 50.0,
      startTime: DateTime.now().subtract(const Duration(days: 3)),
      endTime: DateTime.now().add(const Duration(days: 2)),
      status: 'active',
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      options: const [
        PollOptionModel(
          id: 'opt-mock-04',
          pollId: 'poll-mock-02',
          optionText: 'Đồng ý lắp đặt (Ưu tiên xe cư dân)',
          optionOrder: 1,
        ),
        PollOptionModel(
          id: 'opt-mock-05',
          pollId: 'poll-mock-02',
          optionText: 'Chưa nên lắp đặt (Lo ngại nguy cơ an toàn cháy nổ)',
          optionOrder: 2,
        ),
      ],
    ),
  ];

  static final Map<String, Set<String>> _mockVotedApartments = {
    'poll-mock-01': {'apt-02'},
  };

  static final List<PetitionModel> _mockPetitions = [
    PetitionModel(
      id: 'pet-mock-01',
      petitionCode: 'PET-202611-00001',
      apartmentId: 'apt-01',
      apartmentCode: 'A0502',
      authorUserId: 'usr-01',
      authorName: 'Nguyễn Văn Nam',
      title: 'Đề xuất lắp thêm camera hành lang tầng 5 tháp A',
      content: 'Khu vực hành lang tầng 5 góc khuất cạnh lối thoát hiểm chưa có mắt camera giám sát. Đề nghị BQL khảo sát lắp bổ sung để đảm bảo an ninh.',
      category: 'security',
      endorsementCount: 14,
      status: 'in_progress',
      officialResponse: 'BQL đã tiếp nhận kiến nghị và cử kỹ thuật khảo sát trong tuần này.',
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
    PetitionModel(
      id: 'pet-mock-02',
      petitionCode: 'PET-202611-00002',
      apartmentId: 'apt-02',
      apartmentCode: 'A0205',
      authorUserId: 'usr-02',
      authorName: 'Trần Minh Tuấn',
      title: 'Mở cửa phòng tập Gym sớm hơn lúc 5h30 sáng',
      content: 'Hiện tại phòng Gym mở lúc 6h00 khiến cư dân đi làm sớm không kịp tập luyện. Kính mong BQL hỗ trợ điều chỉnh giờ mở cửa từ 5h30 sáng.',
      category: 'amenity',
      endorsementCount: 28,
      status: 'resolved',
      officialResponse: 'BQL đã cập nhật quy chế và bố trí nhân viên mở cửa từ 5h30 sáng các ngày trong tuần bắt đầu từ ngày 01 tháng sau.',
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
    ),
  ];

  static final Map<String, Set<String>> _mockEndorsedApartments = {
    'pet-mock-01': {'apt-01', 'apt-03'},
    'pet-mock-02': {'apt-02', 'apt-04'},
  };

  // ─── 1. POLLS APIS ───
  Future<List<PollModel>> fetchPolls({String? status, String? apartmentId}) async {
    final client = _supabase;
    if (client != null) {
      try {
        var query = client.from('polls').select('*, poll_options(*)');
        if (status != null && status.isNotEmpty) {
          query = query.eq('status', status);
        }
        final res = await query.order('created_at', ascending: false);
        final list = (res as List).map((j) => PollModel.fromJson(j as Map<String, dynamic>)).toList();

        // Kiểm tra xem apartmentId đã bầu chưa nếu có apartmentId
        if (apartmentId != null && apartmentId.isNotEmpty) {
          final votesRes = await client.from('poll_votes').select('poll_id').eq('apartment_id', apartmentId);
          final votedPollIds = (votesRes as List).map((v) => v['poll_id'] as String).toSet();
          return list.map((p) => p.copyWith(hasVoted: votedPollIds.contains(p.id))).toList();
        }
        return list;
      } catch (_) {
        // Fallback
      }
    }

    var result = List<PollModel>.from(_mockPolls);
    if (status != null && status.isNotEmpty) {
      result = result.where((p) => p.status == status).toList();
    }
    if (apartmentId != null && apartmentId.isNotEmpty) {
      result = result.map((p) {
        final votedSet = _mockVotedApartments[p.id] ?? {};
        return p.copyWith(hasVoted: votedSet.contains(apartmentId));
      }).toList();
    }
    return result;
  }

  Future<PollModel> createPoll({
    required String title,
    String? description,
    String category = 'general',
    String voteWeightType = 'per_apartment',
    String choiceType = 'single_choice',
    double minParticipationRate = 50.0,
    double requiredApprovalRate = 50.0,
    required DateTime startTime,
    required DateTime endTime,
    required List<String> options,
    required String createdBy,
    String? buildingId,
  }) async {
    final client = _supabase;
    if (client != null) {
      try {
        final payload = {
          'title': title,
          'description': description,
          'category': category,
          'vote_weight_type': voteWeightType,
          'choice_type': choiceType,
          'min_participation_rate': minParticipationRate,
          'required_approval_rate': requiredApprovalRate,
          'start_time': startTime.toIso8601String(),
          'end_time': endTime.toIso8601String(),
          'created_by': createdBy,
          'building_id': buildingId,
        };
        final pollRes = await client.from('polls').insert(payload).select().single();
        final pollId = pollRes['id'] as String;

        // Insert options
        final optionPayloads = options.asMap().entries.map((e) => {
          'poll_id': pollId,
          'option_text': e.value,
          'option_order': e.key + 1,
        }).toList();
        final optionsRes = await client.from('poll_options').insert(optionPayloads).select();

        final completeJson = Map<String, dynamic>.from(pollRes);
        completeJson['poll_options'] = optionsRes;
        return PollModel.fromJson(completeJson);
      } catch (_) {
        // Fallback
      }
    }

    final id = 'poll-${DateTime.now().millisecondsSinceEpoch}';
    final code = 'POLL-${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}-${(_mockPolls.length + 1).toString().padLeft(5, '0')}';
    final parsedOptions = options.asMap().entries.map((e) => PollOptionModel(
      id: 'opt-$id-${e.key}',
      pollId: id,
      optionText: e.value,
      optionOrder: e.key + 1,
    )).toList();

    final poll = PollModel(
      id: id,
      pollCode: code,
      title: title,
      description: description,
      category: category,
      voteWeightType: voteWeightType,
      choiceType: choiceType,
      minParticipationRate: minParticipationRate,
      requiredApprovalRate: requiredApprovalRate,
      startTime: startTime,
      endTime: endTime,
      status: 'active',
      createdBy: createdBy,
      createdAt: DateTime.now(),
      options: parsedOptions,
    );
    _mockPolls.insert(0, poll);
    return poll;
  }

  Future<Map<String, dynamic>> submitPollVote({
    required String pollId,
    required String apartmentId,
    required String voterUserId,
    required List<String> selectedOptionIds,
  }) async {
    return FailClosedGuard.guard(
      operation: 'submitPollVote',
      call: () async {
        final client = _supabase;
        if (client == null) throw const AppException('Supabase chưa sẵn sàng');
        final res = await client.rpc('submit_poll_vote', params: {
          'p_poll_id': pollId,
          'p_apartment_id': apartmentId,
          'p_voter_user_id': voterUserId,
          'p_option_ids': selectedOptionIds,
        });
        return Map<String, dynamic>.from(res as Map);
      },
      mockFallback: () {
        final votedSet = _mockVotedApartments.putIfAbsent(pollId, () => <String>{});
        if (votedSet.contains(apartmentId)) {
          return {'success': false, 'message': 'Căn hộ này đã tham gia biểu quyết rồi'};
        }
        votedSet.add(apartmentId);

        return {
          'success': true,
          'message': 'Gửi phiếu biểu quyết thành công (Mock)',
          'vote_id': 'vote-${DateTime.now().millisecondsSinceEpoch}',
        };
      },
    );
  }

  Future<PollResultModel> getPollResults(String pollId) async {
    final client = _supabase;
    if (client != null) {
      try {
        final res = await client.rpc('get_poll_results', params: {'p_poll_id': pollId});
        return PollResultModel.fromJson(Map<String, dynamic>.from(res as Map));
      } catch (_) {
        // Fallback
      }
    }

    final poll = _mockPolls.firstWhere(
      (p) => p.id == pollId,
      orElse: () => _mockPolls.first,
    );
    final votedCount = (_mockVotedApartments[poll.id] ?? {}).length + 35;
    const totalApts = 50;
    final rate = (votedCount / totalApts) * 100;

    final optResults = poll.options.asMap().entries.map((e) {
      final cnt = e.key == 0 ? 25 : 10;
      final pct = votedCount > 0 ? (cnt / votedCount) * 100 : 0.0;
      return PollOptionResultModel(
        optionId: e.value.id,
        optionText: e.value.optionText,
        voteCount: cnt,
        voteWeightSum: cnt * 75.0,
        percentOfVotes: double.parse(pct.toStringAsFixed(1)),
      );
    }).toList();

    return PollResultModel(
      pollId: poll.id,
      pollCode: poll.pollCode,
      title: poll.title,
      status: poll.status,
      voteWeightType: poll.voteWeightType,
      totalApartments: totalApts,
      votedApartments: votedCount,
      totalArea: totalApts * 75.0,
      votedArea: votedCount * 75.0,
      participationRate: double.parse(rate.toStringAsFixed(1)),
      isQuorumMet: rate >= poll.minParticipationRate,
      options: optResults,
    );
  }

  // ─── 2. RESIDENT PETITIONS APIS ───
  Future<List<PetitionModel>> fetchPetitions({
    String? status,
    String? category,
    String? apartmentId,
  }) async {
    final client = _supabase;
    if (client != null) {
      try {
        var query = client.from('resident_petitions').select('*, apartments(code), users!resident_petitions_author_user_id_fkey(full_name)');
        if (status != null && status.isNotEmpty) {
          query = query.eq('status', status);
        }
        if (category != null && category.isNotEmpty) {
          query = query.eq('category', category);
        }
        final res = await query.order('created_at', ascending: false);
        final list = (res as List).map((j) => PetitionModel.fromJson(j as Map<String, dynamic>)).toList();

        if (apartmentId != null && apartmentId.isNotEmpty) {
          final endRes = await client.from('petition_endorsements').select('petition_id').eq('apartment_id', apartmentId);
          final endorsedIds = (endRes as List).map((e) => e['petition_id'] as String).toSet();
          return list.map((p) => p.copyWith(isEndorsedByMe: endorsedIds.contains(p.id))).toList();
        }
        return list;
      } catch (_) {
        // Fallback
      }
    }

    var result = List<PetitionModel>.from(_mockPetitions);
    if (status != null && status.isNotEmpty) {
      result = result.where((p) => p.status == status).toList();
    }
    if (category != null && category.isNotEmpty) {
      result = result.where((p) => p.category == category).toList();
    }
    if (apartmentId != null && apartmentId.isNotEmpty) {
      result = result.map((p) {
        final endorsedSet = _mockEndorsedApartments[p.id] ?? {};
        return p.copyWith(isEndorsedByMe: endorsedSet.contains(apartmentId));
      }).toList();
    }
    return result;
  }

  Future<PetitionModel> createPetition({
    required String apartmentId,
    required String authorUserId,
    required String title,
    required String content,
    String category = 'general',
    List<String> imageUrls = const [],
  }) async {
    final client = _supabase;
    if (client != null) {
      try {
        final payload = {
          'apartment_id': apartmentId,
          'author_user_id': authorUserId,
          'title': title,
          'content': content,
          'category': category,
          'image_urls': imageUrls,
        };
        final res = await client.from('resident_petitions').insert(payload).select('*, apartments(code)').single();
        return PetitionModel.fromJson(res);
      } catch (_) {
        // Fallback
      }
    }

    final id = 'pet-${DateTime.now().millisecondsSinceEpoch}';
    final code = 'PET-${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}-${(_mockPetitions.length + 1).toString().padLeft(5, '0')}';
    final pet = PetitionModel(
      id: id,
      petitionCode: code,
      apartmentId: apartmentId,
      apartmentCode: 'A0110',
      authorUserId: authorUserId,
      authorName: 'Cư dân',
      title: title,
      content: content,
      category: category,
      imageUrls: imageUrls,
      endorsementCount: 0,
      status: 'pending',
      createdAt: DateTime.now(),
    );
    _mockPetitions.insert(0, pet);
    return pet;
  }

  Future<Map<String, dynamic>> endorsePetition({
    required String petitionId,
    required String apartmentId,
    required String userId,
  }) async {
    return FailClosedGuard.guard(
      operation: 'endorsePetition',
      call: () async {
        final client = _supabase;
        if (client == null) throw const AppException('Supabase chưa sẵn sàng');
        final res = await client.rpc('endorse_petition', params: {
          'p_petition_id': petitionId,
          'p_apartment_id': apartmentId,
          'p_user_id': userId,
        });
        return Map<String, dynamic>.from(res as Map);
      },
      mockFallback: () {
        final endorsedSet = _mockEndorsedApartments.putIfAbsent(petitionId, () => <String>{});
        if (endorsedSet.contains(apartmentId)) {
          return {'success': false, 'message': 'Căn hộ của bạn đã bấm đồng thuận kiến nghị này rồi'};
        }
        endorsedSet.add(apartmentId);

        final idx = _mockPetitions.indexWhere((p) => p.id == petitionId);
        if (idx != -1) {
          final current = _mockPetitions[idx];
          _mockPetitions[idx] = current.copyWith(
            endorsementCount: current.endorsementCount + 1,
            isEndorsedByMe: true,
          );
        }

        return {
          'success': true,
          'message': 'Đã ghi nhận sự đồng thuận của bạn (Mock)',
          'endorsement_count': idx != -1 ? _mockPetitions[idx].endorsementCount : 1,
        };
      },
    );
  }

  Future<Map<String, dynamic>> updatePetitionResponse({
    required String petitionId,
    required String status,
    required String officialResponse,
    required String staffId,
  }) async {
    final client = _supabase;
    if (client != null) {
      try {
        final res = await client.rpc('update_petition_response', params: {
          'p_petition_id': petitionId,
          'p_status': status,
          'p_response': officialResponse,
          'p_staff_id': staffId,
        });
        return Map<String, dynamic>.from(res as Map);
      } catch (_) {
        // Fallback
      }
    }

    final idx = _mockPetitions.indexWhere((p) => p.id == petitionId);
    if (idx == -1) {
      return {'success': false, 'message': 'Không tìm thấy kiến nghị'};
    }

    _mockPetitions[idx] = _mockPetitions[idx].copyWith(
      status: status,
      officialResponse: officialResponse,
      respondedByStaffId: staffId,
      respondedAt: DateTime.now(),
    );

    return {
      'success': true,
      'message': 'Cập nhật phản hồi chính thức thành công',
      'status': status,
    };
  }
}

