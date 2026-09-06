import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/user_repository.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository();
});

final coResidentsProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, apartmentId) async {
  if (apartmentId.isEmpty) return [];
  final repo = ref.watch(userRepositoryProvider);
  return await repo.fetchCoResidents(apartmentId);
});
