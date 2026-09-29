import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/issue_rating_model.dart';
import '../repositories/issue_repository.dart';
import 'management_provider.dart';

/// Stream lắng nghe Realtime bảng `issue_ratings` từ Supabase
final issueRatingsStreamProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final repo = ref.watch(issueRepositoryProvider);
  return repo.streamRatings();
});

/// Provider lấy thông tin đánh giá dịch vụ cho một sự cố cụ thể
final issueRatingProvider = FutureProvider.family.autoDispose<IssueRatingModel?, String>((ref, issueId) async {
  // Lắng nghe Realtime để tự làm mới khi có đánh giá/sửa đánh giá
  ref.watch(issueRatingsStreamProvider);

  final repo = ref.watch(issueRepositoryProvider);
  return repo.fetchRatingForIssue(issueId);
});

/// Provider lấy toàn bộ danh sách đánh giá dịch vụ phục vụ BQL giám sát chất lượng
final allIssueRatingsProvider = FutureProvider.autoDispose<List<IssueRatingModel>>((ref) async {
  // Lắng nghe Realtime để tự làm mới khi cư dân gửi đánh giá mới
  ref.watch(issueRatingsStreamProvider);

  final repo = ref.watch(managementRepositoryProvider);
  return repo.fetchAllRatings();
});
