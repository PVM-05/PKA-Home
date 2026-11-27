import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_skeleton_shimmer.dart';

class _CachedUrl {
  final String url;
  final DateTime expiresAt;
  _CachedUrl(this.url, this.expiresAt);
  bool get isValid => DateTime.now().isBefore(expiresAt);
}

/// Thông tin bucket và object path sau khi phân tích từ URL hoặc đường dẫn lưu trữ.
class StorageObjectTarget {
  final String bucket;
  final String objectPath;

  const StorageObjectTarget({
    required this.bucket,
    required this.objectPath,
  });

  String get cacheKey => '$bucket:$objectPath';
}

/// Widget hiển thị ảnh từ Supabase Storage thông minh:
/// - Tự động nhận diện Object Path (vd: staffId/issueId/proof.jpg) hoặc URL công khai
/// - Hỗ trợ đa bucket (issue-images, vehicle-docs, handover-docs)
/// - Tự động sinh và làm mới Signed URL đối với private bucket
/// - Có bộ nhớ đệm (cache) giúp tối ưu hiệu năng không gọi thừa API tạo Signed URL
class AppStorageImage extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final String defaultBucket;

  const AppStorageImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    this.defaultBucket = 'issue-images',
  });

  static const List<String> _knownBuckets = [
    'issue-images',
    'vehicle-docs',
    'handover-docs',
    'meter-readings',
  ];

  static final Map<String, _CachedUrl> _cache = {};

  /// Tách bucket và object path từ đường dẫn hoặc URL Supabase Storage.
  /// Trả về null nếu là URL bên ngoài không thuộc các bucket được quản lý.
  static StorageObjectTarget? parseStorageTarget(
    String urlOrPath, {
    String defaultBucket = 'issue-images',
  }) {
    final trimmed = urlOrPath.trim();
    if (trimmed.isEmpty) return null;

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      try {
        final uri = Uri.parse(trimmed);
        final segments = uri.pathSegments;
        for (final bucket in _knownBuckets) {
          final bucketIndex = segments.indexOf(bucket);
          if (bucketIndex != -1 && bucketIndex + 1 < segments.length) {
            return StorageObjectTarget(
              bucket: bucket,
              objectPath: segments.sublist(bucketIndex + 1).join('/'),
            );
          }
        }
        return null;
      } catch (_) {
        return null;
      }
    }

    final normalized = trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;
    for (final bucket in _knownBuckets) {
      final prefix = '$bucket/';
      if (normalized.startsWith(prefix)) {
        return StorageObjectTarget(
          bucket: bucket,
          objectPath: normalized.substring(prefix.length),
        );
      }
    }

    if (defaultBucket == 'issue-images' &&
        (normalized.startsWith('signatures/') || normalized.startsWith('photos/'))) {
      return StorageObjectTarget(
        bucket: 'handover-docs',
        objectPath: normalized,
      );
    }

    return StorageObjectTarget(
      bucket: defaultBucket,
      objectPath: normalized,
    );
  }

  /// Trả về Signed URL đã cache nếu còn hạn.
  static String? getCachedSignedUrl(
    String urlOrPath, {
    String defaultBucket = 'issue-images',
  }) {
    final target = parseStorageTarget(urlOrPath, defaultBucket: defaultBucket);
    if (target == null) return null;
    final cached = _cache[target.cacheKey];
    if (cached != null && cached.isValid) {
      return cached.url;
    }
    return null;
  }

  /// Chuyển đổi một chuỗi image_url (có thể là object path hoặc URL) thành Signed URL dùng được
  static Future<String> resolveSignedUrl(
    String urlOrPath, {
    int expiresInSeconds = 3600,
    String defaultBucket = 'issue-images',
  }) async {
    final trimmed = urlOrPath.trim();
    if (trimmed.isEmpty) return '';

    final target = parseStorageTarget(trimmed, defaultBucket: defaultBucket);
    if (target == null) {
      return trimmed;
    }

    // Nếu đã là URL có sẵn token (đã sign) thì giữ nguyên
    if ((trimmed.startsWith('http://') || trimmed.startsWith('https://')) &&
        trimmed.contains('token=')) {
      return trimmed;
    }

    final cached = _cache[target.cacheKey];
    if (cached != null && cached.isValid) {
      return cached.url;
    }

    try {
      final signedUrl = await Supabase.instance.client.storage
          .from(target.bucket)
          .createSignedUrl(target.objectPath, expiresInSeconds);
      _cache[target.cacheKey] = _CachedUrl(
        signedUrl,
        DateTime.now().add(Duration(seconds: expiresInSeconds - 60)),
      );
      return signedUrl;
    } catch (_) {
      return trimmed;
    }
  }

  /// Resolve danh sách URL phục vụ phóng to ảnh (PhotoViewerScreen)
  static Future<List<String>> resolveSignedUrlList(
    List<String> list, {
    String defaultBucket = 'issue-images',
  }) async {
    return Future.wait(
      list.map((item) => resolveSignedUrl(item, defaultBucket: defaultBucket)),
    );
  }

  @override
  State<AppStorageImage> createState() => _AppStorageImageState();
}

class _AppStorageImageState extends State<AppStorageImage> {
  String? _resolvedUrl;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    final cachedUrl = AppStorageImage.getCachedSignedUrl(
      widget.imageUrl,
      defaultBucket: widget.defaultBucket,
    );
    if (cachedUrl != null) {
      _resolvedUrl = cachedUrl;
      _isLoading = false;
    } else {
      _loadUrl();
    }
  }

  @override
  void didUpdateWidget(covariant AppStorageImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.defaultBucket != widget.defaultBucket) {
      final cachedUrl = AppStorageImage.getCachedSignedUrl(
        widget.imageUrl,
        defaultBucket: widget.defaultBucket,
      );
      if (cachedUrl != null) {
        setState(() {
          _resolvedUrl = cachedUrl;
          _isLoading = false;
          _hasError = false;
        });
      } else {
        _loadUrl();
      }
    }
  }

  Future<void> _loadUrl() async {
    if (widget.imageUrl.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
      return;
    }

    try {
      final url = await AppStorageImage.resolveSignedUrl(
        widget.imageUrl,
        defaultBucket: widget.defaultBucket,
      );
      if (mounted) {
        setState(() {
          _resolvedUrl = url;
          _isLoading = false;
          _hasError = url.isEmpty;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content;

    final defaultPlaceholder = AppSkeletonShimmer.rectangular(
      width: widget.width,
      height: widget.height,
      borderRadius: widget.borderRadius ?? BorderRadius.zero,
    );

    if (_isLoading) {
      content = widget.placeholder ?? defaultPlaceholder;
    } else if (_hasError || _resolvedUrl == null || _resolvedUrl!.isEmpty) {
      content = widget.errorWidget ??
          Container(
            width: widget.width,
            height: widget.height,
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
            child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
          );
    } else {
      final dpr = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 2.0;
      final cacheW = widget.width != null && widget.width!.isFinite ? (widget.width! * dpr).round() : null;
      final cacheH = widget.height != null && widget.height!.isFinite ? (widget.height! * dpr).round() : null;

      content = Image.network(
        _resolvedUrl!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        cacheWidth: cacheW,
        cacheHeight: cacheH,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return widget.placeholder ?? defaultPlaceholder;
        },
        errorBuilder: (context, error, stackTrace) =>
            widget.errorWidget ??
            Container(
              width: widget.width,
              height: widget.height,
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
              child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
            ),
      );
    }

    if (widget.borderRadius != null) {
      return ClipRRect(
        borderRadius: widget.borderRadius!,
        child: content,
      );
    }

    return content;
  }
}
