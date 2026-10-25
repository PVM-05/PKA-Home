import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_config.dart';
import '../../core/utils/app_logger.dart';
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
    final response = await _client
        .from('amenity_bookings')
        .select('*, apartments(code), users(full_name), payment_transactions(*)')
        .eq('amenity_id', amenityId)
        .eq('booking_date', dateStr)
        .inFilter('status', ['confirmed', 'waitlist', 'pending_payment']);

    return (response as List)
        .map((json) => AmenityBookingModel.fromJson(json))
        .toList();
  }

  /// Lấy danh sách lịch đã đặt của người dùng hiện tại
  Future<List<AmenityBookingModel>> getMyBookings(String userId) async {
    final response = await _client
        .from('amenity_bookings')
        .select('*, building_amenities(name), apartments(code), users(full_name), payment_transactions(*)')
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
    String? notes,
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
        'p_notes': ?notes,
      });

      final resMap = response as Map<String, dynamic>;
      if (resMap['success'] != true) {
        throw Exception(resMap['message'] ?? 'Đặt lịch thất bại.');
      }

      final bookingId = resMap['booking_id'] as String;
      final bookingData = await _client
          .from('amenity_bookings')
          .select('*, building_amenities(name), apartments(code), payment_transactions(*)')
          .eq('id', bookingId)
          .single();

      return AmenityBookingModel.fromJson(bookingData);
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw Exception('Khung giờ vừa được người khác đặt. Vui lòng chọn khung giờ khác.');
      }
      if (e.code == '23503') {
        throw Exception('Thông tin tiện ích hoặc căn hộ liên kết không tồn tại hoặc không hợp lệ.');
      }
      throw Exception(e.message);
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Không thể đặt lịch: $e');
    }
  }

  /// Hủy đặt lịch tiện ích nguyên tử qua RPC (hủy transaction PENDING và đôn người trong Waitlist)
  Future<Map<String, dynamic>> cancelBooking(String bookingId) async {
    try {
      final response = await _client.rpc('cancel_amenity_booking', params: {
        'p_booking_id': bookingId,
      });
      final resMap = Map<String, dynamic>.from(response as Map);
      if (resMap['success'] != true) {
        throw Exception(resMap['message'] ?? 'Không thể hủy lịch đặt chỗ.');
      }
      return resMap;
    } catch (e) {
      // Fallback: nếu RPC gặp lỗi hoặc quyền hạn, cập nhật trực tiếp
      final response = await _client
          .from('amenity_bookings')
          .update({'status': 'cancelled', 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', bookingId)
          .select('id');
      if ((response as List).isEmpty) {
        throw Exception('Không tìm thấy lượt đặt chỗ hoặc bạn không có quyền hủy.');
      }
      return {'success': true, 'booking_id': bookingId};
    }
  }

  /// Lấy thông tin thống kê tình trạng chỗ trống theo từng khung giờ (ẩn danh PII cư dân khác)
  Future<List<Map<String, dynamic>>> getSlotAvailability({
    required String amenityId,
    required DateTime date,
  }) async {
    final dateStr = _formatDate(date);
    final response = await _client.rpc('get_amenity_slot_availability', params: {
      'p_amenity_id': amenityId,
      'p_date': dateStr,
    });
    return List<Map<String, dynamic>>.from(response as List);
  }

  /// Ban quản lý cập nhật trạng thái tiền cọc (none, pending, received, refunded, forfeited)
  Future<void> updateDepositStatus(
    String bookingId,
    String depositStatus, {
    String? notes,
  }) async {
    final response = await _client.from('amenity_bookings').update({
      'deposit_status': depositStatus,
      'deposit_notes': notes,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', bookingId).select('id');
    if ((response as List).isEmpty) {
      throw Exception('Không tìm thấy lượt đặt chỗ hoặc bạn không có quyền cập nhật tiền cọc.');
    }
  }

  /// Ban quản lý xác nhận thu phí dịch vụ / tiền cọc tiện ích nguyên tử
  Future<Map<String, dynamic>> recordManualAmenityPayment({
    required String bookingId,
    String paymentMethod = 'CASH',
    String? notes,
  }) async {
    final response = await _client.rpc('record_manual_amenity_payment', params: {
      'p_booking_id': bookingId,
      'p_payment_method': paymentMethod,
      'p_notes': notes,
    });
    return Map<String, dynamic>.from(response as Map);
  }

  /// Ban quản lý điểm danh cư dân đến nhận tiện ích (completed hoặc no_show)
  Future<void> markBookingAttendance(String bookingId, String status) async {
    final response = await _client.from('amenity_bookings').update({
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', bookingId).select('id');
    if ((response as List).isEmpty) {
      throw Exception('Không tìm thấy lượt đặt chỗ hoặc bạn không có quyền cập nhật điểm danh.');
    }
  }

  /// Lấy danh sách tất cả các lượt đặt chỗ (cho Ban quản lý theo dõi)
  Future<List<AmenityBookingModel>> getAllBookings() async {
    final response = await _client
        .from('amenity_bookings')
        .select('*, building_amenities(name), apartments(code), users(full_name), payment_transactions(*)')
        .order('booking_date', ascending: false)
        .order('time_slot', ascending: false);

    return (response as List)
        .map((json) => AmenityBookingModel.fromJson(json))
        .toList();
  }

  /// Ban quản lý xác nhận Check-in lượt đặt chỗ (gọi RPC check_in_amenity_booking)
  Future<Map<String, dynamic>> checkInBooking(String bookingId) async {
    final response = await _client.rpc('check_in_amenity_booking', params: {
      'p_booking_id': bookingId,
    });
    return response as Map<String, dynamic>;
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
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST205' || e.code == '42P01') {
        AppLogger.w('Bảng amenity_maintenance_windows chưa khả dụng trên CSDL: ${e.message}');
        return [];
      }
      rethrow;
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
      'created_by': ?createdBy,
    });
  }

  /// Ban quản lý xóa lịch bảo trì
  Future<void> deleteMaintenanceWindow(String windowId) async {
    await _client.from('amenity_maintenance_windows').delete().eq('id', windowId);
  }

  /// Cư dân đổi lịch đặt tiện ích (chống Deadlock, bảo toàn tiền cọc/phí & đôn Waitlist)
  Future<Map<String, dynamic>> rescheduleBooking({
    required String bookingId,
    required DateTime newDate,
    required String newTimeSlot,
    int? newGuestsCount,
    String? newNotes,
  }) async {
    final dateStr = _formatDate(newDate);
    final response = await _client.rpc('reschedule_amenity_booking', params: {
      'p_booking_id': bookingId,
      'p_new_date': dateStr,
      'p_new_time_slot': newTimeSlot,
      'p_new_guests_count': ?newGuestsCount,
      'p_new_notes': ?newNotes,
    });
    final resMap = response as Map<String, dynamic>;
    if (resMap['success'] != true) {
      throw Exception(resMap['message'] ?? 'Không thể đổi lịch đặt tiện ích.');
    }
    return resMap;
  }
}

