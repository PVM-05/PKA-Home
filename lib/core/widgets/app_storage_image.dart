import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_skeleton_shimmer.dart';

class _CachedUrl {
  final String url;
  final DateTime expiresAt;
  _CachedUrl(this.url, this.expiresAt);
  bool get isValid => DateTime.now().isBefore(expiresAt);
}

/// Widget hiển thị ảnh từ Supabase Storage thông minh:
/// - Tự động nhận diện Object Path (vd: staffId/issueId/proof.jpg) hoặc URL công khai
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

  const AppStorageImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
  });

  static final Map<String, _CachedUrl> _cache = {};

  /// Chuyển đổi một chuỗi image_url (có thể là object path hoặc URL) thành Signed URL dùng được
  static Future<String> resolveSignedUrl(String urlOrPath, {int expiresInSeconds = 3600}) async {
    final trimmed = urlOrPath.trim();
    if (trimmed.isEmpty) return '';

    // Nếu là URL bên ngoài (không thuộc issue-images, ví dụ ảnh placeholder)
    if ((trimmed.startsWith('http://') || trimmed.startsWith('https://')) &&
        !trimmed.contains('issue-images')) {
      return trimmed;
    }

    // Trích xuất object path
    String objectPath = trimmed;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      try {
        final uri = Uri.parse(trimmed);
        final segments = uri.pathSegments;
        final bucketIndex = segments.indexOf('issue-images');
        if (bucketIndex != -1 && bucketIndex + 1 < segments.length) {
          objectPath = segments.sublist(bucketIndex + 1).join('/');
        }
      } catch (_) {
        return trimmed;
      }
    }

    // Kiểm tra cache
    final cached = _cache[objectPath];
    if (cached != null && cached.isValid) {
      return cached.url;
    }

    try {
      final signedUrl = await Supabase.instance.client.storage
          .from('issue-images')
          .createSignedUrl(objectPath, expiresInSeconds);
      _cache[objectPath] = _CachedUrl(
        signedUrl,
        DateTime.now().add(Duration(seconds: expiresInSeconds - 60)),
      );
      return signedUrl;
    } catch (_) {
      // Fallback: nếu không tạo được signed URL, trả về chuỗi gốc
      return trimmed;
    }
  }

  /// Resolve danh sách URL phục vụ phóng to ảnh (PhotoViewerScreen)
  static Future<List<String>> resolveSignedUrlList(List<String> list) async {
    return Future.wait(list.map((item) => resolveSignedUrl(item)));
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
    final trimmed = widget.imageUrl.trim();
    final cached = AppStorageImage._cache[trimmed];
    if (cached != null && cached.isValid) {
      _resolvedUrl = cached.url;
      _isLoading = false;
    } else {
      _loadUrl();
    }
  }

  @override
  void didUpdateWidget(covariant AppStorageImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      final trimmed = widget.imageUrl.trim();
      final cached = AppStorageImage._cache[trimmed];
      if (cached != null && cached.isValid) {
        setState(() {
          _resolvedUrl = cached.url;
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
      final url = await AppStorageImage.resolveSignedUrl(widget.imageUrl);
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
