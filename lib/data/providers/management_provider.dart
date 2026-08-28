import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/management_repository.dart';
import '../../../data/models/resident_model.dart';
import '../../../data/models/apartment_model.dart';
import '../../../data/models/invoice_model.dart';
import '../../../data/models/issue_model.dart';

final managementRepositoryProvider = Provider((ref) => ManagementRepository());

final residentsProvider = FutureProvider.autoDispose<List<ResidentModel>>((ref) async {
  final repo = ref.watch(managementRepositoryProvider);
  return await repo.fetchResidents();
});

final apartmentsProvider = FutureProvider.autoDispose<List<ApartmentModel>>((ref) async {
  final repo = ref.watch(managementRepositoryProvider);
  return await repo.fetchApartments();
});

final invoicesProvider = FutureProvider.autoDispose<List<InvoiceModel>>((ref) async {
  final repo = ref.watch(managementRepositoryProvider);
  return await repo.fetchInvoices();
});

final _allIssuesStreamProvider = StreamProvider((ref) => ref.watch(managementRepositoryProvider).watchRawIssues());

final allIssuesProvider = FutureProvider.autoDispose<List<IssueModel>>((ref) async {
  // Đăng ký lắng nghe Stream Realtime từ Supabase (bất kỳ thay đổi nào cũng làm Future này chạy lại)
  ref.watch(_allIssuesStreamProvider);
  final repo = ref.watch(managementRepositoryProvider);
  return await repo.fetchIssues();
});

final assignResidentProvider = FutureProvider.autoDispose.family<void, Map<String, String>>((ref, params) async {
  final repo = ref.watch(managementRepositoryProvider);
  final userId = params['user_id']!;
  final apartmentId = params['apartment_id']!;
  await repo.assignResidentToApartment(userId, apartmentId);
});
