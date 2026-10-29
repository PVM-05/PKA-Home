import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/document_lookup_result_model.dart';
import '../repositories/document_repository.dart';

/// Provider cung cấp thể hiện DocumentRepository
final documentRepositoryProvider = Provider<DocumentRepository>((ref) {
  return DocumentRepository();
});

/// FutureProvider.family cho phép tra cứu kết quả chứng từ theo mã tra cứu trực tiếp
final documentLookupFamilyProvider =
    FutureProvider.family<DocumentLookupResultModel, String>((ref, lookupCode) async {
  final repo = ref.watch(documentRepositoryProvider);
  return repo.verifyLookupCode(lookupCode);
});
