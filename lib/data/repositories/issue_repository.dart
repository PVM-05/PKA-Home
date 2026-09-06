import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_config.dart';

final issueRepositoryProvider = Provider<IssueRepository>((ref) {
  return IssueRepository();
});

class IssueRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  Future<void> createIssue({
    required String reporterId,
    required String description,
    File? imageFile,
  }) async {
    // 1. Get apartment_id
    final linkData = await _client
        .from('residents_apartments')
        .select('apartment_id')
        .eq('user_id', reporterId)
        .single();
    final apartmentId = linkData['apartment_id'];

    // 2. Insert issue_reports
    final issueData = await _client.from('issue_reports').insert({
      'apartment_id': apartmentId,
      'reporter_id': reporterId,
      'description': description,
    }).select().single();
    
    final issueId = issueData['id'];

    // 3. Upload image if provided
    if (imageFile != null) {
      final fileExt = imageFile.path.split('.').last;
      final fileName = '$reporterId/${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      
      await _client.storage
          .from('issue-images')
          .upload(fileName, imageFile);
          
      final imageUrl = _client.storage
          .from('issue-images')
          .getPublicUrl(fileName);

      await _client.from('issue_images').insert({
        'issue_report_id': issueId,
        'image_url': imageUrl,
      });
    }
  }

  Stream<List<Map<String, dynamic>>> streamIssues({String? userId}) async* {
    if (userId == null) yield* const Stream<List<Map<String, dynamic>>>.empty();
    try {
      final linkData = await _client.from('residents_apartments').select('apartment_id').eq('user_id', userId!).single();
      final apartmentId = linkData['apartment_id'];
      yield* _client.from('issue_reports').stream(primaryKey: ['id']).eq('apartment_id', apartmentId).map((list) => list);
    } catch (_) {
      yield* const Stream<List<Map<String, dynamic>>>.empty();
    }
  }

  Future<List<Map<String, dynamic>>> fetchIssues() async {
    final response = await _client
        .from('issue_reports')
        .select('*, apartments(*), users:reporter_id(*), issue_images(image_url)')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }
}
