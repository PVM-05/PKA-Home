import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/issue_comment_model.dart';
import '../repositories/issue_repository.dart';

/// Provider stream realtime danh sách comment theo issue ID.
/// - Tự động nạp dữ liệu ban đầu qua REST để hiển thị ngay lập tức (không cần chờ websocket kết nối).
/// - Lắng nghe thay đổi qua Supabase Realtime stream khi có comment mới.
/// - Bắt ngoại lệ và fallback an toàn nếu Realtime stream bị timeout (RealtimeSubscribeException),
///   tránh làm gián đoạn hiển thị màn hình trao đổi của người dùng.
final issueCommentsProvider = StreamProvider.family
    .autoDispose<List<IssueCommentModel>, String>((ref, issueId) async* {
  final repo = ref.watch(issueRepositoryProvider);
  List<IssueCommentModel> currentComments = [];

  // 1. Nạp danh sách ban đầu qua REST API (nhanh chóng, không phụ thuộc handshake realtime)
  try {
    final initial = await repo.fetchComments(issueId);
    currentComments =
        initial.map((json) => IssueCommentModel.fromJson(json)).toList();
    yield currentComments;
  } catch (e) {
    debugPrint('[issueCommentsProvider] Lỗi fetch comments ban đầu: $e');
    rethrow;
  }

  // 2. Lắng nghe realtime stream để đồng bộ tức thì khi có bình luận mới
  try {
    final stream = repo.streamComments(issueId);
    await for (final _ in stream) {
      try {
        final updated = await repo.fetchComments(issueId);
        currentComments =
            updated.map((json) => IssueCommentModel.fromJson(json)).toList();
        yield currentComments;
      } catch (e) {
        debugPrint('[issueCommentsProvider] Lỗi cập nhật comments từ realtime event: $e');
        yield currentComments;
      }
    }
  } catch (e) {
    debugPrint('[issueCommentsProvider] Lỗi kết nối realtime stream (timeout/ngắt kết nối): $e');
    // Khi stream bị ngắt hoặc RealtimeSubscribeException(status: timedOut),
    // giữ nguyên danh sách hiện tại để giao diện không bị crash hoặc trắng xóa
    yield currentComments;
  }
});
