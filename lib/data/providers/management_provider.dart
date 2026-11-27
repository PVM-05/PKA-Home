import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/management_repository.dart';
import '../../../data/models/resident_model.dart';
import '../../../data/models/apartment_model.dart';
import '../../../data/models/invoice_model.dart';
import '../../../data/models/issue_model.dart';
import 'building_provider.dart';

final managementRepositoryProvider = Provider((ref) => ManagementRepository());

final apartmentsProvider = FutureProvider.autoDispose<List<ApartmentModel>>((ref) async {
  final activeBuildingId = ref.watch(activeBuildingIdProvider);
  final repo = ref.watch(managementRepositoryProvider);
  final list = await repo.fetchApartments();
  final hasBuildingId = list.any((a) => a.buildingId != null && a.buildingId!.isNotEmpty);
  if (!hasBuildingId || activeBuildingId.isEmpty) return list;
  return list.where((a) => a.buildingId == activeBuildingId).toList();
});

final residentsProvider = FutureProvider.autoDispose<List<ResidentModel>>((ref) async {
  final activeBuildingId = ref.watch(activeBuildingIdProvider);
  final repo = ref.watch(managementRepositoryProvider);
  final apts = await ref.watch(apartmentsProvider.future);
  final residents = await repo.fetchResidents();
  if (activeBuildingId.isNotEmpty && apts.isEmpty) {
    // Tòa nhà mới chưa có căn hộ: không hiển thị cư dân thuộc tòa nhà khác
    return residents
        .where((r) => r.apartments.isEmpty && r.apartment == null)
        .toList();
  }
  final hasBuildingApts = apts.any((a) => a.buildingId != null && a.buildingId!.isNotEmpty);
  if (!hasBuildingApts) return residents;
  final allowedAptIds = apts.map((a) => a.id).toSet();
  return residents.where((r) {
    if (r.apartments.isEmpty && r.apartment == null) return true;
    if (r.apartments.any((link) => allowedAptIds.contains(link.apartmentId))) return true;
    if (r.apartment != null && allowedAptIds.contains(r.apartment!.id)) return true;
    return false;
  }).toList();
});

final invoicesProvider = FutureProvider.autoDispose<List<InvoiceModel>>((ref) async {
  final activeBuildingId = ref.watch(activeBuildingIdProvider);
  final repo = ref.watch(managementRepositoryProvider);
  final apts = await ref.watch(apartmentsProvider.future);
  if (activeBuildingId.isNotEmpty && apts.isEmpty) {
    return const [];
  }
  final invoices = await repo.fetchInvoices();
  final hasBuildingApts = apts.any((a) => a.buildingId != null && a.buildingId!.isNotEmpty);
  if (!hasBuildingApts) return invoices;
  final allowedAptIds = apts.map((a) => a.id).toSet();
  return invoices.where((inv) => allowedAptIds.contains(inv.apartmentId)).toList();
});

final rawIssuesStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  ref.watch(activeBuildingIdProvider);
  return ref.watch(managementRepositoryProvider).watchRawIssues();
});

final allIssuesProvider = FutureProvider.autoDispose<List<IssueModel>>((ref) async {
  final activeBuildingId = ref.watch(activeBuildingIdProvider);
  ref.watch(rawIssuesStreamProvider);
  final repo = ref.watch(managementRepositoryProvider);
  final apts = await ref.watch(apartmentsProvider.future);
  if (activeBuildingId.isNotEmpty && apts.isEmpty) {
    return const [];
  }
  final issues = await repo.fetchIssues();
  final hasBuildingApts = apts.any((a) => a.buildingId != null && a.buildingId!.isNotEmpty);
  if (!hasBuildingApts) return issues;
  final allowedAptIds = apts.map((a) => a.id).toSet();
  return issues.where((iss) => allowedAptIds.contains(iss.apartmentId)).toList();
});

final assignResidentProvider = FutureProvider.autoDispose.family<void, Map<String, String>>((ref, params) async {
  final repo = ref.watch(managementRepositoryProvider);
  final userId = params['user_id']!;
  final apartmentId = params['apartment_id']!;
  await repo.assignResidentToApartment(userId, apartmentId);
});

final managementApartmentVehiclesProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String?>((ref, apartmentId) async {
  return ref.watch(managementRepositoryProvider).fetchResidentVehicles(apartmentId);
});

final residentInvoicesProvider = FutureProvider.autoDispose.family<List<InvoiceModel>, String?>((ref, apartmentId) async {
  return ref.watch(managementRepositoryProvider).fetchResidentInvoices(apartmentId);
});

final residentBookingsProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, userId) async {
  return ref.watch(managementRepositoryProvider).fetchResidentBookings(userId);
});

