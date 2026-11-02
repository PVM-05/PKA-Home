import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/parking_slot_model.dart';
import '../models/parking_capacity_stats_model.dart';
import '../models/visitor_parking_ticket_model.dart';
import '../repositories/parking_repository.dart';

final parkingRepositoryProvider = Provider<ParkingRepository>((ref) {
  return ParkingRepository();
});

class ParkingFilter {
  final String? zone; // 'B1', 'B2', 'all'
  final String? type; // 'car', 'motorcycle', 'all'
  final String? status; // 'available', 'occupied', 'all'
  final String searchQuery;

  const ParkingFilter({
    this.zone,
    this.type,
    this.status,
    this.searchQuery = '',
  });

  ParkingFilter copyWith({
    String? zone,
    String? type,
    String? status,
    String? searchQuery,
  }) {
    return ParkingFilter(
      zone: zone ?? this.zone,
      type: type ?? this.type,
      status: status ?? this.status,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

final parkingFilterProvider = StateProvider<ParkingFilter>((ref) {
  return const ParkingFilter();
});

/// Provider danh sách ô đỗ tầng hầm theo bộ lọc
final parkingSlotsProvider = FutureProvider<List<ParkingSlotModel>>((ref) async {
  final repo = ref.watch(parkingRepositoryProvider);
  final filter = ref.watch(parkingFilterProvider);

  final slots = await repo.fetchSlots(
    zone: filter.zone,
    slotType: filter.type,
    status: filter.status,
  );

  if (filter.searchQuery.trim().isEmpty) {
    return slots;
  }

  final query = filter.searchQuery.trim().toLowerCase();
  return slots.where((s) {
    final slotMatch = s.slotNumber.toLowerCase().contains(query);
    final plateMatch = (s.licensePlate ?? '').toLowerCase().contains(query);
    final aptMatch = (s.apartmentCode ?? '').toLowerCase().contains(query);
    return slotMatch || plateMatch || aptMatch;
  }).toList();
});

/// Provider thống kê sức chứa bãi xe
final parkingCapacityStatsProvider = FutureProvider<ParkingCapacityStatsModel>((ref) async {
  final repo = ref.watch(parkingRepositoryProvider);
  return repo.fetchCapacityStats();
});

/// Provider danh sách vé xe vãng lai đang đỗ
final activeVisitorTicketsProvider = FutureProvider<List<VisitorParkingTicketModel>>((ref) async {
  final repo = ref.watch(parkingRepositoryProvider);
  return repo.fetchActiveVisitorTickets();
});
