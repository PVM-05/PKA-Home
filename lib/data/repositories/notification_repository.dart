import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_config.dart';
import '../models/notification_model.dart';

class NotificationRepository {
  final SupabaseClient? _customClient;

  NotificationRepository([SupabaseClient? client]) : _customClient = client;

  SupabaseClient get _client => _customClient ?? SupabaseConfig.client;

  /// Lấy danh sách thông báo của cư dân (hỗ trợ lọc theo buildingId)
  Future<List<NotificationModel>> getNotifications(String userId, {String? buildingId}) async {
    var query = _client.from('notifications').select().eq('user_id', userId);
    if (buildingId != null) {
      query = query.eq('building_id', buildingId);
    }
    final response = await query.order('created_at', ascending: false);

    return (response as List).map((json) => NotificationModel.fromJson(json)).toList();
  }

  /// Lắng nghe stream thông báo thời gian thực của người dùng qua Supabase Realtime
  Stream<List<NotificationModel>> streamUserNotifications(String userId, {String? buildingId}) {
    return _client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map((rows) {
          var filtered = rows;
          if (buildingId != null) {
            filtered = filtered.where((r) => r['building_id'] == buildingId).toList();
          }
          return filtered.map((json) => NotificationModel.fromJson(json)).toList();
        });
  }

  /// Đánh dấu một thông báo đã đọc
  Future<void> markAsRead(String notificationId) async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId);
  }

  /// Đánh dấu tất cả thông báo của người dùng đã đọc
  Future<void> markAllAsRead(String userId) async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
  }

  /// Đăng ký hoặc cập nhật FCM device token của người dùng
  Future<void> registerFcmToken({
    required String userId,
    required String token,
    String? deviceInfo,
  }) async {
    await _client.from('user_fcm_tokens').upsert(
      {
        'user_id': userId,
        'token': token,
        'device_info': deviceInfo,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'user_id,token',
    );
  }

  /// Kích hoạt quét nhắc hạn thủ công (dành cho Ban Quản Lý hoặc trigger khẩn cấp)
  Future<int> triggerInvoiceRemindersScan({String? buildingId}) async {
    final result = await _client.rpc(
      'check_and_generate_invoice_due_reminders',
      params: buildingId != null ? {'p_building_id': buildingId} : {},
    );
    return (result as num?)?.toInt() ?? 0;
  }
}
