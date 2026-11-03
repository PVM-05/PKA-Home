import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/poll_model.dart';
import '../models/poll_result_model.dart';
import '../models/petition_model.dart';
import '../repositories/community_repository.dart';

final communityRepositoryProvider = Provider<CommunityRepository>((ref) {
  return CommunityRepository();
});

/// Danh sách cuộc biểu quyết / khảo sát
final pollsProvider = FutureProvider.family<List<PollModel>, ({String? status, String? apartmentId})>((ref, filter) async {
  final repo = ref.watch(communityRepositoryProvider);
  return repo.fetchPolls(status: filter.status, apartmentId: filter.apartmentId);
});

/// Báo cáo thống kê kết quả biểu quyết
final pollResultsProvider = FutureProvider.family<PollResultModel, String>((ref, pollId) async {
  final repo = ref.watch(communityRepositoryProvider);
  return repo.getPollResults(pollId);
});

/// Danh sách kiến nghị của cư dân
final petitionsProvider = FutureProvider.family<List<PetitionModel>, ({String? status, String? category, String? apartmentId})>((ref, filter) async {
  final repo = ref.watch(communityRepositoryProvider);
  return repo.fetchPetitions(status: filter.status, category: filter.category, apartmentId: filter.apartmentId);
});

/// KPI tổng quan phân hệ Cộng đồng & Biểu quyết
final communityStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  final repo = ref.watch(communityRepositoryProvider);
  final polls = await repo.fetchPolls();
  final petitions = await repo.fetchPetitions();

  final activePolls = polls.where((p) => p.isActive).length;
  final pendingPetitions = petitions.where((p) => p.status == 'pending').length;
  final resolvedPetitions = petitions.where((p) => p.status == 'resolved').length;

  return {
    'activePolls': activePolls,
    'totalPolls': polls.length,
    'pendingPetitions': pendingPetitions,
    'resolvedPetitions': resolvedPetitions,
  };
});

