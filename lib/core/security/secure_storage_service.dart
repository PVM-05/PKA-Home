import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_config.dart';

/// Bản ghi lưu trữ Signed URL trong bộ nhớ đệm
class SignedUrlCacheEntry {
  final String url;
  final DateTime expiresAt;

  const SignedUrlCacheEntry({
    required this.url,
    required this.expiresAt,
  });

  /// Kiểm tra URL còn hạn sử dụng (có trừ hao an toàn 60 giây)
  bool get isValid => DateTime.now().isBefore(expiresAt.subtract(const Duration(seconds: 60)));
}

typedef StorageUrlGenerator = Future<String> Function(String bucket, String path, int expiresIn);

/// Dịch vụ quản lý truy cập tệp tin riêng tư qua Signed URLs kèm cơ chế bộ nhớ đệm
class SecureStorageService {
  final SupabaseClient? client;
  final StorageUrlGenerator? urlGenerator;

  /// In-memory cache lưu các signed URLs theo khóa `bucket:path`
  final Map<String, SignedUrlCacheEntry> _cache = {};

  SecureStorageService({
    this.client,
    this.urlGenerator,
  });

  SupabaseClient get _effectiveClient => client ?? SupabaseConfig.client;

  String _cacheKey(String bucket, String path) => '$bucket:$path';

  /// Tạo đường dẫn chuẩn hóa cho tệp tin riêng tư
  String formatSecurePath({
    required String buildingId,
    required String category,
    required String fileName,
  }) {
    final cleanFileName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '$buildingId/$category/${timestamp}_$cleanFileName';
  }

  /// Lấy Temporary Signed URL truy cập tệp tin trong Private Bucket
  Future<String> getSignedUrl({
    required String bucket,
    required String path,
    int expiresInSeconds = 1800, // 30 phút mặc định
  }) async {
    final key = _cacheKey(bucket, path);
    final cached = _cache[key];

    // Trả về từ cache nếu URL còn hạn sử dụng
    if (cached != null && cached.isValid) {
      return cached.url;
    }

    try {
      String signedUrl;
      if (urlGenerator != null) {
        signedUrl = await urlGenerator!(bucket, path, expiresInSeconds);
      } else {
        signedUrl = await _effectiveClient.storage
            .from(bucket)
            .createSignedUrl(path, expiresInSeconds);
      }

      final expiresAt = DateTime.now().add(Duration(seconds: expiresInSeconds));
      _cache[key] = SignedUrlCacheEntry(url: signedUrl, expiresAt: expiresAt);
      return signedUrl;
    } catch (e) {
      debugPrint('[SecureStorageService] Lỗi tạo signed URL cho $bucket/$path: $e');
      rethrow;
    }
  }

  /// Xóa cache cho 1 tệp tin cụ thể
  void invalidateCache({required String bucket, required String path}) {
    _cache.remove(_cacheKey(bucket, path));
  }

  /// Xóa toàn bộ bộ nhớ đệm Signed URLs
  void clearAllCache() {
    _cache.clear();
  }
}

/// Riverpod Provider cung cấp SecureStorageService dùng chung toàn ứng dụng
final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

