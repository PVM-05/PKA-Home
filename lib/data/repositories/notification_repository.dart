import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_config.dart';
import '../models/notification_model.dart';

class NotificationRepository {
  final SupabaseClient _client;

  NotificationRepository([SupabaseClient? client])
      : _client = client ?? SupabaseConfig.client;

  /// Lấy danh sách thông báo của cư dân
  Future<List<NotificationModel>> getNotifications(String userId) async {
    final response = await _client
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (response as List).map((json) => NotificationModel.fromJson(json)).toList();
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
  Future<int> triggerInvoiceRemindersScan() async {
    final result = await _client.rpc('check_and_generate_invoice_due_reminders');
    return (result as num?)?.toInt() ?? 0;
  }
}
