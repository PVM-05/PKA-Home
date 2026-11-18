import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/paginated_list.dart';
import '../../../data/models/issue_model.dart';
import '../../../data/repositories/issue_repository.dart';
import 'auth_provider.dart';
import 'resident_apartment_provider.dart';

final _issueReportsStreamProvider = StreamProvider((ref) {
  final repo = ref.watch(issueRepositoryProvider);
  final userState = ref.watch(authProvider);
  final activeAptId = ref.watch(selectedApartmentIdProvider);
  
  final userId = userState.valueOrNull?.id;
  if (userId != null || activeAptId != null) {
    return repo.streamIssues(userId: userId, apartmentId: activeAptId);
  }
  return const Stream.empty();
});

/// Notifier quản lý danh sách sự cố có phân trang (Pagination & Infinite Scroll)
class ResidentIssuePaginatedNotifier extends StateNotifier<AsyncValue<PaginatedList<IssueModel>>> {
  final IssueRepository _repo;
  final String? _apartmentId;
  static const int _pageSize = 20;

  ResidentIssuePaginatedNotifier({
    required IssueRepository repo,
    required String? apartmentId,
  }) : this._(repo, apartmentId);

  ResidentIssuePaginatedNotifier._(this._repo, this._apartmentId)
      : super(const AsyncValue.loading()) {
    fetchInitial();
  }

  Future<void> fetchInitial() async {
    try {
      state = const AsyncValue.loading();
      final response = await _repo.fetchIssues(
        apartmentId: _apartmentId,
        limit: _pageSize,
        offset: 0,
      );
      final items = response.map((e) => IssueModel.fromJson(e)).toList();
      state = AsyncValue.data(
        PaginatedList<IssueModel>(
          items: items,
          page: 1,
          pageSize: _pageSize,
          hasMore: items.length >= _pageSize,
          isLoadingMore: false,
        ),
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncValue.data(current.copyWith(isLoadingMore: true));
    try {
      final response = await _repo.fetchIssues(
        apartmentId: _apartmentId,
        limit: _pageSize,
        offset: current.items.length,
      );
      final newItems = response.map((e) => IssueModel.fromJson(e)).toList();
      state = AsyncValue.data(
        current.copyWith(
          items: [...current.items, ...newItems],
          page: current.page + 1,
          hasMore: newItems.length >= _pageSize,
          isLoadingMore: false,
        ),
      );
    } catch (e) {
      state = AsyncValue.data(current.copyWith(isLoadingMore: false));
    }
  }
}

final residentIssuePaginatedProvider = StateNotifierProvider.autoDispose<
    ResidentIssuePaginatedNotifier, AsyncValue<PaginatedList<IssueModel>>>((ref) {
  ref.watch(_issueReportsStreamProvider);
  final repo = ref.watch(issueRepositoryProvider);
  final activeAptId = ref.watch(selectedApartmentIdProvider);
  return ResidentIssuePaginatedNotifier(
    repo: repo,
    apartmentId: activeAptId,
  );
});

/// Giữ nguyên tương thích ngược 100% cho các màn hình và test hiện có
final residentIssueProvider = FutureProvider<List<IssueModel>>((ref) async {
  final paginated = ref.watch(residentIssuePaginatedProvider);
  return paginated.when(
    data: (p) => p.items,
    loading: () => const [],
    error: (e, st) => throw e,
  );
});
