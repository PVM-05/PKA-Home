import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_config.dart';

final announcementRepositoryProvider = Provider<AnnouncementRepository>((ref) {
  return AnnouncementRepository();
});

class AnnouncementRepository {
  final SupabaseClient? _customClient;

  AnnouncementRepository([SupabaseClient? client]) : _customClient = client;

  SupabaseClient get _client => _customClient ?? SupabaseConfig.client;

  Stream<List<Map<String, dynamic>>> streamAnnouncements() {
    return _client
        .from('announcements')
        .stream(primaryKey: ['id'])
        .order('created_at');
  }

  Future<void> createAnnouncement({
    required String title,
    required String content,
    required bool isUrgent,
    String targetType = 'all',
    String? targetValue,
    String? targetApartment,
  }) async {
    final effectiveValue = targetValue ?? targetApartment;
    await _client.from('announcements').insert({
      'title': title,
      'content': content,
      'is_urgent': isUrgent,
      'target_type': targetType,
      if (effectiveValue != null) 'target_value': effectiveValue,
      if (effectiveValue != null) 'target_apartment': effectiveValue,
    });
  }

  Future<void> updateAnnouncement({
    required String id,
    required String title,
    required String content,
    required bool isUrgent,
    String targetType = 'all',
    String? targetValue,
    String? targetApartment,
  }) async {
    final effectiveValue = targetValue ?? targetApartment;
    await _client.from('announcements').update({
      'title': title,
      'content': content,
      'is_urgent': isUrgent,
      'target_type': targetType,
      if (effectiveValue != null) 'target_value': effectiveValue,
      if (effectiveValue != null) 'target_apartment': effectiveValue,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> deleteAnnouncement(String id) async {
    await _client.from('announcements').delete().eq('id', id);
  }
}
