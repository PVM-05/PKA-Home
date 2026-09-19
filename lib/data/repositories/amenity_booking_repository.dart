import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_config.dart';
import '../models/amenity_booking_model.dart';

class AmenityBookingRepository {
  final SupabaseClient _client;

  AmenityBookingRepository([SupabaseClient? client])
      : _client = client ?? SupabaseConfig.client;

  String _formatDate(DateTime date) {
    return "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  /// Lấy danh sách lượt đặt chỗ của 1 tiện ích trong ngày cụ thể
  Future<List<AmenityBookingModel>> getBookingsByAmenityAndDate({
    required String amenityId,
    required DateTime date,
  }) async {
    final dateStr = _formatDate(date);
    final response = await _client
        .from('amenity_bookings')
        .select('*, apartments(code), users(full_name)')
        .eq('amenity_id', amenityId)
        .eq('booking_date', dateStr)
        .eq('status', 'confirmed');

    return (response as List)
        .map((json) => AmenityBookingModel.fromJson(json))
        .toList();
  }

  /// Lấy danh sách lịch đã đặt của người dùng hiện tại
  Future<List<AmenityBookingModel>> getMyBookings(String userId) async {
    final response = await _client
        .from('amenity_bookings')
        .select('*, building_amenities(name), apartments(code), users(full_name)')
        .eq('booked_by', userId)
        .order('booking_date', ascending: false)
        .order('time_slot', ascending: false);

    return (response as List)
        .map((json) => AmenityBookingModel.fromJson(json))
        .toList();
  }

  /// Đặt lịch tiện ích mới
  Future<AmenityBookingModel> createBooking({
    required String amenityId,
    required String apartmentId,
    required String userId,
    required DateTime date,
    required String timeSlot,
  }) async {
    final dateStr = _formatDate(date);

    // 1. Kiểm tra xem slot đã có ai đặt chưa (Client-side fast check)
    final existing = await _client
        .from('amenity_bookings')
        .select('id')
        .eq('amenity_id', amenityId)
        .eq('booking_date', dateStr)
        .eq('time_slot', timeSlot)
        .eq('status', 'confirmed');

    if ((existing as List).isNotEmpty) {
      throw Exception('Khung giờ $timeSlot ngày $dateStr đã được người khác đặt trước.');
    }

    try {
      final response = await _client
          .from('amenity_bookings')
          .insert({
            'amenity_id': amenityId,
            'apartment_id': apartmentId,
            'booked_by': userId,
            'booking_date': dateStr,
            'time_slot': timeSlot,
            'status': 'confirmed',
          })
          .select('*, building_amenities(name), apartments(code)')
          .single();

      return AmenityBookingModel.fromJson(response);
    } on PostgrestException catch (e) {
      if (e.message.contains('uq_active_amenity_slot') || e.code == '23505') {
        throw Exception('Khung giờ $timeSlot ngày $dateStr vừa được người khác đặt. Vui lòng chọn khung giờ khác.');
      }
      rethrow;
    }
  }

  /// Hủy đặt lịch tiện ích
  Future<void> cancelBooking(String bookingId) async {
    await _client
        .from('amenity_bookings')
        .update({'status': 'cancelled', 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', bookingId);
  }
}
