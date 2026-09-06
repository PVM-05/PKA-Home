import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/issue_model.dart';
import '../../../data/repositories/issue_repository.dart';
import 'auth_provider.dart';

final _issueReportsStreamProvider = StreamProvider((ref) {
  final repo = ref.watch(issueRepositoryProvider);
  final userState = ref.watch(authProvider);
  
  final userId = userState.valueOrNull?.id;
  if (userId != null) {
    return repo.streamIssues(userId: userId);
  }
  return const Stream.empty();
});

final residentIssueProvider = FutureProvider<List<IssueModel>>((ref) async {
  // Đăng ký lắng nghe Stream Realtime từ Supabase
  ref.watch(_issueReportsStreamProvider);

  final repo = ref.watch(issueRepositoryProvider);
  final response = await repo.fetchIssues();
  
  final mapped = response.map((e) => IssueModel.fromJson(e)).toList();
  return mapped;
});
