import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_config.dart';
import '../models/amenity_booking_model.dart';
import '../models/amenity_maintenance_model.dart';

class AmenityBookingRepository {
  final SupabaseClient _client;

  AmenityBookingRepository([SupabaseClient? client])
      : _client = client ?? SupabaseConfig.client;

  String _formatDate(DateTime date) {
    return "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  /// Lấy danh sách lượt đặt chỗ của 1 tiện ích trong ngày cụ thể (bao gồm confirmed & waitlist)
  Future<List<AmenityBookingModel>> getBookingsByAmenityAndDate({
    required String amenityId,
    required DateTime date,
  }) async {
    final dateStr = _formatDate(date);
    try {
      final response = await _client
          .from('amenity_bookings')
          .select('*, apartments(code), users(full_name)')
          .eq('amenity_id', amenityId)
          .eq('booking_date', dateStr)
          .inFilter('status', ['confirmed', 'waitlist']);

      return (response as List)
          .map((json) => AmenityBookingModel.fromJson(json))
          .toList();
    } catch (_) {
      try {
        final response = await _client.rpc('get_amenity_bookings', params: {
          'p_amenity_id': amenityId,
          'p_date': dateStr,
        });
        return (response as List)
            .map((json) => AmenityBookingModel.fromJson(json))
            .toList();
      } catch (_) {
        return [];
      }
    }
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

  /// Đặt lịch tiện ích mới thông qua Atomic RPC (có khóa FOR UPDATE & hỗ trợ Waitlist)
  Future<AmenityBookingModel> createBooking({
    required String amenityId,
    required String apartmentId,
    required String userId,
    required DateTime date,
    required String timeSlot,
    int guestsCount = 1,
    bool allowWaitlist = false,
  }) async {
    final dateStr = _formatDate(date);

    try {
      final response = await _client.rpc('book_amenity_slot', params: {
        'p_amenity_id': amenityId,
        'p_apartment_id': apartmentId,
        'p_booking_date': dateStr,
        'p_time_slot': timeSlot,
        'p_guests_count': guestsCount,
        'p_allow_waitlist': allowWaitlist,
      });

      final resMap = response as Map<String, dynamic>;
      if (resMap['success'] != true) {
        throw Exception(resMap['message'] ?? 'Đặt lịch thất bại.');
      }

      final bookingId = resMap['booking_id'] as String;
      final bookingData = await _client
          .from('amenity_bookings')
          .select('*, building_amenities(name), apartments(code)')
          .eq('id', bookingId)
          .single();

      return AmenityBookingModel.fromJson(bookingData);
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Không thể đặt lịch: $e');
    }
  }

  /// Hủy đặt lịch tiện ích (Trigger Postgres sẽ tự động đôn người trong Waitlist)
  Future<void> cancelBooking(String bookingId) async {
    await _client
        .from('amenity_bookings')
        .update({'status': 'cancelled', 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', bookingId);
  }

  /// Ban quản lý cập nhật trạng thái tiền cọc (none, pending, received, refunded, forfeited)
  Future<void> updateDepositStatus(
    String bookingId,
    String depositStatus, {
    String? notes,
  }) async {
    await _client.from('amenity_bookings').update({
      'deposit_status': depositStatus,
      if (notes != null) 'deposit_notes': notes,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', bookingId);
  }

  /// Ban quản lý điểm danh cư dân đến nhận tiện ích (completed hoặc no_show)
  Future<void> markBookingAttendance(String bookingId, String status) async {
    await _client.from('amenity_bookings').update({
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', bookingId);
  }

  /// Lấy danh sách các khoảng thời gian bảo trì của tiện ích trong ngày
  Future<List<AmenityMaintenanceModel>> getMaintenanceWindows({
    required String amenityId,
    required DateTime date,
  }) async {
    final dayStart = DateTime(date.year, date.month, date.day).toIso8601String();
    final dayEnd = DateTime(date.year, date.month, date.day, 23, 59, 59).toIso8601String();

    try {
      final response = await _client
          .from('amenity_maintenance_windows')
          .select('*, building_amenities(name)')
          .eq('amenity_id', amenityId)
          .lte('start_time', dayEnd)
          .gte('end_time', dayStart);

      return (response as List)
          .map((json) => AmenityMaintenanceModel.fromJson(json))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Ban quản lý tạo lịch tạm ngừng tiện ích để bảo trì/vệ sinh
  Future<void> createMaintenanceWindow({
    required String amenityId,
    required DateTime startTime,
    required DateTime endTime,
    required String reason,
    String? createdBy,
  }) async {
    await _client.from('amenity_maintenance_windows').insert({
      'amenity_id': amenityId,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'reason': reason,
      if (createdBy != null) 'created_by': createdBy,
    });
  }

  /// Ban quản lý xóa lịch bảo trì
  Future<void> deleteMaintenanceWindow(String windowId) async {
    await _client.from('amenity_maintenance_windows').delete().eq('id', windowId);
  }
}
