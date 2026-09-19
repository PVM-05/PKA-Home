import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_config.dart';
import '../../core/utils/app_logger.dart';

final issueRepositoryProvider = Provider<IssueRepository>((ref) {
  return IssueRepository();
});

class CreateIssueResult {
  final String issueId;
  final bool imageUploadFailed;

  const CreateIssueResult({
    required this.issueId,
    this.imageUploadFailed = false,
  });
}

class IssueRepository {
  final SupabaseClient _client;

  IssueRepository([SupabaseClient? client]) : _client = client ?? SupabaseConfig.client;

  Future<CreateIssueResult> createIssue({
    required String reporterId,
    required String description,
    File? imageFile,
    List<File>? imageFiles,
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
    
    final issueId = issueData['id'] as String;

    // 3. Upload images if provided (bọc try-catch để cách ly lỗi upload ảnh)
    final filesToUpload = <File>[];
    if (imageFiles != null && imageFiles.isNotEmpty) {
      filesToUpload.addAll(imageFiles);
    } else if (imageFile != null) {
      filesToUpload.add(imageFile);
    }

    bool imageUploadFailed = false;
    for (int i = 0; i < filesToUpload.length; i++) {
      try {
        final file = filesToUpload[i];
        final fileExt = file.path.split('.').last;
        final fileName = '$reporterId/$issueId/${DateTime.now().millisecondsSinceEpoch}_$i.$fileExt';
        
        await _client.storage
            .from('issue-images')
            .upload(fileName, file);
            
        final imageUrl = _client.storage
            .from('issue-images')
            .getPublicUrl(fileName);

        await _client.from('issue_images').insert({
          'issue_report_id': issueId,
          'image_url': imageUrl,
        });
      } catch (e, stack) {
        AppLogger.e('Lỗi tải ảnh sự cố lên Storage: $e', e, stack);
        imageUploadFailed = true;
      }
    }

    return CreateIssueResult(
      issueId: issueId,
      imageUploadFailed: imageUploadFailed,
    );
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
        .select('*, apartments(*), users:reporter_id(*), issue_images(image_url, image_role)')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> deleteIssue({
    required String issueId,
    List<String>? imageUrls,
  }) async {
    // 1. Xóa bản ghi trong bảng issue_reports (issue_images tự động xóa qua ON DELETE CASCADE)
    await _client.from('issue_reports').delete().eq('id', issueId);

    // 2. Dọn dẹp ảnh trên Supabase Storage nếu có
    if (imageUrls != null && imageUrls.isNotEmpty) {
      try {
        final filePaths = <String>[];
        for (final url in imageUrls) {
          final uri = Uri.tryParse(url);
          if (uri != null) {
            final segments = uri.pathSegments;
            final bucketIndex = segments.indexOf('issue-images');
            if (bucketIndex != -1 && bucketIndex + 1 < segments.length) {
              filePaths.add(segments.sublist(bucketIndex + 1).join('/'));
            }
          }
        }
        if (filePaths.isNotEmpty) {
          await _client.storage.from('issue-images').remove(filePaths);
        }
      } catch (e) {
        AppLogger.w('Không thể dọn dẹp ảnh trên storage khi xóa phản ánh: $e');
      }
    }
  }

  Future<void> updateIssue({
    required String issueId,
    required String reporterId,
    required String description,
    List<String>? removedImageUrls,
    List<File>? newImageFiles,
  }) async {
    // 1. Cập nhật mô tả (DB Trigger tự động phân loại lại priority)
    await _client.from('issue_reports').update({
      'description': description,
    }).eq('id', issueId);

    // 2. Xóa các ảnh được đánh dấu gỡ bỏ
    if (removedImageUrls != null && removedImageUrls.isNotEmpty) {
      await _client
          .from('issue_images')
          .delete()
          .eq('issue_report_id', issueId)
          .inFilter('image_url', removedImageUrls);

      try {
        final filePaths = <String>[];
        for (final url in removedImageUrls) {
          final uri = Uri.tryParse(url);
          if (uri != null) {
            final segments = uri.pathSegments;
            final bucketIndex = segments.indexOf('issue-images');
            if (bucketIndex != -1 && bucketIndex + 1 < segments.length) {
              filePaths.add(segments.sublist(bucketIndex + 1).join('/'));
            }
          }
        }
        if (filePaths.isNotEmpty) {
          await _client.storage.from('issue-images').remove(filePaths);
        }
      } catch (e) {
        AppLogger.w('Không thể xóa file ảnh cũ khỏi storage: $e');
      }
    }

    // 3. Tải lên các ảnh mới nếu có
    if (newImageFiles != null && newImageFiles.isNotEmpty) {
      for (int i = 0; i < newImageFiles.length; i++) {
        try {
          final file = newImageFiles[i];
          final fileExt = file.path.split('.').last;
          final fileName = '$reporterId/$issueId/${DateTime.now().millisecondsSinceEpoch}_new_$i.$fileExt';

          await _client.storage.from('issue-images').upload(fileName, file);

          final imageUrl = _client.storage.from('issue-images').getPublicUrl(fileName);

          await _client.from('issue_images').insert({
            'issue_report_id': issueId,
            'image_url': imageUrl,
          });
        } catch (e, stack) {
          AppLogger.e('Lỗi tải ảnh mới khi chỉnh sửa sự cố: $e', e, stack);
        }
      }
    }
  }
}
