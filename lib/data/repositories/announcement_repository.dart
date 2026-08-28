import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_config.dart';

final announcementRepositoryProvider = Provider<AnnouncementRepository>((ref) {
  return AnnouncementRepository();
});

class AnnouncementRepository {
  final SupabaseClient _client = SupabaseConfig.client;

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
  }) async {
    await _client.from('announcements').insert({
      'title': title,
      'content': content,
      'is_urgent': isUrgent,
    });
  }

  Future<void> deleteAnnouncement(String id) async {
    await _client.from('announcements').delete().eq('id', id);
  }
}
