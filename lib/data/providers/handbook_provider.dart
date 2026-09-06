import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/handbook_repository.dart';
import '../models/emergency_contact_model.dart';
import '../models/building_rule_model.dart';
import '../models/building_amenity_model.dart';

final handbookRepositoryProvider = Provider<HandbookRepository>((ref) {
  return HandbookRepository();
});

// Realtime Stream Triggers
final _contactsStreamProvider = StreamProvider.autoDispose((ref) {
  return ref.watch(handbookRepositoryProvider).watchContacts();
});

final _rulesStreamProvider = StreamProvider.autoDispose((ref) {
  return ref.watch(handbookRepositoryProvider).watchRules();
});

final _amenitiesStreamProvider = StreamProvider.autoDispose((ref) {
  return ref.watch(handbookRepositoryProvider).watchAmenities();
});

// Future Providers that auto-refresh when Realtime events occur
final emergencyContactsProvider = FutureProvider.autoDispose<List<EmergencyContactModel>>((ref) async {
  // Lắng nghe stream để tự động fetch lại khi có thay đổi
  ref.watch(_contactsStreamProvider);
  final repo = ref.watch(handbookRepositoryProvider);
  return await repo.fetchEmergencyContacts();
});

final buildingRulesProvider = FutureProvider.autoDispose<List<BuildingRuleModel>>((ref) async {
  ref.watch(_rulesStreamProvider);
  final repo = ref.watch(handbookRepositoryProvider);
  return await repo.fetchBuildingRules();
});

final buildingAmenitiesProvider = FutureProvider.autoDispose<List<BuildingAmenityModel>>((ref) async {
  ref.watch(_amenitiesStreamProvider);
  final repo = ref.watch(handbookRepositoryProvider);
  return await repo.fetchBuildingAmenities();
});
