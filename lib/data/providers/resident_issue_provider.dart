import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/issue_model.dart';
import '../../../data/repositories/issue_repository.dart';

final _issueReportsStreamProvider = StreamProvider((ref) {
  final repo = ref.watch(issueRepositoryProvider);
  return repo.streamIssues();
});

final residentIssueProvider = FutureProvider<List<IssueModel>>((ref) async {
  // Đăng ký lắng nghe Stream Realtime từ Supabase
  ref.watch(_issueReportsStreamProvider);

  final repo = ref.watch(issueRepositoryProvider);
  final response = await repo.fetchIssues();
  
  return response.map((e) => IssueModel.fromJson(e)).toList();
});
