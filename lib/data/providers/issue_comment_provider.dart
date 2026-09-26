import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/issue_comment_model.dart';
import '../repositories/issue_repository.dart';

/// Provider stream realtime danh sách comment theo issue ID.
/// Khi có comment mới từ Supabase realtime, tự động cập nhật UI.
final issueCommentsProvider = StreamProvider.family
    .autoDispose<List<IssueCommentModel>, String>((ref, issueId) {
  final repo = ref.watch(issueRepositoryProvider);
  return repo.streamComments(issueId).asyncMap((rawList) async {
    // stream chỉ trả về dữ liệu cơ bản (không join), cần fetch lại với join users
    final fullData = await repo.fetchComments(issueId);
    return fullData.map((json) => IssueCommentModel.fromJson(json)).toList();
  });
});
