import '../../core/utils/guard_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_config.dart';
import '../models/poll_model.dart';
import '../models/poll_result_model.dart';
import '../models/petition_model.dart';

class CommunityRepository {
  final SupabaseClient? _client;
  final String? _defaultBuildingId;

  CommunityRepository([this._client, this._defaultBuildingId]);

  SupabaseClient? get _supabase {
    if (_client != null) return _client;
    try {
      if (SupabaseConfig.isConfigured) {
        return SupabaseConfig.client;
      }
    } catch (_) {}
    return null;
  }

  // ─── 1. POLLS APIS ───
  Future<List<PollModel>> fetchPolls({
    String? status,
    String? apartmentId,
  }) async {
    return FailClosedGuard.guard(
      operation: 'fetchPolls',
      call: () async {
        final client = _supabase;
        if (client == null) throw const AppException('Supabase chưa sẵn sàng');
        var query = client.from('polls').select('*, poll_options(*)');
        if (_defaultBuildingId != null && _defaultBuildingId.isNotEmpty) {
          query = query.or('building_id.eq.$_defaultBuildingId,building_id.is.null');
        }
        if (status != null && status.isNotEmpty) {
          query = query.eq('status', status);
        }
        final res = await query.order('created_at', ascending: false);
        final list = (res as List)
            .map((j) => PollModel.fromJson(j as Map<String, dynamic>))
            .toList();

        // Kiểm tra xem apartmentId đã bầu chưa nếu có apartmentId
        if (apartmentId != null && apartmentId.isNotEmpty) {
          final votesRes = await client
              .from('poll_votes')
              .select('poll_id')
              .eq('apartment_id', apartmentId);
          final votedPollIds = (votesRes as List)
              .map((v) => v['poll_id'] as String)
              .toSet();
          return list
              .map((p) => p.copyWith(hasVoted: votedPollIds.contains(p.id)))
              .toList();
        }
        return list;
      },
    );
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
    return FailClosedGuard.guard(
      operation: 'createPoll',
      call: () async {
        final client = _supabase;
        if (client == null) throw const AppException('Supabase chưa sẵn sàng');
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
          'building_id': (buildingId != null && buildingId.isNotEmpty)
              ? buildingId
              : _defaultBuildingId,
        };
        final pollRes = await client
            .from('polls')
            .insert(payload)
            .select()
            .single();
        final pollId = pollRes['id'] as String;

        // Insert options
        final optionPayloads = options
            .asMap()
            .entries
            .map(
              (e) => {
                'poll_id': pollId,
                'option_text': e.value,
                'option_order': e.key + 1,
              },
            )
            .toList();
        final optionsRes = await client
            .from('poll_options')
            .insert(optionPayloads)
            .select();

        final completeJson = Map<String, dynamic>.from(pollRes);
        completeJson['poll_options'] = optionsRes;
        return PollModel.fromJson(completeJson);
      },
    );
  }

  Future<Map<String, dynamic>> submitPollVote({
    required String pollId,
    required String apartmentId,
    String? voterUserId,
    required List<String> selectedOptionIds,
  }) async {
    return FailClosedGuard.guard(
      operation: 'submitPollVote',
      call: () async {
        final client = _supabase;
        if (client == null) throw const AppException('Supabase chưa sẵn sàng');
        final params = <String, dynamic>{
          'p_poll_id': pollId,
          'p_apartment_id': apartmentId,
          'p_option_ids': selectedOptionIds,
        };
        if (voterUserId != null && voterUserId.isNotEmpty) {
          params['p_voter_user_id'] = voterUserId;
        }
        final res = await client.rpc(
          'submit_poll_vote',
          params: params,
        );
        return Map<String, dynamic>.from(res as Map);
      },
    );
  }

  Future<PollResultModel> getPollResults(String pollId) async {
    return FailClosedGuard.guard(
      operation: 'getPollResults',
      call: () async {
        final client = _supabase;
        if (client == null) throw const AppException('Supabase chưa sẵn sàng');
        final res = await client.rpc(
          'get_poll_results',
          params: {'p_poll_id': pollId},
        );
        return PollResultModel.fromJson(Map<String, dynamic>.from(res as Map));
      },
    );
  }

  // ─── 2. RESIDENT PETITIONS APIS ───
  Future<List<PetitionModel>> fetchPetitions({
    String? status,
    String? category,
    String? apartmentId,
  }) async {
    return FailClosedGuard.guard(
      operation: 'fetchPetitions',
      call: () async {
        final client = _supabase;
        if (client == null) throw const AppException('Supabase chưa sẵn sàng');
        var query = client
            .from('resident_petitions')
            .select(
              '*, apartments(code), users!resident_petitions_author_user_id_fkey(full_name)',
            );
        if (_defaultBuildingId != null && _defaultBuildingId.isNotEmpty) {
          query = query.or('building_id.eq.$_defaultBuildingId,building_id.is.null');
        }
        if (status != null && status.isNotEmpty) {
          query = query.eq('status', status);
        }
        if (category != null && category.isNotEmpty) {
          query = query.eq('category', category);
        }
        final res = await query.order('created_at', ascending: false);
        final list = (res as List)
            .map((j) => PetitionModel.fromJson(j as Map<String, dynamic>))
            .toList();

        if (apartmentId != null && apartmentId.isNotEmpty) {
          final endRes = await client
              .from('petition_endorsements')
              .select('petition_id')
              .eq('apartment_id', apartmentId);
          final endorsedIds = (endRes as List)
              .map((e) => e['petition_id'] as String)
              .toSet();
          return list
              .map(
                (p) => p.copyWith(isEndorsedByMe: endorsedIds.contains(p.id)),
              )
              .toList();
        }
        return list;
      },
    );
  }

  Future<PetitionModel> createPetition({
    required String apartmentId,
    required String authorUserId,
    required String title,
    required String content,
    String category = 'general',
    List<String> imageUrls = const [],
  }) async {
    return FailClosedGuard.guard(
      operation: 'createPetition',
      call: () async {
        final client = _supabase;
        if (client == null) throw const AppException('Supabase chưa sẵn sàng');
        final payload = {
          if (_defaultBuildingId != null && _defaultBuildingId.isNotEmpty)
            'building_id': _defaultBuildingId,
          'apartment_id': apartmentId,
          'author_user_id': authorUserId,
          'title': title,
          'content': content,
          'category': category,
          'image_urls': imageUrls,
        };
        final res = await client
            .from('resident_petitions')
            .insert(payload)
            .select('*, apartments(code)')
            .single();
        return PetitionModel.fromJson(res);
      },
    );
  }

  Future<Map<String, dynamic>> endorsePetition({
    required String petitionId,
    required String apartmentId,
    String? userId,
  }) async {
    return FailClosedGuard.guard(
      operation: 'endorsePetition',
      call: () async {
        final client = _supabase;
        if (client == null) throw const AppException('Supabase chưa sẵn sàng');
        final params = <String, dynamic>{
          'p_petition_id': petitionId,
          'p_apartment_id': apartmentId,
        };
        if (userId != null && userId.isNotEmpty) {
          params['p_user_id'] = userId;
        }
        final res = await client.rpc(
          'endorse_petition',
          params: params,
        );
        return Map<String, dynamic>.from(res as Map);
      },
    );
  }

  Future<Map<String, dynamic>> updatePetitionResponse({
    required String petitionId,
    required String status,
    required String officialResponse,
    required String staffId,
  }) async {
    return FailClosedGuard.guard(
      operation: 'updatePetitionResponse',
      call: () async {
        final client = _supabase;
        if (client == null) throw const AppException('Supabase chưa sẵn sàng');
        final res = await client.rpc(
          'update_petition_response',
          params: {
            'p_petition_id': petitionId,
            'p_status': status,
            'p_response': officialResponse,
            'p_staff_id': staffId,
          },
        );
        return Map<String, dynamic>.from(res as Map);
      },
    );
  }
}
