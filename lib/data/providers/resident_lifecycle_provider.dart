import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/apartment_invitation_model.dart';
import '../models/resident_lease_contract_model.dart';
import '../repositories/resident_lifecycle_repository.dart';

export '../models/apartment_invitation_model.dart';
export '../models/resident_lease_contract_model.dart';

final residentLifecycleRepositoryProvider = Provider<ResidentLifecycleRepository>((ref) {
  return ResidentLifecycleRepository();
});

final apartmentContractsProvider =
    FutureProvider.family<List<ResidentLeaseContractModel>, String>((ref, apartmentId) async {
  final repo = ref.watch(residentLifecycleRepositoryProvider);
  return repo.fetchApartmentContracts(apartmentId);
});

final apartmentInvitationsProvider =
    FutureProvider.family<List<ApartmentInvitationModel>, String>((ref, apartmentId) async {
  final repo = ref.watch(residentLifecycleRepositoryProvider);
  return repo.fetchApartmentInvitations(apartmentId);
});
