import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/amenity_booking_model.dart';
import '../repositories/amenity_booking_repository.dart';
import 'auth_provider.dart';

final amenityBookingRepositoryProvider = Provider<AmenityBookingRepository>((ref) {
  return AmenityBookingRepository();
});

class AmenityDateQuery {
  final String amenityId;
  final DateTime date;

  const AmenityDateQuery({required this.amenityId, required this.date});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AmenityDateQuery &&
          runtimeType == other.runtimeType &&
          amenityId == other.amenityId &&
          date.year == other.date.year &&
          date.month == other.date.month &&
          date.day == other.date.day;

  @override
  int get hashCode => Object.hash(amenityId, date.year, date.month, date.day);
}

/// Lấy danh sách booking của 1 tiện ích trong 1 ngày
final amenityBookingsForDateProvider =
    FutureProvider.family<List<AmenityBookingModel>, AmenityDateQuery>((ref, query) async {
  final repo = ref.watch(amenityBookingRepositoryProvider);
  return await repo.getBookingsByAmenityAndDate(
    amenityId: query.amenityId,
    date: query.date,
  );
});

/// Danh sách lịch đặt của cư dân đang đăng nhập
final myAmenityBookingsProvider = FutureProvider<List<AmenityBookingModel>>((ref) async {
  final user = ref.watch(authProvider).valueOrNull;
  if (user == null) return [];
  final repo = ref.watch(amenityBookingRepositoryProvider);
  return await repo.getMyBookings(user.id);
});
