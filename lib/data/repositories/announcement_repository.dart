import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_config.dart';
import '../../core/utils/guard_helper.dart';

final announcementRepositoryProvider = Provider<AnnouncementRepository>((ref) {
  return AnnouncementRepository();
});

class AnnouncementRepository {
  final SupabaseClient? _customClient;

  AnnouncementRepository([SupabaseClient? client]) : _customClient = client;

  SupabaseClient? get _clientSafe {
    if (_customClient != null) return _customClient;
    try {
      if (SupabaseConfig.isConfigured) {
        return SupabaseConfig.client;
      }
    } catch (_) {}
    return null;
  }

  Stream<List<Map<String, dynamic>>> streamAnnouncements() {
    final client = _clientSafe;
    if (client == null) {
      return Stream.value(<Map<String, dynamic>>[]);
    }
    return client
        .from('announcements')
        .stream(primaryKey: ['id'])
        .order('is_pinned', ascending: false)
        .order('created_at', ascending: false);
  }

  Future<Map<String, dynamic>> createAnnouncement({
    required String title,
    required String content,
    required bool isUrgent,
    String targetType = 'all',
    String? targetValue,
    String? targetApartment,
    String category = 'general',
    DateTime? eventStartAt,
    DateTime? eventEndAt,
    bool isPinned = false,
    String? hotlineContact,
    bool autoBroadcast = true,
  }) async {
    final effectiveValue = targetValue ?? targetApartment;
    final payload = <String, dynamic>{
      'title': title,
      'content': content,
      'is_urgent': isUrgent,
      'target_type': targetType,
      'target_value': ?effectiveValue,
      'target_apartment': ?effectiveValue,
      'category': category,
      'event_start_at': ?eventStartAt?.toIso8601String(),
      'event_end_at': ?eventEndAt?.toIso8601String(),
      'is_pinned': isPinned,
      if (hotlineContact != null && hotlineContact.trim().isNotEmpty)
        'hotline_contact': hotlineContact.trim(),
    };

    final client = _clientSafe;
    if (client == null) {
      throw const AppException('Không thể kết nối đến máy chủ thông báo');
    }

    final res = await client
        .from('announcements')
        .insert(payload)
        .select('id')
        .single();
    final announcementId = res['id']?.toString() ?? '';

    if (autoBroadcast && announcementId.isNotEmpty) {
      await broadcastAnnouncement(announcementId);
    }

    return {'success': true, 'id': announcementId};
  }

  Future<Map<String, dynamic>> broadcastAnnouncement(String id) async {
    final client = _clientSafe;
    if (client == null) {
      throw const AppException('Không thể kết nối đến máy chủ thông báo');
    }

    try {
      final res = await client.rpc(
        'broadcast_announcement',
        params: {'p_announcement_id': id},
      );
      return Map<String, dynamic>.from(res as Map);
    } catch (e) {
      return {'success': false, 'message': 'Lỗi phát tán thông báo: $e'};
    }
  }

  Future<Map<String, dynamic>> markAnnouncementAsRead(
    String id,
    String userId,
  ) async {
    final client = _clientSafe;
    if (client == null) {
      throw const AppException('Không thể kết nối đến máy chủ thông báo');
    }

    try {
      final res = await client.rpc(
        'mark_announcement_read',
        params: {
          'p_announcement_id': id,
          'p_user_id': userId,
        },
      );
      return Map<String, dynamic>.from(res as Map);
    } catch (e) {
      return {'success': false, 'message': 'Lỗi cập nhật đã đọc: $e'};
    }
  }

  Future<void> updateAnnouncement({
    required String id,
    required String title,
    required String content,
    required bool isUrgent,
    String targetType = 'all',
    String? targetValue,
    String? targetApartment,
    String category = 'general',
    DateTime? eventStartAt,
    DateTime? eventEndAt,
    bool isPinned = false,
    String? hotlineContact,
  }) async {
    final effectiveValue = targetValue ?? targetApartment;
    final payload = <String, dynamic>{
      'title': title,
      'content': content,
      'is_urgent': isUrgent,
      'target_type': targetType,
      'target_value': ?effectiveValue,
      'target_apartment': ?effectiveValue,
      'category': category,
      'event_start_at': ?eventStartAt?.toIso8601String(),
      'event_end_at': ?eventEndAt?.toIso8601String(),
      'is_pinned': isPinned,
      'hotline_contact': ?hotlineContact?.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    final client = _clientSafe;
    if (client == null) return;

    await client.from('announcements').update(payload).eq('id', id);
  }

  Future<void> deleteAnnouncement(String id) async {
    final client = _clientSafe;
    if (client == null) return;
    await client.from('announcements').delete().eq('id', id);
  }
}
